# V5 Self-Review — 2026-04-26

Reviewer: Claude Board Advisor (this VPS instance)
Trigger: OWNER asked for honest critical review — what's strong, what's weak, what's missing, what's risky.
Scope: every V5 doc + design + decision in repo as of commit ~`f3e5a0c`.

This is a one-shot self-review, not a recurring artifact. Wave 0 + Codex phase-boundary audits replace it once Paperclip is online.

## TL;DR

**Strong:** pipeline spec, sub-gate spec, brand application, framework design (paper), V4-learnings now codified as V5 basis, project backlog with honest today's-owner labelling, decisions documented with alternatives.

**Weak:** nothing is implemented. Everything that produces evidence (TDM verification, framework code, calibration JSON, smoke EA) is still ahead of us. The risk of the "specced everything, ran nothing" trap is real.

**Risky:** Drive ↔ git architectural conflict (V4 mass-delete root cause) is not mitigated for VPS yet. Same architecture, same risk if Wave 0 commits concurrently before PC1-00 closes.

## What's Strong

### Pipeline + sub-gate
- 15-phase V2.1 spine sourced from laptop `pipeline-v2-1-detailed.md`, mirrored as `PIPELINE_PHASE_SPEC.md`
- Sub-gate parameters reconstructed honestly from surviving evidence (`PIPELINE_V5_SUB_GATE_SPEC.md`); every default flagged as provisional with named recalibration triggers
- V4-learnings codified into Open Items so the failure modes V5 inherits are visible (lane drift, waiver creep, P5 trade-count guard, etc.)
- News-Compliance Hybrid A+C recommendation is concrete (P8 expands modes, P9 admits per deploy-target) — TBD only on first-wave targets

### Framework design
- Single shared library principle (closes V4 root cause: `Company/Include` was absent)
- 4-module Modularity pattern (No-Trade / Entry / Management / Close) — every V5 EA structurally identical at framework boundary
- Friday Close, BT-Fixed/Live-Percent risk convention (ENV-enforced), gridding 1%-cap, ML ban — all V4 patterns now in code-spec, not just prompt-rule
- Magic registry with hash-baked-into-binary closes V4 magic-collision class
- Per-EA chart UI specced with brand-conformant tiles
- Implementation order is a numbered 25-step Codex playbook with no ambiguity

### Brand
- Hard rules from Brand Book carried 1:1 (dark mode, Inter + Source Code Pro, Emerald accent, "I" voice)
- MT5-applicable color tokens (BGR ints, Windows-resident font names) — code can consume
- `brand_tokens.json` is single-source-of-truth for all surfaces

### Process / governance
- `PROJECT_BACKLOG.md` reads as "what can OWNER do today?" not "what should Paperclip do eventually?"
- Honest "today's actor" labelling: most Paperclip-owned tasks marked blocked
- Specification Density Principle codified: pre-spec the boundary, leave interior for Wave 0+
- 9 ADRs in `decisions/` cover every major call with alternatives considered
- V4 lessons archive (22 entries KEPT/CHANGED/DISCARDED) is repo-resident
- Mass-delete incident + file-deletion policy are repo-resident

## What's Weak

### Implementation deficit
**Nothing in the framework runs yet.** 25-step implementation order is theory until Codex (post-Phase-1 hire) produces the first compilable EA + smoke run. Risk: design assumptions (4-module composition, ENV-mode enforcement, ChartUI layout, log-line schema) survive only paper review until that point.

### Missing primary evidence
- Custom Tick Data DST verification: not run
- VPS slippage / latency calibration JSON: not measured
- T1-T5 + T6 isolation proof: not produced
- First V5 EA distribution: does not exist
- First sub-gate calibration pass: blocked on above

### Doc/code drift risk reintroduced
`framework/V5_FRAMEWORK_DESIGN.md` references PowerShell + MQL5 files that don't exist (`sync_brand_tokens.ps1`, `compile_one.ps1`, `build_check.ps1`, `run_smoke.ps1`, `brand_report.ps1`, `validate_setfile.ps1`, `rotate_logs.ps1`, every `QM_*.mqh`). This is the exact V4 failure mode where the V2.1 runner guide referenced scripts that did not exist. Mitigation needed: badge every script ref `[SPEC ONLY]` until built, and treat the framework as half-complete until smoke regression passes.

### Notion ↔ Repo drift
- Notion `V5 Pipeline Design` is superseded (banner) but not rewritten
- Notion `Phase 0 Execution Board` knows P0-01..P0-21; repo has P0-01..P0-31
- Notion `Pipeline Autonomy Model` still old text; repo has rewritten
Documentation-KM (Wave 0) owns reconciliation. Until then, repo wins per CLAUDE.md source order — but that means anyone reading Notion gets stale state.

### Process registry imported byte-identical
The 12 process docs in `processes/` are V4 verbatim. Wave 0 has not reviewed them for V5-boundary updates (some reference QUAA tickets, old paths). Codex audit at first phase boundary will catch most, but until then, process docs may instruct Wave 0 in V4-isms.

### V5 prompts not in repo
`paperclip-prompts/` folder doesn't exist yet. PC1-03 names this as the migration step but no V5-revised prompts have been authored. Reference exists in Notion (e.g. CTO Agent System Prompt is well-formed and V5-aligned) — needs author pass + repo migration.

## What's Missing

### Phase-0 gate items not done
- P0-04 / P0-05 MT5 install + isolation proof
- P0-06 DarwinexZero MT5 access confirmation
- P0-13 T6 deploy manifest schema dry-run
- P0-14 EP01 production
- P0-15 Public expense log v0
- P0-16 dashboard snapshot schema artifact (only specced, not built)
- P0-21 Tick Data Manager DST verification (the active task)

### Operational artifacts that Wave 0 will need on Day 1
- Paperclip install on `C:\QM\paperclip\` (folder empty by design, but installer not run)
- Browser / control plane health check at `http://localhost:3100`
- 4 Wave-0 prompts in `paperclip-prompts/`
- Strategy Card template
- VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json
- FTMO / 5ers blackout-window definitions
- `framework/include/news_rules/{ftmo,5ers}.mqh`
- `framework/calibrations/`

### Secondary docs from V4 not yet migrated as basis
- `Company/Research/strategies/` — the 5 markdown specs migrated (P0-25), but the broader `Company/Research/` folder has more
- `Company/Status/CTO/current.md` — operational status (large file, V4-era)
- `Company/Roles/`, `Company/Reviews/` — empty on Drive but the convention is intact
- `Company/Archive/2026-04-02/` — possibly older plans worth scanning before Wave 0 starts

## What's Risky

### Architectural carry-over
**Drive ↔ git ↔ multi-agent concurrent commits** is the V4 mass-delete root cause and is NOT mitigated on VPS. PC1-00 is the new first task in Phase 1 to close this before Wave 0 starts writing. If Wave 0 starts writing concurrently and `.git/` is still in Drive sync surface, expect the same incident.

### Specification trap
Every doc-only commit feels like progress. Real progress = first compilable smoke EA + first DST verification CSV + first calibration JSON. Until those land, V5 has paper, not artifacts. Risk of spending more cycles on spec polish instead of moving to implementation.

### Wave 0 over-direction
The Specification Density Principle is in CLAUDE.md and the backlog, but it's a habit not a hard rule. When Wave 0 hires happen, the temptation to pre-design every Wave 0 issue into oblivion is real. CEO-Claude needs room to make CEO decisions.

### Live-trading framing creep
`PHASE_FINAL_FOUNDER_COMMS.md` is frozen, `LIVE_T6_AUTOMATION_RUNBOOK.md` is detailed. Both are written for Phase 5+ but exist now. Risk of someone (human or agent) reading them as authorization for early live action. CLAUDE.md hard rules cover this but the docs themselves don't carry "PHASE-GATED" banners.

### YouTube content cadence
EP01 is part of Phase 0 acceptance gate. Without content discipline (one episode per real milestone, not aspirational), the build-in-public narrative drifts.

## Honest Self-Assessment Of This Review

This review is by the same Claude that produced the work. That's a known weakness: confirmation bias toward "the design is good, only implementation is missing". A second-opinion pass — by Codex at first phase boundary, by OWNER, or by an external Claude session — would catch things this review misses.

Specific unknowns where I cannot self-judge:
- Whether the Friday Close default time (`21:00 broker time`) is right for Darwinex NY-Close — should be validated against actual close behavior
- Whether the news-CSV-loaded-at-OnInit pattern scales to 50+ EAs running concurrently on T1-T5 (file-handle exhaustion risk)
- Whether the per-EA log files (one per EA per terminal) generate so many small writes that Drive sync chokes
- Whether the `magic = ea_id * 10000 + symbol_slot` formula stays inside MT5 32-bit signed `int` for ea_id ranges 9000-9999 (`9999 * 10000 = 99990000` + slot 9999 = `99999999`, fits — but worth a `BUILD_CHECK_MAGIC_BOUNDS` test)
- Whether `OnTimer` 1s for ChartUI refresh is too aggressive when 5+ EAs share a chart on one terminal
- Whether the 4-module Modularity pattern composes cleanly when an EA wants intra-tick state shared between Trade Management and Trade Close

These need empirical validation, not more spec work.

## Recommended Next Concrete Actions (in order)

1. **OWNER + Board Advisor: P0-21 Custom Tick Data verification** on T1. Produce evidence CSV + screenshots. This is the **active task per OWNER 2026-04-26**.
2. **OWNER decision on PC1-00:** how do we exclude `.git/` from Drive sync, and what mutex pattern do we use across agents? This must close before Wave 0 starts.
3. **OWNER + Board Advisor: VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json** measurement on Darwinex demo on T1 (in parallel with #1, doesn't block on TDM verification because it measures live tick stream not historical ticks)
4. **OWNER + Board Advisor: T1-T5 + T6 install + isolation proof** (P0-04 / P0-05). Once TDM is verified, install procedure can run.
5. **OWNER decision: PHASE 1 START** — install Paperclip, hire Wave 0, hand the 25-step framework spec to CTO-Codex.
6. **Codex (Wave 0): implement framework per `V5_FRAMEWORK_DESIGN.md` § Implementation Order.**
7. **Quality-Tech (Wave 2): first sub-gate calibration pass once first V5 EA produces distributions.**

After step 6, this self-review should be re-run by Codex against the implemented framework. After step 7, Quality-Tech should produce the first sub-gate calibration ADR.

## Status Of This Review

| Question | Answer |
|---|---|
| Is V5 ready for Wave 0 hiring? | Almost — PC1-00 (Drive/git mitigation) needs to close first, plus P0-21 needs to clear |
| Is V5 ready for Phase 2 framework implementation? | Spec is ready; Codex agent doesn't exist yet |
| Is V5 ready for first V5 EA build? | No — framework must compile first |
| Is V5 ready for first live deployment? | No — framework, basket, manifest, T6 isolation all not proven |
| Are the V4 learnings carried as basis? | Yes (post 2026-04-26 corrections) |
| Are the doc-vs-code drift risks understood? | Yes, codified in Open Items |
| Is the brand applied consistently in spec? | Yes; needs implementation to verify |

End of self-review. Re-run after first concrete artifact (TDM evidence CSV).
