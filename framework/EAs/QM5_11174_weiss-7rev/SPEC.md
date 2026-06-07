# QM5_11174_weiss-7rev - Strategy Spec

**EA ID:** QM5_11174
**Slug:** weiss-7rev
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades Weissman's H1 seven-period reversal rule. A long signal requires closes from bar 8 through bar 2 to decline consecutively, followed by bar 1 closing above bar 2. A short signal requires closes from bar 8 through bar 2 to rise consecutively, followed by bar 1 closing below bar 2. Entries are market entries on the next bar when flat; exits occur through a 1% stop, a 1% target, or an opposite reversal signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for the completed-close reversal test. |
| `strategy_sequence_steps` | `6` | fixed at `6` for card compliance | Number of consecutive close-to-close declines or rises from bar 8 through bar 2. |
| `strategy_stop_pct` | `1.0` | `> 0` | Fixed stop distance as percent of entry price. |
| `strategy_target_pct` | `1.0` | `> 0` | Fixed profit target distance as percent of entry price. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - matches the source context of a 60-minute Nasdaq 100 reversal test.
- `SP500.DWX` - broad US large-cap index exposure in the approved R3 basket; backtest-only at T6 gate.
- `WS30.DWX` - liquid US large-cap index proxy in the approved R3 basket.
- `EURUSD.DWX` - liquid FX symbol included by the approved R3 basket.
- `XAUUSD.DWX` - liquid metal symbol included by the approved R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid DWX test targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Card frontmatter does not specify; expected to be short-term H1 holds until 1% target, 1% stop, or opposite reversal. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent one-way trends. |
| Regime preference | Short-term mean-reversion / seven-bar reversal. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems*, Chapter 5, pp. 96-98; approved card at `artifacts/cards_approved/QM5_11174_weiss-7rev.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11174_weiss-7rev.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | 2664e9dd-7645-4dd8-be6b-7bb443430e4a |
