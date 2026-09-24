variable "name" {
  description = "Name of the transit gateway."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
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

variable "resource_share" {
  description = "Optional AWS RAM share for other accounts, organizational units, or an organization."
  type = object({
    name                      = optional(string)
    allow_external_principals = optional(bool, false)
    principals                = set(string)
    tags                      = optional(map(string), {})
  })
  default = null
}
