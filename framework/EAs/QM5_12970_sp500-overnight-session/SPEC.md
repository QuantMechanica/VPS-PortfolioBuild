# QM5_12970_sp500-overnight-session — Strategy Spec

**EA ID:** QM5_12970
**Slug:** `sp500-overnight-session`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03` (see `strategy-seeds/sources/CEO-ANOMALY-SLATE-2026-07-03/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-05

---

## 1. Strategy Logic

BUY SP500.DWX on the M30 bar that opens at the US cash close (16:00 ET, broker
time 23:00 per the DXZ NY-Close model), and close the position on the M30 bar
that opens at the next US cash open (09:30 ET, broker time 16:30). No
indicators drive entry/exit — the edge is the documented overnight-return
premium: US equity index returns accrue almost entirely between the cash
close and the next cash open, while the intraday session nets close to zero
(Cooper/Cliff/Gulen 2008; Kelly/Clark 2011; Lachance 2020). By default the
Friday cash-close entry is skipped so no position is ever held over the
weekend gap. An optional regime filter (only enter when the last closed bar's
close is above SMA(200)) exists as an input but defaults OFF to keep the pure
anomaly signal unfiltered, per the card's "anomaly purity" baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_friday_flat` | true | true/false | Skip the Friday US-cash-close entry so no position is held over the weekend gap (card default: no weekend hold). |
| `strategy_sma_regime_filter` | false | true/false | Optional regime input: only enter when last closed bar's close > SMA(200). Card default OFF for anomaly purity. |
| `strategy_sma_regime_period` | 200 | 200 | SMA period for the optional regime filter (only read when `strategy_sma_regime_filter=true`). |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — pure US large-cap cash-close/cash-open overnight anomaly; the
  card is `single_symbol_only: true` (SP500.DWX is a backtest-only Custom
  Symbol on T1-T5 since 2026-05-16, no live order routing).

**Explicitly NOT for:**
- `NDX.DWX` / `WS30.DWX` — the card cites the SPX-specific overnight-premium
  literature (Cooper/Cliff/Gulen studied the S&P 500 specifically); the card
  frontmatter marks this build single-symbol-only rather than porting the
  anomaly to other US indices in this variant.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~250 (one overnight hold per trading day) |
| Typical hold time | ~17.5 hours (cash close to next cash open) |
| Expected drawdown profile | Crash-overnight gap risk (probed at Q05/Q06); no fixed price stop, bounded by V5 equity kill-switch |
| Regime preference | Session-anomaly / overnight-hold, not trend or mean-reversion |
| Win rate target (qualitative) | medium (small consistent overnight drift, not a high-conviction directional signal) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-ANOMALY-SLATE-2026-07-03`
**Source type:** `paper`
**Pointer:** Cooper, M., Cliff, M. & Gulen, H. (2008), Return Differences
between Trading and Non-Trading Hours (SSRN 1004081); Kelly, M. & Clark, S.
(2011), Returns in trading versus non-trading hours, Journal of Asset
Management; Lachance, M. (2020), Night trading: lower risk, higher returns
(SSRN).
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12970_sp500-overnight-session.md`

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
| v1 | 2026-07-05 | Initial build from card | 609d5505-997a-4aeb-9cc7-8914a660d4ed |
