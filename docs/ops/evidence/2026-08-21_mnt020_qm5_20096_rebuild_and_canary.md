# MNT-020 — QM5_20096 identity-bound rebuild + one governed Q02 canary

**Task:** router `c010ccb7` (MNT-020 runtime proof)

**OWNER authorization:** `OWNER-DEC-MNT020-RECOMPILE` / `OWNER-DEC-MNT006-CANARY`
(written 2026-08-21, recorded in `owner_decisions.json` + vault archive). The
previously-ROT recompile of QM5_20096 and the bounded sequential canary are APPROVED.
Nothing else in the cohort was touched; no deploy; no T_Live/AutoTrading action.

**Measured/executed:** 2026-08-21 ~14:17-14:18 UTC on `agents/board-advisor`.

**EA:** `QM5_20096_ha-stoch-h4-swing` (ea_id 20096).

**Source repair provenance:** commit `b4745f5b2a00bd4eae66df7c9be23adcd5a40d74`
("fix: prime indicator warmup before readiness gates"). Repair evidence:
`docs/ops/evidence/2026-08-21_mnt020_barscalculated_first_recovery.md`.

## 1. Preflight (all confirmed before compile)

- Working-tree MQ5 SHA-256 =
  `052f50a55e71f258e43861571c6a8fd7d7324cbe83ee5d3498e3889536e348f7`
  — matches the repaired source named in the repair doc.
- Canonical (stale) EX5 SHA-256 before rebuild =
  `a343d30a5d70d5dc705f5dfc79450bd70f7fa7a264b124cd4ce68bbe3aa7a3e5`
  — the expected pre-rebuild binary.
- Magic registry rows for 20096 present + `active` in
  `framework/registry/magic_numbers.csv` (magic = ea_id*10000+slot):
  - slot 0 GBPUSD.DWX → 200960000
  - slot 1 EURAUD.DWX → 200960001
  - slot 2 USDCHF.DWX → 200960002  (anchor pair)
  - slot 3 EURCAD.DWX → 200960003
- ea_id 20096 is `active` in `framework/registry/ea_id_registry.csv` and is baked
  into `framework/include/QM/QM_MagicResolver.mqh` (required by the compile gate).
- News calendar current: `D:\QM\data\news_calendar\forex_factory_calendar_clean.csv`
  and `news_calendar_2015_2025.csv` both dated 2026-08-21.

## 2. Rebuild (single EA only, serial, canonical path)

Command (the canonical scoped single-EA compile wrapper over
`framework/scripts/compile_one.ps1` → MetaEditor CLI):

```
python tools/strategy_farm/compile_ea.py --ea-id 20096 --force --json
```

Result:

```
verdict = COMPILED  ("fresh build, 0 warnings")
compile_one_exit_code = 0 ; errors = 0 ; warnings = 0
symbol_scope_verdict = SINGLE_SYMBOL_OK
ex5_size_bytes = 407344
```

Compile log tail
(`framework/build/compile/20260821_141659/QM5_20096_ha-stoch-h4-swing.compile.log`):

```
Result: 0 errors, 0 warnings, 6048 ms elapsed, cpu='X64 Regular'
```

**EX5 SHA-256 before → after:**

| | SHA-256 |
|---|---|
| before (stale) | `a343d30a5d70d5dc705f5dfc79450bd70f7fa7a264b124cd4ce68bbe3aa7a3e5` |
| after (rebuilt) | `531e8e75094cc5756de7326d0efdb6d51ad0578f10b7f3fb22832ce8cd8dc3a9` |

The canonical EX5 hash **changed**, which is the required visible proof that the
identity-bound rebuild from the repaired source actually happened. MQ5 SHA-256 is
unchanged at `052f50a5…` (source was already committed in `b4745f5b2`).

## 3. Setfile integrity check (scoped by EALabel — never unscoped)

```
framework\scripts\build_check.ps1 -EALabel QM5_20096_ha-stoch-h4-swing -SkipCompile
```

- `build_check.result=PASS`, `failures=0`, `warnings=2`.
- Report: `D:\QM\reports\framework\21\build_check_20260821_141822.json`.
- The 2 warnings are benign card-of-record undecidables
  (`EA_CARD_LOSS_LIMIT_UNDECIDABLE`, `EA_BROKER_TIME_WINDOW_UNDECIDABLE`) — no
  setfile-integrity failure.
- Scope: only QM5_20096's 4 setfiles under
  `framework/EAs/QM5_20096_ha-stoch-h4-swing/sets/` were touched. The check only
  re-stamps the `; build_hash:` header line to bind each setfile to the new binary;
  all other header keys and body inputs are preserved. `-SkipCompile` preserved the
  exact rebuilt binary verified in step 2.
- USDCHF.DWX (anchor) setfile after the check: `environment: backtest`,
  `risk_mode: FIXED`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, all `strategy_*` inputs
  intact; `build_hash` restamped `64cd0317… → dcb8c45d…`. This EA's setfiles carry no
  seed/news/friday inputs (not part of its input surface), so there is nothing of that
  class to lose; the header/risk/strategy surface is fully preserved.

## 4. One governed append-only Q02 canary

Anchor row (from the repair doc): `41a774ad-2429-42de-8714-52822c225513` —
QM5_20096 / USDCHF.DWX / H4, terminal `done` / verdict `ZERO_TRADES` /
`MIN_TRADES_NOT_MET`, unclaimed, canonical setfile path.

Command:

```
python tools/strategy_farm/farmctl.py enqueue-backtest \
  --ea QM5_20096 --phase Q02 \
  --from-work-item-id 41a774ad-2429-42de-8714-52822c225513 \
  --append-only-rerun-of 41a774ad-2429-42de-8714-52822c225513 \
  --rerun-reason "MNT-020 runtime proof canary … OWNER-DEC-MNT020-RECOMPILE approved 2026-08-21 …" \
  --expected-current-ex5-sha256 531e8e75094cc5756de7326d0efdb6d51ad0578f10b7f3fb22832ce8cd8dc3a9
```

The exact-row Q02 rerun path (`_enqueue_q02_append_only_exact_row_rerun`) requires
`--from-work-item-id == --append-only-rerun-of`, and for a stale-economic
`ZERO_TRADES` source it authenticates against the **current repo EX5** via
`--expected-current-ex5-sha256` (verified equal to the freshly rebuilt
`531e8e75…`). Result:

```
enqueued = true
created work_item id = 256846e2-edce-4354-a346-0a428dafcc1b
  rerun_of_work_item_id = 41a774ad-2429-42de-8714-52822c225513
  symbol = USDCHF.DWX
  setfile = …/QM5_20096_ha-stoch-h4-swing_USDCHF.DWX_H4_backtest.set
```

**Append-only confirmed (read-only DB check):**

| Row | status | verdict |
|---|---|---|
| NEW canary `256846e2-…` | `pending` | `null` |
| OLD anchor `41a774ad-…` | `done` | `ZERO_TRADES` (untouched) |

Exactly one new work item was created. The historical row remains immutable
evidence. The factory pump/dispatch-tick will claim the pending row; the verdict
arrives via the pipeline (not awaited here).

## 5. Runtime-proof acceptance criterion (for whoever adjudicates the canary)

Per the repair doc's continuation contract, the canary report's
`execution_identity.expert_binary.sha256` must equal the new canonical EX5 hash
`531e8e75094cc5756de7326d0efdb6d51ad0578f10b7f3fb22832ce8cd8dc3a9`. Accept trades
(then normal Q-only adjudication) or bounded `SETUP_DATA_MISSING` / gate evidence;
zero trades alone is never PASS. Cohort fanout stays gated on the MNT-038 canary
contract — this run does not release it.

## Guardrails honored

No T_Live or live-account action; no AutoTrading toggle; no terminal64 /
factory / scheduled-task start-stop; no bulk build (single `--ea-id 20096`); no
unscoped setfile tool; magic-registry order-of-operations respected (rows +
resolver already present and verified before compile); DB written only via
`farmctl` CLI; reads via read-only SQLite with `busy_timeout=5000`; no git
commit/add (left for the orchestrator). Working-tree changes: the 4 QM5_20096
setfiles (build_hash restamp) and the rebuilt `.ex5`.

## Codex review addendum: binary omitted from commit, canary not yet valid

Post-commit review found that commit `334e3199d` included the four restamped
setfiles and this evidence document but omitted the rebuilt EX5. The canonical
tracked binary had therefore returned to stale SHA-256 `a343d30a...`, while the
pending canary `256846e2-edce-4354-a346-0a428dafcc1b` remained bound to the
uncommitted `531e8e75...` bytes. That is an execution-identity mismatch and the
runtime acceptance claim above is not yet satisfied.

Codex repeated the OWNER-authorized, single-EA compile through `compile_ea.py`:
0 errors, 0 warnings, `SINGLE_SYMBOL_OK`. The exact rebuilt binary now has
SHA-256 `4a60bfcdb...` (the included resolver changed after the first compile,
so a byte-identical `531e8e75...` reproduction is not expected). Scoped
`build_check.ps1 -EALabel QM5_20096_ha-stoch-h4-swing -SkipCompile` remains
PASS with the same two undecidable-card warnings and no failure.

The pending canary still expects `531e8e75...`; it was not claimed or rewritten
in this review. A governed successor/rebinding step must preserve the stale
pending row as evidence and bind the runnable successor to canonical EX5
`4a60bfcdb...`. Until that happens and a terminal result lands, the correct
task verdict is `DEFER_IDENTITY_MISMATCH`, not PASS and not a strategy verdict.
