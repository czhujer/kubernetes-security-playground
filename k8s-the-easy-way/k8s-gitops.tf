# gitops stuff
#
resource "helm_release" "argocd" {
  name             = "argocd-single"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "4.5.7"
  namespace        = "argocd"
  create_namespace = "true"

  values = [
    file("../kind/kind-values-argocd.yaml"),
    file("../kind/kind-values-argocd-service-monitors.yaml")
  ]

  set {
    name  = "global.image.imagePullPolicy"
    value = "Always"
    type  = "string"
  }

  set {
    name  = "repoServer.image.imagePullPolicy"
    value = "Always"
    type  = "string"
  }

  set {
    name  = "redis.image.imagePullPolicy"
    value = "Always"
    type  = "string"
  }

  set {
    name  = "redis.metrics.image.imagePullPolicy"
    value = "Always"
    type  = "string"
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = "argocd.67.207.76.143.nip.io"
    type  = "string"
  }

  depends_on = [helm_release.cilium,
    digitalocean_droplet.worker,
  ]
}

## update CRDs
#
data "kubectl_file_documents" "argo_cd_crds" {
  content = file("../argocd/argo-cd-crds.yaml")
}

resource "kubectl_manifest" "argo_cd_crds" {
  yaml_body  = data.kubectl_file_documents.argo_cd_crds.content
  depends_on = [helm_release.argocd]
}
