# FTMO Demo Book v3 — roster D2f — deployment package

**Status: NOT EXECUTABLE AS-IS.** `trial_setpath --roster` refuses with `sealed_source_hash_drift`
for 2 of 8 sleeves (21505, 13054), so `sets/` and `sets/manifest.json` do **not** exist and
`demo_install --package` cannot run. Everything that does not depend on the derived presets
(`roster.json`, `authority.json`, governor rebind, chart plan, runbook) is complete and verified.

- Decision: `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`
- Receipt: `docs/ftmo/FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` (Addendum 3, 2026-09-18 ~02:40Z)
- Cycle id: `FTMO_DEMO_BOOK_V3_D2F_20260918` · trial id `M13_D2F_20260918_1514536732`
- Book risk: **2.34375 %** (13213 @ 0.15625 %, seven others @ 0.3125 %)
- Target terminal: `...\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850` (login 1514536732, FTMO-Demo)
- Package: `C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2f`

Nothing in this package was installed, attached, started or toggled. No MT5 process was
touched, no chart profile written, no AutoTrading change, no SQLite write (all DB reads via
`?mode=ro`), no write outside this folder.

---

## 1. Roster (`roster.json`, schema `qm.ftmo-demo-roster/v1`)

`trial_setpath.load_roster()` accepts the file: 8 rows, no magic-formula violation, no magic or
slot collision, no `.DWX` venue name, all timeframes valid, every `risk_percent` inside the
`0 < r <= 1` dry-run cap.

| ea_id | ea_label | dxz | **FTMO venue** | TF | slot | magic | risk % |
|---|---|---|---|---|---|---|---|
| 13213 | QM5_13213_balke-gmt3-range-breakout | USDJPY | USDJPY | H1 | 0 | 132130000 | 0.15625 |
| 10706 | QM5_10706_tv-mon-ls | GBPUSD | GBPUSD | H1 | 1 | 107060001 | 0.3125 |
| 10700 | QM5_10700_tv-liq-break | XAUUSD | XAUUSD | H1 | 3 | 107000003 | 0.3125 |
| 11422 | QM5_11422_williams-18ma-outside-bar-entry-d1 | USDCAD | USDCAD | D1 | 4 | 114220004 | 0.3125 |
| 10403 | QM5_10403_et-turtle20x | XAUUSD | XAUUSD | D1 | 2 | 104030002 | 0.3125 |
| 21505 | QM5_21505_xag-weekly-lowvol-momentum | XAGUSD | XAGUSD | D1 | 0 | 215050000 | 0.3125 |
| 41219 | QM5_41219_cum-rsi2-commodity-requal8 | XAUUSD | XAUUSD | D1 | 0 | 412190000 | 0.3125 |
| 13054 | QM5_13054_brent-tom-mom | XTIUSD | USOIL.cash | D1 | 0 | 130540000 | 0.3125 |

`dxz_symbol` is carried **bare** (no `.DWX`): `trial_setpath` appends `FACTORY_SUFFIX` itself for
the seal lookup and for the symbol-slot rebind. The draft (`roster_draft.json`) used `USDJPY.DWX`
style names, list-valued `timeframe`/`slot`/`magic`, and the key `sleeves`; all three are rejected
by the v1 schema (`candidates`, scalar, bare) and were normalised here.

Every timeframe is the one parsed out of the EA's **canonical Q10-sealed backtest setfile name**,
not a document claim — `generate_from_roster` re-checks it and refuses on `roster_timeframe_mismatch`.

### Magic registry cross-check — 8/8 PASS

Every magic exists in `framework/registry/magic_numbers.csv` with `status=active`, matching `ea_id`,
matching `symbol_slot`, and `symbol == <dxz>.DWX`. Registry sha256
`6671944eb975e09b303fb4afd1cb40dc6e6b50d8111af48fbced020050851381`.
`magic == ea_id*10000 + slot` holds for all 8. (A 13213 slot-1 / XAUUSD.DWX row exists but is
`retired` and is not used.)

---

## 2. Venue symbol evidence

Source: `docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/ftmo_symbol_probe.json` (account
1514536732, server FTMO-Demo) — presence in the terminal's own `bases\FTMO-Demo\ticks` and
`...\history` directories, plus terminal-log occurrences.

| venue symbol | ticks dir | history dir | log hits | alias registry (FTMO_TRIAL) | verdict |
|---|---|---|---|---|---|
| USDJPY | yes | yes | — | `USDJPY.DWX -> USDJPY` | **VERIFIED** |
| GBPUSD | yes | yes | — | `GBPUSD.DWX -> GBPUSD` | **VERIFIED** |
| XAUUSD | yes | yes | 776 | `XAUUSD.DWX -> XAUUSD` | **VERIFIED** |
| USDCAD | yes | yes | — | *absent* | **VERIFIED** (ticks + history) |
| XAGUSD | yes | yes | 53 | *absent* | **VERIFIED** (ticks + history) |
| USOIL.cash | yes | yes | 100 | `XTIUSD.DWX -> USOIL.cash` | **VERIFIED** |

No symbol in D2f is UNVERIFIED. Caveat: `framework/registry/execution_symbol_aliases_v1.json`
carries the FTMO_TRIAL venue under `account_id 1513845506`, not the live demo account 1514536732,
and has no rows for USDCAD / XAGUSD. The roster path does not consult the alias registry (the venue
name is an explicit roster field), so this is hygiene, not a blocker — GAPS G5.

---

## 3. Binary identity — canonical repo vs Q10 seal vs FTMO terminal

sha256 of `framework/EAs/<label>/<label>.ex5` vs `identities.ex5_sha256` in the
`Q10_NEWS / status=done / verdict=CONFIG_LOCKED` seal vs the file currently in the terminal's
`MQL5\Experts\QM_FTMO`.

| ea_id | repo ex5 sha256 | = Q10 seal? | in FTMO terminal | terminal match? |
|---|---|---|---|---|
| 13213 | `8c99dea16fbf758a4b2da9f49a26db26bfe7fed3589f2066be5120314106a8f0` | **MATCH** | not present | n/a (new) |
| 10706 | `eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb` | **MATCH** | `6f290d49defdfe1e...` | **MISMATCH** |
| 10700 | `5fbf2ba0048250041296deda0008ff6757f56dce27e39efead69f45838e5e6be` | **MATCH** | not present | n/a (new) |
| 11422 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | **MATCH** | same | match |
| 10403 | `f927f07f46579bbb9a1bdcfdb7caa9b246e9d7555935fbb878f7fc01afbf7ab3` | **MATCH** | not present | n/a (new) |
| 21505 | `395c4747832acbcdf8a68d8598e53abe5786bdc6c538767c400884cd82b2aea1` | **MATCH** | `81386c2dcd80e58d...` | **MISMATCH** |
| 41219 | `e9670141e89249aff7df44a10a2402e2103aa4cecf8d0a35a8cd6d6babedf108` | **MATCH** | not present | n/a (new) |
| 13054 | `2e65488fccdbd985f78318861a223a305d820a4fce3d2ebdcafae6ce956fd96d` | **MATCH** | same | match |

**Repo and Q10 seal agree for all eight.** Two terminal binaries do not:

- `10706` terminal = `6f290d49...`, `21505` terminal = `81386c2d...`. Neither sha exists anywhere in
  the repo. They are the **2026-09-06 "codex alias" rebuilds**: the backup dirs
  `_pre_alias_20260906` and `_pre_codex_alias_20260906_2047Z` hold the pre-alias binaries, and those
  *are* the sealed repo binaries `eaffda6f...` / `395c4747...`. The live demo has therefore been
  running two untracked, unsealed builds of 10706 and 21505 since 2026-09-06 20:42.
- `demo_install` will plan `REPLACE` for both and restore the sealed binaries. For 21505 that is a
  **behaviour regression**, see section 4 and GAPS G2.

---

## 4. Symbol gate audit — where the two blockers come from

Six of the eight EAs contain **no symbol gate at all** as compiled (classification
`CHART_SYMBOL_ONLY`, independently recorded in the R2 symbol-literal inventory
`docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2/symlit_*.json`). They take the chart symbol
and run under any venue name. Two do not:

| ea_id | gate in the **as-compiled** source (the commit that last built the .ex5) | on the FTMO chart |
|---|---|---|
| 21505 | `return (_Symbol == "XAGUSD.DWX" && _Period == PERIOD_D1);` — `e550961321`, 2026-08-17 | `XAGUSD` != `XAGUSD.DWX` -> **dark** |
| 13054 | `return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);` — `d15464ec86`, 2026-08-12 | `USOIL.cash` != `XTIUSD.DWX` -> **dark** |

Commit `9359ecaf2b` (2026-09-13) replaced both hard literals with
`QM_MagicSymbolCanonical(_Symbol) == QM_MagicSymbolCanonical(strategy_host_symbol)` and added
`strategy_host_symbol` to the `.mq5` **and** to the backtest `.set` — but **did not rebuild the
`.ex5`**: `git log` on both `.ex5` paths stops at 2026-08-17 / 2026-08-12, and the commit's own
file list contains no `.ex5`. Direct confirmation from the live terminal: `chart09.chr` (21505) and
`chart06.chr` (13054) enumerate every EA input and **neither contains `strategy_host_symbol`** — the
running binaries have no such input, so a preset line carrying it would be inert.

Consequences:

1. **13054 has been silently dark on the FTMO demo since 2026-09-06.** Its terminal binary is the
   sealed `2e65488f...`, i.e. the hard-`XTIUSD.DWX` build, attached to a `USOIL.cash` chart.
   The D2f financing case counts it as a contributing sleeve.
2. **21505 trades only because of the untracked alias rebuild** `81386c2d...`. Installing the sealed
   `395c4747...` binary (which `demo_install` plans) would make it dark as well.
3. The chain's Addendum-3 claim *"All eight sleeves are class A: no recompile, no new identity, no
   alias, no Q02 re-entry"* is **false for 21505 and 13054**. Both need a recompile and, per the
   rebuilt-EX5-is-a-new-identity rule, a fresh seal before they can run on an FTMO venue name.

---

## 5. Preset derivation — `trial_setpath --roster --dry-run`

Canonical invocation (**module form** — the plain file path does not run, GAPS G4):

    cd C:/QM/repo
    python -m tools.strategy_farm.ftmo.trial_setpath --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/roster.json --run-name ftmo_demo_book_v3_D2f_20260918 --dry-run

**Result: `Refusal: sealed_source_hash_drift`** raised at `trial_setpath.py:267` inside
`sealed_source_raw`. Nothing was written: `D:\QM\strategy_farm\artifacts\ftmo_trial_sets_review`
still holds only the two 2026-09-06 runs. The same refusal occurs when the run is redirected into
this package with `trial_root=`, so `sets/` and `sets/manifest.json` are **absent by design, not by
omission**.

Which rows refuse, and why:

| ea_id | symbol | Q10 seal baseline sha256 | setfile on disk now | relation |
|---|---|---|---|---|
| 21505 | XAGUSD.DWX | `a345970c4c597963...` | `fd653cf2c8a6f7f2...` | seal = **CRLF of the pre-`9359ecaf2b` content** |
| 13054 | XTIUSD.DWX | `d834b193a77b1d10...` | `9388a6e804380c18...` | seal = **LF of the pre-`9359ecaf2b` content** |

The only content delta in both cases is the two lines commit `9359ecaf2b` appended:

    ; symbol inputs (Hard Rule OWNER 2026-09-06): factory .DWX defaults; live presets carry bare broker names
    strategy_host_symbol=XAGUSD.DWX          (resp. XTIUSD.DWX)

No strategy parameter changed. Note also that the two seals were taken with *different* line
endings: `sealed_source_raw()` compares a **raw-byte** sha, while the binding layer uses the
line-ending-invariant `binding_hash.content_sha256()` (ticket a5cf99d0). See GAPS G1 and G6.

The remaining six EAs pass the seal check: their setfile on disk still hashes to the sealed
baseline, and all six carry `RISK_FIXED>0 / RISK_PERCENT=0` as a proper fixed-risk backtest source.

### The other six derive cleanly

`probe_six_sleeves/` (a diagnostic, explicitly **not** the deliverable) runs the identical code path
on the six unblocked rows and produces a valid `qm.ftmo-trial-setpath/v2` manifest:

| ea_id | output preset | sha256 (first 16) | vs currently installed |
|---|---|---|---|
| 13213 | `QM5_13213_USDJPY_H1_live_trial.set` | `19c771ff8224dcff` | new |
| 10706 | `QM5_10706_GBPUSD_H1_live_trial.set` | `31c37ec30421a51d` | **byte-identical to installed** |
| 10700 | `QM5_10700_XAUUSD_H1_live_trial.set` | `6e319d98e5ea7b67` | new |
| 11422 | `QM5_11422_USDCAD_D1_live_trial.set` | `215615b5da7ae2f4` | **byte-identical to installed** |
| 10403 | `QM5_10403_XAUUSD_D1_live_trial.set` | `9d8414ce65912a6b` | new |
| 41219 | `QM5_41219_XAUUSD_D1_live_trial.set` | `ba8ffd63db87de12` | new |

Two of the six reproduce the 2026-09-06 install byte-for-byte — a strong reproducibility proof for
the derivation path itself.

### Preset contract checks (all six PASS)

| check | observed |
|---|---|
| `ENV = live` | `; environment: live` + `; risk_mode: PERCENT` trailer written by `derive()`; these EAs have no `ENV` input, so ENV is provenance metadata (stated in the preset itself) |
| `RISK_FIXED = 0` | 6/6 |
| `RISK_PERCENT` | `0.15625` for 13213, `0.3125` for the other five — equals the roster row; `demo_install._expected_risk` re-checks it per magic at install time |
| bare venue symbol in a slot input | **N/A — no symbol-slot input exists in any of the six presets.** `symbol_slot_changes == {}` for all six, so `rebind_symbol_inputs` had nothing to rewrite. Venue binding for these sleeves is **the chart symbol**, which is why CHART_PLAN.md is load-bearing. The `; symbol: USDJPY.DWX` header line is a comment, not an input. |
| native live calendar | `qm_news_temporal=3`, `qm_news_compliance=2`, `qm_news_stale_max_hours=336` — the framework's native-MT5-calendar fail-closed path; manifest `constraints.calendar_binding = NATIVE_MT5_CALENDAR_LIVE`. No reference to the backtest news archive in any preset. |
| Friday flat (Standard, not Swing) | `qm_friday_close_enabled=true`, `qm_friday_close_hour_broker=21` — 6/6 |

For 21505 and 13054 the symbol-slot check would be the *only* two presets in which a bare venue
symbol actually appears — and they are exactly the two that refuse.

---

## 6. Governor rebind — `governor_rebind_dryrun.json` — PASS

    python -m tools.strategy_farm.ftmo.governor_rebind --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/roster.json --challenge-id M13_D2F_20260918_1514536732 --challenge-start-utc "2026.09.18 06:17:00" --dry-run

Clean dry run: `applied:false`, `terminal_written:false`, `charts_changed:false`,
`autotrading_changed:false`. Derived values:

    allowed_magics_csv   = 104030002,107000003,107060001,114220004,130540000,132130000,215050000,412190000
    governed_ea_ids_csv  = 10403,10700,10706,11422,13054,13213,21505,41219
    governed_symbols_csv = GBPUSD,USDCAD,USDJPY,USOIL.cash,XAGUSD,XAUUSD

Preset re-pins (line-ending-invariant `content_sha256`):
`bootstrap 15c18dc4... -> ef6e212e...`, `active f7345341... -> a50ddf78...`;
binding `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json` `52d9e27d... -> e4f4aba2...`.
Both current governor preset shas equal the copies installed in the terminal, so repo and terminal
are in sync for QM5_13206.

`load_binding()` succeeds at HEAD (`FTMO_M13_STANDARD_DEMO_V1` / `FTMO_2S_100K_STANDARD_V2`,
as_of 2026-09-18) — the a5cf99d0 re-pin (`1279dad2a3`) is effective. Blocker (1) of Addendum 3 is
closed.

---

## 7. Install dry run — `demo_install_dryrun.json` — REFUSED (two independent reasons)

    python -m tools.strategy_farm.ftmo.demo_install --package docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f --dry-run

| stage | refusal |
|---|---|
| `load_package` | `package_sets_manifest_missing` — consequence of section 5 |
| `require_target` | `autotrading_must_be_disabled` — the live terminal's `config\common.ini` currently has `[Experts] Enabled=1` |

The second refusal is **correct and expected**: the installer will not stage into a terminal whose
AutoTrading is on. It clears once MT5 is shut down with AutoTrading off (the value is only flushed
to `common.ini` on clean shutdown).

`authority.json` itself validates: schema `qm.ftmo-demo-install-authority/v1`, decision id present,
receipt file exists, cycle id matches `_CYCLE_ID_RE`, collector binding complete, both collector
paths resolve inside the package.

Projected copy plan (18 rows: 8 experts + 8 presets + collector binary + collector preset). Expert
rows are byte-exact (hashed now); preset rows are placeholders until section 5 clears.

| target | action |
|---|---|
| 13213, 10700, 10403, 41219 `.ex5` | CREATE |
| 11422, 13054 `.ex5` | SKIP_IDENTICAL |
| 10706, 21505 `.ex5` | **REPLACE** (backup to `_pre_FTMO_DEMO_BOOK_V3_D2F_20260918`) — see section 4 |
| `QM_FTMO_TrialTelemetry.ex5` | SKIP_IDENTICAL (`411638a1...`) |
| `QM_FTMO_TrialTelemetry_1514536732.set` | REPLACE (new cycle id / trial id) |
| 8 sleeve presets | CREATE |

Telemetry directories the installer would create:
`...\MQL5\Files\QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918` and
`D:\QM\reports\ftmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918`.

---

## 8. Package inventory

    roster.json                          final qm.ftmo-demo-roster/v1, 8 rows      sha 0b9ccb0d...
    roster_draft.json                    input (superseded; wrong schema shape)
    authority.json                       decision + receipt + cycle + collector binding
    bin/QM_FTMO_TrialTelemetry.ex5       411638a1...  (= demo_install.EXPECTED_COLLECTOR_SHA)
    collector/QM_FTMO_TrialTelemetry_1514536732.set   3b01a12b...  cycle-bound
    governor_rebind_dryrun.json          PASS
    demo_install_dryrun.json             REFUSED + projected copy plan with sha256s
    demo_cycle_observation_readonly.json read-only ledger build, --dark-after-days 5
    probe_six_sleeves/                   diagnostic only - six derivable sleeves, NOT the deliverable
    sets/                                ABSENT - blocked, see section 5
    PACKAGE.md  CHART_PLAN.md  RUNBOOK.md  GAPS.md
