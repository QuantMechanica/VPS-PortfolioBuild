# STR-143 independent mechanized spec — SMA crossover pullback

Independent Codex draft from `00_source.md` and the STR-143 ledger row only. `01_spec_claude.md` was not read. This document is a research specification, not a G0 approval or a pipeline verdict.

## 1. Scope and operating contract

- Strategy family: mechanical trend-following pullback after a 100/200 SMA cross.
- Research cohort: `EURUSD.DWX` only.
- Signal timeframe: H1.
- All arming and entry decisions use completed H1 bars. A valid signal enters at the first tradable tick of the following bar.
- At most one open or pending position per strategy magic. No stacking, scale-in, martingale, grid, recovery hedge, discretionary filter, or ML.
- Canonical high-impact news blackout, spread/session checks, daily/total drawdown limits, and portfolio exposure gate remain mandatory.
- Backtests use `RISK_FIXED > 0`, `RISK_PERCENT = 0`; any later live candidate must use `0 < RISK_PERCENT <= 1.0` and `RISK_FIXED = 0`.

**FLAG STR143-C1 — cohort selection:** the source illustrates EUR/USD H1 and says the framework may apply more broadly, but supplies no tested symbol cohort. The independent baseline is therefore the single illustrated symbol/timeframe. Any multi-pair expansion is a separately labelled variant.

## 2. Inputs and price units

| Input | Baseline | Meaning |
|---|---:|---|
| `SignalTF` | `PERIOD_H1` | Fixed baseline |
| `FastSmaPeriod` | 100 | SMA of close |
| `SlowSmaPeriod` | 200 | SMA of close |
| `StochKPeriod` | 14 | Main lookback |
| `StochDPeriod` | 3 | Signal smoothing |
| `StochSlowing` | 3 | Main slowing |
| `OversoldLevel` | 25.0 | Pullback boundary |
| `OverboughtLevel` | 75.0 | Pullback boundary |
| `StopPips` | 150.0 | Initial hard stop |
| `TargetPips` | 300.0 | Hard profit target |
| `BreakEvenTriggerPips` | 150.0 | Favorable excursion required |
| `RiskFixed` | deployment-set, `>0` in tests | Fixed backtest volume |
| `RiskPercent` | `0` in tests; live `<=1.0` | Live risk sizing only |

Both SMAs use `PRICE_CLOSE`. Stochastic uses SMA smoothing and `STO_LOWHIGH`. `K[i]` is its main value on completed bar `i`.

Convert pips with the symbol contract: `pip = _Point * 10` for 3- or 5-digit FX quotes, otherwise `pip = _Point`. Normalize all order prices to tick size, not merely decimal digits.

**FLAG STR143-I1 — stochastic implementation:** the source states only “Stochastic (14,3,3)” and the 25/75 levels. The baseline uses the conventional MT5 SMA/low-high mapping and treats the main K line as the level-cross trigger. A K/D crossover would be a different strategy.

## 3. Closed-bar arming and entry rules

Maintain one state: `IDLE`, `ARMED_LONG`, or `ARMED_SHORT`.

1. A bullish SMA cross closes on bar `1` when `SMA100[1] > SMA200[1]` and `SMA100[2] <= SMA200[2]`. Set `ARMED_LONG` after evaluating that bar.
2. A bearish SMA cross closes when `SMA100[1] < SMA200[1]` and `SMA100[2] >= SMA200[2]`. Set `ARMED_SHORT`.
3. A new opposite SMA cross cancels and replaces the prior arm. Equality after arming cancels the setup until a later fresh cross.
4. The long pullback trigger is the first strictly later completed bar for which `K[2] <= 25` and `K[1] > 25`, while `SMA100[1] > SMA200[1]`.
5. The short pullback trigger is the first strictly later completed bar for which `K[2] >= 75` and `K[1] < 75`, while `SMA100[1] < SMA200[1]`.
6. A trigger consumes the arm whether common gates accept or reject the order. Later stochastic movements under the same SMA regime cannot enter; a fresh SMA cross is required.
7. Enter at the first tradable tick of the next H1 bar only when no position/order exists for the magic and the news, spread, session, exposure, and account-risk gates all pass.

**FLAG STR143-I2 — “pulls up/drops down from” interpretation:** the source does not mention a K/D line crossover. The baseline defines “pulls up from 25” as K crossing strictly above 25 and “drops down from 75” as K crossing strictly below 75.

**FLAG STR143-I3 — first instance timing:** “after an SMA crossover” is interpreted strictly: a stochastic boundary cross on the same completed bar as the SMA cross cannot trigger. This prevents ambiguous same-bar event ordering.

## 4. Orders and exits

1. Use the actual fill price:
   - long `SL = fill - 150*pip`, `TP = fill + 300*pip`;
   - short `SL = fill + 150*pip`, `TP = fill - 300*pip`.
2. Place both hard server-side SL and TP with the position. Reject the order if either price is invalid, violates broker distance/freeze rules, or cannot be placed safely. Do not widen either distance to force acceptance.
3. Size from the actual fill-to-SL distance. A missing/zero tick value, invalid volume step, or invalid risk mode fails closed.
4. Break-even is evaluated after each completed H1 bar:
   - for a long, arm break-even when that completed bar's high is at least `fill + 150*pip`;
   - for a short, arm it when that bar's low is at most `fill - 150*pip`.
5. On the first tradable tick of the next bar, move SL to the normalized fill price if and only if doing so tightens the stop and the position remains open. Never move it back.
6. If the original SL or TP is touched before the completed-bar break-even update, the broker fill is final. Do not reconstruct an assumed intrabar path.
7. There is no SMA recross exit, stochastic exit, time exit, partial close, trailing distance, or same-bar reversal in the source baseline.

**FLAG STR143-I4 — break-even timing:** “once price moves 150 pips” does not define tick, high/low, or close semantics. The baseline observes favorable high/low only after the bar completes, then updates on the next bar. This preserves deterministic closed-bar decisions and avoids guessing intrabar ordering.

**FLAG STR143-D1 — server protection:** the source specifies fixed SL/TP and break-even. The house implementation requires both initial levels to be real server-side orders from entry; client-only or mental protection is inadmissible.

## 5. Five-hook implementation sketch

1. `InitStrategy`: validate EURUSD/H1 contract, risk mode, pip/tick conversion, and common controls; create SMA and stochastic handles and warm at least 202 completed bars.
2. `ArmOnClosedBar`: detect a fresh 100/200 SMA cross, replace/cancel state deterministically, and prohibit same-cross-bar entry.
3. `DetectPullbackEntry`: detect the first K crossing out through 25/75 while the SMA ordering persists, consume the arm, and emit one next-bar intent.
4. `BuildRiskAndPlace`: derive exact 150/300-pip prices from the actual fill, normalize and validate them, size against the hard SL, and place SL/TP atomically.
5. `ManageOpenPositionOnClosedBar`: latch favorable 150-pip excursion from the completed bar and request a one-way break-even stop update on the next bar.

## 6. Verification obligations

- Unit-test bullish/bearish symmetry, exact threshold equality, same-bar SMA/stochastic events, recross cancellation, first-trigger consumption, and restart warmup.
- Assert every signal uses closed bars and every entry occurs no earlier than the next bar.
- Test 4- and 5-digit pip conversion plus tick-size normalization.
- Test ambiguous bars that touch SL/TP or the break-even threshold; broker protection must remain authoritative and no intrabar order may be fabricated.
- Assert hard SL and TP are present from entry and the stop never loosens.
- Assert all backtest sets contain `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- Use canonical spread, commission, swap, rollover, and server-time evidence. Do not invent missing commission, swap, or DST values.
- Treat the article's “looking good” statement as unverified proposal-stage narrative, not profitability evidence.
