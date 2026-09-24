# Terraform AWS Transit Gateway

Creates an AWS Transit Gateway, explicitly managed transit gateway route
tables, optional AWS RAM sharing, and the owner-side routing policy for
existing attachments.

VPC attachments and VPC route-table routes are created by the nested
[`module`](./module) module in the account that owns the VPC. This keeps the
central transit gateway and spoke VPC lifecycles in separate Terraform states.

## Transit gateway owner

```hcl
module "transit_gateway" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git"

  name = "central-eu-north-1"

  route_tables = {
    spokes          = {}
    shared_services = {}
  }

  resource_share = {
    principals = [
      "arn:aws:organizations::123456789012:ou/o-example/ou-example",
    ]
  }

  # Attachment IDs are normally supplied after the spoke deployment.
  attachments = {
    application = {
      id                       = var.application_attachment_id
      accept                   = true
      association_route_table  = "spokes"
      propagation_route_tables = ["spokes", "shared_services"]
    }
  }
}
```

Automatic default route-table association and propagation are disabled. Every
attachment must therefore be associated and propagated explicitly through the
`attachments` input.

Set `accept = true` only when this state must explicitly accept a cross-account
attachment. It is normally false for same-account attachments and when the
transit gateway automatically accepts shared attachments.

## VPC owner

Call the nested attachment module from the account that owns the VPC:

```hcl
module "transit_gateway_attachment" {
  source = "git::https://github.com/wearetechnative/terraform-aws-module-transit-gateway.git//module"

  name               = "application"
  transit_gateway_id = var.transit_gateway_id
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids_by_group["transit_gateway"]

  routes = {
    for route_table_id in module.network.route_table_ids_by_group["private"] :
    "private-${route_table_id}" => {
      route_table_id         = route_table_id
      destination_cidr_block = "10.0.0.0/8"
    }
  }
}
```

Use one attachment subnet per Availability Zone. The VPC routes generally
belong to the route tables associated with workload subnets, rather than only
to the attachment subnet route tables.

## Routing model

Each attachment has exactly one `association_route_table` and can propagate to
zero or more `propagation_route_tables`. Use `routes` for TGW static routes and
blackhole routes:

```hcl
routes = {
  block-development = {
    route_table            = "shared_services"
    destination_cidr_block = "10.20.0.0/16"
    blackhole              = true
  }

  default-to-inspection = {
    route_table            = "spokes"
    destination_cidr_block = "0.0.0.0/0"
    attachment_id          = var.inspection_attachment_id
  }
}
```

## Important outputs

- `id` — transit gateway ID passed to spoke deployments
- `arn` — transit gateway ARN
- `route_table_ids` — route table IDs keyed by their configured names
- `resource_share_arn` — RAM share ARN, or `null` when sharing is disabled

The attachment module outputs `id`, which is passed back to the owner-side
deployment for acceptance, association, and propagation.

## Local checks

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```
