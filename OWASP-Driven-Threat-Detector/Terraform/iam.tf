# IAM (Setup) Roles and Policies: Securely allow your EC2 instances and services to interact with AWS resources

# IAM Role:
# All EC2 instances must have:

resource "aws_iam_role" "my_ec2_instance_role" {
  name = "ec2_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "my_ec2_instance_role"
  }
}

# IAM Policy:

resource "aws_iam_policy" "my_ec2_basic_policy" {
  name        = "my_ec2_policy"
  path        = "/"
  description = "my_ec2_policy_description"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attach" {
  role       = aws_iam_role.my_ec2_instance_role.name
  policy_arn = aws_iam_policy.my_ec2_basic_policy.arn
}

resource "aws_iam_instance_profile" "my_ec2_instance_profile" {
  # This instance profile will be used by Jenkins, Monitoring, Scanner
    # Jenkins: Needs S3, logs, Terraform CLI, etc.
    # Monitoring: Sends metrics/logs to CloudWatch
    # Scanner: 	Downloads CVE data, uploads reports
  name = "my_ec2_instance_profile_description"
  role = aws_iam_role.my_ec2_instance_role.name
}