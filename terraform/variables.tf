variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project" {
  type    = string
  default = "repairdesk"
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# ── Domain ────────────────────────────────────────────────────────────────────
variable "domain_name" {
  description = "Your GoDaddy domain e.g. repairdesk.com"
  type        = string
}

variable "api_subdomain" {
  type    = string
  default = "api"
}

# ── ECS ───────────────────────────────────────────────────────────────────────
variable "app_image" {
  description = "ECR image URI — overridden by GitHub Actions after first push"
  type        = string
  default     = "placeholder"
}

variable "app_port" {
  type    = number
  default = 5000
}

variable "task_cpu" {
  description = "256 = 0.25 vCPU — cheapest Fargate option"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "512 MB — cheapest Fargate option"
  type        = number
  default     = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

# ── Secrets ───────────────────────────────────────────────────────────────────
variable "mongo_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
}
