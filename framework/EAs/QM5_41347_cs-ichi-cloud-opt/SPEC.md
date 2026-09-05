# QM5_41347_cs-ichi-cloud-opt - Strategy Spec

**EA ID:** QM5_41347
**Slug:** `cs-ichi-cloud-opt`
**Parent EA:** `QM5_11294_cs-ichi-cloud`
**Target symbols:** `XAUUSD.DWX`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (inherited from the approved parent card)
**Author of this spec:** Codex
**Last revised:** 2026-09-05

---

## 1. Strategy Logic

This DL-089 measurement sibling preserves the parent mechanics and adds only
six optional closed-D1 pattern veto inputs. With all six inputs zero, the veto
corset is neutral. Every otherwise-valid entry request passes through
`Pattern_AllowsRequest`; active predicates can veto but never create an entry.

## 2. Parameters

All parent parameters and defaults are unchanged. Added inputs are
`opt_pp_buy1`, `opt_pp_buy2`, `opt_pp_buy3`, `opt_pp_sell1`, `opt_pp_sell2`,
and `opt_pp_sell3`; each defaults to `0` (disabled).

## 3. Symbol Universe

Single measurement host: `XAUUSD.DWX`, magic slot 0.

## 4. Timeframe

Parent base timeframe: `H4`. Pattern permission always reads the completed
D1 bar at shift 1.

## 5. Expected Behaviour

Neutral baseline reproduces the parent, whose expected cadence is about
8 trades/year on the host. This package is measurement-only; no live
or pipeline verdict is authorized.

## 6. Source Citation

Source ID `72f9fcfa-6c75-5544-80c4-31e15c9817ab` and its citations are inherited from the approved
`QM5_11294` parent card.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`; news fail-closed staleness
remains capped at 336 hours. Live use is not authorized.

