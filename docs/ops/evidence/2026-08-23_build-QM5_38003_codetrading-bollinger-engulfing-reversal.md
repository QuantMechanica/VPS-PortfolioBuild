# Build evidence — QM5_38003 CodeTrading Bollinger Engulfing Reversal

**Ticket:** `build-QM5_38003_codetrading-bollinger-engulfing-reversal`
**Execution date:** 2026-08-24
**Scope:** Q01 source/spec/setfile build only; no compile, smoke, backtest enqueue,
router task, verdict mutation, factory toggle, or `T_Live` access.

## Status

Implemented from the OWNER-approved card. The direct EA hardening scan reports
zero failures, both Python guardrails pass, and all focused/regression pytest
tests pass. Compilation was intentionally not run per the ticket. A scoped
`build_check.ps1 -EALabel ... -SkipCompile` attempt was fail-closed by the live
factory interlock before static checks; it was not bypassed or retried through
an enqueue.

## What changed

- The EA uses the canonical `QM_Common.mqh` include chain, fixed-$1,000
  backtest/percent-live inputs, two-axis news filter, Friday close, seeded
  stress hook, MAE sampling, and framework trade APIs
  (`framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal/QM5_38003_codetrading-bollinger-engulfing-reversal.mq5:1`, `:339`, `:372`).
- Closed H1 bars `[1]` and `[2]` are read through `QM_ReadBar`; ATR, Bollinger,
  and RSI use pooled `QM_*` readers and cached state. There is no EA-side
  `CopyBuffer`, raw indicator handle, or dynamic numeric buffer
  (`...reversal.mq5:126`).
- Literal long and symmetric short engulfing predicates, outer-band touch,
  RSI thresholds, two-pip structural stop, and 2R target are wired at
  `...reversal.mq5:185-243`.
- Entry admission covers the GMT rollover blackout, 1.8×ATR spread ceiling,
  2% daily realized-loss halt, 5% total drawdown halt, one-position cap, and
  three-tick slippage configuration (`...reversal.mq5:61-84`, `:159-176`,
  `:189-194`).
- Management closes 50% at the Bollinger middle band without making management
  unreachable during an entry blackout; 2.5% daily and 5% total equity exits
  remain active per tick (`...reversal.mq5:247-295`).
- `SPEC.md` documents all seven Q01 sections and the card-to-framework mapping
  (`framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal/SPEC.md:11`,
  `:30`, `:48`, `:65`, `:75`, `:87`, `:97`). The mirrored approved card is at
  `framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal/docs/strategy_card.md`.
- Governed H1 backtest setfiles exist for EURUSD slot 0, GBPJPY slot 1, and
  AUDUSD slot 2; each seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and every
  strategy input (`framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal/sets/`).
- Four pytest checks cover the corset, exact mechanism, registry/setfile
  bindings, and card mirror
  (`tools/strategy_farm/tests/test_qm5_38003_codetrading_bollinger_engulfing_reversal_static.py:36`,
  `:61`, `:92`, `:139`).

## Registry and resolver evidence

Pre-existing active allocations were retained; no provenance row was
overwritten and no duplicate row was appended:

```text
framework/registry/ea_id_registry.csv:4474
38003,codetrading-bollinger-engulfing-reversal,...,active,...

framework/registry/magic_numbers.csv:17491-17493
slot 0 EURUSD.DWX magic 380030000 active
slot 1 GBPJPY.DWX magic 380030001 active
slot 2 AUDUSD.DWX magic 380030002 active
```

Active-registry query:

```text
active_rows=16560 duplicate_active_magics=0 duplicate_active_pairs=0
```

Resolver regeneration was run only after the EA directory existed:

```text
python framework/scripts/update_magic_resolver.py --keep-obsolete
[OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17994 rows kept,
0 dropped, sha=A271541CEA278762...
```

The generated resolver was already byte-equivalent to the index after
regeneration, so it has no content diff. The two registry CSVs likewise required
no mutation because all required active rows already existed.

Governed setfile outputs after the final source inputs were present:

```text
EURUSD.DWX H1 backtest sha256=e362cc212b73eff7b558521b883b69ab5658869596d6e76942b38de4c0673ccb
GBPJPY.DWX H1 backtest sha256=62f7b6d9a392ccc0b7005744566df2fbdfaec011a08b06f5a9dbf38800e4e00d
AUDUSD.DWX H1 backtest sha256=1b0cdc8009dbb65568bdecc4c161f8bcb974be068be816364fb1b5577f8e90b0
```

## Validation and test output

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal
PASS  QM5_38003_codetrading-bollinger-engulfing-reversal
Summary: 1 PASS, 0 FAIL (of 1)

python framework/scripts/skill_build_ea_guard.py --ea-id 38003 --ea-label QM5_38003_codetrading-bollinger-engulfing-reversal
status=ok; ea_registry_row=true; magic_registry_rows=true; ea_dir_exists=true

python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal/QM5_38003_codetrading-bollinger-engulfing-reversal.mq5
verdict=PASS; findings=[]

python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_38003_codetrading-bollinger-engulfing-reversal
files_scanned=1; failures=[]; warnings=[]

python -m pytest -q tools/strategy_farm/tests/test_qm5_38003_codetrading_bollinger_engulfing_reversal_static.py
4 passed in 1.90s

python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_build_guardrails.py
50 passed in 569.24s (0:09:29)
```

Scoped build-check attempt (expected governance refusal, not an EA failure):

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 \
  -EALabel QM5_38003_codetrading-bollinger-engulfing-reversal -SkipCompile
exit=1
BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED
failure_class=LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
detail=terminal64 processes are alive; ad-hoc compile/build_check is refused
retry_attempted=false
```

The ticket forbids compilation and queue mutation, so the interlock was not
bypassed and no `enqueue-compile` command was issued. Static coverage required
by the ticket is supplied by the direct hardening scan and pytest guard.

## Risks and open question

- The governed `COMPILE_EA` lane still owns syntax compilation; this ticket
  intentionally produced no `.ex5`.
- The card's lifecycle diagram names break-even and trailing states but gives
  no numeric triggers. The exact exit section defines only SL, 2R TP, and a 50%
  middle-band partial, so BE/trailing were left inactive rather than invented.
  A future card revision may define them explicitly.

## Rollback

Revert the ticket commit with `git revert <ticket-commit>`. This removes the EA
source/spec/setfile/test/evidence changes and restores the prior tracked EA
content. Registry CSVs were not changed. If reverting in a tree where the EA
directory is removed, rerun
`python framework/scripts/update_magic_resolver.py --keep-obsolete` and verify
the generated resolver before any later governed compile.
