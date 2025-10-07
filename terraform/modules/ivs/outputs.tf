output "channel_arn" {
  description = "IVS Channel ARN"
  value       = aws_ivs_channel.main.arn
}

output "channel_id" {
  description = "IVS Channel ID"
  value       = aws_ivs_channel.main.id
}

output "ingest_endpoint" {
  description = "RTMPS ingest endpoint for OBS"
  value       = aws_ivs_channel.main.ingest_endpoint
}

output "playback_url" {
  description = "Playback URL for viewing stream"
  value       = aws_ivs_channel.main.playback_url
}

output "stream_key" {
  description = "Stream key for OBS (sensitive)"
  value       = try(jsondecode(data.local_file.stream_key.content).streamKey.value, "")
  sensitive   = true
}

output "recording_bucket_name" {
  description = "S3 bucket name for recordings"
  value       = var.recording_enabled ? aws_s3_bucket.recordings[0].id : null
}

