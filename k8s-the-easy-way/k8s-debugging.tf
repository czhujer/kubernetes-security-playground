# gadget

data "local_file" "gadget" {
  filename = "k8s-manifests/inspektor-gadget-all.yaml"
}

resource "kubectl_manifest" "gadget" {
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
        "\n${replace(data.local_file.gadget.content, "/(?m)^---[[:blank:]]*(#.*)?$/", "---")}\n"
      ) :
      yaml
      if trimspace(replace(yaml, "/(?m)(^[[:blank:]]*(#.*)?$)+/", "")) != ""
    ] : "${value}" => value
  }
  yaml_body = each.value
  wait      = true
  depends_on = [digitalocean_droplet.control_plane,
  helm_release.cilium]
}