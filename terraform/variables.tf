variable "aws_region" {
  description = "AWS region"
  type = string
  default = "us-east-1"
}

variable "key_name" {
  description = "SSH key pair name"
  type = string
}
