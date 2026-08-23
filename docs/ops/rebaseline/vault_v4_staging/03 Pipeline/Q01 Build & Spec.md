# Q01 — Build & Spec

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q01 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q01 (Build & Spec) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q00 Research Intake]] · → [[Q02 Baseline Screening]] |

**Herkunft:** v4 Q01 = v3 Q01 (Build & Spec), ID und Kriterien unverändert (ROT).

---

**Gate Owner:** Codex (build) + Pipeline-Op (smoke verification)
**Trigger:** Q00 APPROVED Strategy Card
**Spec version:** 2026-05-23 (post-rewrite)

---

## Purpose

Q01 ensures an EA is technically correct AND its mechanical spec is fully documented before any compute is invested in Q02 backtests.

Two parallel deliverables:
1. **`.ex5` binary** — compiles, runs, produces at least one trade on smoke.
2. **Spec doc** — the prose-and-table description that a human (or future agent) needs to understand what the EA actually does and what behaviour to expect.

A Q01 PASS without the spec doc is incomplete; a spec doc without the `.ex5` is incomplete.

---

## Gate Criteria (all must PASS)

| Criterion | Check |
|---|---|
| `.ex5` exists | Physically on disk in `framework/EAs/QM5_<NNNN>_<slug>/QM5_<NNNN>_<slug>.ex5` |
| Compiles without errors | No MQL5 compile error (warnings logged but acceptable) |
| **Uses V5 EA framework** | EA imports from `framework/V5_FRAMEWORK_DESIGN.md` canonical template — risk-mode plumbing, magic-number registration, news-mode hook, RISK_FIXED/RISK_PERCENT switch all provided by framework. **No one-off `.mq5` written from scratch.** |
| Smoke ≥1 trade | `run_smoke.ps1` → ≥1 trade executed on EURUSD.DWX H1, 2022-01-01 to 2022-03-31 |
| No crash | MT5 terminal runs to completion, no unexpected abort |
| Magic number registered | Entry in `framework/registry/magic_numbers.csv` |
| No V4 legacy name | No `SM_XXX` prefix anywhere in EA, setfile, or card |
| **Spec doc complete** | `framework/EAs/QM5_<NNNN>_<slug>/SPEC.md` exists and covers all required sections (see below) |

---

## Required Spec Doc Sections

`framework/EAs/QM5_<NNNN>_<slug>/SPEC.md` must contain:

1. **Strategy logic** — what signal does the EA trade? Plain prose, no jargon. Include the formula or rule that decides entry/exit.
2. **Parameters** — table of every input parameter with default value, range, and meaning.
3. **Symbol universe** — which `.DWX` symbols this EA is designed for (FX majors, indices, metals, energy, etc.) and which it explicitly does NOT trade (and why).
4. **Timeframe** — base timeframe (M5/M15/H1/H4/D1) and any multi-timeframe references.
5. **Expected behaviour** — frequency (≈X trades/year/symbol), typical hold time, expected drawdown profile, regime preference (trend/mean-revert).
6. **Source citation** — the Q00-approved paper/source ID this EA is mechanised from.
7. **Risk model** — backtest = Fixed Risk $1,000 (HR); live = RISK_PERCENT (set in Q12 manifest).

This doc is what feeds the EA detail page's "Strategy Description" panel. Q01 PASS without it is a process violation.

---

## Workflow

1. Codex reads the Strategy Card: `artifacts/cards_approved/QM5_<NNNN>_<slug>.md` (must have `g0_status: APPROVED`).
2. Codex creates the directory: `framework/EAs/QM5_<NNNN>_<slug>/`
3. Codex reserves the magic number in registry.
4. Codex writes `.mq5` (mechanical translation of the card spec).
5. Codex compiles via MT5 IDE or DXC.
6. Codex writes `SPEC.md` covering all 7 required sections.
7. Pipeline-Op runs smoke verification:
   ```powershell
   pwsh C:/QM/repo/framework/scripts/run_smoke.ps1 `
     -EALabel QM5_<NNNN>_<slug> `
     -Symbol EURUSD.DWX `
     -Period H1
   ```
8. Pipeline-Op verifies SPEC.md is complete.
9. Commit: `feat(QM5_<NNNN>): Q01 build + spec for <slug>`

→ Skill: [[../05 Skills/qm-build-ea-from-card]]

---

## Smoke ≠ baseline equivalent

**Critical warning:** A positive smoke says nothing about strategy quality. The SM_261 incident showed portable smoke can diverge from real Q02 baseline by ~320×. Smoke verifies the EA *runs*, not that it *works*. Always run Q02 in full.

---

## Setfiles

After Q01 PASS, Pipeline-Op generates the setfiles for Q02:

```powershell
pwsh C:/QM/repo/framework/scripts/gen_setfile.ps1 `
  -EALabel QM5_<NNNN>_<slug> `
  -Period H1
```

Expected: one setfile per symbol in the EA's universe (typically 36-37 files in `framework/EAs/QM5_<NNNN>_<slug>/sets/`).

---

## FAIL handling

If Q01 fails:
- Compile error → Codex re-iterates against the card spec
- Smoke produces zero trades → check entry-condition logic; the card may overconstrain
- Magic-number collision → re-reserve and patch the EA
- SPEC.md missing/incomplete → Codex fills in the gaps before promotion
- Framework template not used → rewrite EA against `framework/V5_FRAMEWORK_DESIGN.md`

An EA cannot advance to Q02 with any Q01 criterion red.

---

## Re-Version Intake (Zero-Trade Recovery from Q02)

Q01 is also the **entry point for EA revisions** triggered by Q02 zero-trade outcomes.

When Q02 reports ALL-symbol zero-trades for an EA, the EA cycles back to Q01:
1. Codex inspects the EA's entry-condition code + Q02 evidence (every symbol produced 0 trades = condition is too restrictive somewhere).
2. Codex creates a new version: `QM5_<NNNN>_<slug>_v2` (or `_v3` if already a v2 came back, etc.).
3. New version typically: relaxed entry filters, widened parameter ranges, removed over-conservative thresholds.
4. New version goes through Q01 fresh (compile, smoke, SPEC.md updated with revision rationale).
5. On Q01 PASS, the `_vN` EA enters Q02.

Loop continues until either:
- The EA finally trades → normal pipeline flow from Q02 onward
- We genuinely exhaust ideas for why it won't trade → Codex documents in lessons-learned, EA closed as terminal FAIL

**Versioning convention:** `_v2`, `_v3`, `_v4`, ... are independent EAs with their own work_items, magic numbers, and spec docs. They are tracked as separate EA-IDs in the registry. The lineage (`_v1 → _v2 → _v3`) is captured in the SPEC.md's revision history.
