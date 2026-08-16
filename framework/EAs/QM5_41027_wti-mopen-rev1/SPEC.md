# QM5_41027_wti-mopen-rev1 - Strategy Spec

**EA ID:** QM5_41027

**Slug:** `wti-mopen-rev1`

**Source:** `MOP-YANG-WTI-MOPEN-REV1-2026`

**Last revised:** 2026-08-16

## 1. Strategy Logic

`QM5_41027_wti-mopen-rev1` is a single-symbol D1 WTI
calendar/reversal strategy. On exactly the second genuine normalized broker-
month session, it fades the completed first session's open-to-close log-return
sign. It exits at the first later normalized D1 boundary.

The approved execution contract is
`strategy-seeds/cards/approved/QM5_41027_wti-mopen-rev1_card.md`. Moskowitz,
Ooi, and Pedersen support own-return-sign and WTI lineage; Yang, Goncu, and
Pantelous support fixed-horizon commodity reversal. Neither source tests this
exact ordinal-session conjunction, continuous CFD carrier, or execution
package.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_session_ordinal` | 2 | exact second genuine month session |
| `strategy_formation_sessions` | 1 | completed first-session formation |
| `strategy_entry_grace_minutes` | 180 | executable-session attachment |
| `strategy_atr_period` | 20 | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 4 | holiday/weekend-safe stale guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

There is no approved parameter sweep.

## 3. Symbol And Timeframe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Timeframe: exact D1.
- Magic slot: 0.
- Magic: `410270000`.
- No alternate carrier or suffix stripping is allowed in research artifacts.

## 4. Signal And Attempt Contract

1. Normalize all involved D1 labels by only zero or one uniform
   `+86400`-second energy offset and require normalized current date to equal
   broker date.
2. Require current and shift-1 labels in the same month; require shift 2 in
   the immediately preceding calendar month. Adjacent, strictly ordered bars
   define the second genuine session without holiday substitution.
3. Consume the normalized `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order gates.
4. Compute only `log(Close[1]/Open[1])`; current-session price cannot enter
   either endpoint.
5. BUY a strictly negative return and SELL a strictly positive return. Exact
   zero or invalid history consumes the month flat.

## 5. Risk And Lifecycle

- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Hard stop: frozen `3.0 * ATR(20,D1)`; take-profit: none.
- Normal exit: first later normalized D1 boundary.
- Repair exits: malformed/duplicated/missing-stop exposure or four elapsed
  calendar days.
- Framework Friday close remains enabled at broker hour 21 as a fail-safe.
- News temporal OFF, compliance NONE, and legacy mode OFF.
- No trailing, break-even, partial close, scale-in, grid, martingale, hedge,
  or pyramid.

## 6. Framework Alignment

- No-Trade: exact host, timeframe, ID, slot, seed, fixed-risk, news, Friday,
  stress, and locked input checks.
- Trade Entry: normalized second-session clock, persistent attempt, completed
  first-session endpoints, strict contrarian direction, spread, quote, ATR,
  and side-correct hard stop.
- Trade Management: malformed, duplicate, missing-stop, later-D1, and stale
  repair runs before entry-only gates on every tick.
- Trade Close: V5 trade-manager close path, server stop, Friday fail-safe, and
  kill switch.

## 7. Q01 Evidence

- Eight deterministic reference tests: PASS.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings; log
  `framework/build/compile/20260816_171720/QM5_41027_wti-mopen-rev1.compile.log`.
- Targeted strict build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260816_171720.json`.
- Static P1 artifact validation: PASS; result
  `D:/QM/reports/pipeline/QM5_41027/P1/P1_QM5_41027_result.json`.

## 8. Falsification And Safety Boundary

Q02 retires the candidate on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong session or
endpoints, current-bar leakage, momentum-side exposure, duplicate/late entry,
missing stop, wrong exit, invalid risk mode, or nondeterminism. Q09 alone may
establish realized correlation with the certified book.

This build is non-live. It authorizes one fixed-risk backtest setfile and one
paced Q02 enqueue only. It excludes manual tester control, live/demo/shadow or
stress setfiles, `T_Live`, AutoTrading, deploy manifests, portfolio-gate
changes, portfolio admission, and correlation waivers.

## Revision History

| Version | Date | Reason | Phase |
|---|---|---|---|
| v1 | 2026-08-16 | initial approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic implementation | Q01 PASS |
