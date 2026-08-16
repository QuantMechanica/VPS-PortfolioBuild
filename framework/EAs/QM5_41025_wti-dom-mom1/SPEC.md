# QM5_41025_wti-dom-mom1 - Strategy Spec

**EA ID:** QM5_41025

**Slug:** `wti-dom-mom1`

**Source:** `BOROWSKI-MOP-WTI-DOMMOM1-2026`

**Last revised:** 2026-08-16

## 1. Strategy Logic

`QM5_41025_wti-dom-mom1` is a single-symbol D1 WTI calendar/momentum
interaction. It buys only on exact normalized broker-calendar day 8 when the
immediately completed calendar-month return is positive, or sells only on
exact day 26 when that return is negative. Each package exits at the first
following normalized D1 boundary.

The approved execution contract is
`strategy-seeds/cards/approved/QM5_41025_wti-dom-mom1_card.md`. Borowski
supports the two WTI calendar directions and Moskowitz, Ooi, and Pedersen
support instrument-own completed-return sign. Neither source tests this
conjunction, Darwinex date mapping, the one-session lifecycle, or its risk
implementation.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_long_day` | 8 | exact positive-calendar long date |
| `strategy_short_day` | 26 | exact negative-calendar short date |
| `strategy_return_months` | 1 | completed calendar-month formation |
| `strategy_hold_bars` | 1 | next-D1 exit contract |
| `strategy_entry_grace_minutes` | 180 | executable-session attachment |
| `strategy_history_bars` | 100 | bounded completed-month endpoint scan |
| `strategy_atr_period` | 20 | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 2.75 | frozen hard-stop distance |
| `strategy_max_hold_days` | 5 | stale guard |
| `strategy_max_spread_points` | 2500 | entry spread ceiling |

There is no approved parameter sweep.

## 3. Symbol And Timeframe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Timeframe: exact D1.
- Magic slot: 0.
- Magic: `410250000`.
- No alternate symbol or suffix stripping is permitted in research/backtest
  artifacts.

## 4. Signal And Attempt Contract

1. Normalize D1 labels only by zero or one uniform `+86400`-second energy
   offset and require the normalized current date to equal broker date.
2. Require exact normalized day 8 or 26. Missing dates never shift.
3. Consume the exact normalized `yyyymmdd` before history, signal, news,
   spread, quote, stop, sizing, or order gates.
4. Use only completed closes from the immediately prior two exact consecutive
   normalized broker months.
5. Day 8 buys only when the prior-month log return is positive; day 26 sells
   only when it is negative. Zero or disagreement consumes the date flat.

## 5. Risk And Lifecycle

- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Hard stop: frozen `2.75 * ATR(20,D1)`.
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
- Trade Entry: normalized exact-date clock, persistent date attempt,
  completed-month endpoint scan, date-specific agreement direction, spread,
  quote, ATR, and hard stop.
- Trade Management: malformed/duplicate repair, next-D1 exit, and stale exit
  before new entry.
- Trade Close: V5 trade-manager close path, server hard stop, Friday close,
  and kill switch.

## 7. Falsification Boundary

Q02 retires the candidate below five completed positions per full post-warm-up
year, on zero trades, nonpositive governed economics, wrong or shifted date,
wrong month endpoints, current-bar leakage, duplicate attempts,
date/sign/direction mismatch, late exit, invalid risk mode, or
nondeterminism. Q09 alone may establish realized correlation with the
certified book.

## 8. Safety Boundary

This build is non-live. It authorizes one fixed-risk backtest setfile and one
paced Q02 enqueue only. It excludes manual tester control,
live/demo/shadow/stress setfiles, `T_Live`, AutoTrading, deploy manifests,
portfolio-gate changes, portfolio admission, and correlation waivers.

## Revision History

| Version | Date | Reason | Phase |
|---|---|---|---|
| v1 | 2026-08-16 | initial approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic implementation | magic/resolver verified; strict compile, targeted build check, static P1, and reference suite PASS |
