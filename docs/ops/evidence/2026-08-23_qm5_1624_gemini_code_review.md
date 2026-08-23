# QM5_1624 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `c724658a-978f-4aae-8492-7a99482269fe`

Source task: `02da6437-8c76-42c5-82df-ed307ce12628` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_1624_ehlers-adaptive-cg-h4/build_identity.json`

Verdict: **REQUEST_CHANGES — wrong dominant-cycle primitive; do not promote to PIPELINE**

## Findings

### 1. Critical — `ComputeDominantPeriod` is not the approved Ehlers autocorrelation periodogram

The approved identity binds period `P` to the Ehlers 2013 Autocorrelation-Periodogram. The EA instead:

1. computes uncentered cosine similarity of raw close-price levels (`sum(x*y) / sqrt(sum(x²)*sum(y²))`) for each lag;
2. performs an unsmoothed sine/cosine sum over those values;
3. returns the single period with maximum raw power.

That omits material components of the named Ehlers primitive: mean/detrend handling in the correlation, the specified power normalization/smoothing and the dominant-cycle selection from the normalized spectrum rather than a bare raw-price argmax. On price levels with a large DC component, the uncentered correlations remain near one across lags and can select a boundary or spectral artifact rather than the dominant cycle.

Since `P` controls the CG window, entries, exits, cooldown and time stop, this is a different strategy implementation under the current EA ID.

Required correction: port and fixture-test the canonical Ehlers 2013 Autocorrelation-Periodogram step by step against known input/output vectors. A generic correlation DFT must not be labeled as the approved primitive.

### 2. High — the `2 × P` H4 time stop counts wall-clock hours

The card requires actual H4 bars. The EA compares `TimeCurrent() - POSITION_TIME` with `2 × P × PeriodSeconds(H4)`, so weekends, holidays and market halts count as bars that never existed. This shortens holding periods unpredictably across calendar gaps.

Required correction: count actual completed H4 bars since entry using validated series history.

### 3. High — entry-period state is not restart durable

The time stop uses global `g_last_dominant_period`, initialized to `20` and set only when this process emits an entry signal. If the terminal or EA restarts with a live position, its original entry-period binding is lost and the stop silently becomes 40 H4-equivalent hours. This violates deterministic restart behavior.

Required correction: seal the entry `P` into durable position-associated provenance, or define and approve a deterministic recomputation rule that survives restart.

### 4. High — H4 execution scope is not enforced

Signal data is H4, but the execution clock is `QM_IsNewBar()` on the chart timeframe and no `_Period == PERIOD_H4` fail-closed check exists. A wrong chart changes when the same H4 state is evaluated without changing the identity.

Required correction: reject non-H4 initialization or bind the new-bar clock explicitly to H4.

### 5. Medium — cooldown starts before order success and is not restart durable

`g_last_trade_time`, `g_last_trade_dir` and `g_last_dominant_period` are assigned before `QM_TM_OpenPosition()` succeeds. A rejected order starts cooldown and changes future state despite no trade. Conversely, a restart clears the cooldown completely.

Required correction: update cooldown from a confirmed accepted entry and make the binding recoverable from durable trade provenance.

## Checks that passed

- Approved card exists with `g0_status: APPROVED`.
- EA registry row `1624 / ehlers-adaptive-cg-h4` is active.
- Fourteen active magic rows and fourteen corresponding H4 setfiles exist.
- All 14 backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0` and carry the declared card defaults.
- `validate_build_guardrails.py framework/EAs/QM5_1624_ehlers-adaptive-cg-h4`: `PASS`, 15 files, zero findings, `max_news_stale_hours=336`.
- MQ5 SHA-256 matches `build_identity.json`: `c1c88789483807a6817f77b2069b8b6bcb5a5f56c51e737a7e5c1fcc6fe9de78`.
- EX5 SHA-256 matches `build_identity.json`: `01c19aab514431c917cdf2899ae5b22ffc1bcd48d8932e2674a3c4385c82eaa7`.
- CG/trigger crossing, D1 EMA slope, ATR stop, spread gate, exit-before-news ordering, MAE tracking and request zero-initialization otherwise follow the declared structure.
- The implementation is deterministic and contains no ML, martingale or grid logic.

These checks establish artifact consistency and baseline hardening only. They do not prove the named period detector and are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict or trade stream was changed by this review. `T_Live` and AutoTrading were not touched. The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a fresh mandatory Codex review before any acceptance or enqueue.
