# https://github.com/kubernetes/sig-release/blob/master/releases/patch-releases.md#timelines
variable "kubernetes_version" { default = "1.23.5" }
# https://docs.docker.com/engine/release-notes/
variable "docker_version" { default = "20.10.8" }
# Note: Cilium no longer releases a deployment file and rely on helm now.
# to generate:
# helm template cilium cilium/cilium --version 1.10.4 --namespace kube-system > cilium-install.yaml
# https://github.com/cilium/cilium/releases
# variable "cilium_version" { default = "1.10.4" }
variable "pod_subnet" { default = "10.217.0.0/16" }
# https://www.digitalocean.com/docs/platform/availability-matrix/#datacenter-regions
variable "dc_region" { default = "fra1" }
# https://developers.digitalocean.com/documentation/v2/#list-all-sizes
# setting below 2 CPUs will fail kubeadm, ignore with `--ignore-preflight-errors=all`
variable "droplet_size" { default = "s-2vcpu-2gb" }
# set with `export DO_PAT=<API TOKEN>`
variable "do_token" {}
# set in `*-cluster.sh` scripts
variable "pub_key" {}
variable "pvt_key" {}

variable "cilium_helm_chart_version" {
  default = "1.11.4"
}
