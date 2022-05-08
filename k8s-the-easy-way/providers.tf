provider "digitalocean" {
  token = var.do_token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config_ktew"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config_ktew"
}

provider "kubernetes" {
  config_path = "~/.kube/config_ktew"
}
