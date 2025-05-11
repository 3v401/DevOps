# S3 bucket:
# Goal: Store logs

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "myowaspproject3v401-logs"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = "eu-north-1a"
  size              = 15
  type              = "gp3"

  tags = {
    Name = "jenkins_data_volume"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "jenkins_data_attachment" {
  device_name = "/dev/xvdf"
  # Linux path to the created EBS volume
  volume_id   = aws_ebs_volume.jenkins_data.id
  instance_id = aws_instance.my_jenkins_EC2_instance.id
  force_detach = true
}