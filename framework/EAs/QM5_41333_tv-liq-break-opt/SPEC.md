# QM5_41333_tv-liq-break-opt - Strategy Spec

**EA ID:** QM5_41333
**Slug:** tv-liq-break-opt
**Parent EA:** QM5_10700_tv-liq-break
**Target symbols:** XAUUSD.DWX
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (TradingView open-source strategy)
**Author of this spec:** Claude
**Last revised:** 2026-09-03

---

## 1. Strategy Logic

This derivative preserves the approved parent mechanics and adds only the six
optional DL-089 closed-D1 pattern veto inputs. With all six inputs at zero,
the veto corset is neutral and the EA behaves identically to the recompiled
QM5_10700 identity.

The parent looks for a contraction pattern made from two recent pivot highs and
two recent pivot lows. A valid contraction exists when the newest pivot high is
below the prior pivot high and the newest pivot low is above the prior pivot
low. On the close of an H1 bar, the EA buys when price closes through the prior
liquidity high and sells when price closes through the prior liquidity low. The
baseline uses an ATR stop and a fixed 2R take-profit; there is no discretionary
exit beyond SL, TP, and the framework Friday close.

The DL-089 addition wires `QM_PatternPermission.mqh` (EA-managed) and evaluates
`Pattern_AllowsRequest(req)` immediately before every order submission. Each of
the six `opt_pp_*` inputs names a closed-D1 pattern predicate id; zero disables
that slot. The measurement census sweeps these predicates one at a time.

---

## 2. Parameters

Parent parameters are unchanged from QM5_10700 (see that EA's SPEC.md). The
DL-089 sibling adds six deterministic inputs:

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| opt_pp_buy1 | 0 | 0+ | Closed-D1 pattern predicate id gating BUY entries (0 = slot off). |
| opt_pp_buy2 | 0 | 0+ | Second BUY-side predicate slot. |
| opt_pp_buy3 | 0 | 0+ | Third BUY-side predicate slot. |
| opt_pp_sell1 | 0 | 0+ | Closed-D1 pattern predicate id gating SELL entries (0 = slot off). |
| opt_pp_sell2 | 0 | 0+ | Second SELL-side predicate slot. |
| opt_pp_sell3 | 0 | 0+ | Third SELL-side predicate slot. |

A negative id fails init (`PP_CENSUS_CONFIG_INVALID`). Any non-zero id turns the
profile active and switches the permission gate from `census_control`
(admit-all) to `QM_PatternPermissionEvaluate` on the closed D1 bar.

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - the DL-089 measurement target for parent QM5_10700; the census
  is materialized only for this (EA, symbol) pair.

**Explicitly NOT for (this sibling's scope):**
- All other parent symbols - the sibling is bound to the single Q12 deferral
  `expected one approved _opt sibling for QM5_10700/XAUUSD.DWX`. Other symbols
  are out of scope for this measurement card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 (closed-bar pattern-permission predicates) |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the framework OnTick gate |

The parent blocks timeframes outside H1, H4, and H6; the DL-089 census runs on
the H1 baseline.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~80 at the neutral baseline (parent expectation); lower when a predicate slot is active |
| Typical hold time | Hours to days; exits are ATR SL, 2R TP, and Friday close |
| Expected drawdown profile | Same as parent at neutral defaults; each active predicate only removes entries |
| Regime preference | Volatility-expansion breakout after contraction |
| Win rate target (qualitative) | Medium; fixed 2R target allows lower hit rate than 1R exits |

---

## 6. Source Citation

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/UUHabgvo-Liquidity-Breakout-Strategy-presentTrading/
**R1-R4 verdict (Q00):** all PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10700_tv-liq-break.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This sibling exists only to run the DL-089
pattern-measurement census; no live or pipeline verdict is authorized.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | DL-089 measurement sibling built from parent QM5_10700 (recipe b91f5ffa); six opt_pp_* pattern veto inputs added | Prepared for CEO-run governed compile/allocation |
