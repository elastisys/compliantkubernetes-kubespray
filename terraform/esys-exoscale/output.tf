# Service cluster outputs
output "sc_master_ips" {
  value = "${module.service_cluster.master_ips}"
}

output "sc_worker_ips" {
  value = "${module.service_cluster.worker_ips}"
}

output "sc_ingress_controller_lb_ip_address" {
  value = "${module.service_cluster.ingress_controller_lb_ip_address}"
}

output "sc_control_plane_lb_ip_address" {
  value = module.service_cluster.control_plane_lb_ip_address
}

# Workload cluster cluster outputs

output "wc_master_ips" {
  value = "${module.workload_cluster.master_ips}"
}

output "wc_worker_ips" {
  value = "${module.workload_cluster.worker_ips}"
}

output "wc_ingress_controller_lb_ip_address" {
  value = "${module.workload_cluster.ingress_controller_lb_ip_address}"
}

output "wc_control_plane_lb_ip_address" {
  value = module.workload_cluster.control_plane_lb_ip_address
}
