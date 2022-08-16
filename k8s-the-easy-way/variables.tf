# https://github.com/kubernetes/sig-release/blob/master/releases/patch-releases.md#timelines
variable "kubernetes_version" { default = "1.24.3" }
# https://docs.docker.com/engine/release-notes/
# variable "docker_version" { default = "20.10.8" }
# k8s cluster bootstrap
variable "pod_subnet" { default = "10.217.0.0/16" }
# https://www.digitalocean.com/docs/platform/availability-matrix/#datacenter-regions
variable "dc_region" { default = "fra1" }
# https://developers.digitalocean.com/documentation/v2/#list-all-sizes
# setting below 2 CPUs will fail kubeadm, ignore with `--ignore-preflight-errors=all`
variable "droplet_size" { default = "s-4vcpu-8gb" }
# set with `export DO_PAT=<API TOKEN>`
variable "do_token" {}
# set in `*-cluster.sh` scripts
variable "pub_key" {}
variable "pvt_key" {}

variable "do_csi_version" {
  default = "v4.0.0"
}

variable "do_ccm_version" {
  default = "v0.1.37"
}

variable "do_external_lb_ip" {
  default = "68.183.240.71"
}
