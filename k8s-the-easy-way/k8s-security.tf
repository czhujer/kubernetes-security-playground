## security stuff
#
data "kubectl_file_documents" "argocd_starboard_project" {
  content = file("../argocd/projects/security-starboard.yaml")
}

data "kubectl_file_documents" "argocd_starboard_app" {
  content = file("../argocd/security-starboard.yaml")
}

resource "kubectl_manifest" "argocd_starboard_project" {
  yaml_body          = data.kubectl_file_documents.argocd_starboard_project.content
  depends_on         = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_starboard_app" {
  yaml_body          = data.kubectl_file_documents.argocd_starboard_app.content
  depends_on         = [kubectl_manifest.argocd_starboard_project]
}
