# Terraform AWS Transit Gateway

This repository contains three small modules:

| Module | Deploy in | Purpose |
|---|---|---|
| Root module | TGW account | Creates the Transit Gateway, one TGW route table, and an optional RAM share |
| `modules/vpc-attachment` | VPC account | Attaches a VPC and adds routes to its VPC route tables |
| `modules/attachment-accepter` | TGW account | Accepts a cross-account attachment and configures its TGW association and propagation |

## VPC and Transit Gateway in the same account

Call the root module and attachment module with the same AWS provider:

```hcl
module "transit_gateway" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git"

  name = "central"
}

module "transit_gateway_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/vpc-attachment"

  name                           = "application"
  transit_gateway_id             = module.transit_gateway.id
  transit_gateway_route_table_id = module.transit_gateway.route_table_id
  vpc_id                         = module.network.vpc_id
  subnet_ids                     = module.network.subnet_ids_by_group["transit_gateway"]

  # Set this to true to enable route propagation or use static routes
  enable_propagation = true

  routes = {
    for index, route_table_id in module.network.route_table_ids_by_group["private"] :
    "private-${index}" => {
      route_table_id         = route_table_id
      destination_cidr_block = "10.0.0.0/8"
    }
  }
}
```

This creates the TGW, attachment, TGW association and propagation, and the VPC
routes in one apply.

Use one attachment subnet per Availability Zone. The routes usually belong to
the private workload route tables, not only to the attachment subnet route
tables.

## VPC in another AWS account

For cross-account use, the TGW owner shares the gateway through AWS RAM. The
VPC account creates the attachment. The TGW account then accepts and routes it.

Each account uses its own Terraform repository or state and its normal AWS
provider.

### 1. TGW account: create and share the gateway

```hcl
module "transit_gateway" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git"

  name = "central"

  resource_share = {
    principals = ["222222222222"]
  }
}

# Child-module outputs are internal to this Terraform state. Re-export the TGW
# ID because the connected VPC account configuration needs it.

output "transit_gateway_id" {
  value = module.transit_gateway.id
}
```

Pass `transit_gateway_id` to the VPC account configuration.

### 2. VPC account: create the attachment and VPC routes

```hcl
module "connected_vpc_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/vpc-attachment"

  name               = "application"
  transit_gateway_id = var.transit_gateway_id
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids_by_group["transit_gateway"]

  # Do not set transit_gateway_route_table_id here. The VPC account cannot
  # manage a route table owned by the TGW account.
  routes = {
    for index, route_table_id in module.network.route_table_ids_by_group["private"] :
    "private-${index}" => {
      route_table_id         = route_table_id
      destination_cidr_block = "10.0.0.0/8"
    }
  }
}

output "transit_gateway_attachment_id" {
  value = module.connected_vpc_attachment.id
}
```

Pass `transit_gateway_attachment_id` back to the TGW account configuration.

### 3. TGW account: accept and route the attachment

```hcl
module "connected_vpc_attachment_accepter" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/attachment-accepter"

  name                           = "application"
  attachment_id                  = var.transit_gateway_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.route_table_id

  # Explicit opt-in: advertise the connected VPC's CIDRs.
  enable_propagation = true
}
```

The deployment order is:

```text
TGW and RAM share (TGW account)
  -> VPC attachment and VPC routes (VPC account)
  -> acceptance, association and propagation (TGW account)
```

When sharing outside AWS Organizations, the VPC account must first accept the
RAM resource-share invitation. That can be managed separately with
`aws_ram_resource_share_accepter` in the VPC account.

If `auto_accept_shared_attachments = true` is set on the root TGW module, pass
`accept_attachment = false` to `modules/attachment-accepter`. The module is
still required for association and propagation.

## Route propagation

Route propagation is disabled by default. Set `enable_propagation = true` on
`modules/vpc-attachment` for a same-account attachment, or on
`modules/attachment-accepter` for a cross-account attachment, only when the
attached VPC's complete CIDR ranges should be advertised into that TGW route
table. AWS does not support filtering individual VPC CIDRs from propagated
routes.

## Passing values between account states

The same account ownership applies when each account has its own state:

1. Apply the root module in the TGW account and publish `id` and
   `route_table_id`.
2. Apply `modules/vpc-attachment` in the VPC account using the published TGW
   ID, then publish its `id` output.
3. Apply `modules/attachment-accepter` in the TGW account using that attachment
   ID.

The output exchange can use your deployment pipeline, Terraform remote state,
or a configuration store such as SSM Parameter Store.

## Root module outputs

- `id` — Transit Gateway ID
- `arn` — Transit Gateway ARN
- `route_table_id` — managed TGW route-table ID
- `resource_share_arn` — RAM share ARN, or `null`
