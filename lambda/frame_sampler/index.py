"""
Lambda function to sample frames from AWS IVS stream and send to n8n.

This function:
1. Gets the current stream state from IVS
2. If stream is live, captures a thumbnail/frame
3. Sends the frame data to n8n webhook for analysis
"""

import os
import json
import base64
import boto3
import urllib3
from datetime import datetime
from typing import Dict, Any, Optional

# Initialize clients
ivs_client = boto3.client('ivs')
http = urllib3.PoolManager()

# Environment variables
IVS_CHANNEL_ARN = os.environ['IVS_CHANNEL_ARN']
N8N_WEBHOOK_URL = os.environ['N8N_WEBHOOK_URL']
AWS_REGION = os.environ.get('AWS_REGION', 'ap-southeast-1')


def get_stream_info(channel_arn: str) -> Optional[Dict[str, Any]]:
    """
    Get information about the current stream.
    
    Returns:
        Stream info dict if stream is live, None otherwise
    """
    try:
        response = ivs_client.get_stream(channelArn=channel_arn)
        stream = response.get('stream', {})
        
        # Check if stream is active
        state = stream.get('state', 'OFFLINE')
        if state == 'LIVE':
            return {
                'state': state,
                'health': stream.get('health', 'UNKNOWN'),
                'viewer_count': stream.get('viewerCount', 0),
                'start_time': stream.get('startTime').isoformat() if stream.get('startTime') else None,
                'playback_url': stream.get('playbackUrl', ''),
            }
        
        print(f"Stream is not live. Current state: {state}")
        return None
        
    except ivs_client.exceptions.ChannelNotBroadcasting:
        print("Channel is not currently broadcasting")
        return None
    except Exception as e:
        print(f"Error getting stream info: {str(e)}")
        return None


def get_stream_thumbnail(channel_arn: str) -> Optional[str]:
    """
    Get a thumbnail from the current stream.
    
    For IVS, we can use the playback URL to get thumbnails.
    In production, you might want to use MediaLive or capture frames directly.
    
    Returns:
        Base64 encoded thumbnail image or None
    """
    try:
        # Get channel info to get playback URL
        channel_response = ivs_client.get_channel(arn=channel_arn)
        playback_url = channel_response['channel'].get('playbackUrl', '')
        
        if not playback_url:
            print("No playback URL available")
            return None
        
        # For IVS, thumbnails are available at: playback_url + "/latest.jpg"
        thumbnail_url = playback_url.replace('.m3u8', '/latest.jpg')
        
        # Fetch thumbnail
        response = http.request('GET', thumbnail_url, timeout=5.0)
        
        if response.status == 200:
            # Encode image to base64
            image_base64 = base64.b64encode(response.data).decode('utf-8')
            return image_base64
        else:
            print(f"Failed to fetch thumbnail. Status: {response.status}")
            return None
            
    except Exception as e:
        print(f"Error getting thumbnail: {str(e)}")
        return None


def send_to_n8n(data: Dict[str, Any]) -> bool:
    """
    Send frame data to n8n webhook.
    
    Args:
        data: Dictionary containing frame data
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Prepare payload
        payload = json.dumps(data).encode('utf-8')
        
        # Send to n8n
        response = http.request(
            'POST',
            N8N_WEBHOOK_URL,
            body=payload,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'AWS-Lambda-Frame-Sampler'
            },
            timeout=10.0
        )
        
        if response.status in [200, 201, 202]:
            print(f"Successfully sent data to n8n. Status: {response.status}")
            return True
        else:
            print(f"Failed to send data to n8n. Status: {response.status}, Response: {response.data}")
            return False
            
    except Exception as e:
        print(f"Error sending data to n8n: {str(e)}")
        return False


def handler(event, context):
    """
    Lambda handler function.
    
    Args:
        event: EventBridge event
        context: Lambda context
        
    Returns:
        Response dictionary
    """
    print(f"Frame sampler invoked at {datetime.utcnow().isoformat()}")
    print(f"Channel ARN: {IVS_CHANNEL_ARN}")
    
    try:
        # Get stream info
        stream_info = get_stream_info(IVS_CHANNEL_ARN)
        
        if not stream_info:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Stream is not live, no frame captured',
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        print(f"Stream is live. Health: {stream_info['health']}, Viewers: {stream_info['viewer_count']}")
        
        # Get thumbnail
        thumbnail_base64 = get_stream_thumbnail(IVS_CHANNEL_ARN)
        
        # Prepare data for n8n
        frame_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'channel_arn': IVS_CHANNEL_ARN,
            'stream_info': stream_info,
            'frame': {
                'format': 'jpeg',
                'encoding': 'base64',
                'data': thumbnail_base64 if thumbnail_base64 else None
            },
            'metadata': {
                'aws_region': AWS_REGION,
                'lambda_request_id': context.request_id,
                'sampler_version': '1.0.0'
            }
        }
        
        # Send to n8n
        success = send_to_n8n(frame_data)
        
        return {
            'statusCode': 200 if success else 500,
            'body': json.dumps({
                'message': 'Frame captured and sent to n8n' if success else 'Failed to send frame to n8n',
                'timestamp': datetime.utcnow().isoformat(),
                'stream_state': stream_info['state'],
                'frame_captured': thumbnail_base64 is not None
            })
        }
        
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing frame',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }


# For local testing
if __name__ == "__main__":
    # Mock event and context
    class MockContext:
        request_id = "test-request-id"
    
    result = handler({}, MockContext())
    print(json.dumps(result, indent=2))

