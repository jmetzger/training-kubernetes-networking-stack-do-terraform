locals {
  all_node_ips = [for droplet in digitalocean_droplet.k8s_nodes : droplet.ipv4_address]
  worker_ips   = slice(local.all_node_ips, 1, length(local.all_node_ips))
  metallb_values_yaml = templatefile("./metallb-values.tpl.yaml", {
    ips = local.worker_ips
  })

}

resource "local_file" "file_metallb_values_yaml" {
    content  = local.metallb_values_yaml
    filename = "metallb-values.yaml"
}

resource "null_resource" "run_helm_install" {

  depends_on = [local_file.file_metallb_values_yaml,null_resource.run_join_script]
  provisioner "local-exec" {
    command = <<EOT
chmod +x ./scripts/helm-charts/deploy.sh && ./scripts/helm-charts/deploy.sh
EOT
  }

}




