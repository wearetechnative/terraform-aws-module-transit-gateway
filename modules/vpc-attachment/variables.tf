variable "name" {
  description = "Name of the VPC attachment."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to attach."
  type        = string
}

variable "transit_gateway_id" {
  description = "ID of the transit gateway."
  type        = string
}

variable "transit_gateway_route_table_id" {
  description = "TGW route table to associate and propagate to. Leave null for a cross-account attachment managed by the TGW owner."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "One attachment subnet ID per Availability Zone."
  type        = set(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one attachment subnet ID must be provided."
  }
}

variable "route_table_ids" {
  description = "VPC route table IDs that should receive routes to the transit gateway."
  type        = list(string)
  default     = []
}

variable "destination_cidr_blocks" {
  description = "IPv4 destination CIDRs routed through the transit gateway in every supplied VPC route table."
  type        = set(string)
  default     = []
}

variable "enable_propagation" {
  description = "Propagate all VPC CIDRs into the supplied TGW route table. Enable explicitly only when that reachability is intended."
  type        = bool
  default     = false
}

variable "dns_support" {
  description = "Enable DNS support for the attachment."
  type        = bool
  default     = true
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
