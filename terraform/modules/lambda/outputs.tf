output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.frame_sampler.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.frame_sampler.arn
}

output "function_role_arn" {
  description = "Lambda function IAM role ARN"
  value       = aws_iam_role.lambda.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "eventbridge_rule_name" {
  description = "EventBridge rule name"
  value       = aws_cloudwatch_event_rule.frame_sampling.name
}

