##################################
#### CONFIGURE CLOUD PROVIDER ####
##################################

provider "digitalocean" { token = var.do_token }

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config_ktew"
  }
}

###########################################################
#### GENERATE RANDOM STRING FOR UNIQUE KUBECTL CONTEXT ####
###########################################################

resource "random_string" "lower" {
  length  = 6
  upper   = false
  lower   = true
  number  = true
  special = false
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
      "add-apt-repository 'deb http://apt.kubernetes.io/ kubernetes-xenial main'",
      #"echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      # INSTALL DOCKER
      "curl -s https://download.docker.com/linux/ubuntu/gpg | apt-key add -",
      "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'",
      "apt install -y docker-ce=5:${var.docker_version}~3-0~ubuntu-focal",
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
      "kubectl taint nodes --all node-role.kubernetes.io/master- || true"
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
      "curl -s https://download.docker.com/linux/ubuntu/gpg | apt-key add -",
      "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'",
      "apt install -y docker-ce=5:${var.docker_version}~3-0~ubuntu-focal",
      # KUBEADM TWEAKS
      "printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/containerd.conf",
      "modprobe overlay",
      "modprobe br_netfilter",
      "printf 'net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n' > /etc/sysctl.d/99-kubernetes-cri.conf",
      "sysctl --system",
      # INSTALL KUBEADM
      "apt install -y kubectl=${var.kubernetes_version}-00 kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 -f",
      # KUBEADM JOIN THE WORKER
      "kubeadm join --config=/tmp/kubeadm-config.yaml"
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

  depends_on = [digitalocean_droplet.control_plane]
}
