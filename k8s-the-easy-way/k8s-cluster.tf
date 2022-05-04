##################################
#### CONFIGURE CLOUD PROVIDER ####
##################################

provider "digitalocean" { token = var.do_token }

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config_ktew"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config_ktew"
}

provider "kubernetes" {
  config_path = "~/.kube/config_ktew"
}

######################################
#### CREATE CONTROL PLANE NODE(S) ####
######################################

# Use SSH key
resource "digitalocean_ssh_key" "terraform" {
  name       = "terraform-tf-cloud"
  public_key = var.pub_key
}

resource "digitalocean_droplet" "control_plane" {
  count              = 1
  image              = "ubuntu-20-04-x64"
  name               = format("control-plane-%s-%v", var.dc_region, count.index + 1)
  region             = var.dc_region
  size               = var.droplet_size
  private_networking = true
  ssh_keys           = [digitalocean_ssh_key.terraform.id]

  connection {
    user        = "root"
    host        = self.ipv4_address
    type        = "ssh"
    private_key = var.pvt_key
    timeout     = "2m"
    agent       = false
  }

  ###############################
  #### RENDER KUBEADM CONFIG ####
  ###############################

  provisioner "file" {
    content = templatefile("${path.module}/kubeadm-config.tpl",
      {
        cluster_name       = format("ktew-%s", var.dc_region),
        kubernetes_version = var.kubernetes_version,
        pod_subnet         = var.pod_subnet,
        control_plane_ip   = digitalocean_droplet.control_plane[0].ipv4_address
    })
    destination = "/tmp/kubeadm-config.yaml"
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

  ###################################################
  #### INSTALL CONTROL PLANE DOCKER / KUBERNETES ####
  ###################################################

  provisioner "remote-exec" {
    inline = [
      # GENERAL REPO SPEEDUP
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "echo '' > /etc/apt/sources.list",
      "add-apt-repository 'deb [arch=amd64] http://mirrors.digitalocean.com/ubuntu/ focal main restricted universe'",
      # ADD KUBERNETES REPO
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "add-apt-repository 'deb https://apt.kubernetes.io/ kubernetes-xenial main'",
      #"echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      # INSTALL DOCKER
      # "curl -s https://download.docker.com/linux/ubuntu/gpg | apt-key add -",
      # "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'",
      # "apt install -y docker-ce=5:${var.docker_version}~3-0~ubuntu-focal",
      # INSTALL CONTAINERD AND TOOLS
      "apt install -y containerd jq apparmor-utils curl etcd-client lsb-release mc strace tree",
      "printf 'runtime-endpoint: unix:///run/containerd/containerd.sock\n' > /etc/crictl.yaml",
      # KUBEADM TWEAKS
      "printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/containerd.conf",
      "modprobe overlay",
      "modprobe br_netfilter",
      "printf 'net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n' > /etc/sysctl.d/99-kubernetes-cri.conf",
      "sysctl --system",
      # INSTALL KUBEADM
      "apt install -y kubectl=${var.kubernetes_version}-00 kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 -f",
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
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${digitalocean_droplet.control_plane.0.ipv4_address}:/etc/kubernetes/admin.conf $${HOME}/.kube/config_ktew"
  }

  depends_on = [digitalocean_ssh_key.terraform]
}

#############################
#### CREATE WORKER NODES ####
#############################

resource "digitalocean_droplet" "worker" {
  count              = 2
  image              = "ubuntu-20-04-x64"
  name               = format("worker-%s-%v", var.dc_region, count.index + 1)
  region             = var.dc_region
  size               = var.droplet_size
  private_networking = true
  ssh_keys           = [digitalocean_ssh_key.terraform.id]

  connection {
    user        = "root"
    host        = self.ipv4_address
    type        = "ssh"
    private_key = var.pvt_key
    timeout     = "2m"
    agent       = false
  }

  ###############################
  #### RENDER KUBEADM CONFIG ####
  ############################### 

  provisioner "file" {
    content = templatefile("${path.module}/kubeadm-config.tpl",
      {
        cluster_name       = format("ktew-%s", var.dc_region),
        kubernetes_version = var.kubernetes_version,
        pod_subnet         = var.pod_subnet,
        control_plane_ip   = digitalocean_droplet.control_plane[0].ipv4_address
    })
    destination = "/tmp/kubeadm-config.yaml"
  }

  ############################################
  #### INSTALL WORKER DOCKER / KUBERNETES ####
  ############################################

  provisioner "remote-exec" {
    inline = [
      # GENERAL REPO SPEEDUP
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "echo '' > /etc/apt/sources.list",
      "add-apt-repository 'deb [arch=amd64] http://mirrors.digitalocean.com/ubuntu/ focal main restricted universe'",
      # ADD KUBERNETES REPO
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "add-apt-repository 'deb http://apt.kubernetes.io/ kubernetes-xenial main'",
      #"echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      # INSTALL DOCKER
      # "curl -s https://download.docker.com/linux/ubuntu/gpg | apt-key add -",
      # "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'",
      # "apt install -y docker-ce=5:${var.docker_version}~3-0~ubuntu-focal",
      # FIX LOGGING
      "systemctl restart systemd-journald",
      # ADD REPO FOR NEWER CONTAINERD
      "echo '' >> /etc/apt/sources.list",
      "echo '#deb http://archive.ubuntu.com/ubuntu/ focal multiverse' >> /etc/apt/sources.list",
      "echo '#deb http://archive.ubuntu.com/ubuntu/ focal-updates multiverse' >> /etc/apt/sources.list",
      "echo 'deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted' >>  /etc/apt/sources.list",
      "apt-get update",
      # INSTALL CONTAINERD AND TOOLS
      "apt install -y containerd jq apparmor-utils curl etcd-client lsb-release mc strace tree",
      "printf 'runtime-endpoint: unix:///run/containerd/containerd.sock\n' > /etc/crictl.yaml",
      # KUBEADM TWEAKS
      "printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/containerd.conf",
      "modprobe overlay",
      "modprobe br_netfilter",
      "printf 'net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n' > /etc/sysctl.d/99-kubernetes-cri.conf",
      "sysctl --system",
      # INSTALL KUBEADM
      "apt install -y kubectl=${var.kubernetes_version}-00 kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 -f",
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
  version    = var.cilium_helm_chart_version
  namespace  = "kube-system"

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