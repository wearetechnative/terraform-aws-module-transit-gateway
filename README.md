# Terraform AWS Transit Gateway

Creates an AWS Transit Gateway and its route tables. It can also attach VPCs
from the same AWS account, add routes to their VPC route tables, and optionally
share the gateway with other accounts through AWS RAM.

## Basic deployment: gateway and VPC attachment

The following is a complete example for a VPC in the same account as the
transit gateway:

```hcl
module "network" {
  source = "git::https://github.com/wearetechnative/terraform-aws-network.git"

  # Normal network module configuration omitted for brevity.
}

module "transit_gateway" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git"

  name = "central-eu-north-1"

  route_tables = {
    default = {}
  }

  vpc_attachments = {
    this_vpc = {
      vpc_id = module.network.vpc_id

      # Use one dedicated TGW attachment subnet per Availability Zone.
      subnet_ids = module.network.subnet_ids_by_group["transit_gateway"]

      association_route_table  = "default"
      propagation_route_tables = ["default"]

      # Add routes to the workload subnet route tables. These routes send
      # traffic destined for other internal networks to the new TGW.
      routes = {
        for index, route_table_id in module.network.route_table_ids_by_group["private"] :
        "private-${index}" => {
          route_table_id         = route_table_id
          destination_cidr_block = "10.0.0.0/8"
        }
      }
    }
  }
}
```

Running the normal Terraform workflow creates, in order:

1. The transit gateway.
2. Its `default` transit gateway route table.
3. The VPC attachment.
4. The attachment association and propagation.
5. The `10.0.0.0/8` routes in the private VPC route tables.

```bash
terraform init
terraform plan
terraform apply
```

The network configuration needs a dedicated attachment subnet group with one
subnet per Availability Zone, for example:

```hcl
subnet_groups = {
  private = {
    nat_gateway      = true
    internet_gateway = false
  }

  transit_gateway = {
    nat_gateway      = false
    internet_gateway = false
  }
}
```

The TGW attachment uses the `transit_gateway` subnets, but the routes normally
belong to the `private` workload route tables.

## Multiple VPCs in the same account

Add another entry to `vpc_attachments`:

```hcl
vpc_attachments = {
  application = {
    vpc_id                    = module.application_network.vpc_id
    subnet_ids                = module.application_network.subnet_ids_by_group["transit_gateway"]
    association_route_table   = "default"
    propagation_route_tables  = ["default"]
    routes = {
      internal = {
        route_table_id         = module.application_network.route_table_ids_by_group["private"][0]
        destination_cidr_block = "10.0.0.0/8"
      }
    }
  }

  shared_services = {
    vpc_id                    = module.shared_services_network.vpc_id
    subnet_ids                = module.shared_services_network.subnet_ids_by_group["transit_gateway"]
    association_route_table   = "default"
    propagation_route_tables  = ["default"]
  }
}
```

## Cross-account VPCs

For a VPC owned by another account:

1. Configure `resource_share` in the central module.
2. Deploy the nested `//module` attachment module in the VPC account.
3. Pass its attachment ID to the central deployment through the `attachments`
   input so the TGW owner can accept and route it.

Central account sharing:

```hcl
module "transit_gateway" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git"

  name = "central-eu-north-1"

  resource_share = {
    principals = ["123456789012"]
  }

  attachments = {
    application_account = {
      id                       = var.application_attachment_id
      accept                   = true
      association_route_table  = "default"
      propagation_route_tables = ["default"]
    }
  }
}
```

VPC account attachment:

```hcl
module "transit_gateway_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//module"

  name               = "application"
  transit_gateway_id = var.transit_gateway_id
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids_by_group["transit_gateway"]

  routes = {
    for index, route_table_id in module.network.route_table_ids_by_group["private"] :
    "private-${index}" => {
      route_table_id         = route_table_id
      destination_cidr_block = "10.0.0.0/8"
    }
  }
}
```

Set `accept = false` when the transit gateway has
`auto_accept_shared_attachments = true`.

## Routing behavior

Automatic default route-table association and propagation are disabled. Every
attachment is explicitly associated with one TGW route table and may propagate
to any number of TGW route tables.

Static and blackhole TGW routes can be configured separately:

```hcl
routes = {
  block-development = {
    route_table            = "default"
    destination_cidr_block = "10.20.0.0/16"
    blackhole              = true
  }
}
```

## Outputs

- `id` — transit gateway ID
- `arn` — transit gateway ARN
- `route_table_ids` — TGW route table IDs keyed by configured name
- `vpc_attachment_ids` — same-account attachment IDs keyed by configured name
- `resource_share_arn` — RAM share ARN, or `null`
