provider "rancher2" {
  api_url    = "https://rancher-demo.susealliances.com/v3"
## Provide access_key with environmental variable RANCHER_ACCESS_KEY 
#  access_key = var.rancher2_access_key
## Provide secret_key with environmental variable RANCHER_SECRET_KEY 
#  secret_key = var.rancher2_secret_key
####
# Uncomment the "insecure = true" line if using self-signed certs and not providing them to Terraform
####
#  insecure = true
}

resource "rancher2_cluster" "k3s-cluster-instance" {
  name = "k3s-${var.edge_location}"
  description = "K3s imported cluster"
  labels = var.cluster_labels
#  labels = tomap({"location" = "north", "customer" = "BigMoney"})
}

data "rancher2_cluster" "k3s-cluster" {
  name = "k3s-${var.edge_location}"
  depends_on = [rancher2_cluster.k3s-cluster-instance]
}

