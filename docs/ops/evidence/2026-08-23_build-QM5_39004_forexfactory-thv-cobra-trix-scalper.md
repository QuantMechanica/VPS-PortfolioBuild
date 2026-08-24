# Build Evidence — QM5_39004 ForexFactory THV Cobra Trix Scalper

**Ticket:** `build-QM5_39004_forexfactory-thv-cobra-trix-scalper`

**Execution date:** 2026-08-24

**Worktree:** `C:\QM\worktrees\rework-slot-18`

**Scope:** Build artifacts and static/unit validation only. No compile, smoke, backtest enqueue, router task, factory toggle, verdict mutation, or `T_Live` access.

## Preflight

- Runtime approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_39004_forexfactory-thv-cobra-trix-scalper.md` has `g0_status: APPROVED` and the target universe `EURUSD.DWX`, `USDJPY.DWX`, `GBPUSD.DWX`.
- The branch already contained a prior implementation and focused regression test (`git log -- framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper` showed `9170289fa` and earlier build commits). Per HR1, this ticket completed and tightened the filesystem artifacts rather than creating a duplicate EA.
- EA identity already existed and was left unchanged: `framework/registry/ea_id_registry.csv:4483`.
- All three card symbols were exact members of `framework/registry/dwx_symbol_matrix.csv`.

## What changed

### EA mechanics

- `framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper/QM5_39004_forexfactory-thv-cobra-trix-scalper.mq5:82` treats the GMT rollover window `23:55` through `00:05` inclusively after `QM_BrokerToUTC` conversion.
- The bounded custom TRIX reconstruction keeps its sanctioned `CopyRates` annotation and now proves every dynamic-array index locally against `ArraySize(rates)` at `:138-150`; there is no raw `CopyBuffer`.
- Card loss rails are executable: realized daily entry halt at `:190`, initialization-anchored total drawdown at `:201`, framework daily/portfolio/per-trade kill-switch configuration at `:371`, and the total-DD trip path at `:401`.
- Existing card rules remain wired: cached ATR spread ceiling at `:229`, pip-normalized Coral stop at `:247`, restart-safe Fast-Trix direction exit at `:298`, M5 execution contract at `:358`, maximum 3-tick entry deviation at `:363`, and the MAE hook before any `OnTick` return at `:396`.
- `SPEC.md:19` records the card ambiguity: the illustrative lifecycle names break-even/trailing states but supplies no deterministic triggers. No unapproved management thresholds were invented. `SPEC.md:68-95` also separates conservative card priors from unevidenced source claims and states the governed live-risk boundary.

### Card, registry, resolver, and presets

- Added the approved-card mirror at `framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper/docs/strategy_card.md`; comparison after normalizing line endings and trailing whitespace returned equal content.
- Existing active magic rows were retained with their original date and updated to the ticket-required reservation owner at `framework/registry/magic_numbers.csv:17517-17519`:
  - slot 0 `EURUSD.DWX` → `390040000`
  - slot 1 `USDJPY.DWX` → `390040001`
  - slot 2 `GBPUSD.DWX` → `390040002`
- Resolver regeneration command:

  ```text
  python framework/scripts/update_magic_resolver.py --keep-obsolete
  [OK] ... 17994 rows kept, 0 dropped, sha=64147D37E6ADF30E...
  ```

  Generated contract: `framework/include/QM/QM_MagicResolver.mqh:16-18` (`QM_MAGIC_REGISTRY_ROWS=17994`).
- Read-only CSV verification returned:

  ```text
  active_rows=16560 duplicate_active_magics=0 duplicate_active_pairs=0
  ```

- Regenerated exactly three governed M5 backtest setfiles with `framework/scripts/gen_setfile.ps1 -EaSlug QM5_39004_forexfactory-thv-cobra-trix-scalper ... -Env backtest`. Each keeps `RISK_FIXED=1000`, `RISK_PERCENT=0`, and all strategy inputs. Their `build_hash` remains `pending` by design because this ticket expressly forbids compile; the governed `COMPILE_EA` lane seals the binary hash.

## Validation evidence

### Static hardening

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_39004_forexfactory-thv-cobra-trix-scalper
files_scanned=1
failures=[]
warnings=[]
magic_numbers.valid=true
dwx_symbol_matrix.valid=true
```

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper/QM5_39004_forexfactory-thv-cobra-trix-scalper.mq5
verdict=PASS
findings=[]
```

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper
PASS  QM5_39004_forexfactory-thv-cobra-trix-scalper
Summary: 1 PASS, 0 FAIL (of 1)
```

### Unit/regression tests

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_qm5_39004_review_rework.py \
  tools/strategy_farm/tests/test_build_gate_hardening.py \
  tools/strategy_farm/tests/test_build_guardrails.py

54 passed in 498.75s (0:08:18)
```

The ticket-focused test covers card mechanics, all declared-input use sites, the magic contract, hardening, and all three backtest presets.

### Scoped build-check interlock

The required scoped invocation was attempted exactly once and did not run checks or compile:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 \
  -EALabel QM5_39004_forexfactory-thv-cobra-trix-scalper \
  -SkipCompile

LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: terminal64 processes are alive;
use the governed COMPILE_EA lane. No retry was attempted.
```

The interlock is expected and was not bypassed. No compile work item was enqueued because the ticket explicitly forbids enqueueing and assigns compilation to the governed lane. The ticket-authorized pytest hardening alternative passed with zero failures.

## Risks and open questions

- Compile/smoke evidence is intentionally absent. MQL5 binary validity and setfile build-hash sealing remain for the governed `COMPILE_EA` lane.
- The approved card's state diagram references break-even and trailing states without defining trigger or distance rules. The executable exact-rule sections specify Coral SL, 2R TP, and Fast-Trix direction exit; the EA implements only those deterministic rules.
- The 5% total-drawdown anchor is account equity at EA initialization. Any future live execution contract must preserve or explicitly replace that anchor under OWNER authority; this build does not authorize live use.

## Rollback

After this ticket commit is identified, rollback the complete scoped change with:

```text
git revert <ticket-commit-sha>
```

This restores the EA/SPEC/setfiles, magic reservation attribution, resolver hash, card mirror, and this evidence atomically. Do not hand-edit the generated resolver; if registry conflict resolution is ever required independently, edit the CSV through its governed path and rerun `python framework/scripts/update_magic_resolver.py --keep-obsolete`.
