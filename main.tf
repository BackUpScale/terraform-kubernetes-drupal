terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.23"
    }
    civo = {
      source = "civo/civo"
      version = "~> 1.0"
    }
  }
}
