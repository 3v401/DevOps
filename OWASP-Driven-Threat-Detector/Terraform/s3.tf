# S3 bucket:
# Goal: Store logs

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "my-s3-bucket"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}