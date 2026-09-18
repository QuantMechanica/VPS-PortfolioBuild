# GAPS — what is not verified, and what needs code

Effort estimates are for the Codex lane unless stated. "Blocking" = the recomposition
cannot execute without it.

---

## G1 — `demo_install.py` is hard-bound to the 2026-09-06 run (BLOCKING, ~3-4 h)

`tools/strategy_farm/ftmo/demo_install.py` installs exactly one roster: the one staged on
2026-09-06. Every binding that must be generalised:

| line / constant | current value | why it blocks |
|---|---|---|
| `TASK_ID` | `"35eac0e9-8568-4114-b68f-45258ad7189b"` | `require_task()` refuses with `live_task_authority_missing` unless that specific row is `("codex","IN_PROGRESS")`. It is not, and re-opening a closed 2026-09-06 task to satisfy a 2026-09-18 install would falsify the evidence trail. |
| `EVIDENCE` / `SETS` | `…\2026-09-06_ftmo_demo_install` | reads the old manifest and the old 8 presets |
| `RECEIPT` | same folder | would overwrite the 2026-09-06 receipt |
| `COLLECTOR_PRESET` contract | `InpOutputDir = QM\ftmo_trial\2026-09-06`, `InpTrialId = M13_OPTION_B_20260906_1514536732` | exact-equality check → `collector_preset_contract_mismatch` |
| `validate_sources()` | `schema == "qm.ftmo-trial-setpath/v2"`, `risk_percent == 0.3125`, `len(candidates) == 8` | v2/0.3125/8 all hold for this package, but the constants are literals, not parameters |
| `backup_dir` | `…\QM_FTMO\_pre_m13_20260906` | a second install would hit `backup_collision` on any name already backed up there |
| `MQL5\Files\QM\ftmo_trial\2026-09-06` + `D:\QM\reports\ftmo_trial\2026-09-06` | hard-coded `mkdir` | new cycle telemetry would land in the old cycle's folder |

**Proposed shape:** `demo_install.py --roster <roster.json> --evidence-dir <dir> --task-id <id>`,
with the roster file carrying `label`, `cycle_id`, sleeves, and the expected collector
contract; `backup_dir` derived from `cycle_id`; everything else (atomic copy, hash
verification, `require_target`, the forbidden-target list, the receipt shape) kept **exactly
as-is** — those parts are correct and are the reason this tool is trustworthy.

Workaround if generalising is deferred: stage manually per `RUNBOOK.md` Phase 4 with
per-file `Get-FileHash` readbacks. Slower and unaudited by a tool, but it does not require
falsifying a task id. Must be signed off explicitly (gate 0.4).

---

## G2 — `trial_setpath` v2/v3 schema and rulepack disagreement (BLOCKING-ADJACENT, ~1 h)

Three artifacts disagree about the same contract:

| artifact | schema | rulepack |
|---|---|---|
| `trial_setpath.py` at HEAD | `qm.ftmo-trial-setpath/**v3**` | `FTMO_2S_100K_STANDARD_V2` (via `load_binding`) |
| `2026-09-06_ftmo_demo_install/sets/manifest.json` (what is installed) | `**v2**` | `FTMO_2S_100K_SWING_V2` |
| `demo_install.validate_sources()` | accepts **only v2** | — |

So `trial_setpath.generate()` at HEAD produces a manifest `demo_install.py` at HEAD
**refuses**. The tools cannot currently be used end-to-end together. This package's
`sets/manifest.json` is v2-shaped (as specified) with the Standard-account constraint block,
which is coherent but is a third variant. Someone has to declare which is canonical and
align the other two. The Swing→Standard rulepack change is the more substantive half: the
installed manifest cites Swing limits while the account is Standard.

---

## G3 — Governor allow-list and its pinned hash (BLOCKING, ~1-2 h)

`PACKAGE.md` §4 B2. Three files change together:

1. `framework/EAs/QM5_13206_ftmo-account-governor/sets/…_demo_active.set`
   (`allowed_magics_csv`, `governed_ea_ids_csv`, `governed_symbols_csv`, `challenge_id`,
   `challenge_start_utc`)
2. the matching `…_demo_bootstrap.set`
3. `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json` →
   `governor.active_preset_sha256` / `bootstrap_preset_sha256`

`trial_setpath.load_binding()` also re-checks each preset's *values* against
`expected_preset` (news mode, Friday close, expected login/server), so the edit must not
disturb those keys. If the shas are updated without the values staying consistent, every
future set derivation refuses.

**Open question, not answerable from the files:** is `governed_symbols_csv` a *coverage
gate* for governed flattening, or only a display/filter list? If it is a coverage gate, any
asymmetry between it and `allowed_magics_csv` is live-account exposure. The 2026-09-15
census raised this as open item 3 and it is still open. **Do not guess** — this decides
whether a symbol missing from that CSV means "not flattened at Friday close".

---

## G4 — `demo_cycle` is blind to timeframe and to dark sleeves (~2-3 h, quality)

Two independent blind spots in the material-change classifier, both of which bite this
recomposition:

1. **Timeframe is not observed.** `parse_chart_profile` reads `symbol`, expert `name`,
   `qm_magic_slot_offset` and `RISK_PERCENT`, but never `period_type`/`period_size`.
   `roster_hash` is over `(magic, ea_id, symbol)` only. Moving a sleeve from H1 to D1 is
   therefore **not** a material change and **not** an identity change — the ledger would
   claim the cycle is still representative. R2 puts 13213 on H1 and 11660 on H4 among five
   D1 sleeves; a wrong `period_size` is invisible. Fix: parse the period pair, add it to the
   row, add a `TIMEFRAME_CHANGED` classification, and decide explicitly whether it enters
   `roster_hash` (it should).
2. **"Attached" is not "trading".** The ledger's roster is derived from charts. A sleeve
   that initialises and never places an order counts as a full member of the book and its
   `risk_pct` counts toward `total_book_risk_pct = 2.5`. This is precisely how
   `QM5_20048` and `QM5_13054` are currently inflating the live book's nominal risk to 2.5 %
   when the realised book is smaller. Fix: cross-check the roster against observed fills
   (per-EA `TM_OPEN` or account deal history by magic) and surface a
   `sleeve_never_traded_since_cycle_start` flag once a sleeve has passed N eligible bars.

---

## G5 — Venue-symbol evidence is inferential for this account (~1 h to close properly)

All six venue names appear in **this account's** `bases\FTMO-Demo\ticks` and `history`
directories, and three are live on charts. That is strong. What is *missing* is a direct
`SymbolInfo` read on account `1514536732`:

* the `FTMO_TRIAL` alias venue is bound to account **`1513845506`**, and its own matching
  rule (`EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL`,
  `cross_venue_pooling_for_qualification=false`) says cross-account reuse is not valid;
* `symbols-1514536732.dat` is not plaintext on this build, so the probe's
  `probe_name_hits: []` is **not** evidence of absence (the probe says so itself);
* `USDJPY`, `XAUUSD` and `US100.cash` have never been attached on this account, so their
  only corroboration is the tick/history inventory.

**Proper close:** a read-only Market Watch add + native `SymbolInfo` capture on
`1514536732` recording, per symbol, `SYMBOL_TRADE_MODE`, contract size, tick value,
min/max/step lot, and the spread — which the cost model needs anyway. Until then the flags
in `PACKAGE.md` §1.2 are "verified by inventory", not "verified by the broker".

---

## G6 — `USDCAD` missing from the alias registry (~15 min, hygiene)

`framework/registry/execution_symbol_aliases_v1.json`'s `FTMO_TRIAL` venue lists 7 symbols
and `USDCAD` is not among them — although `QM5_11422` is trading `USDCAD` on the demo right
now under magic `114220004`. The registry row is missing, not the symbol. Add it (together
with whatever G5 captures), and note the account-id scope problem while there.

---

## G7 — the `NDX → US100` canonicalisation gap (ROT-class, not an engineering estimate)

`QM_MagicSymbolCanonical` (`framework/include/QM/QM_MagicResolver.mqh:134-141`) strips at
the first `.` and carries exactly one alias, `USOIL → XTIUSD`. There is no `NDX → US100`,
`GDAXI → GER40` or `WS30 → US30`. Consequently `QM_MagicResolveChecked`'s registry-symbol
guard (`:216-231`) fails closed for any index sleeve on an FTMO `*.cash` name, for any
binary that carries that guard.

Adding an alias is a **registry/identity decision, ROT-class, OWNER-only** — the 2026-09-15
census reached the same conclusion (its EXCLUDE reason C) and explicitly left it out of
scope. It is recorded here because it is the *second* reason `11660` cannot go on this book,
independent of the `Strategy_ExpectedSlot()` literal in B1. Both would have to be closed.

**Conflicting evidence, recorded rather than resolved:** `QM5_10440` (registry symbol
`NDX.DWX`, magic `104400003`) *did* run on a `US100.cash` chart on this terminal in
2026-08, with `SYMBOL_GUARD_INIT` → `INIT_OK ×20`, `ENTRY_ACCEPTED ×7`, `TM_OPEN ×7`
(`MQL5\Files\QM\QM5_10440_ea-10440.log`). The most likely explanation is that 10440's binary
predates the R-069 host-slot-conflation guard, so the guard simply was not in it — but that
is an inference, and confirming it needs the build provenance of that specific `.ex5`,
which this package could not establish (see G8). **Do not read 10440's log as proof that
index sleeves work on FTMO.**

---

## G8 — binary build provenance could not be established (~30 min, method gap)

The task forbids git commands, so the two dates the census reasoning turns on —
`4fb47bd3b5` (suffix-tolerant compare, 2026-09-06) and `dcaeca68f5`
(`strategy_calendar_symbol` input, 2026-09-06) — could not be checked against each binary's
actual build. What is known is file mtimes in `framework/EAs/`:

| EA | canonical `.ex5` mtime |
|---|---|
| 11422 | 2026-08-02 |
| 10145 | 2026-08-03 |
| 20266 | 2026-08-08 |
| 11660 | 2026-08-11 |
| 10706 | 2026-08-21 |
| 13213 | 2026-08-25 |
| 10700 | 2026-09-03 |
| 12710 | 2026-09-03 |

**All eight predate 2026-09-06.** So none of them carries either 2026-09-06 fix. For the
five literal-free sleeves that is fine (correction (i) of the 2026-09-15 census: pre-fix
binaries initialise correctly on bare broker names, spot-checked on T_Live). For `12710`
(built 2026-09-03) it matters most: it postdates the R-069 guard but predates the USOIL
alias fix, which is the exact window in which the registry-symbol guard fails closed on
`USOIL.cash`. Closing this properly means reading each binary's build stamp or its build
receipt, not its mtime.

---

## G9 — two sleeves' streams come from Q08 `FAIL_SOFT` rows (~evidence note)

`11660` and `12710` have no Q08 `PASS` row; their latest Q08 verdicts are `FAIL_SOFT`
(`0fd00da5…`, `bfda1943…`). Both nevertheless satisfy the W38 snapshot's qualification
predicate because it keys on the **terminal** gate (both are `Q14 = KEEP_INCUMBENT`). The
binaries match, so the streams are correctly attributed — but a quarter of the proposed
book rests on soft-failed Q08 evidence, and both of those sleeves are also B1-dark. Worth
OWNER's attention when weighing option 1 of B1 (drop the three): the three sleeves to drop
are also the three with the weakest gate evidence.

---

## G10 — first-passage numbers do not transfer to a repaired roster (~4-6 h if needed)

If B1 is resolved by dropping or substituting sleeves, `E2E 0.9223 / LCB 0.9059 /
median 288 bd` no longer describe the book. A re-run of
`tools/strategy_farm/ftmo/first_passage.py build` against the same frozen W38 snapshot,
same seed `20260915`, same 10,000 paths, is required before the roster goes to OWNER. The
scripts in `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\`
(`build_rosters.py`, `compare.py`) make this cheap to reproduce, and `stream_stats.json`
already holds the drift ranking needed to pick literal-free substitutes.

---

## G11 — the current live book is already partly dark (not this package's scope, but urgent)

Discovered while verifying B1. On the **current** demo, since 2026-09-11:

| sleeve | chart | `INIT_OK` | `TM_OPEN` | `ENTRY_ACCEPTED` |
|---|---|--:|--:|--:|
| `10706` GBPUSD | chart02 | 15 | 6 | 6 |
| `11422` USDCAD | chart04 | 5 | 2 | 2 |
| `13054` USOIL.cash | chart06 | 5 | **0** | **0** |
| `20048` USOIL.cash | chart07 | 5 | **0** | **0** |

`20048` has the same hard literal as the B1 sleeves
(`QM5_20048_wti-preholiday.mq5:143-147`, `_Symbol!="XTIUSD.DWX"`); `13054` uses a symbol
*input* default (`:47`) that the DXZ-derived preset leaves at `XTIUSD.DWX`. Either way the
current book's nominal 2.5 % over 8 sleeves overstates what is actually trading, and the
realised demo statistics — including the −10.26 % max-DD that holds readiness at
`NOT_READY` — were produced by a smaller book than the ledger reports. This deserves its own
ticket regardless of whether R2 proceeds.

---

## Summary of effort

| gap | blocking? | estimate |
|---|---|---|
| G1 generalise `demo_install.py` | yes | 3-4 h |
| G2 reconcile v2/v3 + Swing/Standard | yes (adjacent) | 1 h |
| G3 governor allow-list + pinned sha | yes | 1-2 h + an OWNER answer on `governed_symbols_csv` |
| G4 `demo_cycle` timeframe + dark-sleeve detection | no | 2-3 h |
| G5 native `SymbolInfo` capture on `1514536732` | no (strengthens) | 1 h + an OWNER-run read |
| G6 add `USDCAD` to the alias registry | no | 15 min |
| G7 `NDX → US100` canonicalisation | yes for 11660 | **ROT — OWNER decision, not an estimate** |
| G8 binary build provenance | no | 30 min |
| G9 Q08 `FAIL_SOFT` streams | no | evidence note |
| G10 re-run first-passage on a repaired roster | yes if B1 changes the roster | 4-6 h |
| G11 current book partly dark | separate ticket | 1 h to confirm + own remediation |
