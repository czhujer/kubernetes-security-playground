# gitops stuff
#
resource "helm_release" "argocd" {
  name             = "argocd-single"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "4.10.0"
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
    value = "argocd.${var.do_external_lb_ip}.nip.io"
    type  = "string"
  }

  set {
    name  = "server.ingress.tls[0].secretName"
    value = "argocd-tls-certificate"
    type  = "string"
  }

  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "argocd.${var.do_external_lb_ip}.nip.io"
    type  = "string"
  }

  set {
    name  = "server.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "selfsigned-issuer"
    type  = "string"
  }

  depends_on = [helm_release.cilium,
    digitalocean_droplet.worker,
    kubectl_manifest.do_ccm
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

## argocd-image-updater
#
data "kubectl_file_documents" "argocd_image_updater" {
  content = file("../argocd/argocd-image-updater.yaml")
}

resource "kubectl_manifest" "argocd_image_updater" {
  yaml_body  = data.kubectl_file_documents.argocd_image_updater.content
  depends_on = [helm_release.argocd]
}
