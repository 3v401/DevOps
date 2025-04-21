variable "my_ip" {
  description = "Your public IP with /32 mask"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alerts"
  type        = string
}

variable "bastion_public_key_path" {
  description = "Path to the bastion public key"
  type        = string
}

variable "api_public_key_path" {
  description = "Path to the API public key"
  type        = string
}

variable "jenkins_public_key_path" {
  description = "Path to the jenkins public key"
  type        = string
}

variable "scanner_public_key_path" {
  description = "Path to the scanner public key"
  type        = string
}

variable "monitoring_public_key_path" {
  description = "Path to the monitoring public key"
  type        = string
}