# coe_admin — API reference

> Generated from `coe_admin/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

The panel exposes no exports: other resources do not call coe_admin. Integration flows in the opposite direction (the panel consumes exports from coe_inventory, coe_businesses, coe_economy, coe_banking, coe_crypto, and others). Staff access is controlled through ACE permissions: `coe_admin.root`, `coe_admin.tools.all`, `coe_admin.tools.<module>`, and inherited `coe.staff.*` permissions from coe_staff. The UI uses internal NUI events that are not part of the public contract.

## Exports
