# Resource API Reference

> Generated from `types.lua` by `tools/gen_reference.lua` (convention defined in coe-docs/ANNOTATIONS.en-US.md).

| Resource | Exports |
|---|---|
| [coe_admin](coe_admin.en-US.md) |  |
| [coe_amzg](coe_amzg.en-US.md) | `AdminCatalog`, `AdminDeleteProduct`, `AdminSaveProduct`, `TabletCall`, `TabletVisible` |
| [coe_appearance](coe_appearance.en-US.md) | `OpenCreator`, `CloseCreator`, `CreatorError`, `IsCreatorOpen`, `Apply`, `ApplyToPlayer`, `CreatePed`, `Normalize`, `Default`, `Version` |
| [coe_apps](coe_apps.en-US.md) | `ClaimPhoto`, `DeletePhoto`, `HasApp`, `PhotoData`, `StorePhoto`, `TabletCall`, `TabletVisible`, `TakePhoto` |
| [coe_audit](coe_audit.en-US.md) | `Record`, `IsReady` |
| [coe_bank](coe_bank.en-US.md) | `Yield`, `Status` |
| [coe_banking](coe_banking.en-US.md) | `AdminAccount`, `AdminBusinessAccount`, `AdminBusinessAccounts`, `AdminBusinessAdjust`, `AdminBusinessCardLimit`, `AdminCard`, `AdminDecideRequest`, `AdminForgiveLoan`, `AdminGrantLoan`, `AdminLoanRequests`, `AdminPoints`, `AdminSaveTiers`, `AdminSetCredit`, `AdminTiers`, `BusinessTablet`, `CardPurchase`, `CardRefund`, `PosCards`, `PosPurchase`, `ShopCharge`, `ShopOptions`, `ShopRefund`, `TabletCall`, `TabletVisible`, `WalletCards`, `WalletEligible`, `WalletIssueVirtual`, `WalletLink` |
| [coe_businesses](coe_businesses.en-US.md) | `IsReady`, `Categories`, `RuleSchema`, `List`, `Get`, `Save`, `Seed`, `Delete`, `ClockIn`, `ClockOut`, `Clock`, `IsOnDuty`, `DutySummary`, `CurrentDuty`, `Access`, `Partners`, `Debtors`, `Permissions`, `RegisterPermissions`, `Grades`, `GradeOf`, `Can`, `Salary`, `Payroll`, `RegisterTab`, `RegisterProvider`, `TabletInstances`, `TabletCall` |
| [coe_characters](coe_characters.en-US.md) | `IsOpen`, `CloseSelection` |
| [coe_core](coe_core.en-US.md) | `GetCoreObject`, `GetCharacterByStateId`, `GetActiveCharacter`, `GetPlayerByStateId`, `GetGroupDefinitions`, `GetPlayerGroups`, `SetPlayerGroup`, `RemovePlayerGroup` |
| [coe_crafting](coe_crafting.en-US.md) | `AdminCatalog`, `AdminDeleteBench`, `AdminDeleteMenu`, `AdminDeleteRecipe`, `AdminSaveBench`, `AdminSaveMenu`, `AdminSaveRecipe`, `AdminSetBusinessMenu`, `Begin`, `Busy`, `Cancel`, `Close`, `Complete`, `List`, `ListRecipes`, `Open`, `RegisterBench`, `RegisterRecipe`, `RemoveRecipe` |
| [coe_crypto](coe_crypto.en-US.md) | `IsReady`, `Price`, `Balance`, `IsAddress`, `Format`, `MintMining`, `ComputerCall`, `HeldWallets`, `EscrowLock`, `EscrowRelease`, `ReserveAddress`, `AdminOverview`, `AdminInspect`, `AdminSaveSettings`, `AdminResetSettings`, `AdminSetPrice`, `TabletVisible`, `TabletCall` |
| [coe_database](coe_database.en-US.md) | `Query`, `Execute`, `Transaction`, `IsReady` |
| [coe_deepweb](coe_deepweb.en-US.md) | `TabletVisible`, `TabletCall`, `AdminOverview`, `AdminSaveSite`, `AdminDeleteSite`, `AdminSaveVendor`, `AdminDeleteVendor`, `AdminResolveOrder`, `AdminRemovePost`, `AdminReplyContact`, `AdminCloseContact` |
| [coe_dispatch](coe_dispatch.en-US.md) | `Accept`, `Active`, `Alert`, `Close` |
| [coe_doors](coe_doors.en-US.md) | `CanAccess`, `Delete`, `IsLocked`, `IsReady`, `List`, `Save`, `SetLocked`, `TabletCall`, `TabletVisible` |
| [coe_economy](coe_economy.en-US.md) | `IsReady`, `Summary`, `GetBalance`, `Credit`, `Debit`, `Transfer`, `Ledger`, `LedgerStats`, `SocietyBalance`, `SocietyLedger`, `SocietyDeposit`, `SocietyWithdraw`, `SocietyCredit`, `SocietyCollect`, `SocietyCharge`, `BankSocietyPay`, `BankSocietyDeposit`, `BankSocietyDebit`, `BankSocietyCredit`, `BankSocietyTransfer`, `BankSocietyLedger`, `RunPayroll` |
| [coe_elos](coe_elos.en-US.md) | `IsReady`, `GetProfile`, `TabletVisible`, `TabletCall` |
| [coe_ems](coe_ems.en-US.md) | `Records`, `Revive`, `SetState`, `State`, `Treat` |
| [coe_factions](coe_factions.en-US.md) | `CanCraft`, `CanCraftInFaction`, `Categories`, `Delete`, `Get`, `IsReady`, `List`, `Members`, `Memberships`, `PauseMenuFaction`, `RecipesFor`, `RecipesForFaction`, `RemoveMember`, `Save`, `SetMember`, `TabletCall`, `TabletInstances` |
| [coe_garage](coe_garage.en-US.md) | `IsReady`, `ListGarages`, `GetGarage`, `GetVehicleGarage`, `SaveGarage`, `DeleteGarage` |
| [coe_garages](coe_garages.en-US.md) | `AddBusinessFleet`, `AddFleetVehicle`, `BusinessFleet`, `DeleteGarage`, `ListFleet`, `ListGarages`, `RemoveFleetVehicle`, `SaveGarage`, `SetFleetStaffAccess`, `TabletCall` |
| [coe_fuel](coe_fuel.en-US.md) | `IsReady`, `GetFuel`, `GetEffects`, `GetStationTanks`, `IsStation`, `BusinessTablet` |
| [coe_handling](coe_handling.en-US.md) | `GetTyre`, `SetTyre`, `ListTyres`, `ListClasses`, `GetModifiers`, `IsReady` |
| [coe_hud](coe_hud.en-US.md) | `SetHidden`, `IsHidden`, `SetLogoVisible`, `IsLogoVisible`, `ToggleLogo` |
| [coe_housing](coe_housing.en-US.md) | `AddressActive`, `BeginPreview`, `BusinessProperties`, `CurrentSpace`, `DeleteProperty`, `DeliveryAddresses`, `EndContract`, `EndPreview`, `InteriorThumbs`, `Interiors`, `IsReady`, `ListProperties`, `PlayersInSpace`, `PropertyContracts`, `SaveInteriorThumb`, `SaveProperty`, `TabletCall`, `TabletVisible` |
| [coe_inventory](coe_inventory.en-US.md) | `CreateInventory`, `DeleteInventory`, `GetInventory`, `GetSlot`, `SwapSlots`, `SplitItem`, `AddItem`, `RemoveItem`, `UseItem`, `SetItemMetadata`, `GetItemCount`, `GetPersistenceStats`, `OpenStash`, `RemoveItemByName`, `RegisterItem`, `Items`, `GetItem`, `GetContainerInventory`, `GetPlayerInventory`, `GetInventoryObject` |
| [coe_jobs](coe_jobs.en-US.md) | `RegisterJob`, `UnregisterJob`, `ListJobs`, `IsReady`, `GetSession`, `GetProgress`, `GetCareer`, `TabletVisible`, `TabletCall` |
| [coe_loadscreen](coe_loadscreen.en-US.md) | `IsActive`, `Shutdown` |
| [coe_logging](coe_logging.en-US.md) | `Log` |
| [coe_loot](coe_loot.en-US.md) | `Give`, `Roll`, `Tables` |
| [coe_mail](coe_mail.en-US.md) | `Send`, `TabletCall`, `TabletVisible` |
| [coe_map](coe_map.en-US.md) | `GetMode`, `OpenFull` |
| [coe_mdt](coe_mdt.en-US.md) | `AccessLog`, `TabletCall` |
| [coe_mechanic](coe_mechanic.en-US.md) | `TabletCall`, `Inspect`, `ReplacePart`, `ServiceVehicle`, `AdjustMileage`, `AddWear`, `GetEffects`, `ListParts`, `IsReady`, `GetShopOwner`, `GetAppearance`, `QuoteAppearance`, `SetAppearance`, `GetShops`, `GetVehicleOptions` |
| [coe_mobile](coe_mobile.en-US.md) | `Yield`, `Status`, `NumberOf` |
| [coe_needs](coe_needs.en-US.md) | `GetNeeds`, `SetNeed`, `AddNeed` |
| [coe_news](coe_news.en-US.md) | `AdminAction`, `AdminOverview`, `AdminQuery`, `TabletCall`, `TabletVisible` |
| [coe_notify](coe_notify.en-US.md) | `Notify`, `Show` |
| [coe_phone](coe_phone.en-US.md) | `ActiveDevice`, `ActiveLine`, `ConsumePayment`, `NumberOf`, `RequestPayment`, `ShopCharge`, `ShopOptions`, `ShopRefund`, `UpgradeStatus` |
| [coe_police](coe_police.en-US.md) | `Arrest`, `Cuff`, `Escort`, `Fine`, `IsCuffed`, `IsEscorted`, `IsJailed`, `Records`, `Search`, `Seize`, `Uncuff` |
| [coe_races](coe_races.en-US.md) | `TabletVisible`, `TabletCall` |
| [coe_rentals](coe_rentals.en-US.md) | `GetActiveRental` |
| [coe_shops](coe_shops.en-US.md) | `IsReady`, `GetShelves`, `IsStore`, `BusinessTablet`, `RegisterPaymentMethod` |
| [coe_spawn](coe_spawn.en-US.md) | `GetStarterHotel`, `SetStarterHotel` |
| [coe_staff](coe_staff.en-US.md) | `Yield`, `Status`, `RegisterGaragesProvider` |
| [coe_supervisor](coe_supervisor.en-US.md) | `List`, `Restart`, `GetUpdateStatus`, `CheckForUpdates`, `WriteFile`, `ReadFile`, `HashFile`, `DownloadFile`, `CommitFile`, `DiscardFile`, `VerifySignature`, `ApplyUpdate` |
| [coe_tablet](coe_tablet.en-US.md) | `TabletVisible`, `TabletCall` |
| [coe_talk](coe_talk.en-US.md) | `SetPlayerRadio`, `GetPlayerRadio`, `SetPlayerCall`, `GetPlayerCall`, `GetRadioMembers`, `GetCallMembers`, `GetVoiceRange`, `SetVoiceRange`, `GetRadioChannel`, `SetRadioChannel`, `GetCallChannel`, `SetCallChannel`, `IsTalking`, `IsRadioTransmitting`, `SetVoiceVolume` |
| [coe_telecom](coe_telecom.en-US.md) | `Authorize`, `Charge`, `LineOf`, `TabletCall`, `TabletVisible` |
| [coe_ui](coe_ui.en-US.md) | `GetTheme`, `GetThemes`, `SetTheme`, `GetAccent`, `SetAccent` |
| [coe_vehicle_catalog](coe_vehicle_catalog.en-US.md) | `GetVehicleInfo`, `ListVehicles`, `GetBaseHandling`, `GetIssues`, `SetOverride`, `ClearOverride`, `Rescan`, `IsReady` |
| [coe_vehicles](coe_vehicles.en-US.md) | `Create`, `Get`, `GetByPlate`, `ListByOwner`, `GetEntity`, `GetMileage`, `SetMileage`, `Spawn`, `Store`, `IsReady`, `HasKey`, `GiveKey`, `RevokeKey`, `ListKeyHolders` |
| [coe_workpad](coe_workpad.en-US.md) | `Yield`, `Status` |
| [coetarget](coetarget.en-US.md) | `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `AddTargetGlobal`, `RemoveTargetGlobal`, `AddTargetSurface`, `RemoveTargetSurface` |
