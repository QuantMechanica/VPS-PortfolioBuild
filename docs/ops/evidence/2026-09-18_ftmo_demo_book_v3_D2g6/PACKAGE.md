# FTMO Demo Book v3 — roster D2g6 — deployment package

**Status: EXECUTABLE.** All six sleeves derive, `sets/` + `sets/manifest.json` exist and validate
6/6, `demo_install --dry-run` produces a clean 14-row copy plan, and the **only** refusal left is
`autotrading_must_be_disabled` — the installer refusing to stage into a hot terminal. It clears on a
clean shutdown of the FTMO demo terminal with AutoTrading off (that shutdown is what flushes
`[Experts] Enabled=0` into `config\common.ini`). See §7 and RUNBOOK step 3.

Two **non-blocking prerequisites** must land in the same reviewed commit as the governor rebind, or
step 6 of the RUNBOOK will fail closed — see GAPS **G1** (the launcher's contract verifier is pinned
to the incumbent 11-chart profile and `FTMO_ON.ps1` refuses to launch when it fails) and **G2**
(`ftmo_trial_pulse.EXPECTED_MAGICS` is still the incumbent eight). Neither is a defect in this
package; both are repo edits owed by ticket `57bfd3af`.

- Decision: `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`
- Receipt: `docs/ftmo/FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` (**Addendum 4**, 2026-09-18 ~04:30Z)
- Risk authority: `FABLE_DECISION_D2G_2026-09-18_DEPLOYABLE2`
- Cycle id: `FTMO_DEMO_BOOK_V3_D2G6_20260918` · trial id `M13_D2G6_20260918_1514536732`
- Book risk: **1.71875 %** (13213 @ 0.15625 %, five others @ 0.3125 %)
- Target terminal: `...\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850` (login 1514536732, FTMO-Demo)
- Package: `C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6`

**What changed against D2f.** D2f was blocked by 21505 (XAGUSD) and 13054 (USOIL.cash): stale Q10
seals plus `.ex5` binaries that still carry a hard `_Symbol == "<X>.DWX"` gate (D2f GAPS G1/G2,
ticket `57bfd3af`). Addendum 4 drops exactly those two. D2g6 is the remaining six — the same six
that D2f's `probe_six_sleeves/` already proved derive cleanly — so **every D2f blocker is removed by
roster construction, not by a workaround**.

Nothing in this package was installed, attached, started or toggled. No MT5 process was touched, no
chart profile written, no AutoTrading change, no SQLite write (all DB reads via `?mode=ro`), no write
outside this folder.

---

## 1. Roster (`roster.json`, schema `qm.ftmo-demo-roster/v1`)

Byte copy of `docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/roster_D2g.json`.
`trial_setpath.load_roster()` accepts it: 6 rows, no magic-formula violation, no magic or slot
collision, no `.DWX` venue name, all timeframes valid, every `risk_percent` inside the `0 < r <= 1`
dry-run cap. `roster_sha256 = 53a1387081ab6b6267afc785a242a8fbe1c9a338fcc71910493fe5b67b9a690b`.

| ea_id | ea_label | dxz | **FTMO venue** | TF | slot | magic | risk % |
|---|---|---|---|---|---|---|---|
| 13213 | QM5_13213_balke-gmt3-range-breakout | USDJPY | USDJPY | H1 | 0 | 132130000 | **0.15625** |
| 10706 | QM5_10706_tv-mon-ls | GBPUSD | GBPUSD | H1 | 1 | 107060001 | 0.3125 |
| 10700 | QM5_10700_tv-liq-break | XAUUSD | XAUUSD | H1 | 3 | 107000003 | 0.3125 |
| 11422 | QM5_11422_williams-18ma-outside-bar-entry-d1 | USDCAD | USDCAD | D1 | 4 | 114220004 | 0.3125 |
| 10403 | QM5_10403_et-turtle20x | XAUUSD | XAUUSD | D1 | 2 | 104030002 | 0.3125 |
| 41219 | QM5_41219_cum-rsi2-commodity-requal8 | XAUUSD | XAUUSD | D1 | 0 | 412190000 | 0.3125 |

Sum = **1.71875 %**. `dxz_symbol` is carried **bare** (no `.DWX`): `trial_setpath` appends
`FACTORY_SUFFIX` itself for the seal lookup. Every timeframe is the one parsed out of the EA's
canonical Q10-sealed backtest setfile name — `generate_from_roster` re-checks it and refuses on
`roster_timeframe_mismatch`.

Note: the roster's own `source` / `receipt_path` point at `FTMO_ALT_ROSTER_DEPLOYABLE2_2026-09-18.md`
(the study that produced D2g6). `authority.json` carries the decision receipt
`FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` (Addendum 4) as instructed; both files exist and both are cited
here on purpose — the study is where the number comes from, the chain is where the decision is.

### Magic registry cross-check — 6/6 PASS

Every magic exists in `framework/registry/magic_numbers.csv` with `status=active`, matching `ea_id`,
matching `symbol_slot`, and `symbol == <dxz>.DWX`. `magic == ea_id*10000 + slot` holds for all six.
Registry sha256 `6671944eb975e09b303fb4afd1cb40dc6e6b50d8111af48fbced020050851381`.

| magic | registry row | formula |
|---|---|---|
| 132130000 | active / 13213 / slot 0 / USDJPY.DWX | OK |
| 107060001 | active / 10706 / slot 1 / GBPUSD.DWX | OK |
| 107000003 | active / 10700 / slot 3 / XAUUSD.DWX | OK |
| 114220004 | active / 11422 / slot 4 / USDCAD.DWX | OK |
| 104030002 | active / 10403 / slot 2 / XAUUSD.DWX | OK |
| 412190000 | active / 41219 / slot 0 / XAUUSD.DWX | OK |

---

## 2. Venue symbol evidence — 4 symbols, all VERIFIED

Source: `docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/ftmo_symbol_probe.json` (account
1514536732, server FTMO-Demo) — presence in the terminal's own `bases\FTMO-Demo\ticks` and
`...\history` directories plus terminal-log occurrences. D2f's two unverifiable-by-gate symbols
(XAGUSD, USOIL.cash) leave with 21505 and 13054.

| venue symbol | ticks dir | history dir | log hits | alias registry (FTMO_TRIAL) | verdict |
|---|---|---|---|---|---|
| USDJPY | yes | yes | — | `USDJPY.DWX -> USDJPY` | **VERIFIED** |
| GBPUSD | yes | yes | — | `GBPUSD.DWX -> GBPUSD` | **VERIFIED** |
| XAUUSD | yes | yes | 776 | `XAUUSD.DWX -> XAUUSD` | **VERIFIED** |
| USDCAD | yes | yes | — | *absent* | **VERIFIED** (ticks + history) |

The roster path never consults the alias registry (the venue name is an explicit roster field), so the
registry's wrong `account_id` and its missing USDCAD row are hygiene, not a blocker — GAPS G5.

---

## 3. Binary identity — repo `.ex5` == Q10 seal == Q08 evidence

`bin/` ships the six canonical binaries. For each: sha256 of `framework/EAs/<label>/<label>.ex5`
equals `identities.ex5_sha256` in that EA's `Q10_NEWS / status=done / verdict=CONFIG_LOCKED` seal,
**and** that seal's `identities.q08_evidence_sha256` equals the sha256 of the Q08 `aggregate.json`
it names — so the deployed binary is the one the Q08 trade stream financed, not a later build.

| ea_id | `bin/` sha256 | = Q10 seal `ex5_sha256` | Q08 work item | Q08 `aggregate.json` == seal `q08_evidence_sha256` | in FTMO terminal now |
|---|---|---|---|---|---|
| 13213 | `8c99dea16fbf758a4b2da9f49a26db26bfe7fed3589f2066be5120314106a8f0` | **MATCH** | `048643ac…` | **MATCH** (`1cb10ef7…`) | not present (new) |
| 10706 | `eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb` | **MATCH** | `a2e1aba6…` | **MATCH** (`7c5015c8…`) | `6f290d49…` **MISMATCH** |
| 10700 | `5fbf2ba0048250041296deda0008ff6757f56dce27e39efead69f45838e5e6be` | **MATCH** | `ce371d25…` | **MATCH** (`25138ee6…`) | not present (new) |
| 11422 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | **MATCH** | `d3907c1a…` | **MATCH** (`be78ca20…`, gz) | same — match |
| 10403 | `f927f07f46579bbb9a1bdcfdb7caa9b246e9d7555935fbb878f7fc01afbf7ab3` | **MATCH** | `7fd4caf6…` | **MATCH** (`bb57935a…`) | not present (new) |
| 41219 | `e9670141e89249aff7df44a10a2402e2103aa4cecf8d0a35a8cd6d6babedf108` | **MATCH** | `800fd4f1…` | **MATCH** (`d78f3f3e…`) | not present (new) |

11422's Q08 aggregate is stored gzipped (`aggregate.json.gz`); the seal hash is over the
**decompressed** bytes and matches exactly.

`demo_install.validate_sources()` re-checks the repo-`.ex5`-vs-seal leg itself
(`sealed_binary_mismatch`) at install time, so this is enforced, not merely documented.

### Only one terminal binary is replaced: 10706

The terminal runs `6f290d49…`, which exists nowhere in the repo — the **2026-09-06 "codex alias"
rebuild** (its pre-alias predecessor in `Experts\QM_FTMO\_pre_codex_alias_20260906_2047Z\` *is* the
sealed `eaffda6f…`). `demo_install` plans `REPLACE` and restores the sealed binary.

This is safe, and the evidence is direct:

- **10706 has no symbol gate.** Its `.mq5` contains no `.DWX` string literal at all (the two textual
  occurrences are comments on lines 51 and 203), and the compiled `bin/QM5_10706_tv-mon-ls.ex5`
  contains **zero** `.DWX` byte sequences in either ASCII or UTF-16LE. It takes the chart symbol.
- **No bug fix is lost.** The terminal binary is dated 2026-09-06 22:42; the only newer source change
  (`2a7647ae9d`, BE-lock wrong-side-of-market guard, 2026-09-13) was **never compiled anywhere** —
  the repo `.ex5` last changed at `18d46c2bf6` (2026-08-21). Both binaries predate the fix equally.
  That the fix is uncompiled is a separate open item, carried as GAPS G6.

The same `.DWX`-literal scan is clean for all six binaries:

    QM5_10403_et-turtle20x.ex5                        utf16 .DWX: 0   ascii .DWX: 0
    QM5_10700_tv-liq-break.ex5                        utf16 .DWX: 0   ascii .DWX: 0
    QM5_10706_tv-mon-ls.ex5                           utf16 .DWX: 0   ascii .DWX: 0
    QM5_11422_williams-18ma-outside-bar-entry-d1.ex5  utf16 .DWX: 0   ascii .DWX: 0
    QM5_13213_balke-gmt3-range-breakout.ex5           utf16 .DWX: 0   ascii .DWX: 0
    QM5_41219_cum-rsi2-commodity-requal8.ex5          utf16 .DWX: 0   ascii .DWX: 0

This is exactly the check 21505 and 13054 fail, and it is why they are not in D2g6.

---

## 4. Preset derivation — `trial_setpath --roster` — 6/6 PASS

Canonical operator invocation (**module form** — the plain file path does not run, GAPS G4):

    cd C:/QM/repo
    python -m tools.strategy_farm.ftmo.trial_setpath --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/roster.json --run-name ftmo_demo_book_v3_D2g6_20260918 --dry-run

That CLI writes into `D:\QM\strategy_farm\artifacts\ftmo_trial_sets_review\ftmo_demo_book_v3_D2g6_20260918\`.
This build was constrained to write nothing outside the package, so `sets/` was produced by the
**identical code path** with `generate_from_roster(..., trial_root=<package>)` and the output directory
renamed to `sets/`. The two are byte-identical by construction: neither the preset bytes nor
`manifest.json` contain the output directory (the manifest records `roster_source`, `binding` and
`rulepath` paths only, and `directory` lives on the return value, not in the file). The RUNBOOK gives
the operator the CLI form plus the readback that proves equality.

Result: **no refusal**. `sets/manifest.json` — schema `qm.ftmo-trial-setpath/v2`,
`status INERT_REVIEW_ONLY`, `installed:false`, `installable:false`, `ENV:"live"`,
`book_risk_percent: 1.71875`, `risk_percent: [0.15625, 0.3125]`, 6 candidates,
`roster_sha256 53a13870…`, `risk_authority FABLE_DECISION_D2G_2026-09-18_DEPLOYABLE2`,
binding `FTMO_M13_STANDARD_DEMO_V1`, rulepack `FTMO_2S_100K_STANDARD_V2` as_of 2026-09-18.
Manifest sha256 `62efe535e71794542bbccf163237f40819f708e6a9c1cb8d5e56587bc3107f57`.

| ea_id | output preset | sha256 | vs installed |
|---|---|---|---|
| 13213 | `QM5_13213_USDJPY_H1_live_trial.set` | `19c771ff8224dcffa5e86df0814f5c51ecac8b2d7f5d898d1ee2e855c849a777` | new |
| 10706 | `QM5_10706_GBPUSD_H1_live_trial.set` | `31c37ec30421a51d7938ebfe911ef13e6615c678d0727ded9def09cb5cd1d140` | **byte-identical to installed** |
| 10700 | `QM5_10700_XAUUSD_H1_live_trial.set` | `6e319d98e5ea7b6790b8c05a7cf2d3b24cb184c070576f20d906fcb0dcd69dd7` | new |
| 11422 | `QM5_11422_USDCAD_D1_live_trial.set` | `215615b5da7ae2f49dd3d9dae7e85cbdff522940f69892d04cdf3c0f61378ea5` | **byte-identical to installed** |
| 10403 | `QM5_10403_XAUUSD_D1_live_trial.set` | `9d8414ce65912a6b75228717d9cf24cdd8329d2f31a8171851242e051132b1ef` | new |
| 41219 | `QM5_41219_XAUUSD_D1_live_trial.set` | `ba8ffd63db87de12495a7536ff8f8fef4e9447a9795c76d82ef2416f08d5f128` | new |

**All six are byte-identical to `D2f/probe_six_sleeves/sets_probe/`**, and the manifest `candidates`
array is element-for-element equal to the probe's (only `roster_label`, `roster_sha256`,
`roster_source` and `risk_authority` differ, as they must). The six presets were byte-verified under
D2f; this package re-derives them from the D2g6 roster and reproduces the same bytes. Two of the six
additionally reproduce the 2026-09-06 install byte-for-byte — an independent reproducibility proof of
the derivation path.

### Preset contract checks (all six PASS)

| check | observed |
|---|---|
| `ENV = live` | `; environment: live` + `; risk_mode: PERCENT` trailer written by `derive()`; these EAs have no `ENV` input, so ENV is provenance metadata stated in the preset itself |
| `RISK_FIXED = 0` | 6/6 |
| `RISK_PERCENT` | `0.15625` for 13213, `0.3125` for the other five — equals the roster row; `demo_install._expected_risk` re-checks it per magic at install time |
| bare venue symbol in a slot input | **N/A — no symbol-slot input exists in any of the six.** `symbol_slot_changes == {}` for all six, so `rebind_symbol_inputs` had nothing to rewrite. **Venue binding for these sleeves is the chart symbol**, which is why CHART_PLAN.md is load-bearing. The `; symbol: USDJPY.DWX` header line is a comment, not an input. |
| native live calendar | `qm_news_temporal=3`, `qm_news_compliance=2`, `qm_news_stale_max_hours=336`; manifest `constraints.calendar_binding = NATIVE_MT5_CALENDAR_LIVE`. No reference to the backtest news archive in any preset. |
| Friday flat (Standard, not Swing) | `qm_friday_close_enabled=true`, `qm_friday_close_hour_broker=21` — 6/6 |

`demo_install.validate_sources()` re-asserts all seven of those key/value pairs per preset
(`preset_contract_mismatch`) — verified green in §7.

---

## 5. Collector binding

- `bin/QM_FTMO_TrialTelemetry.ex5` sha256 `411638a1ae177326070c19b28c849fda36594592279303ce7d96f36bfa458258`
  = `demo_install.EXPECTED_COLLECTOR_SHA`, and = the binary already installed in the terminal
  (`SKIP_IDENTICAL`).
- `collector/QM_FTMO_TrialTelemetry_1514536732.set` sha256
  `9de24d3d6b3ee4c46aa3f1d7a8f0b0ff56bacb830e4f200651ebf4e2e581e88c`, five keys, UTF-8, LF:

      InpTimerSeconds=1
      InpOutputDir=QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918
      InpExpectedLogin=1514536732
      InpExpectedServer=FTMO-Demo
      InpTrialId=M13_D2G6_20260918_1514536732

  `demo_install.validate_sources()` compares this dict **exactly** against
  `{InpTimerSeconds:1, InpOutputDir: "QM\ftmo_trial\"+cycle_id, InpExpectedLogin, InpExpectedServer,
  InpTrialId}` — green.

**Defect found in the D2f package while reusing it (GAPS G7):** D2f's collector preset contains a
literal **0x0C form-feed byte** where `\f` of `\ftmo_trial` should be a backslash followed by `f`
(`QM\x0ctmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918`). D2f never hit it because `plan()` calls
`require_target()` before `validate_sources()`, so the run refused on AutoTrading first; at
`--execute` time it would have refused with `collector_preset_contract_mismatch`. The D2g6 preset was
written byte-controlled and verified by round-trip. The 2026-09-06 legacy preset is correct.

---

## 6. Governor rebind — `governor_rebind_dryrun.json` — PASS

    python -m tools.strategy_farm.ftmo.governor_rebind --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/roster.json --challenge-id M13_D2G6_20260918_1514536732 --challenge-start-utc "2026.09.18 06:17:00" --dry-run

Clean: `applied:false`, `terminal_written:false`, `charts_changed:false`, `autotrading_changed:false`,
`sleeve_count: 6`. Derived values:

    allowed_magics_csv   = 104030002,107000003,107060001,114220004,132130000,412190000
    governed_ea_ids_csv  = 10403,10700,10706,11422,13213,41219
    governed_symbols_csv = GBPUSD,USDCAD,USDJPY,XAUUSD

Preset re-pins (line-ending-invariant `content_sha256`):
`bootstrap 15c18dc4… -> e2640e6e…`, `active f7345341… -> f1b277a6…`;
binding `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json` `52d9e27d… -> 0ed0df9f…`.
Both *current* governor preset shas equal the copies installed in the terminal, so repo and terminal
are in sync for QM5_13206 before the rebind. `load_binding()` succeeds at HEAD
(`FTMO_M13_STANDARD_DEMO_V1` / `FTMO_2S_100K_STANDARD_V2`, as_of 2026-09-18).

The rebind is the **only** step that writes the repo, and it rolls all three files back on any
verification failure.

---

## 7. Install dry run — `demo_install_dryrun.json`

    python -m tools.strategy_farm.ftmo.demo_install --package docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6 --dry-run

**Exactly one refusal: `autotrading_must_be_disabled`** (stage `require_target`). D2f's second
refusal, `package_sets_manifest_missing`, is gone. The remaining refusal is the installer working as
designed — it will not stage into a terminal whose AutoTrading is on — and it clears once MT5 is shut
down cleanly with AutoTrading off, because that shutdown is what flushes `[Experts] Enabled=0` into
`config\common.ini`. Do **not** hand-edit `common.ini` to get past it.

Every other gate in `require_target()` was verified independently and is recorded in the artifact:
`origin.txt` resolves to `C:\Program Files\FTMO Global Markets MT5 Terminal`, `Login=1514536732`,
`Server=FTMO-Demo`, target is a real directory, not a symlink, and is neither `C:\QM\mt5\T_Live` nor
any of `D:\QM\mt5\T1..T10`. `[Experts] Enabled` currently reads `1`.

`demo_install_dryrun.json` therefore carries a **real** plan block produced by `demo_install.plan()`
itself, with only `require_target()` substituted so planning was not aborted by that one gate.
`validate_sources()` ran unmodified — so every `source_sha256`, every preset contract check, the
roster/manifest binding check and the sealed-binary check in it are real, not projected. Nothing was
written to the terminal.

`authority.json` validates: schema `qm.ftmo-demo-install-authority/v1`, decision id present, receipt
file exists, `cycle_id` matches `_CYCLE_ID_RE`, collector binding complete, both collector paths
resolve inside the package.

**Copy plan — 14 rows** (6 experts + 6 presets + collector binary + collector preset):

| # | kind | target file | action | backup |
|---|---|---|---|---|
| 1 | expert | `QM5_13213_balke-gmt3-range-breakout.ex5` | CREATE | — |
| 2 | preset | `QM5_13213_USDJPY_H1_live_trial.set` | CREATE | — |
| 3 | expert | `QM5_10706_tv-mon-ls.ex5` | **REPLACE** | yes |
| 4 | preset | `QM5_10706_GBPUSD_H1_live_trial.set` | SKIP_IDENTICAL | — |
| 5 | expert | `QM5_10700_tv-liq-break.ex5` | CREATE | — |
| 6 | preset | `QM5_10700_XAUUSD_H1_live_trial.set` | CREATE | — |
| 7 | expert | `QM5_11422_williams-18ma-outside-bar-entry-d1.ex5` | SKIP_IDENTICAL | — |
| 8 | preset | `QM5_11422_USDCAD_D1_live_trial.set` | SKIP_IDENTICAL | — |
| 9 | expert | `QM5_10403_et-turtle20x.ex5` | CREATE | — |
| 10 | preset | `QM5_10403_XAUUSD_D1_live_trial.set` | CREATE | — |
| 11 | expert | `QM5_41219_cum-rsi2-commodity-requal8.ex5` | CREATE | — |
| 12 | preset | `QM5_41219_XAUUSD_D1_live_trial.set` | CREATE | — |
| 13 | collector binary | `QM_FTMO_TrialTelemetry.ex5` | SKIP_IDENTICAL | — |
| 14 | collector preset | `QM_FTMO_TrialTelemetry_1514536732.set` | **REPLACE** | yes |

Experts land in `...\MQL5\Experts\QM_FTMO\`, presets in `...\MQL5\Profiles\Presets\QM_FTMO_M13\`.
Backup dir: `...\MQL5\Experts\QM_FTMO\_pre_FTMO_DEMO_BOOK_V3_D2G6_20260918`.
Telemetry dirs the installer creates:
`...\MQL5\Files\QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918` and
`D:\QM\reports\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918`.

**The install removes nothing.** The incumbent sleeves' binaries and presets (11421, 11910, 20048,
1537, 13054, 21505) stay on disk; they leave the book by being **detached in the chart profile**
(CHART_PLAN.md). That is deliberate — it keeps rollback cheap — but it means the chart edit, not the
install, is what actually changes the book.

---

## 8. Package inventory

    roster.json                       qm.ftmo-demo-roster/v1, 6 rows       sha 53a13870…
    authority.json                    decision + receipt + cycle + collector binding
    sets/manifest.json                qm.ftmo-trial-setpath/v2, 6 rows     sha 62efe535…
    sets/*.set                        6 derived live presets (sha256 in §4)
    bin/QM5_*.ex5                     6 canonical sleeve binaries (sha256 in §3)
    bin/QM_FTMO_TrialTelemetry.ex5    411638a1…  (= demo_install.EXPECTED_COLLECTOR_SHA)
    collector/QM_FTMO_TrialTelemetry_1514536732.set   9de24d3d…  cycle-bound
    governor_rebind_dryrun.json       PASS
    demo_install_dryrun.json          one expected refusal + real 14-row copy plan
    PACKAGE.md  CHART_PLAN.md  RUNBOOK.md  GAPS.md

Not carried over from D2f: `roster_draft.json` (superseded), `probe_six_sleeves/` (its purpose is
served — the six it probed are now the roster), `demo_cycle_observation_readonly.json` (it describes
the incumbent eight; the D2g6 equivalent is produced by RUNBOOK step 8, after the cutover).
