variable "name" {
  description = "Name applied to the accepted attachment."
  type        = string
}

variable "attachment_id" {
  description = "ID of the cross-account VPC attachment."
  type        = string
}

variable "transit_gateway_route_table_id" {
  description = "TGW route table to associate and propagate to."
  type        = string
}

variable "accept_attachment" {
  description = "Accept the attachment. Set false when TGW auto-accept is enabled."
  type        = bool
  default     = true
}

variable "enable_propagation" {
  description = "Propagate all attached VPC CIDRs into the TGW route table. Enable explicitly only when that reachability is intended."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied when accepting the attachment."
  type        = map(string)
  default     = {}
}
