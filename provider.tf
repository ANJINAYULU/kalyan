# terraform {
#   required_providers {
#     aws = {
#       source = "hashicorp/aws"
#       version = "3.51.0"
#       region = var.region
#     }
#   }
# }


provider "aws" {
  region = var.region
}