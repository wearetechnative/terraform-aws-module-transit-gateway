# Terraform AWS Transit Gateway

This repository contains three modules:

| Module | Deploy in | Purpose |
|---|---|---|
| Root module | TGW account | Creates the Transit Gateway, one TGW route table, and an optional RAM share |
| `modules/vpc-attachment` | VPC account | Attaches a VPC and adds routes to its VPC route tables |
| `modules/attachment-accepter` | TGW account | Accepts a cross-account attachment and configures its TGW association and propagation |

Each AWS account has its own Terraform repository or state and uses its normal
AWS provider. This module does not require provider aliases.

## Three-account example

This example connects one VPC in each of three accounts:

```text
TGW account          111111111111  VPC 10.10.0.0/16
  Transit Gateway and TGW route table
             │
             ├── Application account  222222222222  VPC 10.20.0.0/16
             └── Data account         333333333333  VPC 10.30.0.0/16
```

Deploy the VPC/network module in all three accounts first. Each VPC needs a
dedicated TGW attachment subnet in every required Availability Zone. The
examples assume the network module exposes `vpc_id`,
`subnet_ids_by_group`, and `route_table_ids_by_group`.

After the VPCs exist, the TGW rollout has three stages and four Terraform
applies:

```text
1. TGW account:         create and share the TGW; attach its own VPC
2. Application account: create its attachment
   Data account:        create its attachment
3. TGW account:         accept and route both attachments
```

The two attachment deployments in stage 2 can run in parallel.

### Stage 1: TGW account

Create the TGW and share it with both VPC accounts:

```hcl
module "transit_gateway" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git"

  name = "central"

  resource_share = {
    principals = [
      "222222222222",
      "333333333333",
    ]
  }
}

module "local_vpc_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/vpc-attachment"

  name                           = "network"
  transit_gateway_id             = module.transit_gateway.id
  transit_gateway_route_table_id = module.transit_gateway.route_table_id
  vpc_id                         = module.network.vpc_id
  subnet_ids                     = module.network.subnet_ids_by_group["transit_gateway"]
  route_table_ids                = module.network.route_table_ids_by_group["private"]

  destination_cidr_blocks = [
    "10.20.0.0/16",
    "10.30.0.0/16",
  ]

  enable_propagation = true
}

# Child-module outputs are internal to this Terraform state. Re-export the TGW
# ID because the connected VPC account configurations need it.
output "transit_gateway_id" {
  value = module.transit_gateway.id
}
```

Pass `transit_gateway_id` to both connected account configurations. This can
be done through pipeline variables, Terraform remote state, or a configuration
store such as SSM Parameter Store.

When sharing outside AWS Organizations, each VPC account must accept the RAM
resource-share invitation before it can create an attachment.

### Stage 2a: application account

The application VPC is `10.20.0.0/16`. Its private subnet route tables need
routes to the TGW account VPC and the data VPC:

```hcl
variable "transit_gateway_id" {
  type = string
}

module "transit_gateway_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/vpc-attachment"

  name               = "application"
  transit_gateway_id = var.transit_gateway_id
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids_by_group["transit_gateway"]

  route_table_ids = module.network.route_table_ids_by_group["private"]

  destination_cidr_blocks = [
    "10.10.0.0/16",
    "10.30.0.0/16",
  ]
}

output "transit_gateway_attachment_id" {
  value = module.transit_gateway_attachment.id
}
```

### Stage 2b: data account

The data VPC is `10.30.0.0/16`. Its private subnet route tables need routes to
the TGW account VPC and the application VPC:

```hcl
variable "transit_gateway_id" {
  type = string
}

module "transit_gateway_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/vpc-attachment"

  name               = "data"
  transit_gateway_id = var.transit_gateway_id
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids_by_group["transit_gateway"]

  route_table_ids = module.network.route_table_ids_by_group["private"]

  destination_cidr_blocks = [
    "10.10.0.0/16",
    "10.20.0.0/16",
  ]
}

output "transit_gateway_attachment_id" {
  value = module.transit_gateway_attachment.id
}
```

Pass both `transit_gateway_attachment_id` values back to the TGW account.

### Stage 3: TGW account

Declare the attachment IDs received from the two VPC account deployments:

```hcl
variable "attachments" {
  type = map(object({
    attachment_id      = string
    enable_propagation = optional(bool, false)
  }))
}
```

For example, in the TGW account's `production.tfvars`:

```hcl
attachments = {
  application = {
    attachment_id      = "tgw-attach-0123456789abcdef0"
    enable_propagation = true
  }

  data = {
    attachment_id      = "tgw-attach-0fedcba9876543210"
    enable_propagation = true
  }
}
```

Accept, associate, and optionally propagate all attachments:

```hcl
module "attachment_accepter" {
  for_each = var.attachments
  source   = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/attachment-accepter"

  name                           = each.key
  attachment_id                  = each.value.attachment_id
  transit_gateway_route_table_id = module.transit_gateway.route_table_id

  accept_attachment  = true
  enable_propagation = each.value.enable_propagation
}
```

After this apply, the TGW route table contains propagated routes similar to:

```text
10.10.0.0/16 -> TGW account VPC attachment
10.20.0.0/16 -> application attachment
10.30.0.0/16 -> data attachment
```

Combined with the VPC routes created in stages 1 and 2, this provides routing
between all three VPCs. Security groups and network ACLs must also permit the
intended traffic.

## Route propagation

Route propagation is disabled by default. Enable it only when all CIDRs from an
attached VPC should be added to the TGW route table automatically. AWS does not
support filtering individual VPC CIDRs from propagated routes.

If you do not enable propagation, manage the required TGW routes explicitly in
the TGW account. The `destination_cidr_blocks` supplied to
`modules/vpc-attachment` configure VPC route tables; they do not configure the
TGW route table.

## Same-account attachment

When the TGW and VPC are in the same account, call the root module and
`modules/vpc-attachment` from the same Terraform configuration. Supply
`transit_gateway_route_table_id` so that the attachment module can also create
the association and optional propagation:

```hcl
module "transit_gateway_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//modules/vpc-attachment"

  name                           = "application"
  transit_gateway_id             = module.transit_gateway.id
  transit_gateway_route_table_id = module.transit_gateway.route_table_id
  vpc_id                         = module.network.vpc_id
  subnet_ids                     = module.network.subnet_ids_by_group["transit_gateway"]
  route_table_ids                = module.network.route_table_ids_by_group["private"]

  destination_cidr_blocks = [
    "10.30.0.0/16",
  ]

  enable_propagation = true
}
```

## Root module outputs

- `id` — Transit Gateway ID
- `arn` — Transit Gateway ARN
- `route_table_id` — managed TGW route-table ID
- `resource_share_arn` — RAM share ARN, or `null`
