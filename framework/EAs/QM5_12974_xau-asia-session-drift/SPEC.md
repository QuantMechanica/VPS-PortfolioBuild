# QM5_12974_xau-asia-session-drift — Strategy Spec

**EA ID:** QM5_12974
**Slug:** `xau-asia-session-drift`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03` (see `strategy-seeds/sources/CEO-ANOMALY-SLATE-2026-07-03/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-05

---

## 1. Strategy Logic

Pure clock, no indicators. Buy XAUUSD.DWX on the M30 bar that opens at 00:00
GMT (the Asian-session open), and close the position on the M30 bar at 07:00
GMT (just before London opens). The edge is documented intraday gold
seasonality: systematic strength during the Asian session driven by Eastern
physical demand, fading once Western paper markets open at the London fix.
One position per magic; no fixed price stop in the strategy definition — the
session close is the real exit. A wide ATR-based stop is attached to every
entry purely so the framework's risk-based lot sizer has a nonzero SL
distance to size against (see Parameters); it is a sizing backstop, not part
of the trading signal, and is not expected to be hit inside the 7-hour hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_gmt_hhmm` | 0 | 0-2330 | Entry clock time in GMT, HHMM integer (0 = 00:00 GMT Asia-session open) |
| `strategy_exit_gmt_hhmm` | 700 | 0-2330 | Exit clock time in GMT, HHMM integer (700 = 07:00 GMT, pre-London) |
| `strategy_stop_atr_period` | 14 | 1-50 | M30 ATR period used only to size the risk-sizing backstop SL |
| `strategy_stop_atr_mult` | 4.0 | >0 | ATR multiple for the backstop SL distance; wide by design, not a signal |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — the only symbol the card targets; the Asia/London seasonality
  edge is specific to gold's Eastern-physical vs Western-paper demand
  structure, confirmed both by Speck's minute-averaged study and in-house
  measurement (bkr04-05, t=+2.45). Card frontmatter sets
  `single_symbol_only: true`, so no other DWX symbols are registered for this
  EA (P2 Saturation exception).

**Explicitly NOT for:**
- All other DWX symbols — the seasonality thesis is gold-specific and the
  card explicitly restricts to a single symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default symbol/period) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~250 |
| Typical hold time | 7 hours (00:00-07:00 GMT) |
| Expected drawdown profile | ~15% (expected_dd_pct per card) |
| Regime preference | session-anomaly / deterministic-clock, long-only |
| Win rate target (qualitative) | medium — thin edge, cost-sensitive per card kill criteria |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-ANOMALY-SLATE-2026-07-03`
**Source type:** `AI` (OWNER-directed anomaly slate; underlying references: Speck (2013) intraday gold seasonality studies; in-house QuantMechanica study bkr04-05)
**Pointer:** `strategy-seeds/sources/CEO-ANOMALY-SLATE-2026-07-03/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12974_xau-asia-session-drift.md`

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
| v1 | 2026-07-05 | Initial build from card | 44201e7a-f160-4f85-bf63-3b1e241ebb91 |
