# One character in a generated setfile kills the run, and it is booked as infrastructure (2026-08-17)

## Root cause, proven four for four with no counterexample

**MT5's `.set` parser does not handle exponent notation for double inputs.** The setfile
generator emitted the *same number* in two different serialisations, and only one of them
survives parsing:

| EA | Setfile writes | Q02 outcome |
|---|---|---|
| QM5_41034 | `strategy_reconcile_tolerance=0.0000000001` | **PASS** |
| QM5_41037 | `strategy_reconcile_tolerance=0.0000000001` | **PASS** |
| QM5_41035 | `strategy_reconcile_tolerance=0.0000000001` | FAIL (economic — a real verdict) |
| QM5_41036 | `strategy_reconcile_tolerance=0.0000000001` | FAIL (economic — a real verdict) |
| QM5_41033 | `strategy_reconcile_tolerance=1.0e-10` | **INFRA_FAIL** |
| QM5_41038 | `strategy_reconcile_tolerance=1.0e-10` | **INFRA_FAIL** |
| QM5_41041 | `strategy_reconcile_tolerance=1.0e-10` | **INFRA_FAIL** |
| QM5_41042 | `strategy_reconcile_tolerance=1.0e-10` | claimed 09:53, predicted to fail |

**The EA source default is `1.0e-10` in both groups** — `input double
strategy_reconcile_tolerance = 1.0e-10;` at `QM5_41034:49` and `QM5_41033:50`. So the EAs are
identical on this point and correct. The difference is entirely in how the generator wrote the
value into the setfile.

The failure chain:

1. the setfile carries `1.0e-10`; MT5 does not parse it to 1e-10;
2. the EA's own self-consistency guard
   `MathAbs(strategy_reconcile_tolerance - 1.0e-10) > 1.0e-20` is therefore true;
3. `Strategy_NoTradeFilter()` returns true, `OnInit` returns `INIT_PARAMETERS_INCORRECT`;
4. the tester stops before the first bar — `tester stopped because OnInit reports incorrect
   input parameters`, with history already loaded and the symbol synchronised;
5. the report carries zero bars, so the classifier stamps `BARS_ZERO` → **`INFRA_FAIL`**;
6. the row is eligible for infra recovery, gets requeued, and fails identically. Three
   attempts per run, ~2 hours of a terminal slot each time.

**Everything about this is deterministic, and every layer records it as transient.**

## A second, unrelated cause in the same band

`QM5_41032_wti-flow-div` produces the identical symptom for a different reason: it was cloned
from `QM5_41029` and its own identity guard still reads

```mql5
if(qm_ea_id != 41029 || qm_magic_slot_offset != 0)
    return true;
```

at lines 438 and 591 — while its setfile correctly sets `qm_ea_id=41032`. The EA rejects its
own correct configuration.

A repo-wide scan of every EA source found **exactly one** instance: 221 EAs carry a correct
identity guard, 3,385 carry none, 1 is stale
(`artifacts/stale_ea_id_literal_scan_20260817.json`). This is the same defect family as the
host-slot magic conflation of 2026-08-16 — a hardcoded identity that was not re-pointed when
the EA was cloned — and it is worth a standing review check for exactly that reason.

## What made this expensive to find

Every cheap hypothesis was wrong, and each had to be refuted with a measurement:

- **Not missing history.** The log shows the symbol synchronised and 193 warmup bars loaded.
- **Not a symbol or terminal problem.** T2 passed XNGUSD at 09:06 and failed XNGUSD at 09:35;
  all terminals hold complete `Bases\Custom` coverage; containment mode `enabled: false`.
- **Not setfile drift.** The staged setfile on T9 hashes
  `98F3A253582A26CF9094C3733F82FE9377BA59E22B66C574B1D3DDD3A5B632C5`, byte-identical to the
  repo copy. The staged file was *faithfully* delivered — it was wrong at the source.
- **Not a value mismatch on inspection.** Reading the setfile, every value the guard checks
  *looks* correct, including `strategy_reconcile_tolerance=1.0e-10`. The defect is invisible to
  a human comparison because the written value is right and only its *encoding* is wrong.
- **Not a build-vintage regression.** Passers and failers interleave in time across the whole
  build wave (41032 ONINIT 22:05, 41034 PASS 00:20, 41035 FAIL 01:15, 41037 PASS 03:34,
  41038 ONINIT 04:44).
- **Not `SymbolSelect`.** All band members call it once in the same position.

The discriminator only appeared when the setfiles of passers and failers were compared
*character by character* rather than value by value.

## Why the classification matters more than the four EAs

An `INFRA_FAIL` verdict is an invitation to retry. A deterministic input rejection cannot
benefit from a retry, so each requeue is a guaranteed ~2-hour loss of an exclusive slot plus
another polluted census row. This directly caps the stranded-infra recovery programme:

- 103 of 936 `INFRA_FAIL` rows since 2026-08-01 carry `BARS_ZERO`;
- only 4 still have a tester log, and **all 4 are OnInit rejections**;
- the other 99 are unclassifiable because `ReportsLogPurge_12h` removed the only artifact that
  separates an input rejection from a data failure;
- `oninit_failure_detected` fired on **0 of 4**, although `ONINIT_FAILED` is an established
  class with 373 occurrences — the wording is simply not matched.

**Wave 2 of the deep-phase recovery stays gated on this** (`cause before quantity`): an unknown
share of the 1,562 "recoverable" pairs may be deterministic rejections rather than transients.

## Blast radius, measured; and the class reproduces at build time

Scan over **all 30,995 setfiles**: **28 affected across 25 EA directories**
(`artifacts/exponent_notation_setfile_scan_20260817.json`). Every affected input is a
numerical **tolerance, epsilon, floor or deadband** — 18 distinct names, led by
`strategy_variance_floor`, `strategy_beta_tolerance`, `strategy_corr_tolerance` (4 each) and
`strategy_reconcile_tolerance` (3). That is why the newest quantitative EA families are hit
hardest, and it is **not confined to Q02**: `QM5_20289` and `QM5_21516` carry it in their
`q05_stress_medium` and `q06_stress` setfiles too.

Of the 981 distinct setfiles referenced by open work, **3** were affected — all in the
QM5_410xx band, and all three were **new rows**: the requeue path had already re-fed the
defect. `d062a748` (QM5_41033 Q02) is held under `SETFILE_EXPONENT_NOTATION_UNPARSEABLE` with
claimability verified 0; the two sibling rows were already active and were left running rather
than aborted.

**The generator is still producing the defect.** `gen_setfile.ps1` has not been touched in 24
hours. `QM5_41042` was built at 11:55 local — three minutes after the cause was named on the
Codex task — and its generated setfile carried `strategy_reconcile_tolerance=1.0e-10` anyway.
It was then hand-sealed by `4748590b4` at 12:04, a two-line change to one setfile. Correct as
an immediate unblock, and the fifth per-EA patch of a generator defect. **So 25 is a floor, not
a total** — the scan predates QM5_41042's existence.

### The exact fix location

`framework/scripts/gen_setfile.ps1`, `Convert-EAInputValueForSetfile` (~line 287). It
special-cases `inputType` `string` and `ENUM_TIMEFRAMES`; for **everything else, including
`double`**, it performs a bare `return $Value` and passes the upstream literal through
unchanged. Nothing in the generator prevents exponent notation from reaching the file.

One open thread worth naming rather than assuming: the passing siblings `QM5_41034` and
`QM5_41037` were **born clean** — created in a single commit with `0.0000000001`, never patched
— although their *source* default is also `1.0e-10`. So the emitted value does not come from
the source literal alone, and some upstream supplier writes it differently. A generator guard
is necessary regardless, but that upstream inconsistency is what makes the defect intermittent
and therefore invisible to review.

## What must change

1. **Fix the generator, not the files.** Setfile serialisation must never emit exponent
   notation for a double input — decimal expansion only — with a generator test asserting no
   emitted value matches an exponent pattern. Hand-editing the affected files leaves the next
   generated batch broken.
2. **Classify correctly.** An OnInit input rejection is `ONINIT_FAILED` (a strategy/build
   verdict), never `BARS_ZERO`/`INFRA_FAIL`, and a genuine zero-bar data failure must still
   classify as `BARS_ZERO` — do not collapse the two.
3. **Make guards self-describing.** A compound boolean returning a bare
   `INIT_PARAMETERS_INCORRECT` says neither which predicate failed nor what value it saw. That
   silence is what turned a one-character defect into a multi-hour investigation. This is a
   framework-level fix, not a per-EA one.
4. **Stop destroying the evidence.** Exempt the tester log of any non-OK run from the 12-hour
   purge, or extract the decisive lines into the summary before purging. Quantify the disk cost
   — D: sits near the 150 GB purge low-water mark, so it is a real trade-off.
5. **Repoint the `QM5_41032` literal** and add a review check for an EA whose identity guard
   names a foreign `ea_id`.

## Evidence

- `artifacts/exponent_notation_setfile_scan_20260817.json` — every setfile carrying exponent
  notation, i.e. every latent instance of this failure
- `artifacts/stale_ea_id_literal_scan_20260817.json` — the repo-wide identity-guard scan
- `artifacts/bars_zero_oninit_misclassification_20260817.json` — the misclassification census
- `D:\QM\reports\work_items\058c59e8-…\QM5_41033\20260817_092133\raw\run_01\20260817.log`
- Related: `2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md` (the
  classification finding), `2026-08-17_stranded_infra_recovery_wave1.md` (the gated programme)
