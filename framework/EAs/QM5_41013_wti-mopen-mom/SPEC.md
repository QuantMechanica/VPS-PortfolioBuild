# QM5_41013_wti-mopen-mom — Strategy Spec

**EA ID:** QM5_41013
**Slug:** `wti-mopen-mom`
**Source:** `MOP-WTI-MOPEN-MOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-15

---

## 1. Strategy Logic

On each new `XTIUSD.DWX` D1 bar, the EA counts completed bars in the current
broker month. At the first tick of the sixth D1 bar it computes
`log(fifth current-month close / prior-month-end close)`, buys when that value
is positive, and sells when it is negative. The month is durably consumed
before endpoint, news, spread, quote, stop, or order gates; a restart after the
sixth bar consumes the month flat rather than entering late.

The package has a frozen `3.5 * ATR(20,D1)` server-side stop and no target. It
closes on the first tick of the next broker month, after 35 calendar days, or
when the owned-position state is malformed. Friday close and both news axes
are disabled to preserve the residual-month hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_formation_bars` | 5 | 5 | Number of completed current-month bars in the locked opening segment |
| `strategy_history_bars` | 120 | 120 | Bounded D1 scan used for clock and endpoint validation |
| `strategy_atr_period` | 20 | 20 | Prior-completed-bar ATR period used only for the hard stop |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen ATR hard-stop multiple |
| `strategy_max_hold_days` | 35 | 35 | Stale-position guard around month renewal |
| `strategy_max_spread_points` | 1500 | 1500 | Maximum positive modeled WTI spread for entry |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are
not re-listed here.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the sole WTI CFD carrier named by the approved card; magic
  slot 0 and magic `410130000`.

**Explicitly not for:**

- `XAUUSD.DWX`, `XAGUSD.DWX`, `SP500.DWX`, `NDX.DWX`, and `XNGUSD.DWX` — the
  mission requests a direct crude-oil sleeve rather than another incumbent
  metal, index, or natural-gas carrier.
- Every other symbol — the broker-month segmentation and card approval are
  WTI-specific; this is an explicit single-symbol baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar()` call; bounded `CopyRates` scans occur only behind that edge |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12; retire below 5 per full year |
| Typical hold time | roughly 15–20 calendar days, from sixth D1 bar to month change |
| Expected drawdown profile | high and clustered when WTI opening impulses reverse |
| Regime preference | persistent directional crude-oil repricing within a broker month |
| Win rate target (qualitative) | medium; Q02 is authoritative |

---

## 6. Source Citation

This card was mechanized from:

**Source ID:** `MOP-WTI-MOPEN-MOM-2026`
**Source type:** governed translation of a peer-reviewed paper
**Pointer:** `strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md`
**R1–R4 verdict (G0):** all PASS; see
`strategy-seeds/cards/approved/QM5_41013_wti-mopen-mom_card.md` and
`decisions/2026-08-15_wti_mopen_momentum_g0.md`.

The source supports the own-return-sign continuation family, monthly cadence,
and WTI membership. It does not test the five-session formation or residual-
month hold; that translation is a disclosed QM falsification.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build authorizes only the RISK_FIXED
backtest configuration; the later rows describe the framework convention and
do not authorize live use.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-15 | Initial build from approved card | branch-only non-live build |
| v1-q01 | 2026-08-15 | Q01 validation | strict compile/build checks, seven reference tests, SPEC validation, and P1 artifact validation PASS |
