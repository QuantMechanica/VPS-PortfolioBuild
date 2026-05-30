# QM5_10148_tii-signal — Strategy Spec

**EA ID:** QM5_10148
**Slug:** `tii-signal`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_10148_tii-signal.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_10148_tii-signal.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | PERIOD_D1 | (see source) | (see strategy logic) |
| `strategy_tii_period` | 60 | (see source) | (see strategy logic) |
| `strategy_signal_ema` | 9 | (see source) | (see strategy logic) |
| `strategy_shorts_enabled` | false | (see source) | (see strategy logic) |
| `strategy_atr_period` | 14 | (see source) | (see strategy logic) |
| `strategy_atr_stop_mult` | 3.0 | (see source) | (see strategy logic) |
| `strategy_max_spread_points` | 0 | (see source) | (see strategy logic) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` — registered in magic_numbers.csv for this EA
- `AUDCHF.DWX` — registered in magic_numbers.csv for this EA
- `AUDJPY.DWX` — registered in magic_numbers.csv for this EA
- `AUDNZD.DWX` — registered in magic_numbers.csv for this EA
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA
- `CADCHF.DWX` — registered in magic_numbers.csv for this EA
- `CADJPY.DWX` — registered in magic_numbers.csv for this EA
- `CHFJPY.DWX` — registered in magic_numbers.csv for this EA
- `EURAUD.DWX` — registered in magic_numbers.csv for this EA
- `EURCAD.DWX` — registered in magic_numbers.csv for this EA
- `EURCHF.DWX` — registered in magic_numbers.csv for this EA
- `EURGBP.DWX` — registered in magic_numbers.csv for this EA
- `EURJPY.DWX` — registered in magic_numbers.csv for this EA
- `EURNZD.DWX` — registered in magic_numbers.csv for this EA
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPAUD.DWX` — registered in magic_numbers.csv for this EA
- `GBPCAD.DWX` — registered in magic_numbers.csv for this EA
- `GBPCHF.DWX` — registered in magic_numbers.csv for this EA
- `GBPJPY.DWX` — registered in magic_numbers.csv for this EA
- `GBPNZD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `GDAXI.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `NZDCAD.DWX` — registered in magic_numbers.csv for this EA
- `NZDCHF.DWX` — registered in magic_numbers.csv for this EA
- `NZDJPY.DWX` — registered in magic_numbers.csv for this EA
- `NZDUSD.DWX` — registered in magic_numbers.csv for this EA
- `SP500.DWX` — registered in magic_numbers.csv for this EA
- `UK100.DWX` — registered in magic_numbers.csv for this EA
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA
- `USDCHF.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA
- `WS30.DWX` — registered in magic_numbers.csv for this EA
- `XAGUSD.DWX` — registered in magic_numbers.csv for this EA
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA
- `XNGUSD.DWX` — registered in magic_numbers.csv for this EA
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Cadence note | see card body |
| Typical hold time | see card body |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | per card thesis |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Pointer:** `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_10148_tii-signal.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-25 | Initial spec (ex-post, generated by gen_spec_md.py) | post-PT15 remediation |
