# QM5_9936: missing qm_news_calendar_* provenance inputs — root cause + governed rebuild (2026-08-24)

Router task `3c4f876a-cb07-4bbe-bbd4-9b0a8c3b275f` ("QM5_9936: fehlende
qm_news_calendar_*-Provenienz-Inputs — Rebuild-Pfad klaeren"), commissioned off
`docs/ops/evidence/2026-08-24_q10_news_run_smoke_terminal_reservation_race.md`
§4 (row `73b21148-65be-4aad-a2dd-fb7c2f22e9bc`, EA `QM5_9936_ff-range-breakout-gmt3-h1`,
USDJPY.DWX): 8/8 Q10_NEWS cells rejected on `MT5 report effective input
qm_news_calendar_bundle_id mismatch` — the compiled EA's tester report never
contains the three provenance-echo inputs at all.

## 1. Root cause: Include-Revision, not Input-Truncation

`QM5_9936_ff-range-breakout-gmt3-h1.mq5` (`framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/`)
declares its own news inputs directly (`qm_news_temporal`, `qm_news_compliance`,
`qm_news_stale_max_hours`, `qm_news_min_impact`, `qm_news_mode_legacy` —
lines 63-69) and includes `QM/QM_Common.mqh`, which in turn `#include`s
`QM_NewsFilter.mqh` (`QM_Common.mqh:12`). The three provenance inputs
(`qm_news_calendar_bundle_id`, `qm_news_calendar_expected_sha256`,
`qm_news_calendar_common_relative_path`) are declared as `input string` **inside**
`QM_NewsFilter.mqh` itself (lines 73-75) — added by commit `f0102fbcf`
("fix(q09): bind sealed calendar inputs in tester"), **2026-08-03**.

`QM5_9936`'s compiled `.ex5` was last content-changed (git blob hash diff,
not just mtime) by commit `2883001bc`, **2026-07-29** — 5 days *before* the
provenance-input include change. Confirmed the working-tree/HEAD `.ex5` blob
(`869289cae041ac80b496414308e5d823e945a4df`) is exactly that 2026-07-29
compile — no further recompile has happened since. The `.mq5` source's own
last content commit is 2026-06-11 (initial build); its later "2026-07-27"
touches were recompiles-only (pump auto-commits), also pre-dating the
2026-08-03 include change.

Cross-check against the actual failing report
(`D:/QM/reports/work_items/73b21148-.../q09_contract_v3/cells/control_off__m0__c0__s17/runs/selection/QM5_9936/20260824_053803/raw/run_01/report.htm`):
the Inputs table carries `qm_news_temporal`, `qm_news_compliance`,
`qm_news_stale_max_hours`, `qm_news_min_impact`, `qm_news_mode_legacy` (all
EA-owned inputs) but **none** of the three `qm_news_calendar_*` inputs — i.e.
the compiled binary never declared them at all (a truncation theory would
imply the .set-file writer dropped keys the binary *does* declare; that is
not what's observed).

**Verdict: Include-Revision.** No source edit needed — the `.mq5`'s include
chain already resolves to the current `QM_NewsFilter.mqh` on disk; a plain
governed recompile is sufficient to pick up the three inputs.

## 2. Governed rebuild — action taken

Per constraint (compile only governed, EX5-guard active) and the 23.08.
identity rule (rebuilt EX5 = new identity from Q02 onward), the correct path
is the `enqueue-compile` / `release_compile_wave.py` COMPILE_EA queue, not a
manual recompile:

```
python tools/strategy_farm/farmctl.py enqueue-compile QM5_9936_ff-range-breakout-gmt3-h1
  -> work_item_id 300c007a-1d2e-4a62-bf32-5effa8d3ccd3, activation_hold=COMPILE_EA_WORKER_ROLLOUT_PENDING

python tools/strategy_farm/release_compile_wave.py --work-item-id 300c007a-1d2e-4a62-bf32-5effa8d3ccd3
  (dry-run: source SHA verified — actual == expected mq5_sha256 b6ceb97d...)

python tools/strategy_farm/release_compile_wave.py --work-item-id 300c007a-1d2e-4a62-bf32-5effa8d3ccd3 --apply \
  --release-note "claude-orchestrator 2026-08-24: governed recompile ... task 3c4f876a"
  -> applied=1, backup D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260824T203608Z_94536d07.sqlite
```

This is Stehende-Vollmacht **GRÜN** (operate an existing tool — the bounded
COMPILE_EA rollout releaser — with unchanged criteria; no gate threshold or
verdict logic touched; source-SHA-bound, EX5-guard enforced by the tool
itself).

As of this evidence doc, `compile-status QM5_9936_ff-range-breakout-gmt3-h1`
shows the hold released and the work item **pending** pickup by the resident
terminal COMPILE_EA worker (`terminal_worker.py`); it had not yet compiled by
the end of this orchestration pass (single-pass cycle, no sleep-loop wait).
**Follow-up verification** (next cycle or reviewer):

```
python tools/strategy_farm/farmctl.py compile-status QM5_9936_ff-range-breakout-gmt3-h1
```

Expect `compiled=true`, a fresh `ex5_sha256` different from
`869289cae041ac80b496414308e5d823e945a4df`, and — once any subsequent Q10_NEWS
cell runs against the new binary — the report Inputs table to carry all three
`qm_news_calendar_*` keys (report-echo confirmation is acceptance criterion 2
and cannot be produced before a tester run against the new binary exists).

## 3. Recommendation: row `73b21148` successor

Do **not** re-enqueue row `73b21148` (or any cell within it) until
`compile-status` confirms `compiled=true` with a new `ex5_sha256`. Per the
23.08. identity rule, the rebuilt EX5 is a **new identity from Q02** — the old
row stays as permanent evidence (append-only, Stehende-Vollmacht GRÜN
class: "re-enqueue rows without a verdict"), and a fresh Q09→Q10_NEWS run must
be planned against the new binary rather than treated as a same-identity
re-run of `73b21148`. Concretely, once the compile confirms:

1. Re-run/refresh Q02–Q09 gate evidence for the new `QM5_9936` build identity
   on `USDJPY.DWX` (the rebuilt binary is not automatically grandfathered on
   the old identity's Q02-Q09 PASS history).
2. Only then plan a fresh Q10_NEWS contract-v3 row for the new identity via
   `farmctl.py enqueue-backtest` (not `--append-only-rerun-of 73b21148`,
   since the identity itself changed — a wholly new work item, with
   `73b21148` cited as prior-identity context in the payload/rationale).
3. This is a normal build/pipeline follow-up, not a P0 — no immediate factory
   risk; queue it at ordinary priority once the compile lands.

## Evidence / source references

- `framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/QM5_9936_ff-range-breakout-gmt3-h1.mq5:63-69` (EA-owned news inputs)
- `framework/Include/QM/QM_Common.mqh:12` (`#include "QM_NewsFilter.mqh"`)
- `framework/Include/QM/QM_NewsFilter.mqh:73-75` (provenance input declarations, added by `f0102fbcf`, 2026-08-03)
- `git log`/`git rev-parse` on `framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/QM5_9936_ff-range-breakout-gmt3-h1.ex5` — last content change `2883001bc` (2026-07-29); HEAD blob `869289cae041ac80b496414308e5d823e945a4df`
- `D:/QM/reports/work_items/73b21148-65be-4aad-a2dd-fb7c2f22e9bc/q09_contract_v3/cells/control_off__m0__c0__s17/runs/selection/QM5_9936/20260824_053803/raw/run_01/report.htm` (Inputs table — calendar-provenance keys absent)
- `tools/strategy_farm/farmctl.py enqueue-compile` / `tools/strategy_farm/release_compile_wave.py` (governed COMPILE_EA queue + EX5-guard rollout releaser)
- Router task `3c4f876a-cb07-4bbe-bbd4-9b0a8c3b275f`; COMPILE_EA work item `300c007a-1d2e-4a62-bf32-5effa8d3ccd3`
- Predecessor: `docs/ops/evidence/2026-08-24_q10_news_run_smoke_terminal_reservation_race.md` §4
