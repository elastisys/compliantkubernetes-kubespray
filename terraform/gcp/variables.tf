variable keyfile_location {
  description = "Path to the service account file"
  type        = string
}

variable region {
  description = "Region of all resources"
  type        = string
}

variable gcp_project_id {
  description = "ID of the project"
  type        = string
}

variable prefix_sc {
  description = "Prefix for resource names"
  default     = ""
}

variable prefix_wc {
  description = "Prefix for resource names"
  default     = ""
}

variable machines_sc {
  description = "Service cluster machines"
  type = map(object({
    node_type = string
    size      = string
    zone      = string
    additional_disks = map(object({
      size = number
    }))
    boot_disk = object({
      image_name = string
      size = number
    })
  }))
}

variable machines_wc {
  description = "Workload cluster machines"
  type = map(object({
    node_type = string
    size      = string
    zone      = string
    additional_disks = map(object({
      size = number
    }))
    boot_disk = object({
      image_name = string
      size = number
    })
  }))
}

variable ssh_pub_key_sc {
  description = "Path to public SSH key file which is injected into the VMs."
  type        = string
}

variable ssh_pub_key_wc {
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
