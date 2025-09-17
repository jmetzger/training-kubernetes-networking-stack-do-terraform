# DigitalOcean Kubernetes Setup mit Terraform & Calico Operator

Dieses Repository automatisiert den Aufbau eines selbstverwalteten Kubernetes-Clusters auf DigitalOcean mit:

- Terraform-Infrastruktur (VPC, Droplets, SSH Key, Helm, DNS)
- Kubernetes-Installation via Cloud-init + kubeadm
- Automatischer `kubeadm join` per SSH + kubeconfig Übergabe

---

## 🧰 Voraussetzungen

- DigitalOcean-Account + API Token (über Umgebungsvariable setzen mit `export TF_VAR_do_token="<your_token>"`)
- Domain wie `do.t3isp.de` in DigitalOcean DNS verwaltet
- `terraform`, `jq`, `ssh`, `scp` lokal installiert
- SSH-Zugriff auf erzeugte Droplets (automatisch eingerichtet)

---

## 🚀 Schnellstart

> Alternativ kannst du dein API-Token auch in einer `.env`-Datei speichern und mit `source .env` laden:
>
> ```env
> TF_VAR_do_token="<your_token>"
> ```

```bash
# DigitalOcean API Token als Umgebungsvariable setzen
export TF_VAR_do_token="<your_token>"
# Terraform initialisieren und Infrastruktur provisionieren
terraform init
terraform apply -auto-approve
```

Nach erfolgreicher Initialisierung wird die Kubernetes-Konfiguration (`admin.conf`) automatisch vom Control-Plane-Node kopiert und gespeichert als:

```bash
~/.kube/config
```

Falls das Verzeichnis `~/.kube` noch nicht existiert, wird es automatisch erstellt.

---

## 📁 Struktur

```
├── main.tf                 # Hauptlogik
├── variables.tf            # Eingabeparameter
├── outputs.tf              # Ausgaben
├── cloud-init/
│   └── setup-k8s-node.sh   # Cloud-init für Droplets
├── scripts/
│   └── join-workers.sh     # Initialisiert Cluster, joined Worker & kopiert kubeconfig
└── README.md
```

---

## ⚙️ Komponenten & Versionen

- Terraform: >= 1.4.0
- Kubernetes: `1.34.0-00` (Fallback: `1.32.3-00`)

---

---

## 🧪 Validierung (sollte auf NotReady stehen)

```bash
kubectl get nodes
kubectl get pods -A
```

---

## ❗ Sicherheitshinweis

Der generierte private SSH-Key `id_rsa_k8s_do` wird lokal gespeichert. Bitte sicher verwahren und nicht ins Git einchecken:

```bash
.gitignore:
  id_rsa_k8s_do
  .terraform/
  terraform.tfstate*
```

---

## 🧼 Bereinigen

```bash
terraform destroy -auto-approve
rm -f id_rsa_k8s_do id_rsa_k8s_do.pub
```
