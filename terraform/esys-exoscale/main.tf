# terraform {
#   backend "remote" {
# 
#   }
# }

module "service_cluster" {
  source = "../exoscale"

  exoscale_secret_key = var.exoscale_secret_key
  exoscale_api_key    = var.exoscale_api_key

  prefix = var.prefix_sc == "" ? "${terraform.workspace}-service-cluster" : var.prefix_sc

  machines = var.machines_sc

  ssh_pub_key = var.ssh_pub_key_sc

  ssh_whitelist        = var.ssh_whitelist
  api_server_whitelist = var.api_server_whitelist
  nodeport_whitelist   = var.nodeport_whitelist
}


module "workload_cluster" {
  source = "../exoscale"

  exoscale_secret_key = var.exoscale_secret_key
  exoscale_api_key    = var.exoscale_api_key

  prefix = var.prefix_wc == "" ? "${terraform.workspace}-workload-cluster" : var.prefix_wc

  machines = var.machines_wc

  ssh_pub_key = var.ssh_pub_key_wc

  ssh_whitelist        = var.ssh_whitelist
  api_server_whitelist = var.api_server_whitelist
  nodeport_whitelist   = var.nodeport_whitelist
}
