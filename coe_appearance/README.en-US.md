# coe_appearance

Character appearance: saved format, ped application, and the **character creator**. Closes issue #54.

## Format (version 1)

`shared/schema.lua` (pure and tested) defines and normalizes the appearance stored by `coe_core` as opaque JSON (`appearance` + `appearance_version` in `coe_characters`, up to 16 KB):

- `model`: `mp_m_freemode_01` or `mp_f_freemode_01`.
- `heritage`: `mother` and `father` (GTA Online indexes, 0 to 45), `shapeMix`, and `skinMix` (0 to 1; 0 = mother, 1 = father).
- `features`: 20 facial adjustments (-1 to 1, `SetPedFaceFeature` 0 to 19).
- `overlays`: 13 overlays (`SetPedHeadOverlay` 0 to 12) with `style` (-1 = none), `opacity`, `color`, and `secondColor`.
- `hair` (`style`, `texture`, `color`, `highlight`), `eyeColor` (0 to 31).
- `components` and `props`: drawable and texture by ID (clothing and accessories; prop -1 = none).

Out-of-range values are clamped, and unknown keys are discarded. When applying, clothing and hair drawables beyond what the model supports are reset to 0 (natives), so an old appearance never leaves the ped without a face.

## Exports (client)

- `Apply(ped, appearance)`: applies everything except the model.
- `ApplyToPlayer(appearance)`: changes the player's model and applies the appearance.
- `CreatePed(appearance, x, y, z, heading, gender?)`: local ped for scenes (selection, creator); without an appearance, uses the gender's model.
- `Normalize(appearance)`, `Default(gender)`, `Version()`.
- Creator: `OpenCreator({ mode = 'create'|'appearance', characterId?, gender?, firstName?, lastName?, birthDate? })`, `CloseCreator()` (leaves the screen dark so the caller can build the next scene), `CreatorError(message)`, `IsCreatorOpen()`.
- Local events: `coe_appearance:creatorSubmit` (`{ mode, characterId, identity, appearance, version }`) and `coe_appearance:creatorCancelled`. `coe_characters` listens and communicates with the server.

## Character creator

Opens in the GTA Online creator's lineup room (`Creator.Ped` in `config.lua`), with a local ped, the game's own idle animation, frozen time, and cameras with interpolation and depth of field (body, bust, face, and legs; each step chooses its own). Steps:

1. **Identity** (creation only): first name, last name, date of birth, and gender.
2. **Heritage**: mother and father with in-game portraits (`https://nui-img/char_creator_portraits/...`), resemblance, and skin tone.
3. **Face**: 20 grouped adjustments (nose, eyebrows, cheeks, eyes and lips, jaw and chin, neck).
4. **Details**: eye color, skin, aging, freckles, blemishes, and sun damage.
5. **Hair and makeup**: style and variation, color and highlights from the game's palette (`GetPedHairRgbColor`), eyebrows, beard and body hair (male), makeup, blush, and lipstick (`GetPedMakeupRgbColor`).
6. **Clothing**: tabs by subcategory (Outfits, Torso, Legs and feet, Head, Accessories — `AppearanceSchema.ClothingCategories`), pills per item, a grid with a photo of each item (loaded as you scroll; "No." field jumps directly), and color variations for the selected item. Limited to what the model supports, including DLCs and add-ons; the camera follows the item.
7. **Review** and registration.

Drag in the empty space (or use A/D) to rotate the character; "Random" chooses coherent heritage, face, and details. After registration, appearance can only be changed at a barber and clothing store (future): `coe_core` only accepts setting the appearance of a character that does not already have one.

## Clothing photos

Photos are generated on the server itself, once (and again when new clothing is added):

1. Grant the ACE: `add_ace group.admin coe_appearance.thumbs allow` and keep `screenshot-basic` started.
2. In game: `/coe_fotos_roupas` (both genders), `/coe_fotos_roupas male`, or `female`; `refazer` retakes existing photos. Backspace or repeating the command interrupts.
3. The client builds the creator room, puts each item on over the base outfit (`Thumbnails.BaseOutfit`), frames it by subcategory (`Thumbnails.Cameras`), takes a screenshot, crops the center, resizes to 256 px in WebP in the NUI, and sends it to the server (latent event). The server checks name, type, and size, then saves to `thumbs/<male|female>_<c|p><id>_<drawable>.webp`.
4. Restart `coe_appearance`: photos are resource files and players download them once (they are cached). To reduce download size, `Thumbnails.Base` can point to an HTTPS CDN with the same names.

Without a photo, the card displays the item's number.

## Configuration

`config.lua`: ped position and streaming focus, cameras, camera for each step, idle animation, blur, time, and preset outfits. Outfit drawables vary with DLCs and clothing add-ons: check in game.

## Tests

`lua test/schema_test.lua`: models, defaults, normalization (ranges, types, unknown keys, idempotency), randomization, portraits, adjustment catalog, clothing subcategories, and photo names. `lua test/thumbs_server_test.lua`: base64, photo validation, ACE, and generator session. Natives, cameras, and NUI require in-game validation.
