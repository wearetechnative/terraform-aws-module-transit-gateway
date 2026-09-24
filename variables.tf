variable "name" {
  description = "Name used for the transit gateway and as a prefix for other child resources."
  type        = string

}

variable "description" {
  description = "Transit gateway description. Defaults to name."
  type        = string
  default     = null
}


variable "amazon_side_asn" {
  description = "Private ASN for the Amazon side of BGP sessions."
  type        = number
  default     = 64512

  validation {
    condition = (
      var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534
      ) || (
      var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294
    )
    error_message = "amazon_side_asn must be in 64512-65534 or 4200000000-4294967294."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Automatically accept cross-account attachment requests."
  type        = bool
  default     = false
}

variable "dns_support" {
  description = "Enable DNS support on the transit gateway."
  type        = bool
  default     = true
}

variable "vpn_ecmp_support" {
  description = "Enable equal-cost multi-path routing for VPN attachments."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}

variable "route_tables" {
  description = "Transit gateway route tables keyed by a stable logical name."
  type = map(object({
    name = optional(string)
    tags = optional(map(string), {})
  }))
  default = {
    default = {}
  }

}

variable "resource_share" {
  description = "Optional AWS RAM share for making the transit gateway available to other accounts, OUs, or an organization."
  type = object({
    name                      = optional(string)
    allow_external_principals = optional(bool, false)
    principals                = set(string)
    tags                      = optional(map(string), {})
  })
  default = null
}

variable "attachments" {
  description = "Existing attachment IDs and their owner-side route-table policy. Set accept for cross-account attachments that require explicit acceptance."
  type = map(object({
    id                       = string
    name                     = optional(string)
    accept                   = optional(bool, false)
    association_route_table  = string
    propagation_route_tables = optional(set(string), [])
    tags                     = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for attachment in values(var.attachments) :
      contains(keys(var.route_tables), attachment.association_route_table)
    ])
    error_message = "Every attachment association_route_table must reference a key in route_tables."
  }

  validation {
    condition = alltrue(flatten([
      for attachment in values(var.attachments) : [
        for route_table in attachment.propagation_route_tables :
        contains(keys(var.route_tables), route_table)
      ]
    ]))
    error_message = "Every attachment propagation_route_tables entry must reference a key in route_tables."
  }
}

variable "routes" {
  description = "Static or blackhole routes keyed by a stable logical name."
  type = map(object({
    route_table            = string
    destination_cidr_block = string
    attachment_id          = optional(string)
    blackhole              = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for route in values(var.routes) : contains(keys(var.route_tables), route.route_table)
    ])
    error_message = "Every route route_table must reference a key in route_tables."
  }

  validation {
    condition = alltrue([
      for route in values(var.routes) : route.blackhole || route.attachment_id != null
    ])
    error_message = "Every non-blackhole route must specify attachment_id."
  }
}
