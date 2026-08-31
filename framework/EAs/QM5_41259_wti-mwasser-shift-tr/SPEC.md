# QM5_41259_wti-mwasser-shift-tr - Strategy Spec

**EA ID:** QM5_41259

**Slug:** `wti-mwasser-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-MWASSER-20260901_S01`

**Source:** `AI-CODEX-WTI-MWASSER-20260901`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
the EA reconstructs thirteen consecutive completed month-end closes and forms
twelve chronological log returns. The oldest six and newest six returns are
fixed samples; the current month is never used.

Each six-value block is sorted ascending. The signal statistic is equal-weight
one-dimensional Wasserstein-1 distance:
`W1 = sum(abs(sort(old)[j] - sort(recent)[j]), j=0..5) / 6`. The EA enumerates
all 924 six-of-twelve recent-label assignments and counts distances at least as
large as observed using a relative inclusive tolerance. It trades only when
the tail is at most 554 and also satisfies `5*tail <= 3*924`: buy when the
recent-block median exceeds the old-block median, sell when it is lower, and
otherwise consume the month flat.

An accepted position closes on the first tick of a later broker month or after
forty elapsed calendar days. It has a frozen `3.5*ATR(20,D1)` broker hard stop,
no target, and no same-month retry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_month_returns` | 12 | locked 12 | adjacent completed monthly log returns |
| `strategy_block_size` | 6 | locked 6 | fixed old and recent sample size |
| `strategy_assignment_count` | 924 | locked 924 | complete six-of-twelve label space |
| `strategy_tail_numerator` | 3 | locked 3 | activity-tail numerator |
| `strategy_tail_denominator` | 5 | locked 5 | activity-tail denominator |
| `strategy_tail_count_max` | 554 | locked 554 | inclusive exact-tail count cap |
| `strategy_wasserstein_epsilon` | 1e-12 | locked | relative inclusive statistic tolerance |
| `strategy_direction_epsilon` | 1e-12 | locked | recent-minus-old median deadband |
| `strategy_history_bars` | 900 | locked 900 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | locked 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | locked 10 | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked 3.5 | frozen broker hard-stop distance |
| `strategy_stale_days` | 40 | locked 40 | elapsed-calendar survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | locked 1500 | positive entry-spread ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - direct WTI continuous-CFD carrier for the approved crude-oil
  structural hypothesis; slot 0 and governed magic `412590000`.

**Explicitly not for:**

- Every FX pair, index, metal, and `XNGUSD.DWX` - the statistic and threshold
  were declared for WTI only; cross-market portability is not authorized.
- External futures curves or macro series - no external runtime feed is part
  of the approved data contract.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; completed month endpoints are reconstructed from D1 |
| Bar gating | one framework `QM_IsNewBar()` consume; `QM_CalendarPeriodKey(PERIOD_MN1)` supplies the month key |
| Risk reference | completed D1 `ATR(20)` at shift 1 |

The EA is D1-native because `.DWX` tester history does not rely on MN1 bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 6-7 before execution gates; at least 5 completed positions in every full scored year |
| Decision frequency | one consumed attempt per broker month; the equal-spaced reference qualifies 540/924 assignments, about 7.013 decisions/year |
| Typical hold time | until the next broker month; forty calendar days is the stale-repair maximum |
| Expected drawdown profile | high-risk candidate estimate, about 30% before governed validation; continuous-CFD gaps and roll effects are material |
| Regime preference | persistent WTI quantile shifts with a non-neutral median displacement |
| Win rate target | unspecified; Q02 measures activity and economics without an efficacy prior |

## 6. Source Citation

**Source ID:** `AI-CODEX-WTI-MWASSER-20260901`

**Source type:** governed AI synthesis with pinned public statistical sources
and peer-reviewed WTI carrier support.

**Pointer:**
`strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/source.md`.

**R1-R4 verdict (Q00):** all PASS under the approved card at
`strategy-seeds/cards/approved/QM5_41259_wti-mwasser-shift-tr_card.md`; the
runtime mirror is `framework/EAs/QM5_41259_wti-mwasser-shift-tr/docs/strategy_card.md`.

The complete-read Moskowitz, Ooi, and Pedersen (2012) record supports only WTI
membership, monthly cadence, and own-return continuation. Ramdas, Garcia, and
Cuturi (2015) and SciPy 1.13.1 pinned at commit
`44e4ebaac992fde33f04638b99629d23973cb9b2` support the nonparametric
two-sample context and one-dimensional equal-weight quantile representation.
The six-by-six split, exact tail, activity boundary, CFD translation, risk,
and lifecycle are pre-result QM choices.

### Non-duplicate boundary

`QM5_41258` uses all cross- and within-block absolute pair distances in energy
distance, `QM5_41255` integrates a pooled rank path, and `QM5_41250` compares
within-block MAD scale. This EA instead pairs corresponding sorted empirical
quantiles and retains actual return spacing. Locked nonlinear fixtures produce
both disagreement directions against energy distance and integrated ECDF;
these mechanics are not aliases.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This branch contains only the fixed-risk
backtest setfile and authorizes no live, demo, shadow, or deployment preset.

Retire on zero positions, fewer than five in any full scored year,
nonpositive governed economics, or deterministic-fixture failure. Fail on
current-month leakage, wrong return orientation, wrong sort/pairing, wrong
divisor six, wrong assignment count, tolerance, tail cap, side, risk mode,
hard stop, attempt ordering, or lifecycle.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, Wasserstein arithmetic, and position
  state.
- `trade_entry`: cached qualifying direction, quote/spread/ATR/stop gates, and
  one fixed-risk WTI market order.
- `trade_management`: malformed-position repair, next-month exit, and forty-day
  stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-01 | Initial build from approved card | OWNER commodity/energy portfolio mission; governed magic `412590000` |
