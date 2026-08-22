# `OWNER-DEC-RISK-FREEZE` — armed 2026-08-22

Date: 2026-08-22

Decision: **EXECUTED — interim live-risk freeze is ACTIVE.**

Authority: OWNER, explicit instruction the same evening — *"Führ den Risk-Freeze
jetzt aus, nicht erst morgen."*

**This is a direct order, not an Auffangregel execution.** The Vorlage on the
vault decision surface carried a 12-hour Auffangregel deadline of 2026-08-23
~12:00; OWNER pre-empted it. The distinction matters for the audit trail: the
freeze rests on an instruction, not on my own recommendation executed by
default, and it is recorded as such in the freeze state's `authority` field.

## What is frozen

- per-sleeve `RISK_PERCENT` on the T_Live DXZ book
- the sleeve roster — no additions, no removals
- deployed preset bytes and their bound binaries
- new live promotions of any kind

## What is explicitly NOT frozen

- backtests and the T1–T10 factory
- gate work Q02–Q10 and the whole drain programme
- builds, reviews, research
- diagnosis of the deployed presets (`740049db`) — diagnosis only, no T_Live write

Freezing the *book* rather than the *pipeline* is the point. The drain
programme is what eventually earns the right to lift this freeze; stopping it
would be self-defeating.

## Baseline captured at arming

```
sleeve_count          24
total RISK_PERCENT    9.7499
roster_sha256         a98bfdeb08a95d9bd9c8dfe3593e258cc24ec94677a67d821a1338338c8ee159
armed_at_utc          2026-08-22T19:55:00Z
state file            D:\QM\reports\state\live_risk_freeze.json
state sha256          88059e2f0d838f867963c8e479362ea7c981a05df26536756f5d46967565d1a6
```

Per sleeve the baseline records `RISK_PERCENT`, `RISK_FIXED`,
`PORTFOLIO_WEIGHT`, `qm_magic_slot_offset` and the preset's SHA-256. The
measurement is taken from **the deployed preset files themselves**, not from a
manifest: a manifest states intent, only the files the terminal actually loads
state fact.

## Why this is a state and not a note

A freeze that exists only in a document is a note. `tools/strategy_farm/risk_freeze.py`
makes it measurable:

- `arm` — capture the baseline, write the signed state. **Refuses to re-arm an
  active freeze** without `--force`, because re-arming would silently rebase the
  baseline onto whatever is deployed at that moment, absorbing exactly the drift
  the freeze exists to catch.
- `verify` — re-measure and diff; non-zero exit on any drift.
- `status` — the same, rendered for a human.

It is read-only against `C:\QM\mt5\T_Live`. It never writes a preset, never
touches a binary, and never toggles AutoTrading — that remains OWNER-only under
the Hard Rules.

### The verifier was proven to refuse before it was trusted

Run against a fixture copy of the live presets, six checks, all passing:

| # | Case | Result |
|---|---|---|
| 1 | arm on fixture | baseline captured, 24 sleeves / 9.7499 |
| 2 | nothing changed | `held=True` — no false alarm |
| 3 | one `RISK_PERCENT` raised | `held=False`, total 9.7499 → 9.7659 reported |
| 4 | sleeve added (a promotion) | `held=False`, "roster changed: 24 → 25" |
| 5 | sleeve removed | `held=False`, names the removed preset |
| 6 | freeze state corrupted | `held=False`, `STATE_UNREADABLE` — fails closed |

Case 6 is the one that matters most: an unreadable freeze state is treated as
drift, never as "fine". Case 2 matters nearly as much — a guard that cries wolf
gets ignored, and then it protects nothing.

Building the fixture surfaced a real fragility in the tool and it was fixed:
`measure()` originally bound the presets directory as a default argument at
import time, so it could not be pointed at a known-bad tree. A verifier that
cannot be aimed at a bad tree cannot be proven to refuse anything.

## It is now re-measured every 15 minutes

`probe_risk_freeze` was added to `tools/strategy_farm/heartbeat_snapshot.py`
(task `QM_Orchestrator_Heartbeat_15min`). Any drift raises
`RISK_FREEZE_BREACH:<what changed>` on the FLAGS line. The probe uses the
existing `@guarded` pattern, so a failure in it reports itself as a flag and
cannot break the heartbeat. First run after wiring: `risk_freeze` block present,
`held: true`, no probe failure.

## Lift conditions

All three must hold, **and** OWNER must lift it in writing. No AI seat lifts
this freeze, and no seat lifts it by inference from a condition merely being
satisfied.

| Condition | Status |
|---|---|
| SP-A1/A2 deploy pointer signed, consumers authenticated | **BLOCKED** by `OWNER-DEC-POINTER-PRESETS` — reconciliation is complete and unambiguous, but 10 of 24 deployed presets carry no valid build provenance and one carries its own `DO_NOT_COPY_TO_T_LIVE` marker. Signing was held rather than asserting provenance that does not exist. Repair diagnosis: `740049db`. |
| News contract V2 implemented under `qm.news_impact_mapping.v1` | **PARTIAL.** OWNER half decided 2026-08-22 (clean canonical); `84c988e6` remains correctly gated on the second condition, Q09 rerun completion. Pilot `ba24e7a3` running. |
| Governor hardening **and actually enforcing** | **PARTIAL.** SP-C1 (`5c02a347`) is already APPROVED with `PASS_DRY_RUN` at `593c9ddca` — fresh DD source, magic-independent all-position reconciliation, staged escalation verified. But the v2 monitor deploy and the action adapter are correctly OWNER/ROT-gated and are therefore **not live**. Built and proven is not the same as enforcing. |

## Enforcement still to come

What is armed today **detects** a breach; it does not yet **prevent** one. The
control points that could move the live book are the subject of router task
`6e512650` (priority 89), which wires a fail-closed guard into each of them and
surfaces the freeze on Mission Control. It demands a positive test per guard as
well as a negative one — a guard tested only against an active freeze could just
as easily block forever, and that would surface only after the freeze is lifted.

The most relevant one is worth stating plainly:
`tools/strategy_farm/portfolio/stage_tlive_presets_risk.py` defaults its
`--manifest` to `portfolio_manifest_sunday_24sleeve_TOTALRISK12_20260726.json` —
i.e. the 9.75 % → 12 % scaling this freeze exists to hold back. That tool is
read-only against T_Live and only writes to a staging directory, so it cannot
deploy on its own; the actual promotion is the manual copy into
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets`, which no automation performs.

Independent corroboration worth recording: that same tool already carries
`HEADER_FIXES` for exactly the two preset headers flagged in tonight's
reconciliation (`10919` backtest/FIXED, `12989` draft `risk_mode`), attributed
to a 2026-07-25 deployment-readiness audit. So those two header defects were
known a month ago and simply never applied to the deployed files. That
strengthens the case for repairing provenance before signing, and it slightly
revises tonight's framing: the defects were previously observed, not newly
discovered — what was new tonight is that they are still live, and that a third
file carries an explicit `DO_NOT_COPY_TO_T_LIVE` marker.

## Evidence

- Freeze state: `D:\QM\reports\state\live_risk_freeze.json`
- Tool: `tools/strategy_farm/risk_freeze.py`
- Heartbeat probe: `tools/strategy_farm/heartbeat_snapshot.py::probe_risk_freeze`
- Reconciliation the baseline rests on: `docs/ops/evidence/2026-08-22_deploy_pointer_manifest_reconciliation.md`
- Decision batch: `decisions/2026-08-22_owner_decisions_evening_batch.md`

## Correction made after arming

At arming time the freeze state recorded the governor-hardening condition as
"open; not yet commissioned". **That was wrong** — SP-C1 had already been
approved the same morning (`5c02a347`, `PASS_DRY_RUN`, commit `593c9ddca`). The
condition is `PARTIAL`, not open: the hardening is built and dry-run-proven, and
only its deploy half is still OWNER-gated.

The correction was applied to `live_risk_freeze.json` as a metadata-only edit;
the captured baseline was proven byte-identical before and after
(`sha256(baseline)` unchanged), and `risk_freeze.py verify` still reports
`held=true`, `drift=[]`. Nothing about what is frozen changed — only the
description of what would unfreeze it.

The general lesson is the one already in the operating rules: check "is this
already done?" before recording something as open. I recorded a condition as
uncommissioned without querying the router for it first.
