# QM5_10359_et-gap-fade — Strategy Spec

**EA ID:** QM5_10359
**Slug:** `et-gap-fade`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Opening-gap fade on M5 index CFDs (Elite Trader / WarEagle, 2002). On the first
session bar (US symbols default to broker 16:30; GDAXI/UK100-style European
symbols default to broker 10:00), compute `gap = abs(prev_day_close -
session_open)`. If the gap is at least
`strategy_gap_percent` (0.6%) of the prior daily close AND the session opened
*above* the prior day's high, arm a SHORT fade entered as a SELL_STOP through the
first bar's low; if it opened *below* the prior day's low, arm a LONG fade as a
BUY_STOP through the first bar's high. Profit target is a gap-fill equal to the
gap size; protective stop is `strategy_stop_gap_mult` × gap (1.25× — V5 mandates a
hard stop the source left optional). Unfilled pending orders expire after
`strategy_inactive_stop_bars` bars, and a filled position is time-stopped after the
same number of bars. Trades are skipped when the first-bar range exceeds
`strategy_first_range_atr_max` × ATR(14) or when the stop distance is tighter than
`strategy_min_stop_spreads` × current spread. One trade per symbol per session;
Friday close enforced by the framework.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_10359_et-gap-fade.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_gap_percent` | 0.006 | 0.004–0.010 | Min gap as fraction of prior daily close to arm a fade (card sweep set). |
| `strategy_inactive_stop_bars` | 15 | 10–30 | Bars before an unfilled pending order expires and a filled position is time-stopped. |
| `strategy_stop_gap_mult` | 1.25 | 1.0–2.0 | Protective stop distance = mult × gap (V5-mandated hard stop). |
| `strategy_first_range_atr_max` | 0.8 | 0.5–1.5 | Skip if first-bar range > mult × ATR(14) (rejects already-extended opens). |
| `strategy_atr_period` | 14 | 7–28 | ATR period (M5) for the first-bar-range volatility filter. |
| `strategy_auto_session_open` | true | true/false | Use symbol-aware session-open mapping for US vs European index CFDs. |
| `strategy_us_session_open_hhmm` | 1630 | broker HHMM | Broker-time of the US cash index session open. |
| `strategy_eu_session_open_hhmm` | 1000 | broker HHMM | Broker-time of the European cash index session open. |
| `strategy_entry_window_minutes` | 10 | 5–30 | Minutes after the session-open bar during which an entry may be armed. |
| `strategy_min_stop_spreads` | 4 | 2–10 | Skip if stop distance < mult × current spread (cost-floor guard). |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `WS30.DWX` — registered in magic_numbers.csv for this EA
- `GDAXI.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Cadence note | "Opening gap fade only when the index gaps beyond 0.6%; conservative estimate 45 trades/year/symbol after spread and session filters." |
| Typical hold time | see card body |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | per card thesis |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Pointer:** `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_10359_et-gap-fade.md`

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
| v2 | 2026-06-05 | Rebuild-in-place: added `// perf-allowed` tags to bespoke gap OHLC reads (build_check EA_FRAMEWORK_RAW_SERIES_CALL), filled §1 logic + §2 param meanings, and made session-open mapping symbol-aware for the GDAXI port | 8f2cd142-8faa-4228-89ab-b384696b6640 |
