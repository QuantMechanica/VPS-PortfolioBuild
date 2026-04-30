# QUA-171 - V5 Framework Step 19 (`sync_brand_tokens.ps1`)

Date: 2026-04-27  
Issue: QUA-171  
Owner: CTO

## Scope

Implement Step 19 from `framework/V5_FRAMEWORK_DESIGN.md`: `framework/scripts/sync_brand_tokens.ps1` must generate `framework/include/QM_Branding.mqh` from `branding/brand_tokens.json`.

## Implementation

- Added `framework/scripts/sync_brand_tokens.ps1`.
- Default paths:
  - input: `branding/brand_tokens.json`
  - output: `framework/include/QM_Branding.mqh`
- Enforced strict token validation for every mapped colour (`#RRGGBB` only).
- Implemented RGB->MQL5 BGR conversion to emit constants in `C'0xBB,0xGG,0xRR'` format.
- Emits framework constants used by V5 chart/report surfaces:
  - `QM_CLR_BG`, `QM_CLR_SURFACE_0`, `QM_CLR_SURFACE_1`, `QM_CLR_SURFACE_2`
  - `QM_CLR_TEXT`, `QM_CLR_TEXT_DIM`, `QM_CLR_TEXT_MUTED`, `QM_CLR_TEXT_SUBTLE`, `QM_CLR_TEXT_FAINT`
  - `QM_CLR_EMERALD`, `QM_CLR_EMERALD_LT`, `QM_CLR_EMERALD_DARK`
  - `QM_CLR_PASS`, `QM_CLR_PROMISING`, `QM_CLR_FAIL`, `QM_CLR_DEAD`, `QM_CLR_LIVE`, `QM_CLR_WARN`, `QM_CLR_INFO`
  - `QM_FONT_SANS`, `QM_FONT_MONO`
- Idempotence behavior: if output content matches generated content, script reports `no_change` and does not rewrite the file.

## Verification

Command (run twice sequentially):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/sync_brand_tokens.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/sync_brand_tokens.ps1
```

Observed result:

```text
sync_brand_tokens: no_change
token_path=C:\QM\repo\branding\brand_tokens.json
output_path=C:\QM\repo\framework\include\QM_Branding.mqh
sync_brand_tokens: no_change
token_path=C:\QM\repo\branding\brand_tokens.json
output_path=C:\QM\repo\framework\include\QM_Branding.mqh
```

## Notes

- Script compatibility adjusted for Windows PowerShell 5.1 (`ConvertFrom-Json` used without `-Depth`).
- This step only delivers the token-sync generator; compile/build/smoke scripts are tracked in later framework steps.
