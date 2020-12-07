# Exoscale credentials.
variable exoscale_api_key {
  description = "Either use .cloudstack.ini or this to set the API key."
  type        = string
}

variable exoscale_secret_key {
  description = "Either use .cloudstack.ini or this to set the API secret."
  type        = string
}

variable prefix {
  description = "Prefix for resource names"
  default     = "default"
}

variable machines {
  description = "Service cluster machines"
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

variable ssh_pub_key {
  description = "Path to public SSH key file which is injected into the VMs."
  type        = string
}

variable ssh_whitelist {
  type = list(string)
}

variable api_server_whitelist {
  type = list(string)
}

variable nodeport_whitelist {
  type = list(string)
}
