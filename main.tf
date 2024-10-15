provider "aws" {
  region = "us-east-1"
}

resource "aws_kms_key" "dynamodb_kms" {
  description             = "KMS key for DynamoDB encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_dynamodb_table" "customers" {
  name           = "Customers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "customerID"
  
  attribute {
    name = "customerID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_kms.arn
  }

  tags = {
    Name        = "Customers"
    Environment = "production"
  }
}

resource "aws_iam_role" "dynamodb_role" {
  name = "DynamoDBAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "dynamodb_policy" {
  name = "DynamoDBAccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.customers.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_attach_policy" {
  role       = aws_iam_role.dynamodb_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_vpc_endpoint" "dynamodb_endpoint" {
  vpc_id       = aws_vpc.main_vpc.id
  service_name = "com.amazonaws.us-east-1.dynamodb"
}

resource "aws_cloudwatch_log_group" "dynamodb_log_group" {
  name              = "/aws/dynamodb"
  retention_in_days = 30
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_alarm" {
  alarm_name          = "DynamoDBHighLatencyAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000

  dimensions = {
    TableName = aws_dynamodb_table.customers.name
  }

  alarm_actions = ["arn:aws:sns:us-east-1:123456789012:NotifyMe"]
}
