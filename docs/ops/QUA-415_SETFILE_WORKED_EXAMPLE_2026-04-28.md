# QUA-415 Worked Example — Generated Backtest Set File

Date: 2026-04-28

Command:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/gen_setfile.ps1 `
  -EaSlug QM5_SRC04_S03_lien_fade_double_zeros `
  -Symbol EURUSD.DWX `
  -TF H1 `
  -Env backtest
```

Output path:

`framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/QM5_SRC04_S03_lien_fade_double_zeros_EURUSD.DWX_H1_backtest.set`

SHA256:

`d38d2adbe1932227e96bd3f33e24078e0b5b9b0109087350c27cce6f739eea18`

Rendered `.set` content:

```ini
; QuantMechanica V5 generated set file
; Generator=framework/scripts/gen_setfile.ps1
ENV=backtest
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
; strategy-specific params from card must be appended below this line
```
