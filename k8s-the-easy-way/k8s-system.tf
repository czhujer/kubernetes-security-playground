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
}

# kubectl apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/v0.1.24.yml

# ingress
data "kubectl_file_documents" "argo_nginx_ingress" {
  content = file("argocd/nginx-ingress.yaml")
}

resource "kubectl_manifest" "argo_nginx_ingress" {
  yaml_body  = data.kubectl_file_documents.argo_nginx_ingress.content
  depends_on = [helm_release.argocd]
}

data "kubectl_file_documents" "argo_gateway_api_crds" {
  content = file("../argocd/gateway-api-crds.yaml")
}

resource "kubectl_manifest" "argo_gateway_api_crds" {
  yaml_body  = data.kubectl_file_documents.argo_gateway_api_crds.content
  depends_on = [helm_release.argocd]
}

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
  ]
}
