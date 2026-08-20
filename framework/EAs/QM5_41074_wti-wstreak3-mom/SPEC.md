# QM5_41074_wti-wstreak3-mom - Strategy Spec

**EA ID:** QM5_41074

**Slug:** `wti-wstreak3-mom`

**Strategy ID:** `MOP-WTI-WSTREAK3-MOM-2026_S01`

**Source:** `MOP-WTI-WSTREAK3-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-20

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
five consecutive completed broker-week ending closes and the four adjacent
weekly returns. Trade only when the newest three returns have one strict
common sign and the preceding return has the strict opposite sign. Follow the
fresh three-week streak direction for one broker week.

Zero returns, malformed history, nonconsecutive anchors, invalid session
counts, or every sign path other than strict `-+++` / `+---` consumes the week
flat. The position uses one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 50 | bounded D1 weekly-endpoint buffer |
| `strategy_required_weeks` | 5 | consecutive completed weekly endpoints |
| `strategy_min_week_bars` | 3 | minimum completed sessions per week |
| `strategy_max_week_bars` | 5 | maximum completed sessions per week |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410740000`, after governed allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: five consecutive completed broker-week ending closes.
- Trigger: newest three adjacent weekly returns have one strict sign and the
  immediately preceding return has the opposite strict sign.
- Direction: follow the fresh three-week streak.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately four to ten completed positions per full post-warm-up year;
  Q02 retires below three.
- Symmetric WTI continuation only on the first appearance of a three-week
  same-sign streak; a rolling fourth same-sign week cannot re-enter.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WSTREAK3-MOM-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon, three-week streak, and opposite-sign predecessor transition
are disclosed QM hypotheses; no source result transfers to this CFD
implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The position has a frozen completed-bar ATR stop. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-20 | approved build-directory identity | source approval `c0fe1591d`; deterministic registry reservation in the commit containing this spec |
| v1-card | 2026-08-20 | G0-approved execution contract | `strategy-seeds/cards/approved/QM5_41074_wti-wstreak3-mom_card.md` |
| v1-build | 2026-08-20 | deterministic implementation and Q01 validation | 11-test reference suite; strict compile/build PASS; static P1 PASS |
| v1-q02-capacity | 2026-08-20 | paced Q02 admission check | one target baseline eligible; not enqueued because sampled host CPU exceeded the 97% ceiling |
| v1-q02-queue | 2026-08-20 | shared-farm queue reconciliation | exact `XTIUSD.DWX` Q02 row `059206dc-dc65-4bee-aa7c-68f5ce7be3e3` observed pending; no duplicate enqueue; SPEC metadata normalized for deterministic validation |
