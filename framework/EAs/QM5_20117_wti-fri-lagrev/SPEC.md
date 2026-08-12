# QM5_20117_wti-fri-lagrev — Strategy Spec

**EA ID:** QM5_20117  
**Slug:** `wti-fri-lagrev`  
**Source:** `MEEK-HOELSCHER-WTI-DOW-2023`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

Run only on `XTIUSD.DWX` D1. At the first tradable tick of a
broker-calendar Friday, require the two previous completed D1 bars to be
Thursday and Wednesday. Compute
`100 * ln(ThursdayClose / WednesdayClose)`. If that return is at least 4.5%,
sell WTI once with a hard stop `3.0 * ATR(20)` above entry. Close at broker
Friday hour 21; a non-Friday D1 bar and a three-calendar-day limit are stale
safety exits.

The Friday is consumed before history, signal, news, spread, ATR, price, or
order gates. A terminal-global marker plus position/deal history prevents a
restart, rejection, stop, or blocked gate from creating a same-Friday retry.
The 4.5% threshold exceeds the Friday-coefficient/lag-coefficient break-even
point in every WTI model reported in the source.

---

## 2. Parameters

All strategy parameters are locked for the Q02 baseline.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_thu_log_return_pct` | 4.5 | locked | Minimum completed Thursday log return |
| `strategy_entry_grace_minutes` | 5 | locked | Maximum delay from the Friday D1 open |
| `strategy_atr_period` | 20 | locked | Completed-bar ATR stop estimator |
| `strategy_atr_sl_mult` | 3.0 | locked | Hard-stop distance in ATR units |
| `strategy_max_hold_days` | 3 | locked | Final calendar stale-position guard |
| `strategy_max_spread_points` | 1000 | locked | Entry spread ceiling |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the registered Darwinex WTI continuous-CFD route, magic slot
  0 and magic `201170000`.

**Explicitly NOT for:**

- `XNGUSD.DWX` — natural gas has different weekday coefficients and a
  separate source-family extraction.
- `XBRUSD.DWX` — the paper's Brent result and local carrier status are
  different; this build is WTI-specific.
- Any index, metal, FX, synthetic pair, or implicit symbol port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the exact host |
| Raw reads | shifts 0-2 only, once on a genuine new D1 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 3-8 consumed signals; roughly 5 entries before blocked gates |
| Typical hold time | one Friday session |
| Expected drawdown profile | sparse, discontinuous WTI gap/tail losses capped by a broker hard stop where executable |
| Regime preference | rare one-day conditional mean reversion after a large Thursday surge |
| Win rate target | unknown; must be established by Q02 |

Q02 must retire the carrier for zero trades, fewer than two completed trades
per year on average, wrong-day or duplicate entries, weekend holds,
nondeterminism, risk-mode mismatch, or governed PF/DD failure. The source
implies only a very small conditional mean before costs.

---

## 6. Source Citation

**Source ID:** `MEEK-HOELSCHER-WTI-DOW-2023`  
**Source type:** peer-reviewed open-access paper  
**Pointer:** `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`  
**DOI:** https://doi.org/10.1080/23322039.2023.2213876  
**R1-R4 verdict:** all PASS; see
`strategy-seeds/cards/approved/QM5_20117_wti-fri-lagrev_card.md`.

The paper uses synchronized WTI futures closes. The executable carrier starts
at the first Friday CFD tick, omits the overnight gap, and uses a continuous
CFD rather than the paper's CL1/CL2 roll. Those differences and transaction
costs are binding falsification risks.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | 1000 |
| Live burn-in (Q13) | not authorized | - |
| Full live | not authorized | - |

The only preset is the backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. There is no take-profit, trailing,
scale-in, partial close, grid, martingale, or live setfile. This build does not
touch AutoTrading, `T_Live`, a deploy/T_Live manifest, the portfolio gate, or
portfolio admission.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-24 | Initial build from approved S05 card | source-derived 4.5% threshold; Q01/Q02 only |
