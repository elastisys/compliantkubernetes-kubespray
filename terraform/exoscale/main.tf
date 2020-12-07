provider "exoscale" {
  version = "~> 0.20"
  key     = var.exoscale_api_key
  secret  = var.exoscale_secret_key

  timeout = 120 # default: waits 60 seconds in total for a resource
}

module "kubernetes" {
  source = "./modules/kubernetes-cluster"

  prefix = var.prefix

  machines = var.machines

  ssh_pub_key = var.ssh_pub_key

  ssh_whitelist        = var.ssh_whitelist
  api_server_whitelist = var.api_server_whitelist
  nodeport_whitelist   = var.nodeport_whitelist
}
