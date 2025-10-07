# AWS IVS Module
# Creates IVS channel for live streaming

resource "aws_ivs_channel" "main" {
  name          = "${var.project_name}-${var.environment}-channel"
  latency_mode  = "LOW" # LOW latency for better interaction
  type          = var.channel_type
  authorized    = false # Public channel, no authorization needed

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ivs-channel"
    }
  )
}

# List stream keys for the channel (IVS auto-creates one stream key per channel)
resource "null_resource" "get_stream_key" {
  triggers = {
    channel_arn = aws_ivs_channel.main.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ivs list-stream-keys \
        --channel-arn ${aws_ivs_channel.main.arn} \
        --region ${var.aws_region} \
        --output json > ${path.module}/stream_keys_list.json
    EOT
  }

  depends_on = [aws_ivs_channel.main]
}

# Get the stream key details
resource "null_resource" "get_stream_key_value" {
  triggers = {
    channel_arn = aws_ivs_channel.main.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      STREAM_KEY_ARN=$(jq -r '.streamKeys[0].arn' ${path.module}/stream_keys_list.json)
      aws ivs get-stream-key \
        --arn "$STREAM_KEY_ARN" \
        --region ${var.aws_region} \
        --output json > ${path.module}/stream_key.json
    EOT
  }

  depends_on = [null_resource.get_stream_key]
}

# Read the stream key value from the file
data "local_file" "stream_key" {
  filename   = "${path.module}/stream_key.json"
  depends_on = [null_resource.get_stream_key_value]
}

# S3 Bucket for recording (optional, can be enabled later)
resource "aws_s3_bucket" "recordings" {
  count = var.recording_enabled ? 1 : 0

  bucket_prefix = "${var.project_name}-${var.environment}-recordings-"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-recordings"
    }
  )
}

resource "aws_s3_bucket_versioning" "recordings" {
  count = var.recording_enabled ? 1 : 0

  bucket = aws_s3_bucket.recordings[0].id
  
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  count = var.recording_enabled ? 1 : 0

  bucket = aws_s3_bucket.recordings[0].id

  rule {
    id     = "delete-old-recordings"
    status = "Enabled"

    filter {}  # Apply to all objects in the bucket

    expiration {
      days = 7 # Keep recordings for 7 days only
    }
  }
}

# Recording Configuration (optional)
resource "aws_ivs_recording_configuration" "main" {
  count = var.recording_enabled ? 1 : 0

  name = "${var.project_name}-${var.environment}-recording-config"

  destination_configuration {
    s3 {
      bucket_name = aws_s3_bucket.recordings[0].id
    }
  }

  thumbnail_configuration {
    recording_mode = "INTERVAL"
    target_interval_seconds = 60 # Generate thumbnail every 60 seconds
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-recording-config"
    }
  )

  depends_on = [aws_s3_bucket.recordings]
}

