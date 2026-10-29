# Resource API Reference

> Generated from `types.lua` by `tools/gen_reference.lua` (convention defined in coe-docs/ANNOTATIONS.en-US.md).

| Resource | Exports |
|---|---|
| [coe_appearance](coe_appearance.en-US.md) | `OpenCreator`, `CloseCreator`, `CreatorError`, `IsCreatorOpen`, `Apply`, `ApplyToPlayer`, `CreatePed`, `Normalize`, `Default`, `Version` |
| [coe_audit](coe_audit.en-US.md) | `Record`, `IsReady` |
| [coe_bank](coe_bank.en-US.md) | `Yield`, `Status` |
| [coe_businesses](coe_businesses.en-US.md) | `IsReady`, `Categories`, `RuleSchema`, `List`, `Get`, `Save`, `Seed`, `Delete`, `ClockIn`, `ClockOut`, `Clock`, `IsOnDuty`, `DutySummary`, `CurrentDuty`, `Access`, `Partners`, `Debtors`, `Permissions`, `RegisterPermissions`, `Grades`, `GradeOf`, `Can`, `Salary`, `Payroll`, `RegisterTab`, `RegisterProvider`, `TabletInstances`, `TabletCall` |
| [coe_characters](coe_characters.en-US.md) | `IsOpen`, `CloseSelection` |
| [coe_core](coe_core.en-US.md) | `GetCoreObject`, `GetCharacterByStateId`, `GetActiveCharacter`, `GetPlayerByStateId`, `GetGroupDefinitions`, `GetPlayerGroups`, `SetPlayerGroup`, `RemovePlayerGroup` |
| [coe_database](coe_database.en-US.md) | `Query`, `Execute`, `Transaction`, `IsReady` |
| [coe_economy](coe_economy.en-US.md) | `IsReady`, `Summary`, `GetBalance`, `Credit`, `Debit`, `Transfer`, `Ledger`, `LedgerStats`, `SocietyBalance`, `SocietyLedger`, `SocietyDeposit`, `SocietyWithdraw`, `SocietyCredit`, `SocietyCollect`, `SocietyCharge`, `BankSocietyPay`, `BankSocietyDeposit`, `BankSocietyDebit`, `BankSocietyCredit`, `BankSocietyTransfer`, `BankSocietyLedger`, `RunPayroll` |
| [coe_garage](coe_garage.en-US.md) | `IsReady`, `ListGarages`, `GetGarage`, `GetVehicleGarage`, `SaveGarage`, `DeleteGarage` |
| [coe_hud](coe_hud.en-US.md) | `SetHidden`, `IsHidden`, `SetLogoVisible`, `IsLogoVisible`, `ToggleLogo` |
| [coe_inventory](coe_inventory.en-US.md) | `CreateInventory`, `DeleteInventory`, `GetInventory`, `GetSlot`, `SwapSlots`, `SplitItem`, `AddItem`, `RemoveItem`, `UseItem`, `SetItemMetadata`, `GetItemCount`, `GetPersistenceStats`, `OpenStash`, `RemoveItemByName`, `RegisterItem`, `Items`, `GetItem`, `GetContainerInventory`, `GetPlayerInventory`, `GetInventoryObject` |
| [coe_jobs](coe_jobs.en-US.md) | `RegisterJob`, `UnregisterJob`, `ListJobs`, `IsReady`, `GetSession`, `GetProgress`, `GetCareer`, `TabletVisible`, `TabletCall` |
| [coe_loadscreen](coe_loadscreen.en-US.md) | `IsActive`, `Shutdown` |
| [coe_logging](coe_logging.en-US.md) | `Log` |
| [coe_map](coe_map.en-US.md) | `GetMode`, `OpenFull` |
| [coe_mobile](coe_mobile.en-US.md) | `Yield`, `Status`, `NumberOf` |
| [coe_needs](coe_needs.en-US.md) | `GetNeeds`, `SetNeed`, `AddNeed` |
| [coe_notify](coe_notify.en-US.md) | `Notify`, `Show` |
| [coe_rentals](coe_rentals.en-US.md) | `GetActiveRental` |
| [coe_shops](coe_shops.en-US.md) | `IsReady`, `GetShelves`, `IsStore`, `BusinessTablet`, `RegisterPaymentMethod` |
| [coe_spawn](coe_spawn.en-US.md) | `GetStarterHotel`, `SetStarterHotel` |
| [coe_staff](coe_staff.en-US.md) | `Yield`, `Status`, `RegisterGaragesProvider` |
| [coe_supervisor](coe_supervisor.en-US.md) | `List`, `Restart`, `GetUpdateStatus`, `CheckForUpdates`, `WriteFile`, `ReadFile`, `HashFile`, `DownloadFile`, `CommitFile`, `DiscardFile`, `VerifySignature`, `ApplyUpdate` |
| [coe_talk](coe_talk.en-US.md) | `SetPlayerRadio`, `GetPlayerRadio`, `SetPlayerCall`, `GetPlayerCall`, `GetRadioMembers`, `GetCallMembers`, `GetVoiceRange`, `SetVoiceRange`, `GetRadioChannel`, `SetRadioChannel`, `GetCallChannel`, `SetCallChannel`, `IsTalking`, `IsRadioTransmitting`, `SetVoiceVolume` |
| [coe_ui](coe_ui.en-US.md) | `GetTheme`, `GetThemes`, `SetTheme`, `GetAccent`, `SetAccent` |
| [coe_vehicle_catalog](coe_vehicle_catalog.en-US.md) | `GetVehicleInfo`, `ListVehicles`, `GetBaseHandling`, `GetIssues`, `SetOverride`, `ClearOverride`, `Rescan`, `IsReady` |
| [coe_vehicles](coe_vehicles.en-US.md) | `Create`, `Get`, `GetByPlate`, `ListByOwner`, `GetEntity`, `GetMileage`, `SetMileage`, `Spawn`, `Store`, `IsReady`, `HasKey`, `GiveKey`, `RevokeKey`, `ListKeyHolders` |
| [coe_workpad](coe_workpad.en-US.md) | `Yield`, `Status` |
| [coetarget](coetarget.en-US.md) | `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `AddTargetGlobal`, `RemoveTargetGlobal`, `AddTargetSurface`, `RemoveTargetSurface` |
