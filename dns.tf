
# -----------------------------
# DNS ENTRY (Wildcard pro Benutzer)
# Nutzt eine Datenquelle, um die IP des Ingress-Service aus dem Cluster abzurufen,
# nachdem dieser via Helm erstellt wurde. Damit wird die externe IP zuverlässig abgefragt.
# -----------------------------

#resource "digitalocean_record" "ingress_dns_wildcard_user" {
#  domain = "do.t3isp.de"
#  type   = "A"
#  name   = "*.${local.current_user}"
#  value  = data.kubernetes_service.ingress_svc.status.load_balancer.ingress[0].ip
#}


