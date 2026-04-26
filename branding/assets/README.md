# Brand Assets

V5 brand asset working copies. Drive remains canonical for full brand archive (Brand Book HTML, Brand Guidelines DOCX, mascot PNGs, YouTube banners). Repo carries only what scripts and dashboards need at runtime.

## Files

| File | Purpose | Source on Drive |
|---|---|---|
| `favicon.svg` | Browser tab favicon, dashboard tab icon | `Backups/pre_claude_design_20260418/Website/favicon.svg` |
| `og-image.svg` | OpenGraph / link-preview card | `Backups/pre_claude_design_20260418/Website/assets/og-image.svg` |
| `logo_transparent_2000px.png` | Primary logo, transparent background | `Backups/pre_claude_design_20260418/Brand_Assets/Logo_Transparent_2000px.png` |
| `logo_black_bg_2000px.png` | Logo on solid black, when BG transparency would clash | `Backups/pre_claude_design_20260418/Brand_Assets/Logo_Black_BG_2000px.png` |

## Sync Rule

If the Drive originals change, update repo + bump `branding/QM_BRANDING_GUIDE.md` § 9 with the new SHA256. Do not edit repo copies directly — Drive is upstream for visual brand.

## Not Included In Repo

- Mascot 9 poses (YouTube/social-media only per Brand Book § 07)
- YouTube banner / thumbnail templates (live in Drive `02_YouTube/`)
- Brand Book HTML + Brand Guidelines DOCX (read-only reference on Drive)
- Audio signation MP3s
- Desktop wallpaper

These stay on Drive because they don't ship at runtime. Wave 0 reads Drive when needed.
