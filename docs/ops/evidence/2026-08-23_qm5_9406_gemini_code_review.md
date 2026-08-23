# QM5_9406 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `a81c8603-e857-466e-bd93-df15cae0bd8f`

Source task: `52fc3ee3-bd54-41c4-a3fd-d3616da86b62` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9406_qs-daily-mac/build_identity.json`

Verdict: **REQUEST_CHANGES — the D1 execution contract, exit semantics, and approved symbol scope are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

The approved strategy is explicitly D1. `OnInit()` calls
`QM_FrameworkInit()` and returns success without immediately calling
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines 133-140).
Entry admission then uses the no-argument `QM_IsNewBar()` (line 192), which
follows the attached chart timeframe while the indicators remain fixed to D1.
A wrong-period attachment can therefore evaluate the same completed-D1 cross
on multiple chart-bar boundaries instead of failing closed at initialization.

Required correction: declare the D1 timeframe and the intended Friday-close
mode immediately after framework initialization, and use that same D1 clock for
the strategy decision boundary.

### 2. High — the exit can be missed permanently after restart or downtime

The card says to close a long whenever `SMA_slow >= SMA_fast` (card line 49).
`Strategy_ExitSignal()` instead requires both the current bearish relation and
a bullish relation on the preceding bar:

```mql5
return (fast_1 <= slow_1 && fast_2 > slow_2);
```

That transition-only predicate is true for one completed D1 boundary. If the
EA starts after that boundary, history was temporarily unavailable, or the
terminal missed it, an existing long remains open while both bars are already
bearish and will not receive the approved exit until another complete up/down
cycle. The server-side ATR stop is not a substitute for the card's regime exit.

Required correction: make the close predicate reflect the current approved
state (`SMA_slow >= SMA_fast`) and keep close attempts restart-safe.

### 3. High — entry eligibility can suppress risk-reducing exits

`OnTick()` returns on `Strategy_NoTradeFilter()` before management and the
strategy exit (lines 163-168). That function includes quote availability,
history warmup, and the spread/ATR entry gate (lines 49-63). A wide spread,
missing quote, missing ATR, or temporarily reduced history can therefore delay
the SMA exit of an already-open position. These are entry-admission conditions,
not approved exit-blackout rules.

Required correction: run Friday close, position management, and the card exit
independently of entry filters; apply history/spread eligibility only before a
new entry request.

### 4. High — ten delivered symbols are outside the card's approved port

The approved card names `SP500.DWX` as the default backtest port and
`NDX.DWX`/`WS30.DWX` as the broker-routable alternatives (card lines 19, 43,
74, and 78). The package and SPEC expand that contract to 13 symbols, adding
`GDAXI.DWX`, `UK100.DWX`, `XAUUSD.DWX`, and seven FX pairs without an approved
card revision. Registry allocation proves identity availability; it does not
authorize a new strategy universe.

Required correction: generate sets only for the approved three-symbol port, or
obtain an OWNER-approved card revision that explicitly authorizes and motivates
the expanded universe.

### 5. Medium — every delivered setfile has malformed `CR CR LF` endings

All 13 setfiles contain exactly 29 `0D 0D 0A` line endings. This is why a
normal anchored risk-line audit does not recognize their otherwise visible
`RISK_FIXED=1000` and `RISK_PERCENT=0` records. Normalize the files through the
governed generator and refresh their bound build hashes before resubmission.

## Checks that passed

- The canonical approved card exists with `g0_status: APPROVED`.
- EA registry row `9406 / qs-daily-mac` is active.
- Thirteen active magic rows exist at slots 0-12 with no global magic
  collisions, and all 13 exact rows are present in `QM_MagicResolver.mqh`.
- All delivered symbols are canonical entries in `dwx_symbol_matrix.csv`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings for the EA.
- `validate_spec_doc.py` returned `PASS`; the SPEC contains no non-whitespace
  control bytes.
- The MQ5 SHA-256 matches `build_identity.json`:
  `23bc76a30cadb074ca66c66ffcd9a5602222cd1649232a433ed29510d0c4c5cf`.
- The EX5 SHA-256 matches `build_identity.json`:
  `d88740fed1952b737134010f86f8fcba65e2ce5252f9b4ed6b1502c58f3e97bf`.
- The focused forbidden scan found no raw indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, ML, martingale, grid, or HFT mechanism.

The resolver dry-run itself refused globally because unrelated active rows
`1001`, `1015`, and `1016` have no materialized EA directories. No resolver or
registry mutation was attempted; the target rows were verified directly in the
current generated arrays.

These passes establish artifact identity and baseline hardening only. No smoke
report or pipeline evidence was supplied, so no runtime or pipeline verdict is
inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a
fresh mandatory Codex review before acceptance or enqueue.
