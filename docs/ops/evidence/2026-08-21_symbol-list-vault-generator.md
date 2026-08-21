# Evidence — Symbol List vault page is now generated from the matrix CSV

Task: QM-TODO-20260821-203 (router task 0b68a0de)
Date: 2026-08-21

## Problem measured

The vault page `06 Infrastructure/Symbol List.md` was hand-maintained and drifted
from the canonical source `framework/registry/dwx_symbol_matrix.csv`:

- Matrix CSV: **37** active `.DWX` symbols (rows 2–38; SP500.DWX present since
  2026-05-16, live-routing confirmed 2026-07-16).
- Old page prose already claimed 37 in one place but the drift class was real and
  had gone unnoticed ~3.5 months.
- **Additional finding (out of task scope, flagged for follow-up):**
  `00 Governance/company_manifest.json` `symbols` block is ALSO drifted —
  `count=36`, `active_len=36`, **SP500.DWX absent**. Measured via:
  `python -c "import json;d=json.load(open('company_manifest.json'));..."` →
  `count 36 / active_len 36 / SP500 in active False`. The vault lint's
  `check_symbols` only asserts `count == len(active)` (36==36, passes) and does
  NOT cross-check the page, so this drift is invisible to the current lint. I did
  not edit the manifest (separate hand-maintained artifact, not in this task).

## What changed and why

New deterministic generator so the page can never silently diverge again:

- `tools/vault/gen_symbol_list_page.py` — derives the entire symbol inventory
  (counts, majors/crosses split, indices, commodities) from the matrix CSV.
  - Forex majors = forex pairs whose stem contains `USD`; crosses = the rest —
    both taken in CSV row order (deterministic).
  - Indices / commodities from the `asset_class` column; display names
    (DAX / Nasdaq 100 / S&P 500 / FTSE 100 / Dow Jones / Gold / Silber /
    WTI Crude / Natural Gas) are pinned in code.
  - The SP500 routing note is rendered from the CSV `live_order_*` /
    `routing_evidence_ref` columns when `live_order_status =
    ORDER_ROUTABLE_CONFIRMED`.
  - Provenance = **sha256 of the CSV bytes**, embedded with a
    `GENERATED — do not hand-edit; regenerate via tools/vault/gen_symbol_list_page.py`
    marker. **No wall-clock timestamps** in the output (the old `**Stand:** <date>`
    line was removed). Determinism: same CSV bytes → byte-identical page.
  - CLI: `--write` (rewrite page), `--check` (non-zero on drift), `--stdout`,
    `--matrix` / `--page` overrides. Writes bytes with LF newlines (no CRLF
    translation on Windows).
- `tools/vault/tests/test_gen_symbol_list_page.py` — 8 tests incl. the drift
  guard (`test_vault_page_matches_matrix`): committed page must equal the page
  generated from the committed CSV; a matrix change fails it until `--write`.
- `tools/strategy_farm/heartbeat_snapshot.py` now invokes the generator on every
  existing `QM_Orchestrator_Heartbeat_15min` run. That task runs as `qm-admin`
  (the account with the Google Drive mount), records `symbol_list_mirror` in the
  durable heartbeat state, and keeps the page current without a manual step.
- Rewrote `06 Infrastructure/Symbol List.md` via `--write` (LF, no BOM,
  now shows 37 with SP500).

Current CSV sha256: `e7844d9a18db8723db2b31d839581d0cc348140cf883200524a1af26d465821d`

## Verification / test output

```
$ python -m pytest tools/vault/tests/test_gen_symbol_list_page.py -x -q
........                                                                 [100%]
8 passed in 0.10s
```

Determinism + drift-guard proof (in-memory, no real files touched):

```
page changes on matrix edit: True
count line new: ## Aktive Symbole (38)
vault matches OLD-render but NOT mutated: True True
```

Byte-hygiene of the rewritten page: `grep -c $'\r'` → 0 (LF only), first bytes
`23 20 4b 61 ...` (`# Kanoni`, no BOM).

Idempotent write: two consecutive `--check` runs both print
`CHECK PASS: vault page matches matrix`.

Final scheduled-path verification in this orchestration cycle:

```
QM_Orchestrator_Heartbeat_15min LastTaskResult = 0
heartbeat_state.json vault_mirror = ok
heartbeat_state.json symbol_list_mirror = ok
```

## Vault lint

```
$ python "00 Governance/lint_company_reference.py"
Company Reference lint: FAIL
- old gate token in active page: 08 Current State/Heartbeat.md
- old gate token in active page: 12 ToDo/AI ToDos/Codex.md
```

The **Symbol List page is clean** — it is NOT in the error list
(`... | grep -i "Symbol List"` → no match). The two failures are in
`08 Current State/Heartbeat.md` and `12 ToDo/AI ToDos/Codex.md`, operational
pages I never touched; they carry pre-existing `P`-series gate tokens. A
same-file edit cannot inject a token into a different file, so those failures
pre-date this change. They are pre-existing vault debt, flagged for a separate
task, and are outside this task's scope.

## Rollback

- Restore the page: `git checkout -- "<vault>/06 Infrastructure/Symbol List.md"`
  is not applicable (the vault is on G:, outside the repo). To revert the page,
  no committed baseline exists in-repo; regenerate is the forward fix. If a
  hand-restore is needed, the previous page content is preserved in this
  conversation transcript / git history of prior edits.
- Remove the generator + test: `git rm tools/vault/gen_symbol_list_page.py
  tools/vault/tests/test_gen_symbol_list_page.py` (repo files; orchestrator
  commits/reverts with pathspecs).

## Recommended follow-up (not done here)

Commission a task to make `company_manifest.json` `symbols` also generated from
the same matrix CSV (currently 36/no-SP500), and extend the lint's
`check_symbols` to cross-check the manifest count against the matrix so this
drift class is caught centrally.
