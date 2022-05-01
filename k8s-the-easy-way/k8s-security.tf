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
