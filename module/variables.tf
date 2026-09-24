variable "name" {
  description = "Name of the VPC attachment."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to attach."
  type        = string
}

variable "transit_gateway_id" {
  description = "ID of the transit gateway shared with this account."
  type        = string
}

variable "subnet_ids" {
  description = "One attachment subnet ID per Availability Zone."
  type        = set(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one attachment subnet ID must be provided."
  }
}

variable "routes" {
  description = "VPC route-table routes that send traffic to the transit gateway."
  type = map(object({
    route_table_id              = string
    destination_cidr_block      = optional(string)
    destination_ipv6_cidr_block = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for route in values(var.routes) :
      (route.destination_cidr_block != null) != (route.destination_ipv6_cidr_block != null)
    ])
    error_message = "Each route must define exactly one of destination_cidr_block or destination_ipv6_cidr_block."
  }
}

variable "dns_support" {
  description = "Enable DNS support for the attachment."
  type        = bool
  default     = true
}

variable "ipv6_support" {
  description = "Enable IPv6 support for the attachment."
  type        = bool
  default     = false
}

variable "appliance_mode_support" {
  description = "Enable appliance mode for the attachment."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the attachment."
  type        = map(string)
  default     = {}
}
