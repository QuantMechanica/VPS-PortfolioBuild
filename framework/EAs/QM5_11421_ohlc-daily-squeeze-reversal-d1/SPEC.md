# QM5_11421_ohlc-daily-squeeze-reversal-d1 - Strategy Spec

**EA ID:** QM5_11421
**Slug:** `ohlc-daily-squeeze-reversal-d1`
**Source:** `ca63d391-50d5-52ea-a026-6e82a7433431` (see approved strategy-farm card)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA watches completed D1 bars for a two-day squeeze pattern. A short setup requires two rising closes and a latest closed bar whose range sits at least halfway above the previous close; it arms a SELLSTOP one latest-bar range below the latest close. A long setup mirrors the rule with two falling closes and a BUYSTOP one latest-bar range above the latest close. Filled positions use a fixed target of one latest-bar range and a stop beyond the squeeze bar, capped at 80 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_range_mult` | 1.0 | 0.5-1.5 P3 sweep axis | Pending entry offset as a multiple of the squeeze bar range. |
| `strategy_sl_range_mult` | 1.5 | 1.0-2.0 P3 sweep axis | Stop placement beyond the squeeze bar high/low. |
| `strategy_tp_range_mult` | 1.0 | positive double | Take-profit distance from pending entry as a multiple of the squeeze bar range. |
| `strategy_min_range_pips` | 30.0 | 20-50 P3 sweep axis | Minimum squeeze-bar range; narrower D1 bars are skipped. |
| `strategy_sl_cap_pips` | 80.0 | positive double | Maximum allowed stop distance for the P2 build. |
| `strategy_pending_ttl_bars` | 1 | positive integer | Pending stop expiry in D1 bars. |
| `strategy_spread_cap_pips` | 25.0 | positive double | Blocks only genuinely wide spreads; zero modeled spread is allowed. |
| `strategy_enable_long` | true | true/false | Enables the symmetric long-side rule described by the card convention. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed D1 FX pair with DWX data available.
- `GBPUSD.DWX` - Card-listed D1 FX pair with DWX data available.
- `USDJPY.DWX` - Card-listed D1 FX pair with DWX data available.
- `AUDUSD.DWX` - Card-listed D1 FX pair with DWX data available.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - The card is an FX D1 OHLC squeeze setup and R3 names only FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | Daily pattern, about 30 entries per symbol per year from card expectation |
| Typical hold time | Not specified in frontmatter; expected to be days because entries and expiry are D1 based |
| Expected drawdown profile | Mean-reversion squeeze reversals with fixed-range SL/TP and 80 pip stop cap |
| Regime preference | Mean-reversion after short-term directional squeeze |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ca63d391-50d5-52ea-a026-6e82a7433431`
**Source type:** book/PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\93933996-forex-scalping-strategies.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11421_ohlc-daily-squeeze-reversal-d1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | e185956c-ec7e-4f25-9881-acdefd504ffc |
