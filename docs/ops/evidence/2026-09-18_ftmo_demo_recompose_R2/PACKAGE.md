# FTMO Demo recomposition package — roster `R2_capped` (PREPARE ONLY)

**Status: PREPARED, NOT EXECUTABLE AS-IS.** Three of eight sleeves are hard-blocked
(§4 B1). Nothing here was installed, attached, started or toggled. No MT5 process was
touched, no chart profile written, no SQLite database written, no git command run. The
only files created are the contents of this folder.

| field | value |
|---|---|
| target account | `1514536732` @ `FTMO-Demo` (100k 2-Step Standard, free trial) |
| terminal | `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850` |
| governor | `QM5_13206_ftmo-account-governor`, policy `FTMO_2S_P1_100K_V2`, M13 |
| roster | `R2_capped`, 8 sleeves @ **0.3125 %** each = **2.5 %** book risk |
| roster source | `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\roster_definitions.json` |
| decision support | `docs/ftmo/FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` §6 (E2E 0.6993 → 0.9223, LCB 0.6571 → 0.9059, median 746 → 288 bd) |
| authority | Roster selection, book construction, install, attach and AutoTrading are **OWNER-only (ROT)**. This package proposes; it does not authorise. |
| machine-readable facts | `facts.json` (schema `qm.ftmo-demo-recompose-facts/v1`), produced by `gather_facts.py` |

---

## 1. Per-sleeve specification

Binary paths are relative to `C:\QM\repo`. `magic = ea_id*10000 + slot`, verified against
`framework/registry/magic_numbers.csv` **and** against the magic actually observed inside
the W38 simulated stream (third column of the verification table in §3).

### 1.1 Identity, symbol, timeframe, magic

| # | EA label | factory symbol | → FTMO venue symbol | flag | TF | slot | magic |
|--:|---|---|---|---|---|--:|--:|
| 1 | `QM5_13213_balke-gmt3-range-breakout` | `USDJPY.DWX` | `USDJPY` | **VERIFIED** | H1 | 0 | `132130000` |
| 2 | `QM5_10706_tv-mon-ls` | `GBPUSD.DWX` | `GBPUSD` | **VERIFIED** | H1 | 1 | `107060001` |
| 3 | `QM5_10700_tv-liq-break` | `XAUUSD.DWX` | `XAUUSD` | **VERIFIED** | H1 | 3 | `107000003` |
| 4 | `QM5_11660_pp-wedge` | `NDX.DWX` | `US100.cash` | **VERIFIED (name) / BLOCKED (EA)** | H4 | 4 | `116600004` |
| 5 | `QM5_11422_williams-18ma-outside-bar-entry-d1` | `USDCAD.DWX` | `USDCAD` | **VERIFIED** | D1 | 4 | `114220004` |
| 6 | `QM5_10145_tsm-meanret` | `XAUUSD.DWX` | `XAUUSD` | **VERIFIED** | D1 | 34 | `101450034` |
| 7 | `QM5_20266_collins-66mom` | `XTIUSD.DWX` | `USOIL.cash` | **VERIFIED (name) / BLOCKED (EA)** | D1 | 0 | `202660000` |
| 8 | `QM5_12710_commodity-tsmom-12m-atr` | `XTIUSD.DWX` | `USOIL.cash` | **VERIFIED (name) / BLOCKED (EA)** | D1 | 0 | `127100000` |

All eight magics are pairwise distinct and distinct from the governor's own EA id 13206.
Two magics (`107060001`, `114220004`) are already live on the demo under the **same**
binary sha, so they are carry-overs, not collisions (§5.2).

### 1.2 Venue-symbol evidence, per sleeve

The venue-name flag above is about the **broker instrument name existing and being
tradable on this account**. It is a separate question from whether the EA binary will
trade on that name (§4).

| venue symbol | alias registry | ticks dir | history dir | terminal logs | live chart today | verdict |
|---|---|---|---|---|---|---|
| `USDJPY` | yes (acct `1513845506`) | yes | yes | — | — | **VERIFIED** |
| `GBPUSD` | yes (acct `1513845506`) | yes | yes | — | `chart02.chr` | **VERIFIED** |
| `XAUUSD` | yes (acct `1513845506`) | yes | yes | ×776 | — | **VERIFIED** |
| `US100.cash` | yes (acct `1513845506`) | yes | yes | ×342 | — | **VERIFIED** |
| `USDCAD` | **no** | yes | yes | — | `chart04.chr` | **VERIFIED** (see caveat) |
| `USOIL.cash` | yes (acct `1513845506`) | yes | yes | ×100 | `chart06/07.chr` | **VERIFIED** |

Sources: `framework/registry/execution_symbol_aliases_v1.json` (venue `FTMO_TRIAL`);
`docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/ftmo_symbol_probe.json` (`ticks_dir`,
`history_dir`, `logs.probe_name_occurrences`); the live chart profile parsed read-only by
`demo_cycle.parse_chart_profile`.

Two caveats, both recorded rather than papered over:

* **The alias registry is scoped to the wrong account.** Its matching rule is
  `EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL` with
  `cross_venue_pooling_for_qualification=false`, and the `FTMO_TRIAL` venue is bound to
  account **`1513845506`**, not `1514536732`. Strictly read, the registry does not cover
  this account. It is treated here as corroboration only; the load-bearing evidence is the
  **per-server** `bases\FTMO-Demo\ticks` + `history` inventories, which every one of the
  six names appears in, plus live attachment for three of them. This is the same caveat
  the 2026-09-15 census records under its EXCLUDE reason D/E.
* **`USDCAD` is absent from the alias registry entirely** — yet it is on `chart04.chr`
  right now under magic `114220004` and has `ENTRY_ACCEPTED ×2 / TM_OPEN ×2` in
  `MQL5\Files\QM\QM5_11422_ea-11422.log`. Live execution outranks a stale registry row;
  the registry row is the thing that is missing, not the symbol. Recorded in `GAPS.md` G6.

### 1.3 Binaries and Q08 binding

`ex5 sha256` is the canonical repo binary. `Q08-bound` compares it with the `ex5_sha256`
stored on the Q08 work item whose trade stream the W38 simulation consumed.

| # | EA | ex5 sha256 | Q08 work item | Q08 verdict | bound? |
|--:|---|---|---|---|---|
| 1 | 13213 | `8c99dea16fbf758a4b2da9f49a26db26bfe7fed3589f2066be5120314106a8f0` | `048643ac-a569-45f6-9d5d-c559c5a9c060` | PASS | **MATCH** |
| 2 | 10706 | `eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb` | `a2e1aba6-45ea-4dcf-af98-1f679ebeb64f` | PASS | **MATCH** |
| 3 | 10700 | `5fbf2ba0048250041296deda0008ff6757f56dce27e39efead69f45838e5e6be` | `ce371d25-12b0-44b8-9d55-0854c9adcdd8` | PASS | **MATCH** |
| 4 | 11660 | `5db350ac57411c2b6d81987db4e2f5ec8598eabb05c058f2df6da2dcfe70610e` | `0fd00da5…` (latest Q08) | **FAIL_SOFT** | **MATCH** ⚠ |
| 5 | 11422 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | `2bd0f95c-6c62-4a53-92cf-04f0d39fbb48` | PASS | **MATCH** |
| 6 | 10145 | `c3f5476eff34ce65b25acf8bd967b5d0b349ce8e05bd492f82316f899a38db86` | `48778bc7-e7e0-499a-8266-4c0c1c50e8a5` | PASS | **MATCH** |
| 7 | 20266 | `8760402ac1ba34d9631b125989d13e63a737a0a305f6b3d6b00f3d1b6e128fed` | `87731bac-29cc-4846-ac26-b348b13af59b` | PASS | **MATCH** |
| 8 | 12710 | `11474d4cffcce6867d2907005fc6256f59f88f126759dcfb11f880765a36b95b` | `bfda1943…` (latest Q08) | **FAIL_SOFT** | **MATCH** ⚠ |

**Zero binary/hash mismatches.** For all eight sleeves the canonical repo `.ex5`, the
`ex5_sha256` recorded on the Q10_NEWS seal, and the `ex5_sha256` on the Q08 work item that
produced the simulated stream are the **same** hash. Each EA directory contains exactly one
`.ex5`, so there is no ambiguity about which binary `demo_install`-style globbing would pick.

⚠ **Two sleeves' streams come from a Q08 `FAIL_SOFT` row, not a `PASS` row** (11660, 12710).
Both clear the snapshot's qualification predicate on the *terminal* gate
(`Q14 = KEEP_INCUMBENT` for both, `qualified_pool.definition` = "contiguous Q02..terminal-gate
PASS-class"), so their presence in the pool is contract-correct — but the R2 decision-support
numbers for these two rest on a soft-failed Q08. Recorded, not resolved.

### 1.4 Live preset requirements

Every one of the eight derived presets in `sets/` satisfies, by construction and by
post-write re-verification in `build_sets.py`:

| requirement | value | enforced how |
|---|---|---|
| `RISK_FIXED` | `0` | `trial_setpath.derive()` |
| `RISK_PERCENT` | `0.3125` | `trial_setpath.derive()` |
| ENV | `live` (trailing provenance comment; these EAs have no `ENV` input) | `derive()` |
| `qm_news_temporal` | `3` | `derive()` |
| `qm_news_compliance` | `2` (FTMO profile) | `derive()` |
| `qm_news_stale_max_hours` | `336` | `derive()` |
| `qm_friday_close_enabled` | `true` | `derive()` — Standard account, weekend holding forbidden |
| `qm_friday_close_hour_broker` | `21` | `derive()` |
| calendar | native MT5 live calendar, fail-closed | framework (HR: live EAs never read the backtest news archive) |
| symbol slot inputs | bare venue names | **NOT SATISFIABLE for 3 sleeves — see §4** |
| strategy parameters | byte-identical to the sealed Q10_NEWS baseline | `verify_derivation()` (`strategy_identity_sha256`) |

Two of the eight derived presets — `QM5_10706_GBPUSD_H1_live_trial.set`
(`31c37ec30421a51d…`) and `QM5_11422_USDCAD_D1_live_trial.set` (`215615b5da7ae2f4…`) —
are **byte-identical to the presets installed on 2026-09-06**. That is an independent
reproduction proof that this package's derivation path is the same one the previous
install used.

---

## 2. What changes relative to the current book

Current roster hash (observed read-only, `demo_cycle.roster_hash`):
`6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`

| | current (`R0_demo8`) | target (`R2_capped`) |
|---|---|---|
| kept | `10706 GBPUSD` (chart02), `11422 USDCAD` (chart04) | same magics, same binaries |
| removed | `11421 EURUSD`, `11910 NZDUSD`, `13054 USOIL.cash`, `20048 USOIL.cash`, `1537 XAGUSD`, `21505 XAGUSD` | — |
| added | — | `13213 USDJPY`, `10700 XAUUSD`, `11660 US100.cash`, `10145 XAUUSD`, `20266 USOIL.cash`, `12710 USOIL.cash` |
| book risk | 2.5 % (8 × 0.3125) | 2.5 % (8 × 0.3125) — unchanged |

6 removed + 6 added ⇒ `demo_cycle.classify_material_change` emits 6 × `SLEEVE_REMOVED` and
6 × `SLEEVE_ADDED`, all `material=True, representative_breaking=True` ⇒ `resets_cycle=True`
⇒ **a new cycle starts, the 14-day validation clock restarts at zero.** Detail in
`CHART_PLAN.md` §4.

---

## 3. Verification table (all green)

| check | result |
|---|---|
| Q10_NEWS `CONFIG_LOCKED` seal exists for all 8 (ea, symbol) pairs | **8/8** |
| seal schema | `q09-news-adjudication/v3` on all 8 |
| sealed source `.set` present in repo and sha matches the seal | **8/8** |
| `magic == ea_id*10000 + slot` per `magic_numbers.csv` | **8/8**, all rows `status=active` |
| magic in the preset (`qm_magic_slot_offset`) == registry slot | **8/8** |
| magic observed inside the W38 simulated stream == registry magic | **8/8** |
| canonical `.ex5` sha == seal `ex5_sha256` == Q08 `ex5_sha256` | **8/8** |
| exactly one `.ex5` per EA directory | **8/8** |
| derived preset passes `verify_derivation` (strategy params unchanged) | **8/8** |
| derived preset satisfies the RISK/news/Friday contract | **8/8** |
| magic collisions inside the target roster | **none** |
| venue symbol present in this account's ticks **and** history dir | **6/6 names** |

---

## 4. Blockers

### B1 — THREE SLEEVES WOULD BE SILENTLY DARK ON FTMO VENUE NAMES (deployment-blocking)

`11660`, `20266` and `12710` gate their entire trading logic on an **exact string
comparison against the `.DWX` factory symbol name**. On an FTMO chart the comparison is
false, `Strategy_NoTradeFilter()` returns `true`, and the EA initialises cleanly and then
never trades. There is no error, no `FRAMEWORK_INIT_FAILED`, no log line that says
anything is wrong.

| EA | source | gate |
|---|---|---|
| `11660` | `QM5_11660_pp-wedge.mq5:73-78` | `Strategy_ExpectedSlot()` returns `-1` unless `_Symbol` is one of five `.DWX` literals (incl. `"NDX.DWX"`); `Strategy_ConfigurationAuthorized()` → false; `Strategy_NoTradeFilter()` (`:200-203`) → `true`. On `US100.cash`: **dark**. |
| `20266` | `QM5_20266_collins-66mom.mq5:67-70` | `Strategy_IsXtiD1()` requires `_Symbol == "XTIUSD.DWX"`; `Strategy_NoTradeFilter()` (`:253-255`) returns `true` when false. On `USOIL.cash`: **dark**. |
| `12710` | `QM5_12710_commodity-tsmom-12m-atr.mq5:54-57` | identical construction (`:150-152`). On `USOIL.cash`: **dark**. |

Classification source: `tools/strategy_farm/ea_symbol_literal_inventory.py`, per-EA JSON in
`symlit_QM5_*.json` — all three report `classification: "trading_logic_literal"` (the same
scanner the 2026-09-15 census used). The remaining five sleeves report **zero** symbol
literals and are clean chart-symbol-only EAs.

**This is not a prediction. It is already happening on the live demo.** `QM5_20048_wti-preholiday`
carries the same construction (`QM5_20048_wti-preholiday.mq5:143-147`,
`_Symbol!="XTIUSD.DWX"`) and has been attached to `USOIL.cash` on `chart07.chr` since
2026-09-11. Its log
(`…\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\QM5_20048_ea-20048.log`) shows:

```
INIT_OK          x5
TM_OPEN          x0
ENTRY_ACCEPTED   x0
```

against, over the same window, `10706` (bare `GBPUSD`) `ENTRY_ACCEPTED ×6 / TM_OPEN ×6` and
`11422` (bare `USDCAD`) `ENTRY_ACCEPTED ×2 / TM_OPEN ×2`. `13054` on the other `USOIL.cash`
chart likewise shows `INIT_OK ×5`, `TM_OPEN ×0` (its literal is an input default at
`:47`, but the DXZ-derived preset leaves the input at `XTIUSD.DWX`, so it is dark for the
preset reason rather than the code reason).

Consequences if R2 were deployed as-is: **3 of 8 sleeves = 37.5 % of the 2.5 % book risk
would contribute nothing**, the realised book would be a 5-sleeve 1.5625 % book, and the
14-day validation evidence would be measuring a portfolio that does not exist. Worse, the
post-change verification list would still pass a naive `magics_seen == 8` check, because
`demo_cycle` observes **charts**, not fills.

Remediation options, in order of how much they cost (none are autonomous — a rebuild
changes EA identity and re-enters at Q02 per company policy):

1. **Drop the three sleeves** and take a 5-sleeve R2 at 0.5 % each, or re-run the
   first-passage engine on a 5-sleeve/8-sleeve substitute roster drawn only from
   literal-free sleeves. Cheapest; changes the roster, so it is an OWNER roster decision.
2. **Substitute** the three with the next cap-legal literal-free candidates from
   `stream_stats.json`. Requires a fresh `first_passage.py build` run to re-price the
   roster — the R2 numbers do not transfer.
3. **Rebuild the three EAs** against the OWNER 2026-09-06 symbol-input rule (symbol as an
   `input`, resolver comparing base names). A rebuilt `.ex5` is a new identity and re-enters
   the pipeline at Q02; it cannot be admitted to this book as a precondition (the
   2026-09-15 census's correction (ii) says exactly this).

The census also records a *second*, independent reason the `NDX → US100.cash` sleeve is
unsafe even after such a rebuild: `QM_MagicSymbolCanonical`
(`framework/include/QM/QM_MagicResolver.mqh:134-141`) canonicalises to the text before the
first `.` and has exactly one alias, `USOIL → XTIUSD`. There is **no `NDX → US100`** alias,
so `QM_MagicResolveChecked`'s registry-symbol guard (`:216-231`) fails closed on
`US100.cash` for any binary that carries that guard. Closing that is a registry re-symbol —
ROT-class, OWNER-only.

### B2 — governor allow-list does not cover the new roster (deployment-blocking, fixable)

`framework/EAs/QM5_13206_ftmo-account-governor/sets/QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set`
and the live `chart01.chr` both carry the R0 lists:

```
allowed_magics_csv   = 107060001,114210000,114220004,119100006,130540000,15370001,200480000,215050000
governed_ea_ids_csv  = 10706,11421,11422,11910,13054,1537,20048,21505
governed_symbols_csv = GBPUSD,EURUSD,USDCAD,NZDUSD,USOIL.cash,XAGUSD
```

Only `107060001` and `114220004` of the R2 magics are present. R2 needs:

```
allowed_magics_csv   = 101450034,107000003,107060001,114220004,116600004,127100000,132130000,202660000
governed_ea_ids_csv  = 10145,10700,10706,11422,11660,12710,13213,20266
governed_symbols_csv = GBPUSD,US100.cash,USDCAD,USDJPY,USOIL.cash,XAUUSD
```

This is a **coupled** change: the governor preset's sha256 is pinned in
`tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`
(`governor.active_preset_sha256 = 8537309436…`) and `trial_setpath.load_binding()` refuses
with `active_preset_hash_drift` if the two disagree. Editing the preset without updating
the binding breaks the set-derivation path; updating the binding is a repo change that has
to land before any install runs. Also open: `challenge_id=M13_20260906_1514536732` and
`challenge_start_utc=2026.09.06 06:17:00` both belong to the superseded cycle.

### B3 — `demo_install.py` cannot install this package (tooling, fixable)

`tools/strategy_farm/ftmo/demo_install.py` is hard-bound to the 2026-09-06 run. Exact list
in `GAPS.md` G1; the four refusals it would raise, in order, are
`live_task_authority_missing` (TASK_ID constant), `wrong_set_manifest` (EVIDENCE/SETS
constants point at the old folder), `wrong_risk_or_candidate_count`, and
`collector_preset_contract_mismatch` (`InpOutputDir` / `InpTrialId` carry `2026-09-06`).

### B4 — news capability: **no `NONE` found** (clear)

All eight sealed sources carry `qm_news_temporal` / `qm_news_compliance` and the derived
presets set compliance profile `2`. This is the one class of blocker the 2026-09-15 census
flagged elsewhere (`QM5_1567` has no news input at all) that **does not** apply to any R2
sleeve.

### B5 — overnight/weekend exposure: mitigated, not eliminated

Five of eight sleeves are D1 and one is H4, so R2 is overwhelmingly an overnight book —
but no sleeve is "100 % overnight" in the sense of an unmanaged weekend carry: every
derived preset sets `qm_friday_close_enabled=true` / `qm_friday_close_hour_broker=21` with
a 5-minute flat lead, which is the Standard-account requirement (weekend holding is not
permitted). Residual risk is ordinary overnight gap risk on `XAUUSD ×2`, `USOIL.cash ×2`
and `US100.cash`. Swap is modelled as `0.00` in most snapshot streams — a documented
modelling artefact (`FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` §7 assumption 12), and it biases a
D1-heavy roster more than it biased the R0 control.

---

## 5. Notes carried into the plan

### 5.1 Mechanics drift already on the live terminal

`chart02.chr` runs `QM5_10706_tv-mon-ls` under magic `107060001` with
`ex5_sha = 6f290d49defd…`, but the binary installed on 2026-09-06 and the canonical repo
binary are both `eaffda6f03c8b422…`. The live binary was replaced after the install (the
file in `MQL5\Experts\QM_FTMO\` is dated 2026-09-06 22:42, the install ran 19:27). Same
pattern on `chart03.chr` (11421: live `4ff02978ae5d…`). The 2026-09-15 census records the
same two rows as `magic_held_by_other_binary`. Restaging 10706 from the canonical repo
binary is therefore a `MECHANICS_CHANGED` event on top of the composition change — harmless
here because the composition change already resets the cycle, but it must be stated in the
receipt rather than discovered later.

### 5.2 Magic carry-over is safe only if the detach is sequenced first

`107060001` and `114220004` are reused by the new roster under the *same* magic. Because
the v1 profile is detached wholesale before the v2 profile loads (`CHART_PLAN.md` §2), these
are not two identities racing for one magic — the census's
`magic_collision_resolution = resolved_by_profile_replacement`. The sequencing is a
**deploy-plan obligation**, not something the registry enforces.

### 5.3 `trial_setpath` schema drift

The tool at HEAD emits `qm.ftmo-trial-setpath/**v3**` and binds the
`FTMO_2S_100K_STANDARD_V2` rulepack. The manifest `demo_install.py` validates — and the one
actually installed on 2026-09-06 — is **v2**, and that v2 manifest names the
`FTMO_2S_100K_SWING_V2` rulepack. The task specifies the v2 shape, so `sets/manifest.json`
here is v2-shaped with the Standard-account constraint block. Whoever generalises
`demo_install.py` must decide which schema is canonical; they currently disagree. Recorded
as `GAPS.md` G2.

---

## 6. Files in this package

| file | what it is |
|---|---|
| `PACKAGE.md` | this document |
| `CHART_PLAN.md` | chart-profile change plan, backup, rollback, verification |
| `RUNBOOK.md` | ordered operator steps with readback checks and stop conditions |
| `GAPS.md` | everything unverified or needing code, with effort estimates |
| `facts.json` | machine-readable evidence bundle (seals, hashes, magics, venue evidence, current profile) |
| `gather_facts.py` | read-only producer of `facts.json` |
| `build_sets.py` | read-only producer of `sets/` (wraps `trial_setpath.derive`) |
| `sets/*.set` | 8 derived live trial presets, INERT / REVIEW-ONLY |
| `sets/manifest.json` | `qm.ftmo-trial-setpath/v2`, sha256 `b18876a6e847a97772835ff2047c8463627e8c9d818b97a856fd08a1d4f38f5a` |
| `symlit_QM5_*.json` | per-EA symbol-literal scans (the B1 evidence) |
