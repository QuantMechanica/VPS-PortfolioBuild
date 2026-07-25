# STR-118 — Codex independent mechanical specification

## Source boundary

- Source: unhommefou’s mechanized Ichimoku variant in posts #25–#39 of the BabyPips “Ichimoku Trading System” thread.
- Evidence read for this blind specification: `00_source.md` and the `STR-118` row in `SOURCE_LEDGER.csv` only.
- The original poster’s Chikou support/resistance exits and later contributors’ discretionary Ichimoku methods are not used.
- Status: independent Codex draft for G0 comparison; not an approval, profitability verdict, or live-use authorization.

## Strategy hypothesis

On D1, trade the direction of Tenkan/Kijun agreement only after the completed close stands a full ATR(20) beyond the causally aligned Ichimoku cloud. The distance filter is intended to suppress whipsaw near the cloud. Exit on the opposite Tenkan/Kijun cross and prohibit the author’s optional three-lot ATR scale-in.

## Instrument and timeframe scope

- Baseline cohort: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, and USDCHF.DWX, tested separately on D1.
- The four-pair list is the conventional interpretation of the author’s “four majors”; the extract does not enumerate that exact test basket, so it is interpretation I-01.
- AUD crosses are excluded from the baseline because the author reports them as consistent losers. This is a source-reported, data-mined exclusion and not an independently verified fact.
- Futures and stocks are outside the baseline even though the author comments on them.

## Closed-bar Ichimoku definitions

At the first tick of each new broker D1 bar:

- `close1` is the just-completed D1 close.
- `tenkan1` is the midpoint of the highest high and lowest low over the last 9 completed bars ending at bar 1.
- `kijun1` is the corresponding midpoint over 26 completed bars.
- Ichimoku displacement equals the Kijun period, 26.
- Let `cloudSourceShift = 1 + 26 = 27`. The cloud visibly aligned with closed bar 1 was calculated 26 bars earlier: `spanA1 = (tenkan[27] + kijun[27]) / 2`, while `spanB1` is the midpoint of the 65-bar highest high and lowest low ending at bar 27.
- A native indicator buffer may replace that manual calculation only if an offset test proves it returns those same causally aligned values; no future-plotted buffer may be read as current information.
- `cloudTop1 = max(spanA1, spanB1)` and `cloudBottom1 = min(spanA1, spanB1)`.
- `atr1` is closed-bar Wilder ATR(20).

## Mechanical rules

1. Evaluate once per new D1 bar only after sufficient history exists for all aligned cloud components and ATR(20).
2. A long state exists when `tenkan1 > kijun1` and `close1 > cloudTop1 + atr1`.
3. A short state exists when `tenkan1 < kijun1` and `close1 < cloudBottom1 - atr1`.
4. The ATR-filtered revision does not require Tenkan and Kijun themselves to be beyond the cloud. It requires their directional relation plus price one ATR beyond the relevant cloud edge.
5. When flat and eligible, enter at the first executable price of the new D1 bar. Equality at either comparison creates no entry.
6. Maintain exactly one position per symbol/magic. Never add a second or third lot as price advances by ATR increments.
7. The source provides a signal exit but no protective hard-stop formula. For V5 risk sizing, the baseline house projection freezes the signal bar’s near cloud edge as the initial catastrophic stop: `cloudTop1` for a long and `cloudBottom1` for a short.
8. Do not trail that projected stop with the cloud and do not present it as an author rule. If a gap makes the frozen stop invalid relative to the fill, skip the trade rather than invent another distance.
9. For a long, an exit signal occurs only when the closed lines cross from `tenkan2 >= kijun2` to `tenkan1 < kijun1`. For a short, mirror from `tenkan2 <= kijun2` to `tenkan1 > kijun1`.
10. Execute a valid signal exit at the first policy-permitted price of the new D1 bar. There is no fixed take profit, Chikou exit, or source-backed time exit.
11. If the house protective stop closes a trade while the same directional state remains, lock that direction until its entry condition first becomes false and later becomes true again. This prevents repeated stop/re-entry inside one unchanged state and is interpretation I-07.
12. News blackout and account-level safety policy override entry and normal signal-exit scheduling; protective risk controls remain fail-safe.

## Required inputs and baseline defaults

| Input | Baseline | Allowed research variation | Evidence status |
|---|---:|---:|---|
| `SignalTF` | D1 | fixed baseline | sourced |
| `TenkanPeriod` | 9 | fixed within baseline | source walk-forward winner |
| `KijunPeriod` | 26 | fixed within baseline | source walk-forward winner |
| `SenkouBPeriod` | 65 | separately labelled `100` and `52` variants only | source ranks 65 first, 100 second, 52 third |
| `CloudDisplacement` | 26 | fixed to Kijun | standard/source setting |
| `ATRPeriod` | 20 | fixed | sourced |
| `CloudDistanceATR` | 1.0 | fixed | sourced |
| `UseChikou` | false | fixed | explicitly removed by author |
| `AllowScaleIn` | false | fixed | house ban overrides optional source variant |
| `MaxPositionsPerMagic` | 1 | fixed | house constraint |
| `InitialStopMode` | `FROZEN_SIGNAL_CLOUD_EDGE` | reconciliation required before build | house projection; not sourced |
| `TakeProfitMode` | disabled | none | no source-backed target in this variant |
| `SessionMode` | broker D1 close | fixed baseline | interpretation I-06 |
| `RISK_FIXED` | positive test lot from canonical set generation | positive only | house backtest constraint |
| `RISK_PERCENT` | 0 in backtests | live configuration at or below 1.0 only with separate authorization | house constraint |

## Interpretation register

- **I-01 — four-major cohort:** the author reports testing “the 4 Majors” but does not enumerate them in the captured text. EURUSD, GBPUSD, USDJPY, and USDCHF are a declared cohort interpretation, not source fact.
- **I-02 — 9/26/65 default:** the author calls 9/26/65 best from walk-forward testing, followed by 9/26/100 and 9/26/52. No walk-forward windows, cost model, parameter grid, report, or raw trades are supplied. The ranking is an unverified claim with material selection-bias risk.
- **I-03 — ATR wording:** “20 moving average of the Average True Range” is mechanized as standard Wilder ATR with period 20, matching the author’s later `ATR(20)` shorthand.
- **I-04 — cloud threshold:** “above the Cloud (Senkouspan b AND a)” means above the larger aligned span plus ATR for longs and below the smaller span minus ATR for shorts.
- **I-05 — state versus fresh cross entry:** the author says enter when Tenkan is greater/less and price clears the filtered cloud; a fresh T/K cross is not required. Baseline therefore treats the condition as a state and enters next bar when flat.
- **I-06 — D1 boundary:** the author’s NinjaTrader data close convention is not documented. Baseline uses canonical NY-close broker D1 bars (GMT+2/+3) and `QM_BrokerToUTC` for policy windows; it does not synthesize an unstated GMT candle.
- **I-07 — stop and re-arm:** no hard stop or post-stop behavior is supplied. The frozen signal-cloud edge and state-reset lock are explicit house safety projections required for finite risk; reconciliation may reject or replace them, but they must never be mistaken for source rules.
- **I-08 — entry timing:** closed-bar evaluation with execution on the next D1 bar is the causal implementation of “get in”; the simplified author does not separately state order timing.

## Walk-forward claim and test discipline

The source reports NinjaTrader tests from 1970–2009, names USDJPY as best, rejects AUD pairs, and says 9/26/65 won broad walk-forward optimization. No reproducible report or cost assumptions accompany those claims. Q-gate evidence alone may establish performance. The three source-ranked Senkou-B settings must be labelled variants rather than mined as a broad optimization surface, and the 65 choice needs neighborhood/era stability testing.

## V5 five-hook sketch

1. **Initialization hook:** validate deep D1 history, create or manually calculate Ichimoku 9/26/65 and ATR20, prove cloud-buffer alignment, resolve symbol/risk metadata, and fail closed on stale or missing mandatory news data.
2. **New-bar regime hook:** calculate closed Tenkan/Kijun, aligned cloud edges, ATR distance, direction state, fresh opposite cross, and the post-stop re-arm lock.
3. **Order/risk hook:** size one market intent from the frozen signal-cloud-edge protection, reject invalid gap geometry, and enforce one position with no add-on path.
4. **Position-management hook:** keep the catastrophic stop fixed, issue only the opposite-T/K closed-bar exit, and never execute the ATR three-lot scale-in.
5. **Exit/audit hook:** record all aligned indicator timestamps/values, setting variant, threshold distance, source-versus-house stop tag, lock state, fill/exit, blackout state, and Q-only phase labels.

## House and Edge Lab controls

- Mandatory high-impact-news blackout applies and stale/missing calendar data fails closed. `qm_news_stale_max_hours` is never raised above 336.
- No martingale, grid, averaging, pyramiding/stacking, recovery sizing, discretionary intervention, or ML.
- FTMO + DXZ evaluation only; daily drawdown must remain at or below 5% and total drawdown at or below 10%.
- Backtest setfiles require `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- D1 closed-bar execution is swing-horizon and non-HFT.
- No T_Live, AutoTrading, terminal launch, pipeline verdict, or deployment action is authorized.

## Dedup and fidelity exclusions

The ledger identifies CL-05 overlap with `QM5_10513`. G0 must compare exact rules before authorizing another build; this draft does not itself prove a material delta. The faithful STR-118 baseline excludes Chikou, original-poster support/resistance targets, three-lot ATR scale-ins, discretionary cloud interpretation, fixed take profit, trailing cloud stops, intraday variants, and any broad search beyond the three source-ranked settings.
