
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

#helm repo add argo https://argoproj.github.io/argo-helm
#helm upgrade --install \
#argocd-single \
#argo/argo-cd \
#--namespace argocd \
#--create-namespace \
#--version "${ARGOCD_CHART_VERSION}" \
#-f kind/kind-values-argocd.yaml \
#-f kind/kind-values-argocd-service-monitors.yaml \
#--wait
## update CRDs
#kubectl -n argocd apply -f argocd/argo-cd-crds.yaml

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

  depends_on = [digitalocean_droplet.control_plane,
    digitalocean_droplet.worker,
  ]
}