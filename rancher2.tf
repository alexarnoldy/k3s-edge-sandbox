provider "rancher2" {
  api_url    = "https://rancher.susealliances.com/v3"
## Provide access_key with environmental variable RANCHER_ACCESS_KEY 
#  access_key = var.rancher2_access_key
## Provide secret_key with environmental variable RANCHER_SECRET_KEY 
#  secret_key = var.rancher2_secret_key
}

resource "rancher2_cluster" "k3s-cluster-instance" {
  name = "k3ai-${var.edge_location}"
  description = "K3s imported cluster"
}

data "rancher2_cluster" "k3s-cluster" {
  name = "k3ai-${var.edge_location}"
  depends_on = [rancher2_cluster.k3s-cluster-instance]
}

#locals {
#  clust_reg = 
#}
#
#resource "local_file" "cluster_reg_token" {
#  content     = local.clust_reg
#  filename = "${path.module}/files/cluster_registration_token"
#  depends_on = [rancher2_cluster.k3s-cluster-instance]
#}

output "cluster_registration_token" {
  value = data.rancher2_cluster.k3s-cluster.cluster_registration_token[0]
}
