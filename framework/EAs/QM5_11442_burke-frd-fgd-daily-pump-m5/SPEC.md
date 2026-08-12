# QM5_11442_burke-frd-fgd-daily-pump-m5 — Strategy Spec

**EA ID:** QM5_11442
**Slug:** burke-frd-fgd-daily-pump-m5
**Source:** 04305b6c-b4ce-522b-87b5-71708b6b8327 (see strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/)
**Author of this spec:** Codex
**Last revised:** 2026-08-03

---

## 1. Strategy Logic

The EA looks for a three-day reversal pattern on closed daily candles. An FRD
short requires Day 1 to close above the prior day's high and Day 2 to open at
or above Day 1's close before closing lower; the FGD long uses the exact mirror
conditions. On Day 3, the first closed M5 candle that crosses back through
EMA(20) during the London or New York UTC session opens the trade. The position
uses a fixed 50-pip target and a 20-pip stop; an FRD short may instead use an
EMA-plus-5-pip stop, always capped at 25 pips. After the entry session ends, a
position that has not progressed at least halfway to target closes at market.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 20 | 13–34 | M5 EMA period used by the closed-bar crossover trigger. |
| strategy_session_london | true | true/false | Enables entries in the London UTC window. |
| strategy_session_ny | true | true/false | Enables entries in the New York UTC window. |
| strategy_london_start_utc | 7 | 0–23 | London entry-window start hour in UTC. |
| strategy_london_end_utc | 12 | 1–23 | London entry-window end hour in UTC, exclusive. |
| strategy_ny_start_utc | 13 | 0–23 | New York entry-window start hour in UTC. |
| strategy_ny_end_utc | 17 | 1–23 | New York entry-window end hour in UTC, exclusive. |
| strategy_tp_pips | 50 | 30–75 | Fixed take-profit distance in scale-correct pips. |
| strategy_sl_pips | 20 | 15–25 | Base fixed stop-loss distance in scale-correct pips. |
| strategy_short_ema_buffer_pips | 5 | fixed | FRD short stop buffer above EMA(20). |
| strategy_sl_cap_pips | 25 | fixed | Absolute P2 stop-distance cap. |
| strategy_spread_cap_pips | 15 | fixed | Blocks only a positive modeled spread wider than 15 pips. |

Framework inputs such as RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news,
stress, seed, and Friday-close controls are documented in
framework/V5_FRAMEWORK_DESIGN.md and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- EURUSD.DWX — highly liquid London/New York major matching the card's R3 FX universe.
- GBPUSD.DWX — London-led major suited to the stated daily pump-and-fade setup.
- USDJPY.DWX — liquid major with active New York overlap; framework pip scaling handles JPY precision.
- AUDUSD.DWX — portable DWX major explicitly named by the approved card.
- USDCAD.DWX — New York-active DWX major explicitly named by the approved card.

**Explicitly NOT for:**

- Symbols outside framework/registry/dwx_symbol_matrix.csv — the tester has no canonical tick history for them.
- Index and metal CFDs — the approved card defines FX pip targets and an FX-only instrument basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | PERIOD_D1 shifts 1–3 for the closed FRD/FGD pattern |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Expected trade frequency | Roughly weekly per symbol, derived from 45 expected trades per year |
| Typical hold time | Intraday, from M5 entry until SL/TP or the entry-session time stop |
| Regime preference | Multi-day pump-and-fade reversal after directional excess |
| Expected drawdown profile | Bounded per trade by the 20–25 pip server-side stop |
| Win rate target (qualitative) | Not specified by the approved card |

Only expected_trades_per_year_per_symbol is present as a dedicated frontmatter
metric. Frequency, hold time, and regime are taken literally from the approved
card's mechanics and concepts.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 04305b6c-b4ce-522b-87b5-71708b6b8327
**Source type:** online/self-published trading playbook
**Pointer:** Stacey Burke, The Stacey Burke Trading Playbook (2022), source record sources/burke-stacey-playbook
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per artifacts/cards_approved/QM5_11442_burke-frd-fgd-daily-pump-m5.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by QM_FrameworkInit
(EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-03 | Initial build from card | 5ef6e12b-d284-489a-8faa-860460ba5ebc |
