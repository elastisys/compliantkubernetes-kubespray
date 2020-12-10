# terraform {
#   backend "remote" {
# 
#   }
# }

module "service_cluster" {
  source = "../../kubespray/contrib/terraform/gcp"

  keyfile_location = var.keyfile_location
  gcp_project_id = var.gcp_project_id

  prefix = var.prefix_sc == "" ? "${terraform.workspace}-service-cluster" : var.prefix_sc

  machines = var.machines_sc

  region = var.region

  ssh_pub_key = var.ssh_pub_key_sc

  ssh_whitelist        = var.ssh_whitelist
  api_server_whitelist = var.api_server_whitelist
  nodeport_whitelist   = var.nodeport_whitelist
}


module "workload_cluster" {
  source = "../../kubespray/contrib/terraform/gcp"

  keyfile_location = var.keyfile_location
  gcp_project_id = var.gcp_project_id

  prefix = var.prefix_wc == "" ? "${terraform.workspace}-workload-cluster" : var.prefix_wc

  machines = var.machines_wc

  region = var.region

  ssh_pub_key = var.ssh_pub_key_wc

  ssh_whitelist        = var.ssh_whitelist
  api_server_whitelist = var.api_server_whitelist
  nodeport_whitelist   = var.nodeport_whitelist
}
