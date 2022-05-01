## system stuff
#

# CCM
resource "kubectl_manifest" "ccm_secret" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: ${var.do_token}
YAML
  depends_on = [digitalocean_droplet.control_plane]
}

data "kubectl_file_documents" "ccm_do" {
  content = file("k8s-manifests/digitalocean-cloud-controller-manager-v0.1.37.yaml")
}

resource "kubectl_manifest" "ccm_do" {
  for_each  = data.kubectl_file_documents.ccm_do.manifests
  yaml_body = each.value
  wait      = true
  depends_on = [helm_release.cilium,
  kubectl_manifest.ccm_secret]
}

# ingress
data "kubectl_file_documents" "argo_nginx_ingress" {
  content = file("argocd/nginx-ingress.yaml")
}

resource "kubectl_manifest" "argo_nginx_ingress" {
  yaml_body  = data.kubectl_file_documents.argo_nginx_ingress.content
  wait       = true
  depends_on = [helm_release.argocd]
}

data "kubectl_file_documents" "argo_gateway_api_crds" {
  content = file("../argocd/gateway-api-crds.yaml")
}

resource "kubectl_manifest" "argo_gateway_api_crds" {
  yaml_body  = data.kubectl_file_documents.argo_gateway_api_crds.content
  depends_on = [helm_release.argocd]
}

# fetch nginx service external ip-address for ingress hosts
#
#data "kubernetes_service" "ingress-nginx-nginx-ingress-ingress-nginx-controller" {
#  metadata {
#    name      = "nginx-ingress-ingress-nginx-controller"
#    namespace = "ingress-nginx"
#  }
#}

#output "ingress_external_ip" {
#  value = data.kubernetes_service.ingress-nginx-nginx-ingress-ingress-nginx-controller.status.0.load_balancer.0.ingress.0.ip
#}

# cert-manager
resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.8.0"
  namespace        = "cert-manager"
  create_namespace = "true"

  values = [
    file("../kind/cert-manager.yaml")
  ]

  depends_on = [digitalocean_droplet.control_plane,
    digitalocean_droplet.worker,
    kubectl_manifest.ccm_do,
  ]
}
