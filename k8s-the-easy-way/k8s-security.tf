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
data "http" "spo" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/v${var.security_profiles_operator_version}/deploy/operator.yaml"
  request_headers = {
    Accept = "application/json"
  }
}

resource "kubectl_manifest" "spo" {
  # Create a map { "yaml_doc" => yaml_doc } from the multi-document yaml text.
  # Each element is a separate kubernetes resource.
  # Must use \n---\n to avoid splitting on strings and comments containing "---".
  # YAML allows "---" to be the first and last line of a file, so make sure
  # raw yaml begins and ends with a newline.
  # The "---" can be followed by spaces, so need to remove those too.
  # Skip blocks that are empty or comments-only in case yaml began with a comment before "---".
  for_each = {
    for value in [
      for yaml in split(
        "\n---\n",
        "\n${replace(data.http.spo.body, "/(?m)^---[[:blank:]]*(#.*)?$/", "---")}\n"
      ) :
      yaml
      if trimspace(replace(yaml, "/(?m)(^[[:blank:]]*(#.*)?$)+/", "")) != ""
    ] : "${value}" => value
  }
  yaml_body = each.value
  wait      = true
  depends_on = [helm_release.cilium,
    kubectl_manifest.ccm_secret]
}
