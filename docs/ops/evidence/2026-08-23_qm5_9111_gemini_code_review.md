# QM5_9111 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `f82c46f1-5294-45fa-b75d-6b1120b9a591`

Source task: `c214fe96-6101-46e0-98cc-30daa4ea8d03` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9111_aa-dlwma-trend10/build_identity.json`

Verdict: **REQUEST_CHANGES — entry-only filters suppress exits and the approved spread rule is absent; do not promote to PIPELINE**

## Findings

### 1. High — the approved 20-day median-spread gate is replaced by an ATR ratio

The approved card requires new entries to be skipped when current spread
exceeds `2.5 x` the 20-day median spread. `SpreadAllows()` instead compares
spread with `0.3 x ATR(20,D1)`. ATR measures price movement, not the historical
distribution of spread, so this admits and rejects a different set of entries.
The function also returns `true` when ATR is non-positive, which turns missing
filter evidence into permission to trade.

Required correction: calculate a deterministic 20-day spread sample and its
median, apply the fixed 2.5 multiplier only to entry admission, and fail closed
when the sample is missing or invalid.

### 2. High — news and spread entry filters suppress risk-reducing exits

`OnTick()` returns on `!news_allows` and on `Strategy_NoTradeFilter()` before it
calls `Strategy_ExitSignal()`. The latter includes the spread check. A news
blackout, wide spread, or temporarily unavailable ATR/history can therefore
delay the card's opposite-zero-cross exit. The news return also occurs before
Friday-close handling. These controls are entry gates; the card does not
authorize them to disable position management or risk reduction.

Required correction: run framework risk handling and card exits independently
of new-entry eligibility. Apply the mandatory news blackout and median-spread
gate only before constructing a new entry request.

### 3. High — completed-D1 evaluation is not bound to a D1 execution clock

The signal inputs use completed D1 bars, but the entry gate calls the no-argument
`QM_IsNewBar()`, which follows the attached chart timeframe, and `OnInit()` does
not reject a non-D1 chart. On an H1 or H4 chart, the same completed-D1 cross can
be resubmitted on several chart-bar boundaries if an order is rejected. Exit
evaluation runs on every tick rather than from one explicit completed-D1 event.
The D1 setfiles reduce this risk in governed backtests but do not make the
binary fail closed when attached incorrectly.

Required correction: reject non-D1 initialization or explicitly bind a single
shared entry/exit evaluation clock to `PERIOD_D1`, with one decision per newly
completed D1 bar.

### 4. Medium — the card's fixed DLWMA trend equation is not implemented exactly

The approved card binds the signal to the Stern/Brown double-LWMA linear-trend
equation. `ComputeDLWMATrend()` returns only `LWMA1 - LWMA2`, and the source
comment itself leaves two alternatives (`difference` "or" a scaled difference)
rather than sealing one equation. A positive constant does not ordinarily alter
a zero-cross, but the output is still not the exact fixed indicator authorized
by the mechanical card and has no deterministic reference-vector proof.

Required correction: encode the card/source equation with its fixed
normalization, document the indexing convention, and add reference vectors for
both component LWMAs and the final trend at shifts 1 and 2.

## Checks that passed

- The canonical approved card exists with `g0_status: APPROVED`; its SHA-256 and
  the EA-local copy both equal
  `1f84d4653f85b2261a6f34e0cdae3635e208eba1645afdd5d90b3c9700656001`.
- EA registry row `9111 / aa-dlwma-trend10` is active.
- Thirteen active, symbol-specific magic rows and thirteen corresponding D1
  backtest setfiles exist; the setfile offsets match the registry allocation.
- Every backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_9111_aa-dlwma-trend10`
  returned `PASS`, checking 14 files with zero findings and enforcing
  `max_news_stale_hours=336`.
- MQ5 SHA-256 matches `build_identity.json`:
  `1d1498bfc31dcc463bab92ddfac6206748b148c023495b7711f70c7301abdf73`.
- EX5 SHA-256 matches `build_identity.json`:
  `dcb01b20753f61ecbb5c39c2649552e7ffeb243d42855f26b45d9ba50e1d9ad5`.
- Completed-D1 close inputs, N=10 double-LWMA construction, zero-cross
  direction, optional short mode, one-position lookup, minimum 80-bar gate,
  and 3.0 x ATR(20,D1) initial stop otherwise follow the card's outline.
- Direct first-on-tick MAE tracking and entry-request zero-initialization are
  present. No ML, martingale, grid, or HFT mechanism is present.

These checks establish artifact consistency and baseline hardening only. They
do not cure the execution-contract deviations and are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict, or trade stream was changed
by this review. `T_Live` and AutoTrading were not touched. The task remains in
`REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a fresh
mandatory Codex review before any acceptance or enqueue.
