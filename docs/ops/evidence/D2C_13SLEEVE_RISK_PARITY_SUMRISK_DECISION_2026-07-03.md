# D2-c 13-sleeve risk-parity same-sum-risk decision package - 2026-07-03

Task: `b482e875-6bfd-4ea2-99bc-3459f3d93ae0`
Status: DRAFT OWNER decision package only. No live files changed, no T_Live action taken, no AutoTrading action taken.

## Scope

The live D2-c book currently runs 13 independent sleeves at flat `RISK_PERCENT=0.7500` and `PORTFOLIO_WEIGHT=1.0`, for `9.75%` summed sleeve risk if every sleeve has an open trade. This package computes inverse-vol sleeve allocations over the same 13 Q08 net-of-cost streams and normalizes the new `RISK_PERCENT` values to the same `9.75%` summed sleeve risk. It is a reallocation package, not a risk increase.

## Method

- Sleeve list and magics: `C:/QM/repo/decisions/2026-07-01_t_live_d2c_13sleeve_book.md` and `D:\QM\reports\portfolio\manifest_d2c_13sleeve_2026-06-28.json`.
- Streams: `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files/QM/q08_trades`, parsed with `tools/strategy_farm/portfolio/portfolio_common.py` and worst-case DXZ/FTMO commission model.
- Weighting: `inverse_vol_weights` over daily net-of-cost PnL for the 13 live sleeves.
- Before policy: `RISK_PERCENT=0.7500`, `PORTFOLIO_WEIGHT=1.0` on each sleeve.
- After policy: `RISK_PERCENT=9.75 * inverse_vol_weight`, `PORTFOLIO_WEIGHT=1.0` in staged presets.

## Before / After Metrics

| policy | summed risk | total net | annual return | Sharpe | MaxDD | monthly VaR 95 | worst day |
|---|---:|---:|---:|---:|---:|---:|---:|
| flat 0.75 each | 905 trade-days / 9.75% | $122,822 | 15.829% | 2.481 | 15.363% | 2.753% | -2.261% |
| inverse-vol same-sum | 905 trade-days / 9.75% | $77,950 | 10.046% | 2.986 | 3.887% | 1.712% | -1.914% |

Interpretation: same-sum inverse-vol improves this historical stream view by reducing drawdown and monthly VaR while raising Sharpe. It also concentrates allocation into lower-volatility commodity/FX sleeves, which needs OWNER review before any live manifest is signed.

## Old to New RISK_PERCENT

| slot | EA | symbol | TF | magic | old | new | delta | over 1pct cap |
|---:|---|---|---|---:|---:|---:|---:|---|
| 0 | QM5_10440 | NDX.DWX | H1 | 104400003 | 0.7500 | 0.1771 | -0.5729 | FALSE |
| 1 | QM5_10513 | XAUUSD.DWX | D1 | 105130003 | 0.7500 | 0.5332 | -0.2168 | FALSE |
| 2 | QM5_10692 | NDX.DWX | H1 | 106920005 | 0.7500 | 0.2612 | -0.4888 | FALSE |
| 3 | QM5_10715 | USDJPY.DWX | M15 | 107150004 | 0.7500 | 0.5210 | -0.2290 | FALSE |
| 4 | QM5_10911 | GDAXI.DWX | H1 | 109110003 | 0.7500 | 0.2388 | -0.5112 | FALSE |
| 5 | QM5_10939 | GBPUSD.DWX | H4 | 109390001 | 0.7500 | 0.6159 | -0.1341 | FALSE |
| 6 | QM5_10940 | XAUUSD.DWX | H4 | 109400003 | 0.7500 | 0.5264 | -0.2236 | FALSE |
| 7 | QM5_11132 | SP500.DWX | D1 | 111320000 | 0.7500 | 1.4776 | +0.7276 | TRUE |
| 8 | QM5_11165 | AUDCAD.DWX | H1 | 111650002 | 0.7500 | 2.1399 | +1.3899 | TRUE |
| 9 | QM5_11421 | AUDUSD.DWX | D1 | 114210003 | 0.7500 | 0.6970 | -0.0530 | FALSE |
| 10 | QM5_11421 | EURUSD.DWX | D1 | 114210000 | 0.7500 | 1.0599 | +0.3099 | TRUE |
| 11 | QM5_12567 | XAUUSD.DWX | D1 | 125670003 | 0.7500 | 0.6660 | -0.0840 | FALSE |
| 12 | QM5_12567 | XNGUSD.DWX | D1 | 125670002 | 0.7500 | 0.8359 | +0.0859 | FALSE |

## Guardrail Notes

- The staged draft presets are outside `T_Live`: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\staged_live_presets`.
- The literal same-sum inverse-vol policy puts 3 sleeves above the framework 1% per-trade cap noted in `D2C_FLAT_075_RISK_RECHECK_2026-06-28.md`. This is acceptable as a decision package but should not be copied live without an explicit OWNER-signed manifest and a cap decision.
- `PORTFOLIO_WEIGHT` is kept at `1.0` in staged presets because the current live policy encodes per-sleeve risk directly in `RISK_PERCENT`; setting both `RISK_PERCENT=9.75*w` and `PORTFOLIO_WEIGHT=w` would double-apply the weight.
- No `T_Live` file was written by this task.

## Artifacts

- Metrics JSON: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\d2c_invvol_sumrisk_metrics_2026-07-03.json`
- Equity curve CSV: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\d2c_sumrisk_equity_curve_before_after_2026-07-03.csv`
- Risk table CSV: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\d2c_risk_percent_old_to_invvol_2026-07-03.csv`
- Draft staged presets: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\staged_live_presets`

## Variant B (capped)

Task: `b0b51db3-939c-46cf-a27d-af52b5976b89`

Variant B applies a hard `1.0000%` per-sleeve `RISK_PERCENT` cap to the inverse-vol same-sum allocation, then redistributes capped excess pro-rata to the remaining under-cap sleeves until stable. Total summed risk remains `9.75%`, and the maximum staged sleeve risk is exactly `1.0000%`.

Data-basis note: the live `DEFAULT_COMMON_DIR` Q08 stream files changed after the uncapped package above was generated, so the original b482e875 flat/uncapped metrics could not be reproduced from current files. The table below is internally consistent on the current stream snapshot for flat, uncapped inverse-vol, and capped inverse-vol. The original b482e875 metrics remain preserved in the section above and in the parent metrics JSON.

### Variant B Metrics

| policy | summed risk | total net | annual return | Sharpe | MaxDD | monthly VaR 95 | worst day |
|---|---:|---:|---:|---:|---:|---:|---:|
| flat 0.75 each (current streams) | 960 trade-days / 9.75% | $122,266 | 15.758% | 2.164 | 16.892% | 2.815% | -2.641% |
| inverse-vol same-sum uncapped (current streams) | 960 trade-days / 9.75% | $77,819 | 10.029% | 2.813 | 4.309% | 1.634% | -1.914% |
| inverse-vol same-sum capped (current streams) | 960 trade-days / 9.75% | $90,448 | 11.657% | 2.661 | 6.219% | 2.113% | -2.386% |

### Variant B Old to New RISK_PERCENT

| slot | EA | symbol | TF | magic | old | uncapped | capped | delta vs old | hard capped |
|---:|---|---|---|---:|---:|---:|---:|---:|---|
| 0 | QM5_10440 | NDX.DWX | H1 | 104400003 | 0.7500 | 0.1771 | 0.2403 | -0.5097 | FALSE |
| 1 | QM5_10513 | XAUUSD.DWX | D1 | 105130003 | 0.7500 | 0.5332 | 0.7237 | -0.0263 | FALSE |
| 2 | QM5_10692 | NDX.DWX | H1 | 106920005 | 0.7500 | 0.2612 | 0.3545 | -0.3955 | FALSE |
| 3 | QM5_10715 | USDJPY.DWX | M15 | 107150004 | 0.7500 | 0.5210 | 0.7071 | -0.0429 | FALSE |
| 4 | QM5_10911 | GDAXI.DWX | H1 | 109110003 | 0.7500 | 0.2388 | 0.3241 | -0.4259 | FALSE |
| 5 | QM5_10939 | GBPUSD.DWX | H4 | 109390001 | 0.7500 | 0.6159 | 0.8359 | +0.0859 | FALSE |
| 6 | QM5_10940 | XAUUSD.DWX | H4 | 109400003 | 0.7500 | 0.5264 | 0.7145 | -0.0355 | FALSE |
| 7 | QM5_11132 | SP500.DWX | D1 | 111320000 | 0.7500 | 1.4776 | 1.0000 | +0.2500 | TRUE |
| 8 | QM5_11165 | AUDCAD.DWX | H1 | 111650002 | 0.7500 | 2.1399 | 1.0000 | +0.2500 | TRUE |
| 9 | QM5_11421 | AUDUSD.DWX | D1 | 114210003 | 0.7500 | 0.6970 | 0.9460 | +0.1960 | FALSE |
| 10 | QM5_11421 | EURUSD.DWX | D1 | 114210000 | 0.7500 | 1.0599 | 1.0000 | +0.2500 | TRUE |
| 11 | QM5_12567 | XAUUSD.DWX | D1 | 125670003 | 0.7500 | 0.6660 | 0.9039 | +0.1539 | FALSE |
| 12 | QM5_12567 | XNGUSD.DWX | D1 | 125670002 | 0.7500 | 0.8359 | 1.0000 | +0.2500 | TRUE |

### Variant B Artifacts

- Metrics JSON: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\variant_b\d2c_variant_b_capped_metrics_2026-07-03.json`
- Equity curve CSV: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\variant_b\d2c_sumrisk_equity_curve_flat_invvol_capped_2026-07-03.csv`
- Risk table CSV: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\variant_b\d2c_risk_percent_old_to_invvol_capped_2026-07-03.csv`
- Draft staged capped presets: `D:\QM\strategy_farm\artifacts\portfolio\d2c_invvol_sumrisk_2026-07-03\variant_b\staged_live_presets`

## Verdict

PASS_FOR_OWNER_REVIEW: inverse-vol same-sum-risk package produced and staged. Do not deploy directly; OWNER must decide whether to waive/cap per-sleeve risk above 1% and issue a signed manifest if proceeding.
