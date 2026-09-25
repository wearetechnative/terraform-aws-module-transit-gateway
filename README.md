# Terraform AWS Transit Gateway

This repository contains three modules:

| Module | Deploy in | Purpose |
|---|---|---|
| Root module | TGW account | Creates the Transit Gateway, one TGW route table, and an optional RAM share |
| `modules/vpc-attachment` | VPC account | Attaches a VPC and adds routes to its VPC route tables |
| `modules/attachment-accepter` | TGW account | Accepts a cross-account attachment and configures its TGW association and propagation |

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

## Module reference

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ram_principal_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Private ASN for the Amazon side of BGP sessions. | `number` | `64512` | no |
| <a name="input_auto_accept_shared_attachments"></a> [auto\_accept\_shared\_attachments](#input\_auto\_accept\_shared\_attachments) | Automatically accept cross-account attachment requests. | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Transit gateway description. Defaults to name. | `string` | `null` | no |
| <a name="input_dns_support"></a> [dns\_support](#input\_dns\_support) | Enable DNS support on the transit gateway. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the transit gateway. | `string` | n/a | yes |
| <a name="input_resource_share"></a> [resource\_share](#input\_resource\_share) | Optional AWS RAM share for other accounts, organizational units, or an organization. | <pre>object({<br>    name                      = optional(string)<br>    allow_external_principals = optional(bool, false)<br>    principals                = set(string)<br>    tags                      = optional(map(string), {})<br>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all supported resources. | `map(string)` | `{}` | no |
| <a name="input_vpn_ecmp_support"></a> [vpn\_ecmp\_support](#input\_vpn\_ecmp\_support) | Enable equal-cost multi-path routing for VPN attachments. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | Transit gateway ARN. |
| <a name="output_id"></a> [id](#output\_id) | Transit gateway ID. |
| <a name="output_owner_id"></a> [owner\_id](#output\_owner\_id) | AWS account ID that owns the transit gateway. |
| <a name="output_resource_share_arn"></a> [resource\_share\_arn](#output\_resource\_share\_arn) | AWS RAM resource share ARN, or null when sharing is disabled. |
| <a name="output_route_table_id"></a> [route\_table\_id](#output\_route\_table\_id) | ID of the transit gateway route table. |
<!-- END_TF_DOCS -->
