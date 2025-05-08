# -----------------------------
# HELM RELEASE: INGRESS NGINX
# -----------------------------
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  upgrade_install  = true
  create_namespace = true
  version          = "0.13.12"

  depends_on = [null_resource.run_join_script]
}

resource "helm_release" "metallb_config" {
  depends_on = [helm_release.metallb]
  name             = "metallb-config"
  namespace        = "metallb-system"
  repository       = "./charts"
  upgrade_install  = true 
  chart            = "metallb-config"
  values           = [local.metallb_values_yaml]
  version          = "0.14.8"
}

locals {
  all_node_ips = [for droplet in digitalocean_droplet.k8s_nodes : droplet.ipv4_address]
  worker_ips   = slice(local.all_node_ips, 1, length(local.all_node_ips))
  metallb_values_yaml = templatefile("./metallb-values.tpl.yaml", {
    ips = local.worker_ips
  })

}

resource "helm_release" "nginx_ingress" {
  depends_on = [null_resource.run_join_script,helm_release.metallb_config]
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  upgrade_install  = true
  version          = "4.10.0"

}

