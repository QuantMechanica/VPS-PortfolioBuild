# Book Ceremony Runbook — the day `book_build_guard` reports `qualified_pairs >= 25`

**Status:** operational runbook (evidence-only authoring; no state changed).
**Author:** Claude (board-advisor lane), 2026-09-03.
**Trigger condition:** `python tools/strategy_farm/book_build_guard.py --status --venue <v>` returns
`qualified_pairs >= 25` on a **real census** (contiguous-valid `highest_contiguous_valid_gate == Q14`
with a terminal requalification verdict). This is the CEO loop's end condition — the day a book
becomes buildable.
**Live status when this file was written (2026-09-03, read-only guard run):**
`qualified_pairs=5, distinct_eas=5, strategy_families=5, allowed=false`,
reasons `qualified_pairs_below_minimum: 5 < 25` + `owner_order_missing: venue=dxz`.
This runbook is dormant until the 5 becomes 25.

Every claim below cites the file, command, or decision it rests on. Nothing here is a substitute for
the Hard Rules (`01 Identity/Hard Rules`), DL-089, or the OWNER's Stehende Vollmacht ROT zone.

---

## 0 · Zusammenfassung für OWNER (DE)

An dem Tag, an dem der Guard **25 qualifizierte Paare** meldet, entscheidest **nur du** Folgendes,
und **nichts davon passiert automatisch**:

1. **Auftrag erteilen (ROT):** Der Buchbau startet erst, wenn du `decisions/JJJJ-MM-TT_owner_book_order_<dxz|ftmo|both>.md`
   anlegst — mit der **exakten** Zeile `OWNER-ORDER: BOOK_BUILD <venue> <datum>`. Ohne diese Datei
   verweigert `book_build_guard` jeden Builder und den T_Live-Deploy (fail-closed).
2. **Venue wählen (V3):** DXZ (Fund-Motor) und/oder FTMO (Cash-Motor). Empfehlung Stand heute: **DXZ zuerst**.
3. **5 Vorlagen (V1–V5)** unter §3 abzeichnen: Wiedereinstiegs-Reihenfolge, Konzentrations-Cap,
   Venue, Korrelations-Beweisstandard, News-Bindung.
4. **Risk-Freeze:** Der Buchbau schreibt eine neue Live-Komposition. Der aktuelle Freeze
   (`live_risk_freeze.json`, ACTIVE seit 31.08.) blockiert genau das. Du musst ihn **schriftlich**
   heben — kein AI-Seat hebt ihn per Schlussfolgerung.
5. **Deploy-Manifest signieren (ROT):** Q16-Checkliste (11 Punkte). Du signierst das Manifest;
   Claude verifiziert SHA256/Magic/Setfile/News.
6. **AutoTrading einschalten (ROT, nur du):** Der letzte Klick in MetaTrader gehört **ausschließlich**
   dir. Kein AI-Seat — Claude eingeschlossen — legt den Schalter um.

Was der AI-Seat (Claude) an dem Tag tut: den Pool messen, den Fit-Report bauen, den Copy-Plan als
Dry-Run erstellen, SHA256/Magic/Setfile/News verifizieren, alles als Evidenz unter `docs/ops/`
und `decisions/` protokollieren. Was **nie** automatisch passiert: Auftrag, Freeze-Lift, Signatur,
AutoTrading, Roster-/Gewichts-Anwendung auf T_Live.

---

## 1 · Preconditions — exact commands and expected outputs

### 1.1 Census / guard authority (the gate itself)

```powershell
cd C:/QM/repo
python tools/strategy_farm/book_build_guard.py --status --venue dxz `
  --db-path D:/QM/strategy_farm/state/farm_state.sqlite --order-dir decisions
```

- **Definition of a qualified pair** (`book_build_guard.py:72-84`, delegating to
  `rebaseline_census.build_pairs` / `summarise_pair`): an `(EA, symbol)` pair whose
  `highest_contiguous_valid_gate` equals the manifest's **terminal requalification gate**. That gate
  is resolved by evidence role, not by a hard-coded number
  (`gate_manifest.py:126-136`, `EVIDENCE_ROLE_PREFIXES["HEAD_TO_HEAD"] =
  "SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT"`), which is vault **Q14 Best-Settings
  Head-to-Head**. PASS-class terminal verdicts are `PROMOTE_CHALLENGER`, `CHALLENGER_PROMOTED`,
  `KEEP_INCUMBENT`, and historical `ADMIT_BOTH` (`rebaseline_census.py:100-111`).
- **Threshold:** `MIN_QUALIFIED_PAIRS = 25` (`book_build_guard.py:28`).
- **Trigger-day expected output** (`allowed:true` only when BOTH conditions hold):
  ```json
  { "allowed": true, "qualified_pairs": 25, "distinct_eas": <n>,
    "strategy_families": <n>, "order_artifact": "<abs path to owner_book_order>", "reasons": [] }
  ```
- **Exit codes** (`main`, `book_build_guard.py:232-243`): `0` when `allowed`, `2` when refused.
  Any `qualified_pool_unavailable: <Error>` reason means the census raised — the guard fails closed
  and reports it rather than guessing.
- **Read-only proof:** the guard opens the DB via `rebaseline_census.open_ro()` (`mode=ro` URI); it
  never writes the farm DB, queues, verdicts, factory, deploy tree, or AutoTrading state
  (`book_build_guard.py:1-7`, docstring; verified in `docs/ops/evidence/2026-08-23_rb-book-guard.md`).

**Read the count as three numbers, not one.** Until contract ratification the guard reports
`qualified_pairs` (canonical `(EA,symbol)`), `distinct_eas`, and `strategy_families` separately
(`book_build_guard.py:87-107`, vault Q15 §Buch-Trigger). 25 pairs concentrated in 6 EAs or 4 families
is not the same book as 25 orthogonal edges — carry all three into the V1/V2 decisions.

### 1.2 OWNER order artifact (the second mandatory authority)

- **Location:** `decisions/` (`DEFAULT_ORDER_DIR = REPO_ROOT / "decisions"`, `book_build_guard.py:32`).
- **Filename schema (regex, `book_build_guard.py:33-36`):**
  `^(?P<date>\d{4}-\d{2}-\d{2})_owner_book_order_(?P<venue>dxz|ftmo|both)\.md$`
  → e.g. `decisions/2026-11-14_owner_book_order_dxz.md`.
- **Mandatory content line (exact, `book_build_guard.py:150`):**
  `OWNER-ORDER: BOOK_BUILD <venue> <date>` where `<venue>` and `<date>` are taken **from the filename**
  (so `OWNER-ORDER: BOOK_BUILD dxz 2026-11-14`). The line must appear verbatim (stripped) somewhere in
  the file; the file is read `utf-8-sig` (`book_build_guard.py:152`).
- **Validity rules** (`_find_owner_order`, `book_build_guard.py:116-170`): date must not be **future**
  (`owner_order_future_dated`); venue must be **compatible** with the request — a `dxz` request accepts
  a `dxz` or `both` order, `ftmo` accepts `ftmo` or `both`, and a `both` request needs a `both` order
  (`_compatible_order_venues`, `book_build_guard.py:110-113`); a malformed date is `owner_order_invalid_date`;
  a missing line is `owner_order_invalid`; no matching file is `owner_order_missing`.
- **There is no generator today** — this is a hand-authored decision file (gap G1, §6). Draft it with
  the standing DL/decision provenance conventions and commit it with an explicit pathspec (Worktree
  Discipline in CLAUDE.md).

**As of 2026-09-03 no `*_owner_book_order_*.md` exists in `decisions/` — this is expected.** The order is
the OWNER's ROT act on the trigger day, not a standing artifact.

### 1.3 Risk-freeze must be liftable and lifted

```powershell
python tools/strategy_farm/risk_freeze.py status
# reads D:/QM/reports/state/live_risk_freeze.json (risk_freeze.py:36)
```

- The freeze is **ACTIVE** (armed 2026-08-31T05:12Z, `OWNER-DEC-RISK-FREEZE`; evidence
  `docs/ops/evidence/2026-09-02_ceo_wave1_dxz_live_book_governance.md` §2). It freezes per-sleeve
  RISK_PERCENT, the roster, deployed preset bytes + bound binaries, and **all new live promotions** —
  exactly what a book build produces.
- Both book builders call `risk_freeze.assert_live_book_mutation_allowed(...)` **before writing a
  manifest** (`build_book_dxz.py` main, before `write_json`; same in `build_book_ftmo.py`), and
  `deploy_tlive_book.py` calls it before any apply (`deploy_tlive_book.py:129` guard order). So a book
  cannot be minted or deployed while the freeze holds.
- **Three lift conditions** (`risk_freeze.py:LIFT_CONDITIONS`, all currently unmet): SP-A1/A2
  (signed `live_deployment_pointer.json`), NEWS-CONTRACT-V2 (`qm.news_impact_mapping.v1`, task
  `84c988e6`), GOVERNOR-HARDENING (v2 monitor + action adapter, SP-C1). **Lift rule (verbatim):**
  "All three conditions met AND an explicit written OWNER lift. No AI seat lifts this freeze, and no
  seat lifts it by inference from a condition merely being satisfied."

### 1.4 Sanity checks before the ceremony

```powershell
# concentration policy is OWNER-ratified (else DXZ builder returns CONCENTRATION_POLICY_UNRATIFIED)
python -c "import json;print(json.load(open('tools/strategy_farm/config/concentration_tail_limits.v1.json'))['status'])"
# expect: OWNER_RATIFIED   (ratified 2026-09-02, decisions/2026-09-02_owner_receipts_ceo_asks.md)

# factory idle enough / T_Live healthy (informational; T_Live is independent of factory state)
python tools/strategy_farm/farmctl.py health
```

Expected: concentration policy `OWNER_RATIFIED` (symbol 40%, asset-class 60%, family 50%, session
warn/breach 60/70, stop-risk budget 2.5% — `concentration_tail_limits.v1.json`; design
`docs/ops/SP-C3_CONCENTRATION_TAIL_LIMITS_DESIGN_2026-08-22.md`). If it is still
`PROPOSED_OWNER_RATIFICATION_REQUIRED`, the DXZ builder cannot emit `APPLY_RECOMMENDED`
(`build_book_dxz.py:_final_status`).

---

## 2 · The ceremony — step list, actor, evidence artifact

Order matters: authority → analysis → OWNER selection → readiness → deploy → AutoTrading. Steps 1–5
are read-only/analytic and can be rehearsed; the live boundary is step 8+.

| # | Step | Actor | Command / action | Evidence artifact (path) |
|---|---|---|---|---|
| 1 | **Confirm census ≥ 25** | Claude | `book_build_guard.py --status --venue <v>` (§1.1) | `docs/ops/evidence/YYYY-MM-DD_book_census_<venue>.md` (guard JSON pasted + interpreted) |
| 2 | **OWNER issues the order** | **OWNER** | author + commit `decisions/YYYY-MM-DD_owner_book_order_<venue>.md` with the exact `OWNER-ORDER:` line (§1.2) | the order file itself |
| 3 | **Re-run guard → `allowed:true`** | Claude | `book_build_guard.py --status --venue <v>` (now finds the order) | appended to the step-1 evidence file; `order_artifact` is non-null, `reasons:[]` |
| 4 | **OWNER lifts the risk-freeze** | **OWNER** | written lift + (SP-A1/A2) a **signed** `live_deployment_pointer.json` via `generate_live_deployment_pointer.py --signed --approved-by OWNER --approval-evidence decisions/...md` (`generate_live_deployment_pointer.py:155-162,204-206`) | `decisions/YYYY-MM-DD_owner_risk_freeze_lift.md`; signed `D:/QM/reports/state/live_deployment_pointer.json` |
| 5 | **Build the book (dry-run analytic)** | Claude (factory analysis) | DXZ: `python tools/strategy_farm/portfolio/build_book_dxz.py --order-dir decisions [--total-risk-pct N --sleeve-cap-pct N]` · FTMO: `build_book_ftmo.py` | `D:/QM/reports/portfolio/book_dxz_<as_of>/manifest.json` + `evidence.md` (`build_book_dxz.py` main, `evidence_markdown`) |
| 6 | **Portfolio fit report for OWNER** | Claude | correlation matrix + family clustering + symbol coverage + marginal Sharpe + ENB + risk-budget proposal (vault Q15 §"Analysis Prepared for OWNER"; tool gap G2, §6) | `D:/QM/reports/portfolio/q11_fit_<date>.md` (vault Q15 step 3) |
| 7 | **OWNER selects sleeves + weights** | **OWNER** | reads fit report; decides which `(EA,symbol)` join, order, risk % (vault Q15 §"OWNER Decision Process") | `decisions/YYYY-MM-DD_q11_portfolio_<batch>.md` (selected EAs, risk allocation, reasoning, expected Sharpe/MaxDD) |
| 8 | **Q16 Operational Readiness (11 checks)** | Codex (checks) + **OWNER** (sign) + Claude (verify) | per vault Q16 checklist; OWNER signs the deploy manifest | `decisions/deploy/QM5_<NNNN>_<symbol>_<date>.yaml` (signed) — one per sleeve |
| 9 | **Stage presets at book risk** | Claude | `python tools/strategy_farm/portfolio/stage_tlive_presets_risk.py --manifest <selected manifest> --out-dir <staging> [--apply]` (dry-run default; read-only vs T_Live) | staging dir under `D:/QM/exports/…` + per-file SHA proof (`stage_tlive_presets_risk.py` docstring) |
| 10 | **Deploy copy-plan (dry-run then apply)** | Claude (dry-run) + **OWNER** (approval evidence) | `python tools/strategy_farm/deploy_tlive_book.py --plan <plan.json> [--apply --backup-dir <outside T_Live>]` | copy-plan `qm.tlive_book_copy_plan.v1` JSON; dry-run report; backup dir |
| 11 | **Claude T_Live verification** | Claude | SHA256 factory==T_Live, magic formula, setfile ENV/risk, news calendar (see §4) | `decisions/YYYY-MM-DD_t_live_<ea>_<symbol>.md` with the SHA table |
| 12 | **AutoTrading ON** | **OWNER ALONE** | OWNER flips AutoTrading in MetaTrader on T_Live | note the toggle timestamp in the step-11 decision record |
| 13 | **Q17 Live Burn-In** | OWNER (authority) + Claude (monitor) | 14-day min, min-lot, KS kill-switch, Myfxbook/pulse monitoring (vault Q17) | `D:/QM/reports/state/live_book_pulse.json` cadence |

Step-5 note on builder semantics: both builders are **fail-closed analytic dry-runs** and cannot
deploy (vault Q15; `build_book_dxz.py` docstring lines 1-8). The DXZ builder emits one of
`APPLY_RECOMMENDED` / `NOT_WORSE_BAR_NOT_MET` / `CONCENTRATION_CAP_BREACH` /
`CONCENTRATION_POLICY_UNRATIFIED` (`build_book_dxz.py:_final_status`). `APPLY_RECOMMENDED` requires the
incumbent "not worse" gate to pass on identical sealed common history **and** an OWNER-ratified
concentration policy — application to live weights is still a separate OWNER ceremony (steps 7–12),
never the builder's act.

---

## 3 · OWNER decisions needed BEFORE that day (one-line Vorlagen)

These are the standing decisions to settle **before** the census hits 25, so the trigger day is
execution, not deliberation. V1–V5 are carried verbatim-in-substance from
`docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md` §5 (still the current
frame); V0/V6 are added for the ceremony.

- **V0 — Which pool grows to 25 (re-entry commissioning).** Options: (a) push all audited candidates
  through the full chain to Q14; (b) push the Q09-anchored members first (hash-bound Q08 reusable —
  cheapest distance to Q14); (c) push only a curated orthogonal set. **Rec: (b) then (c).** **Cost of
  waiting:** the 25-floor stays where it is; no book is evaluable while the reservoir idles.
  *(This is the CEO loop's actual work item — the highest-leverage single move, per dossier §8. Not
  authorized by this runbook.)*
- **V1 — Re-entry sequencing of audited members.** Options: (a) all; (b) the Q09-anchored first;
  (c) the 7-member what-if set; (d) none yet. **Rec: (b) then (c).** **Cost of waiting:** floor stays at 5.
- **V2 — Concentration control for the eventual FTMO book.** The FTMO builder does **not** cap at one
  EA per symbol: `build_book_ftmo.py` `select_under_aggregate_control` (`build_book_ftmo.py:181`) admits
  multiple EAs on the same symbol and controls risk at the **aggregate** level, per the ratified Q11
  FTMO-lane design (Vault `03 Pipeline/Q11 Portfolio Construction`, OWNER 2026-08-21;
  `build_book_ftmo.py:57-60`); the manifest stamps
  `symbol_policy = MULTIPLE_EAS_PER_SYMBOL_ALLOWED__AGGREGATE_CONTROL_…` (`build_book_ftmo.py:545-548`).
  Still **open** is ratifying the two aggregate thresholds it runs on, both flagged
  `WORKING_DEFAULT_OPEN_OWNER_ITEM`: pairwise-correlation/cluster reject `max_pairwise_correlation = 0.50`
  and account-wide `account_weight_budget = 10.0` (`build_book_ftmo.py:70-71` values, `:291,293` status;
  the header block `:62-69` states they "must be ratified before any book is constructed"). Options:
  (a) ratify the working defaults as-is; (b) set FTMO-specific numbers; (c) additionally impose an
  explicit per-symbol/per-family cap above SP-C3. **Rec: (a)**, with the OWNER-ratified SP-C3 caps
  (symbol 40%, asset-class 60%, family 50% of the 2.5% stop-risk budget — `concentration_tail_limits.v1.json`)
  and the Vault Q15 hard caps (**family ≤ 3, symbol ≤ 2, 10–15 EAs**) as the binding concentration
  controls; revisit once a real ≥ 25 pool exists. **Cost of waiting:** none today (no book); the builder
  refuses on unratified thresholds, so this must be settled before Buch 2 is constructed.
  **DECIDED (OWNER 2026-09-04, receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`, `OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904`):** Option (a) — `max_pairwise_correlation = 0.50` and `account_weight_budget = 10.0` become `OWNER_RATIFIED`, together with the OWNER-ratified SP-C3 caps and the Vault Q15 hard caps (family ≤ 3, symbol ≤ 2, 10–15 EAs) as the binding concentration controls; the FTMO builder status moves to `OWNER_RATIFIED` referencing this receipt.
- **V3 — Venue targeting.** Options: (a) DXZ-only; (b) FTMO-only; (c) both. **Rec: (a) DXZ-first** —
  slow D1 density fits an uptime/fund book, not a 60-day sprint; FTMO after density *Veredelung*
  (DL-089 pattern filter). The order artifact's venue token binds this (`<dxz|ftmo|both>`, §1.2).
  **Cost of waiting:** FTMO cash-motor payouts deferred; forcing slow sleeves into a sprint risks failure.
- **V4 — Correlation evidence standard.** Options: (a) accept sparse-stream correlation as a screening
  prior; (b) require fresh Q14-terminal streams with **≥ 60-day overlap** before any orthogonality
  claim. **Rec: (b)** — the tool's own floor is `min_overlap_days = 60`
  (`portfolio_correlation.py:build_artifact`), and existing streams fail it (dossier §3c). Vault Q15
  hard rule: **|r| < 0.5** between any two EAs' Q10 equity curves. **Cost of waiting:** correlation
  truth deferred until the first Q14-terminal cohort produces bound streams.
  **DECIDED (OWNER 2026-09-04, receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`, `OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904`):** Option (c) — adopt the two-stage sparse-D1 orthogonality standard as the method now (ZK-SBB certify/abstain + COS flag); the numeric thresholds stay `WORKING_DEFAULT_OPEN_OWNER_ITEM` until calibrated on the first SHA-frozen Q14 cohort. Standard: `docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md`.
- **V5 — News-calendar binding before FTMO.** Options: (a) require a bound current-calendar hash +
  terminal Q10_NEWS per member; (b) evaluate pre-news. **Rec: (a) for FTMO** (145-cell compliance
  matrix), pre-news acceptable only for DXZ screening. **Cost of waiting:** FTMO evaluation blocked
  until the Q10_NEWS bottleneck clears (§6 G7).
- **V6 — Book risk level.** Options: (a) DXZ builder default `--total-risk-pct 9.75` (the 07-19 live
  level); (b) a higher target (the 07-26 FINAL22 exercise raised it to 12.0). **Rec: hold 9.75 until a
  significantly better book number exists** (the deferral logic in
  `T_LIVE_DEPLOYMENT_RUNBOOK_TOTALRISK12_2026-07-26.md`). **Cost of waiting:** none; a raise scales
  uncapped sleeves and must be re-justified against decay/swap.
  **DECIDED (OWNER 2026-09-04, receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`, `OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904`):** Option (a) — hold book risk at 9.75% (no code change).

---

## 4 · T_Live deployment checklist (Q16 — all 11 must PASS; AutoTrading = OWNER only)

Source: vault `03 Pipeline/Q16 Operational Readiness.md`; Hard Rules; CLAUDE.md "T_Live Live Trading".
Claude's four Hard-Rule verifications (Q16 §"Verification by Claude") sit inside this list as #1/#3/#4/#5.

1. **`.ex5` compiles cleanly on T_Live** (fresh compile, not a factory copy) — Codex; compile log.
2. **Deploy manifest created** — Codex; `decisions/deploy/QM5_<NNNN>_<symbol>_<date>.yaml`
   (schema in vault Q16 §"Deploy Manifest Schema").
3. **SHA256 of `.ex5` matches factory → T_Live** — **Claude**; hash table in the decision record.
   `deploy_tlive_book.py` enforces this per copy item: each plan item carries `sha256`, the tool
   recomputes the source hash and refuses on mismatch, then re-verifies the temp copy hash before the
   atomic rename (`deploy_tlive_book.py:load_and_validate_plan`, `execute`).
4. **Magic number registered + unique**, formula `ea_id * 10000 + slot` — Claude/Codex;
   `framework/registry/magic_numbers.csv` (`portfolio_manifest.py:DEFAULT_MAGIC_REGISTRY`). Every
   preset's `ea_id*10000 + qm_magic_slot_offset` must equal the manifest `magic_number`
   (T_Live runbook step 4). NEW sleeves need a fresh, non-colliding slot assigned before staging.
5. **Set-file ENV = live, `RISK_FIXED = 0`, `RISK_PERCENT` set** (per Q15 allocation) — Claude.
   Backtest uses `RISK_FIXED`, live uses `RISK_PERCENT` (Hard Rule). `stage_tlive_presets_risk.py`
   patches only the `RISK_PERCENT=` line and normalizes lying header comments (`HEADER_FIXES`), emitting
   a per-file diff proof. `risk_freeze.py` reads `RISK_PERCENT`, `RISK_FIXED`, `PORTFOLIO_WEIGHT`,
   `qm_magic_slot_offset` per preset (`risk_freeze.py:KEY_RE`) — the sum of RISK_PERCENT must equal the
   manifest total (±1e-6).
6. **Commission / swap matches DXZ Live broker schedule** — Codex; tester groups file
   (`MQL5/Profiles/Tester/Groups/<server>_<account>.txt`). No invented commission/swap/DST values
   (Hard Rule); worst-case model is `framework/registry/live_commission.json` (`worst_case_dxz_ftmo`).
7. **DST timezone correct on T_Live** (GMT+2 outside US DST, GMT+3 during) — Codex; terminal screenshot.
8. **Kill-switch threshold defined + tested** — Codex; in manifest. Note the known 23/24 KS gap on
   10440/NDX (no passing Q10 to derive a baseline from — do **not** synthesize one;
   `2026-09-02_ceo_wave1_dxz_live_book_governance.md` §4).
9. **Symbol routing:** backtest `.DWX` custom symbol → live broker symbol — Codex; routing log.
   Live charts/presets use **bare** broker symbols (EURUSD, XAUUSD…), `.DWX` is tester-only
   (T_Live runbook step 5). **Confirm per-symbol live-order mapping against
   `framework/registry/dwx_symbol_matrix.csv`** — only `SP500.DWX` currently carries an explicit
   `live_order_status=ORDER_ROUTABLE_CONFIRMED`; other symbols have empty routing cells and must not
   be treated as confirmed-tradable (dossier §1e).
10. **News calendar present and current (age < 14 days / 336 h)** — Claude. Live = **native MT5
    calendar** (DL-080; CSV staleness is tester-only). After terminal restart, re-check both
    `NEWS_CALENDAR_LOADED rows=…` and `KILL_SWITCH_INIT` (showing the **relative** `QM\halt\` path) in
    `MQL5\Files\QM\QM5_*_ea-*.log` (T_Live runbook step 6). Manifest field
    `news_calendar_max_age_hours: 336`.
11. **OWNER signs the deploy manifest** (Q16 #3, ROT) and **Claude records** the full verification under
    `decisions/YYYY-MM-DD_t_live_<ea>_<symbol>.md`. Then, and only then, **OWNER ALONE flips
    AutoTrading** on T_Live (Hard Rule — no AI seat, Claude included, toggles it).

Deploy tool guardrails (`deploy_tlive_book.py`): schema `qm.tlive_book_copy_plan.v1`; targets only
`MQL5/Presets` (`.set`) and `MQL5/Experts/Live EAs` (`.ex5`) under `C:\QM\mt5\T_Live\MT5_Base`
(`ALLOWED_TARGET_PARENTS`); `owner_approval_evidence` must name an existing file; `book_build_guard`
is required **even for a dry-run** (`deploy_tlive_book.py:129`); `--apply` requires `--backup-dir`
**outside** T_Live and the risk-freeze guard passes first. Dry-run is the default.

---

## 5 · Rollback and abort criteria

**Abort the ceremony (do not proceed) if any of:**
- `book_build_guard` returns `allowed:false` for the requested venue at step 3 — a missing/invalid/
  future/wrong-venue order or a pool that dropped back below 25 (`book_build_guard.py:_find_owner_order`,
  `check_book_build_allowed`). Fix the cause; never bypass the guard.
- The census reason contains `qualified_pool_unavailable` — the census raised; treat as unknown, not zero.
- Risk-freeze is ACTIVE and unlifted (`risk_freeze.py status` non-inactive) — builders and deploy
  refuse; wait for the written OWNER lift + signed pointer.
- Concentration policy status ≠ `OWNER_RATIFIED` — DXZ builder returns
  `CONCENTRATION_POLICY_UNRATIFIED`; the book is not applyable.
- DXZ builder status is `CONCENTRATION_CAP_BREACH` or `NOT_WORSE_BAR_NOT_MET` — the proposal is worse
  than incumbent on identical history or breaches a ratified cap; do not deploy, revise composition.
- Any Q16 check is not GREEN — deployment is blocked until fixed and the full checklist re-run (vault Q16).
- A SHA256 mismatch at step 3/11, a magic collision, an ENV/risk-mode mismatch, or a stale/absent news
  calendar — abort the deploy; these are the exact things Claude's verification exists to catch.

**Rollback after a partial deploy (steps 9–12):**
- **Presets:** the deployed set is preserved in the staging report (deployed SHA256) and in the
  `--backup-dir` captured by `deploy_tlive_book.py` before replacement. Redeploy the prior presets
  from the backup dir.
- **Binaries:** restore the prior `Live EAs\` set from the dated backup taken before the copy.
- **Risk level:** the 9.75 presets reproduce exactly via the builder defaults
  (`gen_dxz_final_manifest.py`/`build_book_dxz.py --total-risk-pct 9.75`).
- **Deploy pointer:** if a signed pointer was minted for a composition that is then rolled back,
  re-mint an unsigned pointer for the restored composition; a signed pointer is OWNER/ROT to replace.
- **In-flight ambiguity:** halt via the manual halt files (post-fix relative `QM\halt\` channel),
  **not** by toggling AutoTrading mid-session (T_Live runbook §Rollback).
- **DL-089 guardrail:** a requalification failure of a *rebuilt* binary excludes that sleeve from the
  **next** book — it does **not** trigger a live change on the deployed binary. Pulling a live sleeve
  because a different binary failed is acting on evidence about the wrong artifact
  (`DL-089` §3). Exception: a mechanism defect / lookahead that transfers across binaries → escalate
  to OWNER immediately.

---

## 6 · Tooling gaps (with a proposed router task per gap)

Each gap is real today and would slow or endanger the trigger day. Router tasks are proposals for the
Orchestrator to commission — none is enqueued by this runbook.

- **G1 — No OWNER order generator/template.** The guard hand-parses
  `decisions/YYYY-MM-DD_owner_book_order_<venue>.md` but nothing writes or validates one, so a typo in
  the `OWNER-ORDER:` line fails silently as `owner_order_invalid`.
  → **Router task (Codex, `ops_issue`, prio 60):** add `decisions/templates/owner_book_order_TEMPLATE.md`
  + a `mint_owner_book_order.py` writer that emits the exact filename+line and round-trips through
  `book_build_guard._find_owner_order`. Payload: venue enum, date, provenance header.
- **G2 — No Q15 fit-report generator.** Vault Q15 step 3 promises `q11_fit_<date>.md` (correlation
  matrix, family clustering, symbol coverage, marginal Sharpe, **ENB**, risk-budget) but no single tool
  produces it bound to Q14-terminal streams; `build_book_dxz.py` emits a manifest, not the OWNER-facing
  fit report. → **Router task (Codex, `ops_issue`, prio 55):** build `q15_fit_report.py` consuming the
  qualified-pool streams; ENB + marginal-Sharpe + `|r|<0.5`/family≤3/symbol≤2 cap checks; markdown +
  visualizations to `D:/QM/reports/portfolio/q11_fit_<date>.md`.
- **G3 — Correlation standard for sparse D1 streams (V4).** `portfolio_correlation.py` hard-floors at
  `min_overlap_days=60`; slow daily sleeves 0-filled over the union window drive |r|→0 mechanically and
  fail the floor (dossier §3c). → **Router task (Claude/research, `ops_issue`, prio 50):** define an
  orthogonality standard for sparse D1 (trade-level co-activity, block bootstrap, or ENB on returns) and
  a refutation criterion; feed the V4 decision. Refute-or-adopt, no invented thresholds.
- **G4 — FTMO aggregate concentration control is already implemented; only threshold ratification is
  open (no tooling gap).** The earlier per-symbol cap was **replaced** by `select_under_aggregate_control`
  (`build_book_ftmo.py:181`) — pairwise-correlation/cluster reject + account-wide risk budget, fail-closed
  when a correlation is missing — under task `9bdfde03-c9ef-43ce-b7ea-632347ad0f06`, which is **`PASSED`**
  (Orchestrator close 2026-08-21, commit a9b414c96; farm DB `agent_tasks`, read-only query). Multiple EAs
  per symbol are allowed (`symbol_policy = MULTIPLE_EAS_PER_SYMBOL_ALLOWED__…`, `build_book_ftmo.py:545-548`).
  → **No new router task; nothing to commission on Codex here.** The only residual is the **OWNER
  ratification** of the two `WORKING_DEFAULT_OPEN_OWNER_ITEM` thresholds (`max_pairwise_correlation = 0.50`,
  `account_weight_budget = 10.0`; `build_book_ftmo.py:70-71`), carried as Vorlage **V2 (§3)** — an OWNER
  act, not a build item. No FTMO book may be constructed until they are ratified (`build_book_ftmo.py:69`).
- **G5 — Deploy-pointer signature + authenticated consumers (freeze lift SP-A1/A2).**
  `live_deployment_pointer.json` is unsigned; `morning_brief.py` / `verify_live_deployment_contract.py`
  read UNKNOWN (governance evidence §2). → **Router task (Claude prep → OWNER sign, `ops_issue`, prio 70):**
  produce the unsigned dry-run pointer + provenance vorlage so OWNER's signing is a 2-minute review; roll
  the authenticated read into the consumers.
- **G6 — Governor v2 not enforcing (freeze lift GOVERNOR-HARDENING).** SP-C1 is approved + dry-run-proven
  (commit 593c9ddca) but the v2 monitor deploy + action adapter are OWNER/ROT and not live
  (`ACCOUNT_PORTFOLIO_GOVERNOR_CONTRACT_2026-08-22.md`). → **Router task (Codex, `ops_issue`, prio 65):**
  finish the v2 monitor + atomic account-wide pre-trade action adapter; OWNER-gated activation.
- **G7 — Q10_NEWS bottleneck blocks FTMO news binding (V5).** Near-zero service rate / 19–36-day
  latency on Q10_NEWS is the throughput wall for growing the census with news-bound members
  (dossier §5 V5; `Q09_NEWS_MACHINERY_RUNBOOK_2026-08-05.md`). → **Router task (Codex, `ops_issue`, prio 75):**
  land the Q10_NEWS v4 acceleration (contract in progress) — this is the CEO loop's critical path to 25.
- **G8 — End-to-end book path is unproven (0 rows in `Q15_DXZ`/`Q15_FTMO`).** Vault Q15 records the dual
  lanes have never carried a row; the builder→fit→stage→deploy chain has never run against a real ≥25
  pool. → **Router task (Claude, `ops_issue`, prio 45):** a Factory-analysis **rehearsal** of steps 5–10
  against the current 5-pair pool using a throwaway `--order-dir` (a scratch dir, never `decisions/`) and
  a scratch T_Live-shaped fixture — smoke-test the tooling now so the real day is not the first run. No
  T_Live write, no `decisions/` order, no freeze lift.

---

## 7 · Provenance

- **Tooling read:** `tools/strategy_farm/book_build_guard.py`, `gate_manifest.py`,
  `rebaseline_census.py`, `risk_freeze.py`, `deploy_tlive_book.py`,
  `generate_live_deployment_pointer.py`, `portfolio/build_book_dxz.py`, `portfolio/build_book_ftmo.py`,
  `portfolio/portfolio_manifest.py`, `portfolio/portfolio_correlation.py`,
  `portfolio/concentration_tail.py`, `portfolio/stage_tlive_presets_risk.py`,
  `tools/strategy_farm/config/concentration_tail_limits.v1.json`.
- **Decisions read:** `DL-064_portfolio_construction_layer.md`,
  `DL-089_live_book_full_chain_requalification.md`, `2026-08-12_DL-084_optimization_track_q14_q16_dual_book.md`,
  `docs/ops/T_LIVE_DEPLOYMENT_RUNBOOK_TOTALRISK12_2026-07-26.md`.
- **Evidence read:** `docs/ops/evidence/2026-08-23_rb-book-guard.md`,
  `docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md`,
  `docs/ops/evidence/2026-09-02_ceo_wave1_dxz_live_book_governance.md`.
- **Vault read:** `03 Pipeline/Q14 Best-Settings Head-to-Head.md`, `Q15 Final Portfolio Construction.md`,
  `Q16 Operational Readiness.md`, `Q17 Live Burn-In DXZ.md`.
- **Live guard run (read-only, 2026-09-03):** `book_build_guard.py --status --venue dxz` →
  `qualified_pairs=5, distinct_eas=5, strategy_families=5, allowed=false`.
- **Mutation statement:** this runbook created no book, manifest, sleeve, weight, allocation, deploy
  artifact, order file, live/T_Live state, gate threshold, verdict, trade stream, queue row, or DB
  change. It is documentation under `docs/ops/`. Every ROT action above remains a separate OWNER act.
