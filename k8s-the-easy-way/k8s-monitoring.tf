# protmetheus-stack
#
data "kubectl_file_documents" "argocd_prometheus_crds" {
  content = format("%s---\n%s",
    file("../argocd/projects/system-monitoring.yaml"),
    file("../argocd/prometheus-stack-crds.yaml")
  )
}

resource "kubectl_manifest" "argocd_prometheus_crds" {
  for_each   = data.kubectl_file_documents.argocd_prometheus_crds.manifests
  yaml_body  = each.value
  wait       = true
  depends_on = [helm_release.argocd]
}

data "kubectl_file_documents" "argocd_prometheus" {
  content = format("%s---\n%s",
    file("../argocd/prometheus-stack.yaml"),
    file("../argocd/prometheus-adapter.yaml")
  )
}

resource "kubectl_manifest" "argocd_prometheus" {
  for_each  = data.kubectl_file_documents.argocd_prometheus.manifests
  yaml_body = each.value
  wait      = true
  depends_on = [helm_release.argocd,
    kubectl_manifest.argocd_prometheus_crds
  ]
}

# Loki stack
#
data "kubectl_file_documents" "argocd_loki" {
  content = format("%s---\n%s---\n%s",
    file("../argocd/projects/system-logging.yaml"),
    file("../argocd/logging-loki.yaml"),
    file("../argocd/logging-promtail.yaml")
  )
}

resource "kubectl_manifest" "argocd_loki" {
  for_each   = data.kubectl_file_documents.argocd_loki.manifests
  yaml_body  = each.value
  wait       = true
  depends_on = [helm_release.argocd]
}
