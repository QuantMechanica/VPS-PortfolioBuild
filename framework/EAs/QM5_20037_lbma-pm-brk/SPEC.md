# QM5_20037_lbma-pm-brk — Strategy Spec

**EA ID:** QM5_20037
**Slug:** `lbma-pm-brk`
**Source:** CAMINSCHI-HEANEY-2014
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

On each UTC weekday, the EA freezes the completed 14:55–15:00 London M5 range
and arms in the direction of that bar's body. It enters at 15:05 or 15:10
London only when the first eligible completed M5 close breaks the frozen range
in the armed direction; an opposite close cancels the date. The opposite range
edge is the immutable hard stop, there is no profit target or trade-management
overlay, and any remaining position closes at the first tradable quote at or
after 15:15 London. Exact valid bars replace the external auction ledger, and
Tester Groups applies venue commission to fills.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `LBMA_PM_BRK_BASELINE` | locked | Approved card variant identity. |
| `strategy_signal_tf` | `PERIOD_M5` | locked | Signal and execution-bar timeframe. |
| `strategy_pre_bar_*_london` | `14:55` | locked | Frozen pre-auction M5 bar start in London time. |
| `strategy_confirmation1_*_london` | `15:00` | locked | First confirmation-bar start in London time. |
| `strategy_confirmation2_*_london` | `15:05` | locked | Second confirmation/first-entry bar start in London time. |
| `strategy_exit_*_london` | `15:15` | locked | Mandatory flat time in London time. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — the card's sole gold-auction price, signal, and order route.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card forbids sibling order routes and
  depends specifically on the LBMA PM gold auction.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 200 before dojis and unconfirmed breaks |
| Typical hold time | 5–15 minutes, always flat at or after 15:15 London |
| Expected drawdown profile | approximately 12% card prior, with losses clustered around failed auction breakouts |
| Regime preference | benchmark-auction information concentration and short-horizon breakout |
| Win rate target (qualitative) | not specified by the approved card |

## 6. Source Citation

This card was mechanised from:

**Source ID:** CAMINSCHI-HEANEY-2014
**Source type:** academic paper
**Pointer:** Caminschi and Heaney (2014), *Journal of Futures Markets* 34(11),
DOI 10.1002/fut.21636; implementation card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20037_lbma-pm-brk_card.md`.
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20037_lbma-pm-brk.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The approved baseline itself authorizes fixed-risk testing only; any live risk
mode remains a later governed promotion decision.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | e7bbe65a-a948-4127-a13a-5422895208fa |
| v2 | 2026-07-22 | FTMO density fix | Replaced the unprovisioned auction ledger and commission/cost gate with broker-clock weekday/bar eligibility and the optional native spread guard. |
