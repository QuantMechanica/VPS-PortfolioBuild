# QM5_11409_big-ben-london-fade-asian-range-m15 - Strategy Spec

**EA ID:** QM5_11409
**Slug:** `big-ben-london-fade-asian-range-m15`
**Source:** `b771d955-5033-500a-bb6b-98bd284b5b79` (see `strategy-seeds/sources/b771d955-5033-500a-bb6b-98bd284b5b79/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades the Big Ben London fade on M15. It builds a body-based Asian range from broker-time 01:00 through 09:00 by taking the maximum of open/close as `asian_high` and the minimum of open/close as `asian_low`. Between 09:00 and 10:00 broker time it requires a pre-London sweep: low below `asian_low` for a long fade, or high above `asian_high` for a short fade. From 10:00 until the 11:00 time stop it enters only on the first M15 close back through the swept range boundary, then uses the reversal-bar extreme as SL capped at 40 pips and projects the Asian range as TP. Open positions are force-closed at 11:00 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_asian_start_hour` | 1 | 0-23 | Asian session start, broker hour inclusive |
| `strategy_asian_end_hour` | 9 | 0-23 | Asian session end, broker hour exclusive |
| `strategy_london_open_hour` | 10 | 0-23 | London fade window start, broker hour |
| `strategy_time_stop_hour` | 11 | 0-23 | Force-close hour, broker time |
| `strategy_spread_cap_pips` | 20 | 1-100 | Entry is blocked only when spread is genuinely wider than this pip cap |
| `strategy_sl_cap_pips` | 40 | 1-200 | Maximum stop distance in pips |
| `strategy_fallback_sl_pips` | 30 | 1-200 | Fixed fallback stop when the reversal-bar extreme is invalid |
| `strategy_tp_range_mult` | 1.0 | 0.1-3.0 | TP equals Asian range height times this multiple |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card-preferred GBP cross, directly tied to London liquidity.
- `GBPJPY.DWX` - card-preferred GBP cross with active Asian and London sessions.
- `EURUSD.DWX` - liquid London-session FX major with clean overnight range formation.
- `USDJPY.DWX` - active Asian-session FX major listed by the card.

**Explicitly NOT for:**
- Index, metal, energy, and crypto `.DWX` symbols - the card defines an FX London-open false-breakout fade.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` from card frontmatter |
| Typical hold time | `intraday; minutes to 1 hour, with forced exit at 11:00 broker` |
| Expected drawdown profile | `small, bounded intraday losses from false-break fade failures` |
| Regime preference | `session mean-reversion after pre-London false breakout` |
| Win rate target (qualitative) | `not specified in card` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b771d955-5033-500a-bb6b-98bd284b5b79`
**Source type:** `website / local PDF`
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\450251566-Big-Ben-Breakout-Strategy-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11409_big-ben-london-fade-asian-range-m15.md`

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
| v1 | 2026-06-23 | Initial build from card | 2faafd3a-0e2d-4f01-8608-2b375c905bba |
