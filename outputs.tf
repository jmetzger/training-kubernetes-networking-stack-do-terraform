output "droplet_ips" {
  description = "Public IPv4 addresses of all droplets"
  value       = [for d in digitalocean_droplet.k8s_nodes : d.ipv4_address]
}

output "private_ips" {
  description = "Private IPv4 addresses of all droplets"
  value       = [for d in digitalocean_droplet.k8s_nodes : d.ipv4_address_private]
}

output "ssh_private_key_path" {
  description = "Path to the generated private SSH key"
  value       = local_file.private_key.filename
}

output "project_name" {
  description = "Name of the DigitalOcean project created"
  value       = digitalocean_project.k8s_project.name
}

