provider "rancher2" {
  api_url    = "https://rancher-demo.susealliances.com/v3"
## Provide access_key with environmental variable RANCHER_ACCESS_KEY 
#  access_key = var.rancher2_access_key
## Provide secret_key with environmental variable RANCHER_SECRET_KEY 
#  secret_key = var.rancher2_secret_key
}

resource "rancher2_cluster" "k3s-cluster-instance" {
  name = "k3s-${var.edge_location}"
  description = "K3s imported cluster"
}

data "rancher2_cluster" "k3s-cluster" {
  name = "k3s-${var.edge_location}"
  depends_on = [rancher2_cluster.k3s-cluster-instance]
}

