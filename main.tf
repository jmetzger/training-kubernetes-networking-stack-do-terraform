# -----------------------------
# VERSIONS
# -----------------------------
terraform {
  required_version = ">= 1.4.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.29.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }
  }
}

# -----------------------------
# LOCALS
# -----------------------------
locals {
  current_user = trimspace(chomp(tolist([
    try(env("USER"), ""),
    try(env("USERNAME"), "")
  ])[0]))

  project_suffix = length(local.current_user) > 0 ? "-" + local.current_user : ""
}

# -----------------------------
# PROVIDERS
# -----------------------------
provider "digitalocean" {
  token = var.do_token
}

# -----------------------------
# SSH KEY
# -----------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "id_rsa_k8s_do"
  file_permission = "0600"
}

resource "digitalocean_ssh_key" "k8s_ssh" {
  name       = "k8s-terraform-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# -----------------------------
# NETWORKING
# -----------------------------
resource "digitalocean_vpc" "k8s_vpc" {
  name   = "k8s-vpc"
  region = var.region
}

# -----------------------------
# DROPLETS
# -----------------------------
resource "digitalocean_droplet" "k8s_nodes" {
  count              = 4
  name               = "k8s-${count.index == 0 ? "cp" : "w${count.index}"}"
  region             = var.region
  size               = var.droplet_size
  image              = "ubuntu-22-04-x64"
  ssh_keys           = [digitalocean_ssh_key.k8s_ssh.id]
  private_networking = true
  vpc_uuid           = digitalocean_vpc.k8s_vpc.id
  user_data          = file("cloud-init/setup-k8s-node.sh")
}

# -----------------------------
# PROJECT
# -----------------------------
resource "digitalocean_project" "k8s_project" {
  name        = "k8s-lab${local.project_suffix}"
  description = "Self-managed Kubernetes cluster with Calico"
  purpose     = "Web Application"
  environment = "Development"
}

resource "digitalocean_project_resources" "project_binding" {
  project   = digitalocean_project.k8s_project.id
  resources = [for d in digitalocean_droplet.k8s_nodes : d.urn]
}

# -----------------------------
# LOCAL EXEC JOIN SCRIPT
# -----------------------------
resource "null_resource" "run_join_script" {
  provisioner "local-exec" {
    command = <<EOT
chmod +x ./scripts/join-workers.sh
./scripts/join-workers.sh
EOT
  }
  depends_on = [digitalocean_droplet.k8s_nodes]
}

# -----------------------------
# HELM RELEASE: METALLB
# -----------------------------
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  create_namespace = true
  version          = "0.13.12"
}

resource "kubernetes_manifest" "metallb_pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-address-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [
        for ip in digitalocean_droplet.k8s_nodes : ip.ipv4_address if ip.name != "k8s-cp"
      ]
    }
  }
}

resource "kubernetes_manifest" "metallb_l2" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2adv"
      namespace = "metallb-system"
    }
    spec = {}
  }
}

# -----------------------------
# HELM RELEASE: INGRESS NGINX
# -----------------------------
resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

# -----------------------------
# DNS ENTRY
# -----------------------------
resource "digitalocean_record" "ingress_dns" {
  domain = "do.t3isp.de"
  type   = "A"
  name   = "app"
  value  = helm_release.nginx_ingress.status[0].load_balancer[0].ingress[0].ip
}

