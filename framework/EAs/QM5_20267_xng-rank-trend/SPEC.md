# QM5_20267_xng-rank-trend — Strategy Spec

**EA ID:** QM5_20267

## 1. Strategy Logic

At the first processed `XNGUSD.DWX` D1 bar of a genuine new broker month, the
EA reconstructs exactly thirteen consecutive completed broker-month-end closes
in chronological order. It compares every older/newer endpoint pair:

```text
S = sum(sign(P[j] - P[i])) for all 0 <= i < j <= 12
tau = S / 78
```

All closes must be positive, finite, and pairwise distinct. There are exactly
78 comparisons. A score of `S >= 28` buys XNG and `S <= -28` sells it; a weak,
tied, malformed, stale, or unavailable path consumes the month flat. The score
boundary is the precommitted no-tie, continuity-corrected two-sided ten-percent
Mann-Kendall boundary for thirteen observations, not a pipeline-fit value.

An actionable state opens one position with a frozen `3.5 * ATR(20,D1)` hard
stop, no take-profit, no scale-in, and no intramonth reversal. The prior
position closes at the next broker-month boundary; a forty-calendar-day guard
closes a stale position.

The month is persisted before history, signal, news, spread, quote, sizing, and
order gates. Owned positions and entry-deal history provide restart recovery;
tester initialization clears stale terminal-global state. A flat, rejected,
failed, or stopped attempt cannot retry in the same month.

## 2. Parameters

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_rank_points` | 13 | completed month-end observations |
| `strategy_min_abs_score` | 28 | fixed all-pairs score boundary |
| `strategy_history_bars_d1` | 800 | bounded D1 endpoint-recovery buffer |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale lifecycle guard |
| `strategy_max_spread_points` | 3000 | entry spread ceiling |

Every strategy parameter and the framework identity, risk, news, Friday, and
stress inputs fail closed unless they match the authorized Q02 baseline.

## 3. Symbol Universe

- Exact host and traded symbol: `XNGUSD.DWX`.
- Slot: 0; registered magic: `202670000`.
- This is a direct XNG energy carrier. No basket leg, futures chain, inventory
  feed, file, API, or external series is read at runtime.

## 4. Timeframe

- Host timeframe: D1.
- Decision cadence: first D1 bar after a broker-month transition.
- Formation data: thirteen completed month endpoints reconstructed from a
  bounded D1 history buffer; custom-symbol MN1 data is not assumed.
- Entry frequency: at most one consumed attempt and one position per month.

## 5. Expected Behaviour

After warm-up, the rule is expected to produce roughly five to nine completed
monthly positions per year. Fewer than five completed trades per full
post-warm-up year is a retirement condition. Positive qualified scores map to
long and negative qualified scores map to short; score magnitude changes
eligibility, not cash risk.

The EA remains flat on nonconsecutive endpoints, current-month leakage,
nonpositive or nonfinite closes, exact ties, `abs(S) < 28`, invalid ATR or stop
geometry, excess spread, owned exposure, or unlocked inputs. It closes old
exposure before considering the next month and repairs duplicate, wrong-symbol,
invalid-type, missing-stop, or unexpected-TP exposure bearing its magic.

The non-duplicate boundary is the all-pairs ordinal path score with fixed
no-tie boundary. Existing XNG EAs use endpoint returns, adjacent-return sign
counts, cumulative-return votes, OLS slope and `R^2`, moving averages, channels,
variance ratios, calendar states, events, or relative baskets. Only Q09 may
establish realized decorrelation from the certified book.

## 6. Source Citation

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete-read record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded mechanization is
`strategy-seeds/sources/MOP-XNG-RANKTREND-2026/source.md`.

The paper supplies natural-gas membership and the monthly own-price continuation
family. The rank statistic, score boundary, CFD endpoint reconstruction,
fixed-cash risk, ATR stop, spread cap, and lifecycle controls are transparent
QM hypotheses. No source performance or diversification claim transfers.

## 7. Risk Model

The sole setfile is a non-live `XNGUSD.DWX` D1 backtest configuration with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The V5 risk
layer sizes from the frozen ATR hard stop. Both news axes and legacy news are
off, Friday close is disabled, and stress rejection probability is zero.

Risk is high: continuous-CFD roll and financing, natural-gas gaps and weather
shocks, rank-trend sparsity, persistent but low-magnitude paths, abrupt
reversals, hard-stop slippage, and energy/risk-asset correlation can dominate
the signal. No live,
demo, shadow, stress, or optimization setfile, AutoTrading action, `T_Live`
change, deployment manifest, portfolio-gate edit, or correlation waiver is
authorized.

## Kill Criteria

Retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong or nonconsecutive endpoints, current-month leakage,
an accepted tie, wrong pair count or score, entry below the fixed boundary,
wrong-side entry, repeated monthly attempt, missing hard stop, risk-mode
mismatch, nondeterminism, nonpositive governed economics, or any later
unchanged gate failure. No post-result lookback, threshold, direction, stop,
hold, spread, retry, or carrier rescue is authorized.

## Q01 Build And Q02 Handoff Status

- Q01: `PASS` on 2026-08-08. Strict build report:
  `D:/QM/reports/framework/21/build_check_20260808_200406.json`; compiler
  summary: `D:/QM/reports/compile/20260808_200407/summary.csv`; P1 binary
  presence: `D:/QM/reports/pipeline/QM5_20267/P1/P1_QM5_20267_result.json`.
- Q02: `NOT_ENQUEUED_CPU_CEILING`. A non-mutating sweep selected exactly this
  XNG setfile, but the immediate path-anchored sample found nine T1-T10
  terminals against the paced ceiling of seven. Apply mode was not run and
  the work-item readback count remained zero.
- Handoff evidence:
  `docs/ops/evidence/2026-08-08_qm5_20267_xng_rank_trend_q01_cpu_stop.md`.
