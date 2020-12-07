variable "zone" {
  type = string
  # This is currently the only zone that is supposed to be supporting
  # so called "managed private networks".
  # See: https://www.exoscale.com/syslog/introducing-managed-private-networks
  default = "ch-gva-2"
}

variable "prefix" {}

variable "machines" {
  type = map(object({
    node_type = string
    size      = string
    image = object({
      name = string
    })
    provider_settings = object({
      es_local_storage_capacity = number
      disk_size                 = number
      ceph_partition_size       = number
    })
  }))
}

variable "ssh_pub_key" {}

variable "ssh_whitelist" {
  type = list(string)
}

variable "api_server_whitelist" {
  type = list(string)
}

variable "nodeport_whitelist" {
  type = list(string)
}

variable "private_network_cidr" {
  default = "172.0.10.0/24"
}
