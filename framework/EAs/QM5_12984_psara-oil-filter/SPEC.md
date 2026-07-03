# QM5_12984_psara-oil-filter - Strategy Spec

**EA ID:** QM5_12984
**Slug:** `psara-oil-filter`
**Source:** `PSARADELLIS-OIL-FILTER-2019`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency WTI crude-oil percent-filter rule on
`XTIUSD.DWX`. On each completed D1 bar it updates a running trough and peak of
closed prices since the last directional signal. It opens long when the closed
price rises at least `strategy_filter_pct` percent above the running trough,
and opens short when the closed price falls at least `strategy_filter_pct`
percent below the running peak.

The strategy is intentionally distinct from `QM5_1226`, which mechanizes the
same Psaradellis et al. crude-oil source through a Donchian/channel-breakout
family. It is also distinct from the FX-only Neely/Weller percent-filter builds
because this card is a WTI source port registered only on `XTIUSD.DWX`.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_filter_pct` | 7.5 | 5.0-12.5 | Percent move from tracked extreme required for a new signal |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the safety stop |
| `strategy_sl_atr_mult` | 3.0 | 2.0-4.0 | ATR multiple for the safety stop |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- `XTIUSD.DWX` is present in `framework/registry/dwx_symbol_matrix.csv`.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.
- Raw close reads are single closed-bar reads used only after a new-bar event.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-10, depending on crude-oil volatility.
- Typical hold: multi-day to multi-week, until an opposite filter signal or
  the ATR safety stop.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Psaradellis, I., Laws, J., Pantelous, A. A. and Sermpinis, G. "Performance of
technical trading rules: evidence from the crude oil market." The European
Journal of Finance, 25(17), 1793-1815, 2019.
DOI: https://doi.org/10.1080/1351847X.2018.1552172.

Public metadata:
https://ideas.repec.org/a/taf/eurjfi/v25y2019i17p1793-1815.html and
https://ssrn.com/abstract=2832600.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from card | Enqueue Q02 |
