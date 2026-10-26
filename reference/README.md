# Referência da API dos resources

> Gerado por `tools/gen_reference.lua` a partir dos `types.lua` (convenção em coe-docs/ANNOTATIONS.md).

| Resource | Exports |
|---|---|
| [coe_audit](coe_audit.md) | `Record`, `IsReady` |
| [coe_bank](coe_bank.md) | `Yield`, `Status` |
| [coe_core](coe_core.md) | `GetCoreObject`, `GetCharacterByStateId`, `GetActiveCharacter`, `GetPlayerByStateId`, `GetGroupDefinitions`, `GetPlayerGroups`, `SetPlayerGroup`, `RemovePlayerGroup` |
| [coe_database](coe_database.md) | `Query`, `Execute`, `Transaction`, `IsReady` |
| [coe_inventory](coe_inventory.md) | `CreateInventory`, `DeleteInventory`, `GetInventory`, `GetSlot`, `SwapSlots`, `SplitItem`, `AddItem`, `RemoveItem`, `UseItem`, `SetItemMetadata`, `GetItemCount`, `GetPersistenceStats`, `OpenStash`, `RemoveItemByName`, `RegisterItem`, `Items`, `GetItem`, `GetContainerInventory`, `GetPlayerInventory`, `GetInventoryObject` |
| [coe_jobs](coe_jobs.md) | `RegisterJob`, `UnregisterJob`, `ListJobs`, `IsReady`, `GetSession`, `GetProgress`, `GetCareer`, `TabletVisible`, `TabletCall` |
| [coe_logging](coe_logging.md) | `Log` |
| [coe_map](coe_map.md) | `GetMode`, `OpenFull` |
| [coe_mobile](coe_mobile.md) | `Yield`, `Status`, `NumberOf` |
| [coe_needs](coe_needs.md) | `GetNeeds`, `SetNeed`, `AddNeed` |
| [coe_notify](coe_notify.md) | `Notify`, `Show` |
| [coe_shops](coe_shops.md) | `IsReady`, `GetShelves`, `IsStore`, `BusinessTablet`, `RegisterPaymentMethod` |
| [coe_spawn](coe_spawn.md) | `GetStarterHotel`, `SetStarterHotel` |
| [coe_staff](coe_staff.md) | `Yield`, `Status` |
| [coe_supervisor](coe_supervisor.md) | `List`, `Restart`, `GetUpdateStatus`, `CheckForUpdates`, `ApplyUpdate` |
| [coe_ui](coe_ui.md) | `GetTheme`, `GetThemes`, `SetTheme`, `GetAccent`, `SetAccent` |
| [coe_vehicle_catalog](coe_vehicle_catalog.md) | `GetVehicleInfo`, `ListVehicles`, `GetBaseHandling`, `GetIssues`, `SetOverride`, `ClearOverride`, `Rescan`, `IsReady` |
| [coe_vehicles](coe_vehicles.md) | `Create`, `Get`, `GetByPlate`, `ListByOwner`, `GetEntity`, `GetMileage`, `SetMileage`, `Spawn`, `Store`, `IsReady`, `HasKey`, `GiveKey`, `RevokeKey`, `ListKeyHolders` |
| [coe_workpad](coe_workpad.md) | `Yield`, `Status` |
| [coetarget](coetarget.md) | `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `AddTargetGlobal`, `RemoveTargetGlobal`, `AddTargetSurface`, `RemoveTargetSurface` |
