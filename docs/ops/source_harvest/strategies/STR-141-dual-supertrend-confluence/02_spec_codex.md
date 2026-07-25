# STR-141 independent mechanized spec — dual Supertrend / EMA / RSI / ADX confluence

Independent Codex draft from `00_source.md` and the STR-141 ledger row only. `01_spec_claude.md` was not read. This is a research specification, not evidence of edge, G0 approval, or a pipeline verdict.

## 1. Scope and operating contract

- Strategy family: mechanical FX trend following with an asymmetric dual-Supertrend trigger and momentum/strength confirmation.
- Signal timeframe: H1.
- Research cohort: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, `AUDUSD.DWX`, `USDCHF.DWX`, and `NZDUSD.DWX`, subject to complete canonical history.
- All signals and discretionary strategy exits use completed H1 bars. Orders are submitted on the first tradable tick of the next bar.
- At most one open or pending position per symbol and strategy magic. No stacking, scale-in, martingale, grid, hedge recovery, discretionary order blocks, or ML.
- Canonical high-impact news blackout, spread/session checks, daily/total drawdown guards, and portfolio exposure gates remain mandatory.
- Backtests use `RISK_FIXED > 0`, `RISK_PERCENT = 0`. A later live candidate may use `0 < RISK_PERCENT <= 1.0` and must set `RISK_FIXED = 0`.

**FLAG STR141-C1 — cohort/timeframe interpretation:** the thread names neither symbol nor timeframe. The ledger's FX/H1 classification is explicitly a placeholder. This spec declares a liquid-major DXZ H1 research cohort so results are reproducible; it is not a source claim.

## 2. Inputs

| Input | Baseline | Meaning |
|---|---:|---|
| `SignalTF` | `PERIOD_H1` | Fixed baseline |
| `AtrPeriod` | 7 | Both Supertrends |
| `FastStMultiplier` | 0.9 | Sensitive Supertrend |
| `SlowStMultiplier` | 1.8 | Slow Supertrend |
| `EmaPeriod` | 99 | EMA of close |
| `RsiPeriod` | 9 | RSI of close |
| `RsiMidline` | 50.0 | Directional momentum boundary |
| `AdxPeriod` | 9 | ADX main line |
| `AdxMinimum` | 25.0 | Strict trend-strength threshold |
| `RiskFixed` | deployment-set, `>0` in tests | Fixed backtest lot size |
| `RiskPercent` | `0` in tests; live `<=1.0` | Live risk sizing only |

EMA slope is `EMA[1] - EMA[2]`. Long requires it to be strictly positive; short requires it to be strictly negative. Equality is neither direction. Long requires `RSI[1] > 50` and short `RSI[1] < 50`. Both require `ADX_MAIN[1] > 25`.

**FLAG STR141-I1 — EMA 99 versus EMA 9:** the prose names EMA(99) in the indicator list and every rule; the author's incomplete code fragment declares 9. The prose is the authoritative baseline, so `EmaPeriod=99`. EMA 9 may be tested only as a separately labelled sensitivity variant and may never be silently substituted.

**FLAG STR141-I2 — “RSA”:** the source's “RSA(9)” is treated as a typographical error for RSI(9), consistent with its description and later code fragment.

## 3. Exact Supertrend recursion

Compute the following chronologically from oldest to newest for each completed H1 bar `t`. No external custom indicator is allowed.

1. `TR[t] = max(High[t]-Low[t], abs(High[t]-Close[t-1]), abs(Low[t]-Close[t-1]))`.
2. Seed Wilder ATR at the first eligible bar with the arithmetic mean of the first seven true ranges. Thereafter `ATR[t] = ((6 * ATR[t-1]) + TR[t]) / 7`.
3. For each multiplier `m` in `{0.9, 1.8}`:
   - `mid[t] = (High[t] + Low[t]) / 2`;
   - `basicUpper[t] = mid[t] + m * ATR[t]`;
   - `basicLower[t] = mid[t] - m * ATR[t]`;
   - `finalUpper[t] = basicUpper[t]` when `basicUpper[t] < finalUpper[t-1]` or `Close[t-1] > finalUpper[t-1]`; otherwise retain `finalUpper[t-1]`;
   - `finalLower[t] = basicLower[t]` when `basicLower[t] > finalLower[t-1]` or `Close[t-1] < finalLower[t-1]`; otherwise retain `finalLower[t-1]`.
4. Direction and line recurse as follows:
   - if the prior line was `finalUpper[t-1]`, remain `DOWN` at `finalUpper[t]` when `Close[t] <= finalUpper[t]`; otherwise flip `UP` and use `finalLower[t]`;
   - if the prior line was `finalLower[t-1]`, remain `UP` at `finalLower[t]` when `Close[t] >= finalLower[t]`; otherwise flip `DOWN` and use `finalUpper[t]`.
5. At the first ATR-ready seed bar, initialize `UP`/`finalLower` when `Close >= mid`; otherwise initialize `DOWN`/`finalUpper`. Warm up at least `max(EmaPeriod, AtrPeriod, RsiPeriod, AdxPeriod) + 2` completed bars before allowing a signal.

**FLAG STR141-I3 — Supertrend definition:** the source supplies periods/multipliers but no formula. Rules 1–5 select the standard final-band recursion, Wilder ATR, and an explicit deterministic seed. This definition is part of the strategy identity and must be tested directly; a third-party Supertrend with different seeding or band rules is not equivalent.

## 4. Closed-bar entry and exit rules

1. A fast Supertrend flip up on bar `1` means `FastDir[2]=DOWN` and `FastDir[1]=UP`. A slow flip down is defined symmetrically.
2. Long entry signal on bar `1` requires all of:
   - fast Supertrend flips `DOWN -> UP`;
   - slow Supertrend is already green: `SlowDir[2]=UP` and `SlowDir[1]=UP`;
   - `EMA99[1] > EMA99[2]`;
   - `RSI9[1] > 50`;
   - `ADX9_MAIN[1] > 25`.
3. Short entry signal on bar `1` requires all of:
   - slow Supertrend flips `UP -> DOWN`;
   - fast Supertrend is already red: `FastDir[2]=DOWN` and `FastDir[1]=DOWN`;
   - `EMA99[1] < EMA99[2]`;
   - `RSI9[1] < 50`;
   - `ADX9_MAIN[1] > 25`.
4. Submit one market entry on the next bar only if common news, spread, session, exposure, and account-risk gates pass and no position/order exists for the magic. A rejected signal is consumed; do not enter late.
5. Initial long stop is the fast (`0.9`) Supertrend line from the signal bar. Initial short stop is the slow (`1.8`) line from the signal bar. Normalize to tick size. If the selected line is not strictly on the loss side of the actual fill or violates broker stop distance, reject the order; never widen or synthesize a stop.
6. Size from the actual fill-to-stop distance and fail closed on invalid tick value, volume, or price normalization.
7. On every completed bar, ratchet a long server stop to the current fast Supertrend line only if it is below current bid and tighter than the existing stop. Ratchet a short server stop to the current slow Supertrend line only if it is above current ask and tighter.
8. Close a long on the next bar when either Supertrend is `DOWN` on bar `1` or `EMA99[1] < EMA99[2]`. Close a short when either Supertrend is `UP` or `EMA99[1] > EMA99[2]`.
9. A broker stop may exit intrabar before the completed-bar strategy exit. There is no profit target, partial exit, time exit, same-bar reversal, or ADX/RSI exit in the source baseline.

**FLAG STR141-I4 — “already green/red”:** this requires the non-triggering Supertrend to have the requested direction on both bars `2` and `1`, so a simultaneous dual flip is not “already” aligned.

**FLAG STR141-I5 — trigger asymmetry:** the source explicitly triggers long on the fast 0.9 flip but short on the slow 1.8 flip. The baseline preserves that asymmetry rather than “correcting” it.

**FLAG STR141-D1 — server-stop implementation:** the prose calls the Supertrend line a stop-loss level but does not specify placement/update timing. The baseline places a hard server-side stop with the initial order and ratchets it only after completed bars. This is the required fail-closed house implementation.

## 5. Five-hook implementation sketch

1. `InitStrategy`: validate risk mode and inputs; create EMA/RSI/ADX handles; allocate two internal Supertrend states; warm all series without retrospective trading.
2. `UpdateIndicatorsOnClosedBar`: copy closed-bar data, update Wilder ATR and both exact Supertrend recursions, and calculate EMA slope, RSI, and ADX.
3. `DetectEntry`: evaluate the asymmetric flip plus already-aligned line and all strict confluence thresholds; emit at most one next-bar intent.
4. `BuildRiskAndPlace`: select the source-prescribed Supertrend line, validate/normalize the hard stop, size from stop distance, apply common entry gates, and place atomically.
5. `ManageOpenPosition`: ratchet the appropriate server stop on completed bars and close on either-line color reversal or EMA slope reversal; never reverse in the same evaluation.

## 6. Verification obligations

- Unit-test the Supertrend recursion, seed, final-band carry, and flip behavior against hand-calculated fixtures for both multipliers.
- Assert closed-bar-only indicator reads and next-bar execution.
- Cover simultaneous flips, equality at RSI 50/ADX 25/zero EMA slope, invalid-side stops, signal consumption, and restart warmup.
- Assert a hard stop exists from entry and never loosens.
- Assert backtest sets have `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- Use canonical costs and server-time data; do not invent commission, swap, spread, rollover, or DST values.
- Treat the source as an untested strategy proposal. Only later pipeline evidence may supply an economic verdict.
