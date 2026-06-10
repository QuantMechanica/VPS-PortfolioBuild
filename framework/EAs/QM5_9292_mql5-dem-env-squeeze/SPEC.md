# QM5_9292_mql5-dem-env-squeeze — Strategy Spec

**EA ID:** QM5_9292
**Slug:** `mql5-dem-env-squeeze`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades a volatility-compression breakout on H4. An Envelope squeeze is detected when the current Envelope band width (upper minus lower) is narrower than the previous bar's width AND narrower than its own 20-bar median. Simultaneously, DeMarker must be building pressure inside the neutral zone (0.40–0.60): for a long setup, previous DeMarker >= 0.40 with current DeMarker <= 0.60 and rising; for a short setup, previous DeMarker <= 0.60 with current DeMarker >= 0.40 and falling. Once armed, the EA waits up to three H4 bars for a confirmed breakout: long if close breaks above the upper Envelope band, short if close breaks below the lower band. Positions exit when price crosses the Envelope midline, DeMarker crosses 0.50 in the opposing direction, or after 10 H4 bars (time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_env_period` | 14 | 5–50 | Envelope SMA period |
| `strategy_env_deviation` | 0.10 | 0.05–0.50 | Envelope deviation percentage |
| `strategy_dem_period` | 14 | 5–50 | DeMarker oscillator period |
| `strategy_dem_zone_lo` | 0.40 | 0.20–0.49 | DeMarker neutral zone lower bound |
| `strategy_dem_zone_hi` | 0.60 | 0.51–0.80 | DeMarker neutral zone upper bound |
| `strategy_env_median_bars` | 20 | 10–100 | Width filter lookback (bars) |
| `strategy_breakout_bars` | 3 | 1–10 | Max bars to wait for breakout confirmation |
| `strategy_max_hold_bars` | 10 | 5–50 | Time exit after N H4 bars |
| `strategy_swing_lookback` | 5 | 3–20 | Bars for swing high/low SL anchor |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair; deep liquidity, tight spreads, reacts well to volatility-compression breakouts
- `GBPUSD.DWX` — major FX pair; higher volatility than EURUSD, broadens opportunity set for squeeze setups
- `XAUUSD.DWX` — gold; exhibits distinct volatility-compression phases, diversifies away from FX correlation

**Explicitly NOT for:**
- Index CFDs — card specifies FX + gold basket only; index spread dynamics differ materially

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 |
| Typical hold time | 1–10 H4 bars (4–40 hours) |
| Expected drawdown profile | Low-medium; squeeze breakouts have defined SL at Envelope band or swing structure |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 63): Using Patterns of DeMarker and Envelope Channels", MQL5 Articles, 2025-05-07 — Pattern 4 "Envelope Squeeze + DeMarker Building Pressure"
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9292_mql5-dem-env-squeeze.md`

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
| v1 | 2026-06-10 | Initial build from card | 50ea5f7c-ac0e-4c78-9a13-c0b8dc792dc1 |
