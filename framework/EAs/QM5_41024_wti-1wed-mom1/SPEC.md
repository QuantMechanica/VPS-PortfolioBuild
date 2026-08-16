# QM5_41024_wti-1wed-mom1 - Strategy Spec

**EA ID:** QM5_41024

**Slug:** `wti-1wed-mom1`

**Source:** `LI-MOP-WTI-1WED-MOM1-2026`

**Last revised:** 2026-08-16

## 1. Strategy Logic

`QM5_41024_wti-1wed-mom1` is a single-symbol D1 WTI calendar/trend
interaction. It evaluates only the first genuine Wednesday session of each
normalized broker month. It reconstructs the last completed closes of the two
immediately preceding broker months and follows the one-month log-return sign.
The package closes at the first following D1 boundary.

The approved execution contract is
`strategy-seeds/cards/approved/QM5_41024_wti-1wed-mom1_card.md`. The source
lineage supports WTI's Wednesday information clock and instrument-own monthly
return-sign continuation separately; it does not test this conjunction or its
one-session lifecycle.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_dow` | 3 | normalized Wednesday |
| `strategy_first_week_last_dom` | 7 | first-Wednesday date ceiling |
| `strategy_return_months` | 1 | completed calendar-month formation |
| `strategy_hold_bars` | 1 | next-D1 exit contract |
| `strategy_entry_grace_minutes` | 180 | executable-session attachment |
| `strategy_history_bars` | 100 | bounded completed-month endpoint scan |
| `strategy_atr_period` | 20 | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 5 | stale guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

There is no approved parameter sweep.

## 3. Symbol And Timeframe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Timeframe: exact D1.
- Magic slot: 0.
- Planned magic: `410240000`.
- No alternate symbol or suffix stripping is permitted in research/backtest
  artifacts.

## 4. Signal And Attempt Contract

1. Normalize D1 labels only by zero or one uniform `+86400`-second energy
   offset and require the normalized current date to equal broker date.
2. Require Wednesday, day 1-7, and an immediately prior normalized Tuesday
   label. Missing first Wednesdays do not shift.
3. Consume the normalized `yyyymm` before history, signal, news, spread,
   quote, stop, sizing, or order gates.
4. Use only completed closes from the immediately prior two exact consecutive
   normalized broker months.
5. BUY a strictly positive log return; SELL a strictly negative log return;
   exact zero consumes the month flat.

## 5. Risk And Lifecycle

- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Hard stop: frozen `3.0 * ATR(20,D1)`.
- Take-profit: none.
- Normal exit: first following normalized D1 boundary.
- Stale guard: five calendar days.
- Friday close: enabled at broker hour 21.
- News: temporal OFF, compliance NONE, legacy OFF.
- No trailing, break-even, partial close, scale-in, grid, martingale, or
  pyramid.

## 6. Framework Alignment

- No-Trade: host, timeframe, ID, slot, seed, fixed-risk, news, Friday, stress,
  and locked strategy-input checks.
- Trade Entry: exact normalized first-Wednesday clock, persistent attempt,
  completed-month endpoint scan, strict sign direction, spread, quote, ATR,
  and hard stop.
- Trade Management: malformed/duplicate repair, next-D1 exit, and stale exit
  before new entry.
- Trade Close: V5 trade-manager close path, server hard stop, Friday close,
  and kill switch.

## 7. Falsification Boundary

Q02 retires the candidate below five completed positions per full post-warm-up
year, on zero trades, nonpositive governed economics, wrong or shifted
Wednesday, wrong month endpoints, current-bar leakage, duplicate attempts,
sign/direction mismatch, late exit, invalid risk mode, or nondeterminism. Q09
alone may establish realized correlation with the certified book.

## 8. Safety Boundary

This build is non-live. It authorizes one fixed-risk backtest setfile and one
paced Q02 enqueue only. It excludes manual tester control, live/demo/shadow or
stress setfiles, `T_Live`, AutoTrading, deploy manifests, portfolio-gate
changes, portfolio admission, and correlation waivers.

## Revision History

| Version | Date | Reason | Phase |
|---|---|---|---|
| v1 | 2026-08-16 | initial approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic implementation | magic/resolver verified; strict compile and build check PASS |
| v1-q02-hold | 2026-08-16 | paced Q02 handoff stopped at CPU ceiling | pre-command path-anchored sample found 7/7 T1-T10 tester terminals; no queue row created |
