# Lambda Module for Frame Sampling
# Samples frames from IVS stream and sends to n8n

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name_prefix = "${var.project_name}-${var.environment}-lambda-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-lambda-role"
    }
  )
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda" {
  name_prefix = "${var.project_name}-${var.environment}-lambda-policy-"
  role        = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ivs:GetStream",
          "ivs:ListStreams",
          "ivs:GetChannel"
        ]
        Resource = var.ivs_channel_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-${var.environment}-lambda-"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-lambda-sg"
    }
  )
}

# Package Lambda function
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/frame_sampler"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "frame_sampler" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-${var.environment}-frame-sampler"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.timeout
  memory_size     = var.memory_size
  architectures   = ["arm64"] # Graviton2 for 20% cost savings

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      IVS_CHANNEL_ARN = var.ivs_channel_arn
      N8N_WEBHOOK_URL = var.n8n_webhook_url
      # AWS_REGION is automatically provided by Lambda runtime
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-frame-sampler"
    }
  )

  depends_on = [aws_iam_role_policy.lambda]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.frame_sampler.function_name}"
  retention_in_days = 7 # Keep logs for 7 days only (dev)

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-lambda-logs"
    }
  )
}

# EventBridge Rule for periodic invocation
resource "aws_cloudwatch_event_rule" "frame_sampling" {
  name_prefix         = "${var.project_name}-${var.environment}-frame-sampling-"
  description         = "Trigger Lambda to sample frames every ${var.frame_sample_rate} minute(s)"
  schedule_expression = "rate(${var.frame_sample_rate} ${var.frame_sample_rate == 1 ? "minute" : "minutes"})"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-frame-sampling-rule"
    }
  )
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.frame_sampling.name
  target_id = "FrameSamplerLambda"
  arn       = aws_lambda_function.frame_sampler.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.frame_sampler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.frame_sampling.arn
}

data "aws_region" "current" {}

