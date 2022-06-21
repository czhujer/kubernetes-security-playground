
resource "digitalocean_ssh_key" "terraform" {
  name       = "terraform-tf-cloud"
  public_key = var.pub_key
}

data "template_file" "cloud-init-yaml" {
  template = file("${path.module}/files/cloud-init.yaml")
}

resource "digitalocean_droplet" "control_plane" {
  count     = 1
  image     = "ubuntu-20-04-x64"
  name      = format("control-plane-%s-%v", var.dc_region, count.index + 1)
  region    = var.dc_region
  size      = var.droplet_size
  user_data = data.template_file.cloud-init-yaml.rendered
  ssh_keys  = [digitalocean_ssh_key.terraform.id]

  connection {
    user        = "root"
    host        = self.ipv4_address
    type        = "ssh"
    private_key = var.pvt_key
    timeout     = "10m"
    agent       = false
  }

  # wait to reboot and "handle it"
  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "set -o errexit",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
    ]
  }

  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "set -o errexit",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
    ]
  }

  # prepare file(s) for kubernetes
  #
  provisioner "remote-exec" {
    inline = ["mkdir -p /etc/kubernetes"]
  }

  provisioner "file" {
    content     = file("${path.module}/audit-policy.yaml")
    destination = "/etc/kubernetes/audit-policy.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/files/kubeadm-config.tpl",
      {
        cluster_name       = format("ktew-%s", var.dc_region),
        kubernetes_version = var.kubernetes_version,
        pod_subnet         = var.pod_subnet,
        control_plane_ip   = digitalocean_droplet.control_plane[0].ipv4_address,
        control_plane_name = format("control-plane-%s-1", var.dc_region)
    })
    destination = "/tmp/kubeadm-config.yaml"
  }

  # bootstrap control-plane
  #
  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      # ADD KUBERNETES REPO
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      "apt-get update -qq",
      # FIX LOGGING
      "systemctl restart systemd-journald",
      # CONTAINERD TWEAKS
      "printf 'runtime-endpoint: unix:///run/containerd/containerd.sock\n' > /etc/crictl.yaml",
      # KUBEADM TWEAKS
      "printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/containerd.conf",
      "modprobe overlay",
      "modprobe br_netfilter",
      "printf 'net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n' > /etc/sysctl.d/99-kubernetes-cri.conf",
      "sysctl --system",
      # INSTALL KUBEADM
      "apt install -y kubectl=${var.kubernetes_version}-00 kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 -f",
      "apt-mark hold kubelet kubeadm kubectl",
      # KUBEADM INIT THE CONTROL PLANE
      "kubeadm init --config=/tmp/kubeadm-config.yaml",
      # SETUP KUBECTL REMOTELY
      "mkdir -p /root/.kube && cp -i /etc/kubernetes/admin.conf /root/.kube/config && chown $(id -u):$(id -g) /root/.kube/config"
    ]
  }

  # fixes for cilium and etcd
  #
  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-servicemonitors.yaml",
      #      "kubectl taint nodes --all node-role.kubernetes.io/master- || true"
    ]
  }

  # copy kubeconfig from remote server to workstation
  #
  provisioner "local-exec" {
    command = "scp -i  ~/.ssh/id_rsa_ktew -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${digitalocean_droplet.control_plane.0.ipv4_address}:/etc/kubernetes/admin.conf $${HOME}/.kube/config_ktew"
  }

  depends_on = [digitalocean_ssh_key.terraform]
}

#############################
#### CREATE WORKER NODES ####
#############################

resource "digitalocean_droplet" "worker" {
  count     = 2
  image     = "ubuntu-20-04-x64"
  name      = format("worker-%s-%v", var.dc_region, count.index + 1)
  region    = var.dc_region
  size      = var.droplet_size
  ssh_keys  = [digitalocean_ssh_key.terraform.id]
  user_data = data.template_file.cloud-init-yaml.rendered

  connection {
    user        = "root"
    host        = self.ipv4_address
    type        = "ssh"
    private_key = var.pvt_key
    timeout     = "10m"
    agent       = false
  }

  # wait to reboot and "handle it"
  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "set -o errexit",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
    ]
  }

  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "set -o errexit",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
    ]
  }

  # prepare file(s) for kubernetes
  #
  provisioner "file" {
    content = templatefile("${path.module}/files/kubeadm-config.tpl",
      {
        cluster_name       = format("ktew-%s", var.dc_region),
        kubernetes_version = var.kubernetes_version,
        pod_subnet         = var.pod_subnet,
        control_plane_ip   = digitalocean_droplet.control_plane[0].ipv4_address,
        control_plane_name = format("control-plane-%s-1", var.dc_region)
    })
    destination = "/tmp/kubeadm-config.yaml"
  }

  # boostrap k8s node(s)
  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      # ADD KUBERNETES REPO
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      "apt-get update -qq",
      # FIX LOGGING
      "systemctl restart systemd-journald",
      # CONTAINERD TWEAKS
      "printf 'runtime-endpoint: unix:///run/containerd/containerd.sock\n' > /etc/crictl.yaml",
      # KUBEADM TWEAKS
      "printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/containerd.conf",
      "modprobe overlay",
      "modprobe br_netfilter",
      "printf 'net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n' > /etc/sysctl.d/99-kubernetes-cri.conf",
      "sysctl --system",
      # INSTALL KUBEADM
      "apt install -y kubectl=${var.kubernetes_version}-00 kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 -f",
      "apt-mark hold kubelet kubeadm kubectl",
      # INSTALL GVISOR
      #      "set -e",
      #      "ARCH=$(uname -m)",
      #      "URL=https://storage.googleapis.com/gvisor/releases/release/latest/$${ARCH}",
      #      "wget $${URL}/runsc $${URL}/runsc.sha512 $${URL}/containerd-shim-runsc-v1 $${URL}/containerd-shim-runsc-v1.sha512",
      #      "sha512sum -c runsc.sha512 -c containerd-shim-runsc-v1.sha512",
      #      "rm -f *.sha512",
      #      "chmod a+rx runsc containerd-shim-runsc-v1",
      #      "sudo mv runsc containerd-shim-runsc-v1 /usr/local/bin",
      # INSTALL GVISOR FROM APT
      "curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main\" | sudo tee /etc/apt/sources.list.d/gvisor.list",
      "apt-get update && apt-get install -y runsc",
      # CONFIGURE CONTAINERD (w gvisor)
      "mkdir -p /etc/containerd",
      "printf 'version = 2\n[plugins.\"io.containerd.runtime.v1.linux\"]\n  shim_debug = true\n[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc]\n  runtime_type = \"io.containerd.runc.v2\"\n[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runsc]\n  runtime_type = \"io.containerd.runsc.v1\"\n' > /etc/containerd/config.toml",
      "systemctl restart containerd",
      # KUBEADM JOIN THE WORKER
      "kubeadm join --config=/tmp/kubeadm-config.yaml",
    ]
  }
}

#####################
#### INSTALL CNI ####
#####################

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.11.6"
  namespace  = "kube-system"
  wait       = true

  values = [
    file("helm-values/cilium.yaml")
  ]

  set {
    name  = "hubble.enabled"
    value = "false"
  }
  set {
    name  = "hubble.relay.enabled"
    value = "false"
  }
  set {
    name  = "hubble.ui.enabled"
    value = "false"
  }

  depends_on = [digitalocean_droplet.control_plane]
}
