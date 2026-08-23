# QM5_9910 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `b0616421-88f4-4370-b053-b96031a43386`

Source task: `499eaa2a-1f7a-47d2-b6df-a52d4d2999dc` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/499eaa2a-1f7a-47d2-b6df-a52d4d2999dc.json`

Verdict: **REQUEST_CHANGES — D1 lifecycle safety, the catastrophic-stop contract,
setfile build identity, approved universe, and producer evidence are incomplete;
do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, setfiles, and focused repository checks directly.

## Findings

### 1. High — a wrong-timeframe attachment initializes and suppresses all exits

The card is D1-only (card lines 15 and 44). `OnInit()` never declares a D1
execution contract (source lines 221-242). The later `_Period != PERIOD_D1`
test is inside `Strategy_NoTradeFilter()` (lines 76-89), which `OnTick()` calls
before the ATR trail and signal/time exit paths (lines 262-267). An accidental
intraday attachment therefore succeeds initialization and then disables every
managed exit for an existing position.

Required correction: fail initialization through the framework D1 execution
contract and keep management/exits reachable before all entry-only filters.

### 2. High — the approved 5-ATR catastrophic backstop is not implemented

The card requires a 2-ATR Chandelier primary stop and a separate 5-ATR
catastrophic backstop (card lines 51-62). The source declares
`strategy_catastrophic_atr_mult = 5.0` at line 44, but only reads it in parameter
validation at line 87. Entry sets the sole stop with the 2-ATR trail multiplier
(line 135), and management only maintains that 2-ATR stop (line 164).

Required correction: implement the approved two-layer lifecycle, or obtain a
card/SPEC amendment that makes the executable stop contract unambiguous.

### 3. High — none of the 13 setfiles is bound to the delivered source

The reviewed MQ5 SHA-256 is
`8d19dff75f54158b7f2ff026f12cf0a582a961b4e720fea00318e7cc41c0c78c`.
Each setfile contains a different `build_hash`, and none matches that source
hash. The 13 distinct values show per-file hashing, not one immutable build
identity. Such setfiles cannot enter review or pipeline dispatch under the
current build-hash gate.

Required correction: regenerate or backfill every setfile with the exact MQ5
SHA-256 after the source correction, then recompile and bind a fresh artifact.

### 4. High — the delivered cohort adds two indices and omits approved oil scope

The card authorizes FX majors, XAUUSD, oil CFD, live-routable `NDX.DWX` and
`WS30.DWX`, with `SP500.DWX` backtest-only (card lines 24, 79, and 83). The
13-symbol registry/setfile package adds `GDAXI.DWX` and `UK100.DWX` while
omitting `XTIUSD.DWX`. The legacy card has no machine-readable
`target_symbols`; that parser limitation is not scope authority.

Required correction: align the cohort with approved prose or obtain an
OWNER-approved explicit `target_symbols` amendment.

### 5. High — the producer artifact is schema-incomplete and has no smoke proof

The JSON supplies paths, hashes, setfiles, and `build_check_passed`, but omits
`ea_dir`, `magic_base`, `symbols_registered`, `compile_succeeded`,
`smoke_result`, and `smoke_report_path`. No passing smoke or durable
saturation-only waiver is bound to this immutable task/build.

Required correction: emit a schema-complete task-bound result with fresh compile
identity and smoke evidence, or canonical saturation evidence if the waiver is
actually applicable.

## Checks that passed

- The approved card and one active identity row for
  `9910 / bandy-tema-adx-crossover-trend` exist.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains each corresponding magic exactly once. Codex did not
  touch the concurrent dirty working resolver.
- Closed-D1 TEMA(8/21), ADX(14) gate, symmetric crossover entries, 2-ATR initial
  distance/trail, one-position enforcement, opposite-side exit, and 60-D1-bar
  time stop are materially present on a correct D1 attachment, subject to the
  stop and reachability findings above.
- `SPEC.md` passed its seven-section structural validator.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 and EX5 hashes match the producer artifact. EX5 SHA-256 is
  `39c32ccdc46237df0cfabfe7255ba1994c29a46159c4d604343df5871bcaeb08`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, resolver, setfile, work item, task verdict, or trade
stream was changed by this review. `T_Live` and AutoTrading were not touched.
The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and
evidence require a fresh mandatory Codex review.
