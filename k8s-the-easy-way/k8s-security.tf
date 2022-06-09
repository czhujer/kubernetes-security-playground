## security stuff
#
data "kubectl_file_documents" "argocd_starboard_project" {
  content = file("../argocd/projects/security-starboard.yaml")
}

data "kubectl_file_documents" "argocd_starboard_app" {
  content = file("../argocd/security-starboard.yaml")
}

resource "kubectl_manifest" "argocd_starboard_project" {
  yaml_body  = data.kubectl_file_documents.argocd_starboard_project.content
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_starboard_app" {
  yaml_body  = data.kubectl_file_documents.argocd_starboard_app.content
  depends_on = [kubectl_manifest.argocd_starboard_project]
}

data "kubectl_file_documents" "argocd_starboard_sm" {
  content = file("./k8s-manifests/starboard-service-monitor.yaml")
}

resource "kubectl_manifest" "argocd_starboard_sm" {
  yaml_body  = data.kubectl_file_documents.argocd_starboard_sm.content
  depends_on = [kubectl_manifest.argocd_starboard_app]
}

data "kubectl_file_documents" "argocd_starboard_exporter" {
  content = file("../argocd/security-starboard-exporter.yaml")
}

resource "kubectl_manifest" "argocd_starboard_expoter" {
  yaml_body  = data.kubectl_file_documents.argocd_starboard_exporter.content
  depends_on = [kubectl_manifest.argocd_starboard_app]
}

# falco security
#
data "kubectl_file_documents" "argocd_falco" {
  content = format("%s---\n%s",
    file("../argocd/projects/security-falco.yaml"),
    file("../argocd/security-falco.yaml")
  )
}

resource "kubectl_manifest" "argocd_falco" {
  for_each   = data.kubectl_file_documents.argocd_falco.manifests
  yaml_body  = each.value
  wait       = true
  depends_on = [helm_release.argocd]
}

# SPO
data "kubectl_file_documents" "spo_ns" {
  content = file("./k8s-manifests/spo-ns.yaml")
}

resource "kubectl_manifest" "spo_ns" {
  yaml_body  = data.kubectl_file_documents.spo_ns.content
  wait       = true
  depends_on = [helm_release.argocd]
}

data "kubectl_file_documents" "argocd_spo_project" {
  content = file("../argocd/projects/security-profiles-operator.yaml")
}

data "kubectl_file_documents" "argocd_spo_app" {
  content = file("../argocd/security-profiles-operator.yaml")
}

resource "kubectl_manifest" "argocd_spo_project" {
  yaml_body  = data.kubectl_file_documents.argocd_spo_project.content
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_spo_app" {
  yaml_body  = data.kubectl_file_documents.argocd_spo_app.content
  depends_on = [kubectl_manifest.argocd_spo_project]
}

# https://github.com/kubernetes-sigs/security-profiles-operator/blob/v0.4.1/deploy/base/service.yaml
data "kubectl_file_documents" "spo_svc_metrics" {
  content = file("./k8s-manifests/spo-svc-metrics.yaml")
}

resource "kubectl_manifest" "spo_svc_metrics" {
  yaml_body  = data.kubectl_file_documents.spo_svc_metrics.content
  wait      = true
  depends_on = [kubectl_manifest.argocd_spo_app]
}
