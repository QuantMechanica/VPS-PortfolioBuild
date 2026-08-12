# STR-137 independent mechanized spec — EMA cross / stochastic hook / Fibonacci trail

Independent Codex draft from `00_source.md` and the STR-137 ledger row only. `01_spec_claude.md` was not read. This document is a research specification, not a G0 approval or a pipeline verdict.

## 1. Scope and operating contract

- Strategy family: mechanical trend-continuation after an EMA impulse and oscillator pullback.
- Research cohort: FTMO/Darwinex Zero FX symbols with complete H4 history.
- Signal timeframe: H4 only. All indicator, arming, entry, and strategy-exit decisions use completed H4 bars.
- Execution: market order on the first tradable tick of the bar after a completed-bar signal.
- Position policy: at most one open or pending position per symbol and strategy magic. No scale-in, pyramiding, basket hedge, martingale, grid, recovery order, or ML component.
- Mandatory common controls remain active: spread/session validation, the canonical high-impact news blackout, daily and total drawdown guards, and the portfolio exposure gate. Existing positions remain protected during a news blackout; the blackout suppresses new entries only.
- Backtests use `RISK_FIXED > 0` and `RISK_PERCENT = 0`. Any later live candidate must use `RISK_PERCENT > 0` and `<= 1.0`, with `RISK_FIXED = 0`.

**FLAG STR137-C1 — cohort interpretation:** the source scans all broker instruments and shows several FX and metal examples, but does not define a fixed portfolio. This spec limits the first research cohort to available DXZ FX symbols; the exact symbol list must be declared in the Strategy Card and must not be inferred dynamically by the EA.

**FLAG STR137-C2 — H4 selection:** the source calls H4 its preferred timeframe and warns that lower timeframes produce more false signals. H4 is therefore the only baseline; D1/W1 and M15/H1 variants are excluded from this spec.

## 2. Inputs and derived values

| Input | Baseline | Mechanized meaning |
|---|---:|---|
| `SignalTF` | `PERIOD_H4` | Fixed baseline timeframe |
| `FastEmaPeriod` | 20 | EMA of close |
| `SlowEmaPeriod` | 50 | EMA of close |
| `StochKPeriod` | 14 | Stochastic raw lookback |
| `StochDPeriod` | 3 | Signal-line smoothing |
| `StochSlowing` | 1 | Main-line slowing |
| `StochOverbought` | 80.0 | Upper extreme |
| `StochOversold` | 20.0 | Lower extreme |
| `InitialStopBufferPips` | 10.0 | Buffer beyond the impulse anchor |
| `FibRatios` | `1,1.272,1.618,2,2.618,3,3.618,4,4.618,5` | Ordered extension ladder |
| `RiskFixed` | deployment-set, `>0` in tests | Fixed backtest lot size |
| `RiskPercent` | `0` in tests; live `<=1.0` | Live risk sizing only |

Use EMA shift zero and applied price `PRICE_CLOSE`. Stochastic uses SMA smoothing and `STO_CLOSECLOSE`. Let `K[i]` and `D[i]` be the main and signal values for completed bar `i`, where `i=1` is the most recently closed bar.

**FLAG STR137-I1 — stochastic mapping:** the author repeatedly names “14,3,1”, later corrects charts to that tuple, and says the oscillator is applied to close, but one explanation swaps the labels of K and D. The baseline maps the tuple to MT5 as K-period 14, D-period 3, slowing 1, SMA, close/close. No alternate tuple may be mixed into the baseline.

**FLAG STR137-I2 — extreme test:** “stochastic is overbought/oversold” is mechanized against `K`; the source never states that both lines must already be beyond the threshold. The later hook itself requires a two-line crossover as defined below.

## 3. Closed-bar setup and entry state machine

State is maintained independently per symbol and may be `IDLE`, `ARMED_LONG`, or `ARMED_SHORT`. A setup may wait indefinitely while its EMA ordering remains valid, as the source explicitly permits.

1. On each new H4 bar, refresh indicator values only after the preceding H4 bar is complete. Never signal from bar `0`.
2. A bullish EMA cross exists on bar `1` when `EMA20[1] > EMA50[1]` and `EMA20[2] <= EMA50[2]`. A bearish EMA cross is the exact inverse.
3. On a bullish cross, arm long only if `K[1] >= 80`. Record the bullish cross bar and the impulse-start price defined in rule 5. If that initial extreme is absent, ignore this entire EMA regime.
4. On a bearish cross, arm short only if `K[1] <= 20`. Record the bearish cross bar and the impulse-start price. If that initial extreme is absent, ignore this entire EMA regime.
5. For a bullish cross, `ImpulseStart` is the minimum low of the just-completed contiguous regime in which `EMA20 <= EMA50`, including the cross bar. For a bearish cross, it is the maximum high of the just-completed contiguous regime in which `EMA20 >= EMA50`, including the cross bar.
6. Cancel `ARMED_LONG` immediately if a completed bar has `EMA20 <= EMA50`. Cancel `ARMED_SHORT` immediately if a completed bar has `EMA20 >= EMA50`. A recross on the prospective trigger bar cancels rather than enters.
7. While `ARMED_LONG`, mark `OppositeExtremeSeen` once a completed bar has `K <= 20`. While `ARMED_SHORT`, mark it once a completed bar has `K >= 80`.
8. The first long hook is a completed bar for which `OppositeExtremeSeen` is true, `K[2] <= D[2]`, `K[1] > D[1]`, and `min(K[1],D[1]) <= 20`. The first short hook is symmetric: `K[2] >= D[2]`, `K[1] < D[1]`, and `max(K[1],D[1]) >= 80`.
9. A valid hook consumes the setup whether the common entry gates accept or reject the order. There is no second or third stochastic entry under the same EMA regime.
10. Enter at the next bar's first tradable tick only when the EMA ordering still agrees, no position/pending order exists for the magic, the news blackout is clear, and all common risk/exposure guards accept the order.

**FLAG STR137-I3 — cross-at-extreme rule:** the source says to enter just after the stochastic lines cross in the opposite extreme, not after they leave it. Rule 8 requires the two lines to cross while at least one remains at the relevant boundary. Requiring both lines beyond the boundary would be a different variant.

**FLAG STR137-I4 — “first signal” interpretation:** the source alternates between saying later hooks can work and saying it prefers only the first because later hooks precede trend changes. The house baseline consumes the first hook and forbids stacking.

**FLAG STR137-I5 — impulse-start anchor:** “the lowest low/highest high before the EMA crossover” has no stated lookback. Rule 5 uses the complete immediately preceding opposite EMA regime, avoiding an arbitrary bar-count parameter and all future look-ahead.

## 4. Initial risk, Fibonacci geometry, and exits

1. At a long hook, set `ImpulseEnd` to the maximum high from the recorded bullish cross bar through the hook bar, inclusive. At a short hook, set it to the minimum low over the analogous interval.
2. Reject the setup if the directional impulse length is non-positive:
   - long `L = ImpulseEnd - ImpulseStart`;
   - short `L = ImpulseStart - ImpulseEnd`.
3. Define extension price `F(r)`:
   - long: `F(r) = ImpulseStart + r * L`;
   - short: `F(r) = ImpulseStart - r * L`.
   Thus `F(1)` is the impulse end.
4. The initial long server-side stop is `ImpulseStart - 10 pips`; the initial short stop is `ImpulseStart + 10 pips`. Normalize to tick size and reject the entry if the stop is not on the loss side of the actual fill, violates broker stop distance, or cannot be placed atomically with the position.
5. Size from the actual fill-to-stop distance. A zero/invalid tick value, volume, or stop distance fails closed.
6. The Fibonacci trail is evaluated only at a completed H4 close:
   - after the first close at or beyond `F(1)` in the trade direction, ratchet the stop to actual entry price;
   - after the first close at or beyond `F(1.272)`, ratchet to `F(1)`;
   - after each later reached ratio, ratchet to the immediately preceding ratio in `FibRatios`.
7. A ratchet is monotonic: a long stop can only increase and a short stop can only decrease. Apply the new normalized server-side stop on the first tradable tick of the next bar.
8. If the last ratio, `5.0`, is exceeded, retain the stop at `F(4.618)`; do not invent further extension ratios.
9. A broker stop fill, take-over by the common account drawdown guard, or common emergency close ends the trade. There is no fixed take-profit.
10. If an opposite setup completes before the protective stop closes the position, close the existing position on the next bar; do not reverse on the same bar. A new opposite entry requires a fresh, independently completed setup and all common gates.

**FLAG STR137-D1 — mandatory hard-stop deviation:** the author treats the initial stop as mental/position-sizing information and describes holding a trade roughly 350 pips beyond it. That is inadmissible under the FTMO/DXZ drawdown contract. This spec always places and honors a hard server-side stop. No “wait for the opposite signal after the stop” override exists.

**FLAG STR137-D2 — trail execution deviation:** the source expresses the Fibonacci trail as a close-breach exit. The house baseline ratchets a real server-side stop after the qualifying close, so a later intrabar touch can exit before another H4 close. This deliberate conservative deviation must remain visible in any Strategy Card and report.

**FLAG STR137-I6 — impulse-end anchor:** the source calls this the highest/lowest point after the cross and before the pullback but gives no pivot algorithm. The no-look-ahead baseline takes the directional extreme from cross through hook, fixed when the hook closes.

**FLAG STR137-I7 — finite extension ladder:** “5 and so on” does not define a reproducible sequence beyond 5.0. The baseline stops extending the ladder at the last explicitly named ratio.

## 5. Five-hook implementation sketch

1. `InitStrategy`: create H4 EMA and stochastic handles; validate periods, ratios, risk mode, news controls, and symbol trade properties; initialize per-symbol setup state from historical closed bars without placing a retrospective order.
2. `DetectSetupOnClosedBar`: detect the EMA cross, validate its same-bar stochastic extreme, capture `ImpulseStart`, maintain/cancel the armed state, and emit only the first opposite-extreme hook.
3. `BuildEntryIntent`: recheck EMA alignment and common gates, freeze `ImpulseEnd`, calculate Fibonacci geometry and the buffered hard stop, and return one market-entry intent.
4. `SizeAndPlace`: normalize price/volume, apply fixed-risk or percent-risk mode, and place the position with the hard server-side stop; fail closed on any invalid broker calculation.
5. `ManageOpenPositionOnClosedBar`: advance the Fibonacci stop monotonically, recognize a fully completed opposite setup, and request close without reversal. Common news and account-risk hooks remain authoritative.

## 6. Verification obligations

- Unit-test bullish and bearish symmetry, missing initial extremes, delayed hooks, EMA recross cancellation, first-hook consumption, and restart behavior.
- Assert every indicator read uses closed bars and that entry occurs no earlier than the following bar.
- Test impulse anchors and every Fibonacci level with hand-calculated price series.
- Assert stops never loosen, the hard stop is present from placement, and no code path can honor the source's no-stop doctrine.
- Assert `RISK_FIXED > 0` and `RISK_PERCENT = 0` in every backtest set.
- Run cost-aware evidence with canonical spread, commission, swap, and server-time inputs. Do not hard-code or invent missing commission, swap, rollover, or DST values.
- Report the source's claimed win rate and follower anecdotes, if mentioned at all, as unverified narrative rather than pipeline evidence.
