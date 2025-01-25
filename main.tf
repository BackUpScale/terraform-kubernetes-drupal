terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    civo = {
      source = "civo/civo"
      version = "~> 1.0"
    }
  }
}
