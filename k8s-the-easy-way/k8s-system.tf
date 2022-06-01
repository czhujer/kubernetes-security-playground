## system stuff
#

# GVISOR AND RUNTIMECLASS
resource "null_resource" "set_label_for_gvisor" {
  provisioner "local-exec" {
    command = "export KUBECONFIG=$${HOME}/.kube/config_ktew; kubectl label node ${digitalocean_droplet.worker.0.name} runtimeclass=gvisor && kubectl label node ${digitalocean_droplet.worker.1.name} runtimeclass=gvisor"
  }
  depends_on = [digitalocean_droplet.control_plane,
  helm_release.cilium]
}

resource "kubectl_manifest" "runtimeclass_gvisor" {
  yaml_body = <<YAML
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    runtimeclass: gvisor
YAML
  depends_on = [digitalocean_droplet.control_plane,
  helm_release.cilium]
}

# DO TOKEN
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
  depends_on = [digitalocean_droplet.control_plane,
  helm_release.cilium]
}

# DO CSI
#
data "http" "do_csi_crds" {
  url = "https://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v4.0.0/crds.yaml"

  request_headers = {
    Accept = "application/json"
  }
}

resource "kubectl_manifest" "do_csi_crds" {
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
        "\n${replace(data.http.do_csi_crds.body, "/(?m)^---[[:blank:]]*(#.*)?$/", "---")}\n"
      ) :
      yaml
      if trimspace(replace(yaml, "/(?m)(^[[:blank:]]*(#.*)?$)+/", "")) != ""
    ] : "${value}" => value
  }
  yaml_body = each.value
  wait      = true
  depends_on = [digitalocean_droplet.control_plane,
  kubectl_manifest.ccm_secret]
}

data "http" "do_csi_driver" {
  url = "https://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v4.0.0/driver.yaml"

  request_headers = {
    Accept = "application/json"
  }
}

resource "kubectl_manifest" "do_csi_driver" {
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
        "\n${replace(data.http.do_csi_driver.body, "/(?m)^---[[:blank:]]*(#.*)?$/", "---")}\n"
      ) :
      yaml
      if trimspace(replace(yaml, "/(?m)(^[[:blank:]]*(#.*)?$)+/", "")) != ""
    ] : "${value}" => value
  }
  yaml_body = each.value
  wait      = true
  depends_on = [digitalocean_droplet.control_plane,
    kubectl_manifest.ccm_secret,
  kubectl_manifest.do_csi_crds]
}

data "http" "do_csi_snapshot_controller" {
  url = "https://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v4.0.0/snapshot-controller.yaml"

  request_headers = {
    Accept = "application/json"
  }
}

resource "kubectl_manifest" "do_csi_snapshot_controller" {
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
        "\n${replace(data.http.do_csi_snapshot_controller.body, "/(?m)^---[[:blank:]]*(#.*)?$/", "---")}\n"
      ) :
      yaml
      if trimspace(replace(yaml, "/(?m)(^[[:blank:]]*(#.*)?$)+/", "")) != ""
    ] : "${value}" => value
  }
  yaml_body = each.value
  wait      = true
  depends_on = [digitalocean_droplet.control_plane,
    kubectl_manifest.ccm_secret,
  kubectl_manifest.do_csi_crds]
}

# TODO: add snapshot-validation-webhook
# https://github.com/digitalocean/csi-digitalocean/blob/master/deploy/kubernetes/releases/csi-digitalocean-v4.0.0/snapshot-validation-webhook.yaml

# CCM
data "kubectl_file_documents" "ccm_do" {
  content = format("%s---\n%s",
    file("k8s-manifests/digitalocean-cloud-controller-manager-v0.1.37.yaml"),
    file("k8s-manifests/digitalocean-cloud-controller-manager-service-monitor.yaml")
  )
}

resource "kubectl_manifest" "ccm_do" {
  for_each  = data.kubectl_file_documents.ccm_do.manifests
  yaml_body = each.value
  wait      = true
  depends_on = [helm_release.cilium,
  kubectl_manifest.ccm_secret]
}

# ingress
data "kubectl_file_documents" "argo_nginx_ingress" {
  content = file("argocd/nginx-ingress.yaml")
}

resource "kubectl_manifest" "argo_nginx_ingress" {
  yaml_body  = data.kubectl_file_documents.argo_nginx_ingress.content
  wait       = true
  depends_on = [helm_release.argocd]
}

data "kubectl_file_documents" "argo_gateway_api_crds" {
  content = file("../argocd/gateway-api-crds.yaml")
}

resource "kubectl_manifest" "argo_gateway_api_crds" {
  yaml_body  = data.kubectl_file_documents.argo_gateway_api_crds.content
  depends_on = [helm_release.argocd]
}

# fetch nginx service external ip-address for ingress hosts
#
#data "kubernetes_service" "ingress-nginx-nginx-ingress-ingress-nginx-controller" {
#  metadata {
#    name      = "nginx-ingress-ingress-nginx-controller"
#    namespace = "ingress-nginx"
#  }
#}

#output "ingress_external_ip" {
#  value = data.kubernetes_service.ingress-nginx-nginx-ingress-ingress-nginx-controller.status.0.load_balancer.0.ingress.0.ip
#}

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
    kubectl_manifest.ccm_do,
  ]
}

# cluster issuer + CA(s)
data "kubectl_file_documents" "cm_cluster_issuer_self_signed" {
  content = file("k8s-manifests/cert-manager-cluster-issuer-self-signed.yaml")
}

resource "kubectl_manifest" "cm_cluster_issuer_self_signed" {
  yaml_body  = data.kubectl_file_documents.cm_cluster_issuer_self_signed.content
  wait       = true
  depends_on = [helm_release.cert-manager]
}

data "kubectl_file_documents" "cm_cert_ca_hujer_info_selfsigned" {
  content = file("k8s-manifests/cert-manager-certificate-ca-hujer.info-selfsigned.yaml")
}

resource "kubectl_manifest" "cm_cert_ca_hujer_info_selfsigned" {
  yaml_body  = data.kubectl_file_documents.cm_cert_ca_hujer_info_selfsigned.content
  wait       = true
  depends_on = [helm_release.cert-manager]
}
