# ----------------------------------------------------------------
# variables.tf
# ----------------------------------------------------------------

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

variable "builder_public_key_path" {
  description = "Path to the builder public key"
  type        = string
}

variable "MY_DOMAIN" {
  description = "Target domain of the project"
  type        = string
}

variable "CLOUDFLARE_TOKEN" {
  description = "Cloudflre token for domain to pod connection"
  type        = string
}

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS Access Key ID"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS Secret Key ID"
  type        = string
}

variable "OPENAI_API_KEY" {
  description = "OpenAI API Key"
  type = string
}

variable "AWS_USER" {
  description = "AWS user"
  type = string
}