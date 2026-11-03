# [vendor] — third-party dependencies

Third-party resources required by COE scripts that do not have a prebuilt download. They are kept in their own
category (`[vendor]`) to avoid mixing them with framework resources: FXServer finds them under
`[coe-framework]`, but repository tools (contracts, reference, boundary, version.json) ignore them.

| Resource | Source | License | Used by |
|---|---|---|---|
| `screenshot-basic` | [citizenfx/screenshot-basic](https://github.com/citizenfx/screenshot-basic), precompiled build (`dist/`) | MIT (Cfx.re) | `coe_apps` (camera and gallery) |

To update: build the official repository (`yarn && yarn build`) and replace `dist/`, recording the commit in `fxmanifest.lua`.
Reapply the `screenshot-basic` patch: in `dist/client.js`, `screenshot_created` uses `https://${GetCurrentResourceName()}/...` (the original uses `http://`).
