# Referência da API dos resources

> Gerado por `tools/gen_reference.lua` a partir dos `types.lua` (convenção em coe-docs/ANNOTATIONS.md).

| Resource | Exports |
|---|---|
| [coe_admin](coe_admin.md) |  |
| [coe_amzg](coe_amzg.md) | `AdminCatalog`, `AdminDeleteProduct`, `AdminSaveProduct`, `TabletCall`, `TabletVisible` |
| [coe_appearance](coe_appearance.md) | `OpenCreator`, `CloseCreator`, `CreatorError`, `IsCreatorOpen`, `Apply`, `ApplyToPlayer`, `CreatePed`, `Normalize`, `Default`, `Version` |
| [coe_apps](coe_apps.md) | `ClaimPhoto`, `DeletePhoto`, `HasApp`, `PhotoData`, `StorePhoto`, `TabletCall`, `TabletVisible`, `TakePhoto` |
| [coe_audit](coe_audit.md) | `Record`, `IsReady` |
| [coe_banking](coe_banking.md) | `AdminAccount`, `AdminBusinessAccount`, `AdminBusinessAccounts`, `AdminBusinessAdjust`, `AdminBusinessCardLimit`, `AdminCard`, `AdminDecideRequest`, `AdminForgiveLoan`, `AdminGrantLoan`, `AdminLoanRequests`, `AdminPoints`, `AdminSaveTiers`, `AdminSetCredit`, `AdminTiers`, `BusinessTablet`, `CardPurchase`, `CardRefund`, `PosCards`, `PosPurchase`, `ShopCharge`, `ShopOptions`, `ShopRefund`, `TabletCall`, `TabletVisible`, `WalletCards`, `WalletEligible`, `WalletIssueVirtual`, `WalletLink` |
| [coe_businesses](coe_businesses.md) | `IsReady`, `Categories`, `RuleSchema`, `List`, `Get`, `Save`, `Seed`, `Delete`, `ClockIn`, `ClockOut`, `Clock`, `IsOnDuty`, `DutySummary`, `CurrentDuty`, `Access`, `Partners`, `Debtors`, `Permissions`, `RegisterPermissions`, `Grades`, `GradeOf`, `Can`, `Salary`, `Payroll`, `RegisterTab`, `RegisterProvider`, `TabletInstances`, `TabletCall` |
| [coe_characters](coe_characters.md) | `IsOpen`, `CloseSelection` |
| [coe_core](coe_core.md) | `GetCoreObject`, `GetCharacterByStateId`, `GetActiveCharacter`, `GetPlayerByStateId`, `GetGroupDefinitions`, `GetPlayerGroups`, `SetPlayerGroup`, `RemovePlayerGroup` |
| [coe_crafting](coe_crafting.md) | `AdminCatalog`, `AdminDeleteBench`, `AdminDeleteMenu`, `AdminDeleteRecipe`, `AdminSaveBench`, `AdminSaveMenu`, `AdminSaveRecipe`, `AdminSetBusinessMenu`, `Begin`, `Busy`, `Cancel`, `Close`, `Complete`, `List`, `ListRecipes`, `Open`, `RegisterBench`, `RegisterRecipe`, `RemoveRecipe` |
| [coe_crypto](coe_crypto.md) | `IsReady`, `Price`, `Balance`, `IsAddress`, `Format`, `MintMining`, `ComputerCall`, `HeldWallets`, `EscrowLock`, `EscrowRelease`, `ReserveAddress`, `AdminOverview`, `AdminInspect`, `AdminSaveSettings`, `AdminResetSettings`, `AdminSetPrice`, `TabletVisible`, `TabletCall` |
| [coe_database](coe_database.md) | `Query`, `Execute`, `Transaction`, `IsReady` |
| [coe_deepweb](coe_deepweb.md) | `TabletVisible`, `TabletCall`, `AdminOverview`, `AdminSaveSite`, `AdminDeleteSite`, `AdminSaveVendor`, `AdminDeleteVendor`, `AdminResolveOrder`, `AdminRemovePost`, `AdminReplyContact`, `AdminCloseContact` |
| [coe_dispatch](coe_dispatch.md) | `Accept`, `Active`, `Alert`, `Close` |
| [coe_doors](coe_doors.md) | `CanAccess`, `Delete`, `IsLocked`, `IsReady`, `List`, `Save`, `SetLocked`, `TabletCall`, `TabletVisible` |
| [coe_economy](coe_economy.md) | `IsReady`, `Summary`, `GetBalance`, `Credit`, `Debit`, `Transfer`, `Ledger`, `LedgerStats`, `SocietyBalance`, `SocietyLedger`, `SocietyDeposit`, `SocietyWithdraw`, `SocietyCredit`, `SocietyCollect`, `SocietyCharge`, `BankSocietyPay`, `BankSocietyDeposit`, `BankSocietyDebit`, `BankSocietyCredit`, `BankSocietyTransfer`, `BankSocietyLedger`, `RunPayroll` |
| [coe_elos](coe_elos.md) | `IsReady`, `GetProfile`, `TabletVisible`, `TabletCall` |
| [coe_ems](coe_ems.md) | `Records`, `Revive`, `SetState`, `State`, `Treat` |
| [coe_factions](coe_factions.md) | `CanCraft`, `CanCraftInFaction`, `Categories`, `Delete`, `Get`, `IsReady`, `List`, `Members`, `Memberships`, `PauseMenuFaction`, `RecipesFor`, `RecipesForFaction`, `RemoveMember`, `Save`, `SetMember`, `TabletCall`, `TabletInstances` |
| [coe_fuel](coe_fuel.md) | `IsReady`, `GetFuel`, `GetEffects`, `GetStationTanks`, `IsStation`, `BusinessTablet` |
| [coe_garages](coe_garages.md) | `AddBusinessFleet`, `AddFleetVehicle`, `BusinessFleet`, `DeleteGarage`, `ListFleet`, `ListGarages`, `RemoveFleetVehicle`, `SaveGarage`, `SetFleetStaffAccess`, `TabletCall` |
| [coe_handling](coe_handling.md) | `GetTyre`, `SetTyre`, `ListTyres`, `ListClasses`, `GetModifiers`, `IsReady` |
| [coe_housing](coe_housing.md) | `AddressActive`, `BeginPreview`, `BusinessProperties`, `CurrentSpace`, `DeleteProperty`, `DeliveryAddresses`, `EndContract`, `EndPreview`, `InteriorThumbs`, `Interiors`, `IsReady`, `ListProperties`, `PlayersInSpace`, `PropertyContracts`, `SaveInteriorThumb`, `SaveProperty`, `TabletCall`, `TabletVisible` |
| [coe_hud](coe_hud.md) | `SetHidden`, `IsHidden`, `SetLogoVisible`, `IsLogoVisible`, `ToggleLogo` |
| [coe_inventory](coe_inventory.md) | `CreateInventory`, `DeleteInventory`, `GetInventory`, `GetSlot`, `SwapSlots`, `SplitItem`, `AddItem`, `RemoveItem`, `UseItem`, `SetItemMetadata`, `GetItemCount`, `GetPersistenceStats`, `OpenStash`, `RemoveItemByName`, `RemoveItemsByMetadata`, `RegisterItem`, `Items`, `GetItem`, `GetContainerInventory`, `GetPlayerInventory`, `GetInventoryObject` |
| [coe_jobs](coe_jobs.md) | `RegisterJob`, `UnregisterJob`, `ListJobs`, `IsReady`, `GetSession`, `GetProgress`, `GetCareer`, `TabletVisible`, `TabletCall` |
| [coe_loadscreen](coe_loadscreen.md) | `IsActive`, `Shutdown` |
| [coe_logging](coe_logging.md) | `Log` |
| [coe_loot](coe_loot.md) | `Give`, `Roll`, `Tables` |
| [coe_mail](coe_mail.md) | `Send`, `TabletCall`, `TabletVisible` |
| [coe_map](coe_map.md) | `GetMode`, `OpenFull` |
| [coe_mdt](coe_mdt.md) | `AccessLog`, `TabletCall` |
| [coe_mechanic](coe_mechanic.md) | `TabletCall`, `Inspect`, `ReplacePart`, `ServiceVehicle`, `AdjustMileage`, `AddWear`, `GetEffects`, `ListParts`, `IsReady`, `GetShopOwner`, `GetAppearance`, `QuoteAppearance`, `SetAppearance`, `GetShops`, `GetVehicleOptions` |
| [coe_needs](coe_needs.md) | `GetNeeds`, `SetNeed`, `AddNeed` |
| [coe_news](coe_news.md) | `AdminAction`, `AdminOverview`, `AdminQuery`, `TabletCall`, `TabletVisible` |
| [coe_notify](coe_notify.md) | `Notify`, `Show`, `Prompt` |
| [coe_phone](coe_phone.md) | `ActiveDevice`, `ActiveLine`, `ConsumePayment`, `NumberOf`, `RequestPayment`, `ShopCharge`, `ShopOptions`, `ShopRefund`, `UpgradeStatus` |
| [coe_police](coe_police.md) | `Arrest`, `Cuff`, `Escort`, `Fine`, `IsCuffed`, `IsEscorted`, `IsJailed`, `Records`, `Search`, `Seize`, `Uncuff` |
| [coe_races](coe_races.md) | `TabletVisible`, `TabletCall` |
| [coe_rentals](coe_rentals.md) | `GetActiveRental`, `ListStations`, `SaveStation`, `DeleteStation`, `Catalog` |
| [coe_shops](coe_shops.md) | `IsReady`, `GetShelves`, `IsStore`, `BusinessTablet`, `RegisterPaymentMethod` |
| [coe_spawn](coe_spawn.md) | `GetStarterHotel`, `SetStarterHotel` |
| [coe_supervisor](coe_supervisor.md) | `List`, `Restart`, `GetUpdateStatus`, `CheckForUpdates`, `WriteFile`, `ReadFile`, `HashFile`, `DownloadFile`, `CommitFile`, `DiscardFile`, `VerifySignature`, `ApplyUpdate` |
| [coe_tablet](coe_tablet.md) | `TabletVisible`, `TabletCall` |
| [coe_talk](coe_talk.md) | `SetPlayerRadio`, `GetPlayerRadio`, `SetPlayerCall`, `GetPlayerCall`, `GetRadioMembers`, `GetCallMembers`, `GetVoiceRange`, `SetVoiceRange`, `GetRadioChannel`, `SetRadioChannel`, `GetCallChannel`, `SetCallChannel`, `IsTalking`, `IsRadioTransmitting`, `SetVoiceVolume` |
| [coe_telecom](coe_telecom.md) | `Authorize`, `Charge`, `LineOf`, `TabletCall`, `TabletVisible` |
| [coe_ui](coe_ui.md) | `GetTheme`, `GetThemes`, `SetTheme`, `GetAccent`, `SetAccent` |
| [coe_vehicle_catalog](coe_vehicle_catalog.md) | `GetVehicleInfo`, `ListVehicles`, `ListVehiclesPage`, `ListClasses`, `GetBaseHandling`, `GetIssues`, `SetOverride`, `ClearOverride`, `Rescan`, `IsReady` |
| [coe_vehicles](coe_vehicles.md) | `Create`, `Get`, `GetByPlate`, `ListByOwner`, `GetEntity`, `GetMileage`, `SetMileage`, `Spawn`, `Store`, `IsReady`, `HasKey`, `GiveKey`, `RevokeKey`, `ListKeyHolders` |
| [coetarget](coetarget.md) | `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `AddTargetGlobal`, `RemoveTargetGlobal`, `AddTargetSurface`, `RemoveTargetSurface` |
