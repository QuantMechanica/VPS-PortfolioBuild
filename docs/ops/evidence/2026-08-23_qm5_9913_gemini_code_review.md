# QM5_9913 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `6bd917a5-8444-4499-8784-caddfe2527b3`

Source task: `de7917ef-268a-4b01-90a4-c77cf4e04b9e` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/de7917ef-268a-4b01-90a4-c77cf4e04b9e.json`

Verdict: **REQUEST_CHANGES — chart timeframe can change daily cadence and stop
risk, an invented entry filter can suppress exits, the universe is expanded,
and the smoke waiver is unsupported; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, setfiles, and focused repository checks directly.

## Findings

### 1. High — D1 cadence and ATR risk are not bound to a D1 execution contract

The card evaluates once per daily close and sizes from D1 ATR (card lines 16,
43-62). `OnInit()` only invokes the generic framework initializer (source lines
154-162); it neither declares D1 nor rejects another chart period. Entry uses
bare chart-clock `QM_IsNewBar()` at line 209. More critically, the generic
`QM_StopATR()` call at line 96 reads `PERIOD_CURRENT`, so an intraday attachment
turns the approved 2.5-D1-ATR catastrophe distance into an intraday ATR distance.

Required correction: declare/validate the D1 execution contract, use one
explicit D1 entry edge, and prove that stop sizing remains D1-bound.

### 2. High — an invented spread filter can suppress both mandatory exits

The card's only optional entry filter is the fresh-down-bar rule (card line 67).
The EA instead adds `strategy_spread_max_atr = 0.25` (source line 47) and runs
`Strategy_NoTradeFilter()` before `Strategy_ManageOpenPosition()` (lines
180-183). Missing quotes, warmup insufficiency, or a wide spread can therefore
delay both the RSI>=70 exit and the seven-day time stop for an open position.

Required correction: remove or approve the new entry filter and place all
management/exit work ahead of every entry-eligibility return.

### 3. High — the delivered 13-symbol package exceeds the index MR scope

The approved card names `SP500.DWX` for backtest and `NDX.DWX`/`WS30.DWX` for
live validation, with FX majors optional for breadth (card lines 25, 78, and
82). The package also registers/emits `GDAXI.DWX`, `UK100.DWX`, and
`XAUUSD.DWX`, none of which is authorized for this index-MR card. D17 sees an
empty target list because the legacy card uses prose; that does not authorize
the expansion.

Required correction: restrict the cohort to approved instruments or obtain an
OWNER-approved explicit `target_symbols` amendment.

### 4. High — the claimed smoke deferral fails the canonical admission test

The producer reports `deferred_p2_smoke` and a generic statement that T1-T10
were running backtests, but supplies neither `capacity_evidence` nor a durable
slot/process census. Applying `_q01_smoke_admission()` to the artifact returns
`q01_smoke_waiver_missing_capacity_evidence`: deferred smoke is valid only with
durable tester-fleet saturation evidence.

Required correction: provide a real smoke or a task-bound, structured capacity
snapshot that satisfies the saturation-only waiver.

## Checks that passed

- The approved card and one active identity row for
  `9913 / bandy-rsi3-low-adx-mr-index` exist.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains each corresponding magic exactly once; the dirty working
  resolver was not touched.
- Closed-D1 RSI(3), ADX(14)<20, SMA(200), long-only entry, 2.5-ATR stop input,
  one-position enforcement, RSI exit, and seven-D1-bar time stop are materially
  present apart from the cadence/risk and reachability findings above.
- `SPEC.md` passed its seven-section structural validator.
- All 13 setfiles use `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and the exact MQ5
  SHA-256 as `build_hash`.
- `validate_build_guardrails.py` returned `PASS`: 14 files, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 SHA-256 matches the producer artifact:
  `1cb763b49a13d4ccc0a38dd664ef8cd4db6c42766384b16218c808880fe49701`.
- EX5 SHA-256 matches the producer artifact:
  `63809aeb7b06b7436aebdc6ac792df294bc3c49b13491f8959311418c7b045e1`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, resolver, setfile, work item, task verdict, or trade
stream was changed by this review. `T_Live` and AutoTrading were not touched.
The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and
evidence require a fresh mandatory Codex review.
