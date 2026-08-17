# QM5_33008 (thomas-stridsman-rvi-noise-buster) Build & Verification Evidence

- Task ID: `4b97cf9e-7a3c-452d-bc44-964a5a85555b`
- EA ID: `QM5_33008`
- Date: 2026-08-17
- Branch: `agents/board-advisor`
- Target symbols: `NDX.DWX` (slot 0), `SP500.DWX` (slot 1)
- Timeframe: `H1`
- Magic Numbers: `330080000` (slot 0), `330080001` (slot 1)

## Summary of Implementation

Implemented Thomas Stridsman's RVI Volatility Noise Buster system mechanically per approved strategy card `QM5_33008_thomas-stridsman-rvi-noise-buster.md`:
- Relative Volatility Index (RVI) calculated over 14 periods using 10-period standard deviations of upward and downward price changes.
- Trend baseline filter: 50-period EMA on H1.
- Long Entry: evaluated at bar close Shift=1 when $\text{Close}[1] > \text{EMA}(50, \text{H1})[1]$ and $\text{RVI}[2] < 50.0$ and $\text{RVI}[1] \ge 50.0$.
- Short Entry: evaluated at bar close Shift=1 when $\text{Close}[1] < \text{EMA}(50, \text{H1})[1]$ and $\text{RVI}[2] > 50.0$ and $\text{RVI}[1] \le 50.0$.
- Risk & Money Management: Stop Loss set at $1.8 \times \text{ATR}(14, \text{H1})[1]$; Take Profit set at $2.0 \times \text{SL\_Distance}$ ($1:2.0$ Risk:Reward ratio).
- Trailing Stop: once floating profit reaches $+1.0\text{R}$, stop loss is trailed at $1.5 \times \text{ATR}(14, \text{H1})$ behind current market price.
- No-Trade Filter: spread filter ($> 1.8 \times \text{ATR}(14, \text{H1})[1]$) and 23:55-00:05 rollover blackout.

## Verification Checklist

- **Magic Numbers Registry**: Registered both portable DWX basket symbols in `framework/registry/magic_numbers.csv` (`330080000`, `330080001`).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,343 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_33008_thomas-stridsman-rvi-noise-buster/SPEC.md` and validated with `validate_spec_doc.py` -> `PASS`.
- **Build Check & Compilation**: Ran `build_check.ps1` -> `PASS` (0 errors, 0 warnings; `.ex5` compiled cleanly).
- **Setfile Generation**: Generated `NDX.DWX` and `SP500.DWX` H1 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> `PASS` (`max_news_stale_hours: 336`, `verdict: PASS`).
- **Smoke Status**: `deferred_p2_smoke` recorded due to headless scheduled execution; Q02 will provide runtime backtest evidence.

## State Disposition

Artifact ready for Codex review.
