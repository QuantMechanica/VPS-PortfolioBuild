# News Calendar Repair Plan — Source-of-Truth Correction (E1-A)

- **Decision:** OWNER E1-A, 2026-09-05, receipt row 9, decision-bound task `0da3dfec`.
- **Author:** Claude (Orchestrator), planning lane. This document is a **PLAN + implementation spec**, not the repair. No production calendar file, bundle manifest, or `dxz23_execution_contracts.json` is modified by this work item.
- **Scope guard:** the repair corrects **event TIMESTAMPS and the coverage hole**. It does **not** resolve Contract V2 §7 (impact-classification reconciliation) and does **not** implement Contract V2 §3 (single-authoritative-source consumption). Both remain separate, OWNER-gated axes (see §1.3 and Open Questions).
- **Evidence base:** `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md` (+ dir), `..._diagnose.md`, `..._blast_radius/`; private lab `.private/secret_strategy_lab/NEWS_CALENDAR_CORRECTION_2026-07-11.md`; native exports `D:/QM/mt5/T_Export/MQL5/Files/T_EXPORT_<CCY>_HIGH_2018_2025_NATIVE.csv`.
- **r2 (2026-09-05):** rewritten against 13 review findings (3 data-integrity blockers, 6 majors, 2 minors, 2 pipeline majors, 1 pipeline minor). Principal changes: **native-match every USD high-impact event, delete the "do-not-touch" class** (F1); **anchor-gate every USD high-impact class, not just Class A/ET-0830** (F2); **forbid wall-clock recompute on the corrupted stored date** (F3); **native is the sole truth for the zero-tolerance classes, with an explicit reschedule/holiday policy** (F4); the 1 h seam is an **event-instant defect, not cosmetic** (F5); non-USD backfill **scoped to rate decisions with the remainder a surfaced declared gap** (F6); **counts pinned programmatically at repair time** (F7); **dxz23 reconciliation + no-mint-while-repin-pending** (F8); **q09 APPROVED_CORRECTION promoted to an explicit step with its OWNER receipt** (F9); **all four Common\Files mirrors incl. the SYSTEM systemprofile mirror** (F10); **execution reordered E1 → detectors fail-closed → E2 → E4** (F11).

---

## 0. The defect in one paragraph

Both production files store US 08:30-ET high-impact releases **~16–17 h early** for 78 % of 2018–2025 rows (NFP / Retail Sales / Unemployment Rate = 100 % wrong; CPI m/m, Avg Hourly Earnings, PPI, Unemployment Claims, Philly Fed, Core Retail Sales near-total). The events the r1 plan called "already correct" (ADP, ISM Mfg/Svcs, Fed Funds Rate, FOMC Press Conference, JOLTS, Crude) are **correct only for a majority of rows** — a measured minority is still shifted or sits on the DST seam (F1: Federal Funds Rate ~22/84 wrong incl. 9×Wed-17:00 seam, FOMC Press Conf ~11/68, ADP 16/124, ISM Mfg 21/126, ISM Svcs 35/126). Two high-impact Fed events — **FOMC Statement** (70/84 stored Tue 19:30/20:30, −17 h) and **FOMC Economic Projections** (34/40 Tue-shifted) — match **no class in r1** and would have been left at the wrong instant. Both files have a **zero-row coverage hole 2025-05 → 2026-06** (14 months); 2026-07+ is correct. The EA (`QM_NewsFilter.mqh`) **merges both files with no dedup and no fallback**, so a partial repair leaves the other file's displaced Thursday-evening blackouts live in the union. The live branch (T_Live) uses the **native MT5 calendar**, not these CSVs — the CSVs gate T_Live only for OnInit staleness/coverage.

---

## 1. Target state

### 1.1 Both files regenerated consistently (no EA change)

`QM_NewsFilter.mqh:927–944` loads **both** files, sums `g_qm_news_rows_loaded = rows_primary + rows_secondary`, and builds one global UTC index with **no cross-file dedup and no fallback**. Contract V2 §3 (`exactly one active source per run`) is an **unimplemented specification** — the consumption-layer single-source change is deferred Codex work gated on OWNER §7. Therefore:

> **Target = both files corrected to the identical, verified UTC instant set, with all derived columns regenerated. No consumer/EA code change in this work item.** Making one file authoritative (option b) is ROT-adjacent (touches an EA consumer) and is **explicitly out of scope** for E1-A.

### 1.2 Precedence / authority of content

- The **corrected event set is authored once** (the "corrected instant set", §2) and **projected into both file schemas**. PRIMARY (`news_calendar_2015_2025.csv`, 20-col, `datetime` verbatim-UTC) and SECONDARY (`forex_factory_calendar_clean.csv`, 9-col, `DateTime_UTC`) must carry **byte-identical UTC instants** for every event that exists in both.
- A large majority of primary rows are byte-identical instants with the FF-clean file today (`primary_rows_with_identical_ff_instant`). **The exact count is pinned programmatically at repair time (§6.3), not carried as a literal** — the diagnose headline reports ~46,349 and r1's 46,331 literal disagreed with it (F7). They share the same displacement and are corrected by the **same transform**, preserving cross-file identity.
- **Canonical content source = the corrected instant set** (native export + BLS/Fed anchors + offset-fan supplements). Neither existing file is "trusted as-is"; both are rewritten from the corrected set. This makes the two files a **consistent pair**, which is the strongest guarantee achievable without the §3 EA change.

### 1.3 Impact classification is NOT reconciled here

The two files disagree on impact for **41.7 % of 47 565 common events** (25.5 % High/Not-High flips) — Contract V2 §7, recorded pending 2026-08-22, **no OWNER decision**. E1-A is **timestamp-scoped**:

- Each corrected row **keeps its own file's existing `impact` / `is_high_impact` label**; the repair does **not** import the native `high` flag as a new impact taxonomy.
- **Exception (safe, mechanical):** where a row's timestamp is replaced by a native-export instant, the native record is `high`-only; this does not change the existing file's impact label — it only supplies a corrected time. `is_high_impact` in PRIMARY is **regenerated from the unchanged `impact` string** (§5), so no impact flips occur.
- §7 remains an open OWNER axis (Open Question 1). Flagged, not silently settled.

---

## 2. Per-row-class transformation (USD)

Reusable name map already codified: `tools/strategy_farm/research/quantify_news_calendar_defect.py:29–63` (`NAME_MAP_USD`, `ET_0830_CLASS`). Native USD ground truth: `T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv` (4189 rows, `broker_time` = true UTC, high-only, 2018-01..2025-12) + `T_EXPORT_USD_HIGH_2025_NATIVE.csv` (481 rows, all 2025). Private-lab validated build: `.private/.../build_native_usd_calendar.py` → `t_export_native_usd_high_2018_2025.csv` (4197 rows, +10 official BLS 2025-lapse revised rows, 6 asserted UTC anchors).

### 2.1 Design principle (r2): native replacement is idempotent — apply it to the whole map

The r1 plan carved out a "Class C — do not touch" set for the already-mostly-correct events. **Deleted in r2 (F1).** Native replacement of an already-correct row is a **no-op** (the stored instant already equals the native instant, so the ±5 min match passes and the value is unchanged); native replacement of a wrong minority row **repairs it**. There is therefore **no reason to preserve any wrong instant**, and every USD high-impact event that has a native match is native-matched. "Keep-as-is" survives **only** for medium/low non-class events with no ground truth (Class E).

### 2.2 Map extension required before the transform (F1, F3)

Two edits to `NAME_MAP_USD` are prerequisites; both map a corrupted FF name to its native truth name (native names verified present in the export, see §2.5):

1. **`FOMC Statement` → `Fed Interest Rate Decision`** and **`FOMC Economic Projections` → `Fed Interest Rate Decision`** (F1). These fire at the FOMC decision instant; the native "Fed Interest Rate Decision" record (n=65) carries the true UTC. Absent this, 70/84 + 34/40 rows stay at Tuesday-evening −17 h instants under any r1 class.
2. **The four high-impact ET-0830 events that were in `ET_0830_CLASS` but not `NAME_MAP_USD`** — **Core PPI m/m, Empire State Manufacturing Index, Building Permits, Trade Balance** — get native map entries so they become native-matched Class A instead of routing through the (forbidden, F3) wall-clock recompute. Native truth names to be confirmed at build time against the export header (§2.5); if a native name is absent for one of these, it falls to the **conservative over-block** policy (§2.4), never to stored-date recompute.

### 2.3 Class table (USD)

| Class | Definition | Transform | Source of truth | Confidence | EA-relevant? |
|---|---|---|---|---|---|
| **A** | USD, `impact=high`, event ∈ (extended) `NAME_MAP_USD`, **native match** on (name, calendar date, ±36 h join) | Replace timestamp with the **native instant** (`broker_time`, true UTC). Idempotent on already-correct rows; repairs the wrong minority. | Native export + BLS/Fed anchors | **HIGH** (anchor share ≥0.99 target; 1.00 for the zero-tolerance set) | **YES** |
| **B′** | USD, `impact=high`, event ∈ `ET_0830_CLASS`, **no native match** for that (name, month) | **Conservative over-block (Option B), or declared gap** — **never** a wall-clock recompute on the stored date (F3). See §2.4. | Native truth or nothing | **N/A (over-block)** | **YES** |
| **D** | USD, `impact` ∈ {medium, low}, event ∈ `ET_0830_CLASS`, no native | **Over-block (Option B)** across the nominal ET-0830 window, or leave inert. **Not** a stored-date recompute. | class rule → over-block | **N/A** | **NO — INERT** (EA blocks `impact>=HIGH` only) |
| **E** | USD, medium/low, event ∉ `ET_0830_CLASS`, no native | **KEEP AS-IS** (no ground truth, not a member of the shifted class) | n/a | keep | NO — INERT |

**There is no Class C in r2.** Every USD high-impact event is either Class A (native-matched, idempotent) or Class B′ (over-block / declared gap). Nothing high-impact is "kept as-is at a possibly-wrong instant."

### 2.4 Why wall-clock recompute is forbidden, and what replaces it (F3)

The r1 Class B/D recompute keyed 08:30 ET on the **stored calendar date**. Measured, the true-Friday NFP release is stored on **Thursday** (`is_first_friday=0`, `day_of_week=3`), so recomputing 08:30 ET on the stored Thursday date yields **Thursday 13:30Z — a full day before** the true Friday 13:30Z, i.e. a blackout placed a day early. Class B/D are exactly the no-native-match residuals, where **no independent source recovers the true date**, so they **cannot** be anchored to their own corrupted date.

Replacement policy for a no-native-match high-impact ET-0830 residual:

- **First choice — extend the native map** so the event becomes Class A (done in §2.2 for the four known residuals).
- **Second choice — conservative union / over-block (Option B):** for the affected (event, month), place a blackout across the **full plausible ET-0830 daily window in UTC for both DST states** (i.e. block both 12:30Z and 13:30Z ±window on the *native-derived or officially-scheduled* date, never the stored date). Over-blocking never places a blackout a day early because the date comes from the schedule/native side, not the corrupted stored field. This over-blocks slightly (wider window) but is fail-safe.
- **Third choice — declared gap:** if neither native nor an official schedule can supply the date, the (event, month) is a **declared gap** in `repair_gaps.json`, surfaced in the manifest note. Never synthesize an instant from the stored date.

### 2.5 Native-name confirmation at build time

Before the transform runs, the Codex tool **asserts** each extended-map target name exists in the native export header set (Fed Interest Rate Decision n=65, FOMC Press Conference n=61, ADP n≈94, ISM n≈96, and the newly-mapped PPI/Empire/Building-Permits/Trade-Balance equivalents). A missing target name **halts the build with a named error** and routes that event to §2.4 over-block — it does not silently fall back to recompute.

**No rows are dropped** in the USD path. Every row is either corrected (A), over-blocked/declared-gap (B′/D), preserved-correct-by-idempotent-native (A no-op), or preserved-unverified (E, medium/low only). Dropping any row would trip `_assert_plausible` row-shrink guard and destroy audit continuity.

---

## 3. Non-USD handling

### 3.1 Finding

Native non-USD `broker_time` values are encoded **~3–4 h LATE** (opposite direction to USD). Confirmed two ways: (a) private lab validated against **14 official central-bank anchors** with a per-currency **offset fan**; (b) independent EURUSD M5 tick-volume footprint — the elevated-volume band sits at broker-epoch 15:15–16:15 (= 13:15–14:15 UTC: ECB decision 13:15 + US Advance GDP 13:30 + ECB presser 13:45), while the native-encoded 16:15 UTC sits in declining volume. Native non-USD exports exist for EUR (1054), GBP, JPY, AUD, CAD through 2025-12.

### 3.2 Offset fan (primary source of truth)

From `.private/.../native_calendar_multicurrency/build_validated_supplement.py:26–33` (`OFFSETS`), validated against `ANCHORS` (:35–49) + one official **BoC 2025-01-29 09:45-ET** override:

| Currency | Candidate offsets applied to native `broker_time` |
|---|---|
| JPY | raw (0 h) |
| AUD | raw / −3 h / −4 h |
| GBP | raw / −3 h |
| EUR | raw / −3 h |
| CAD | raw / −3 h |

The lab selects the offset per event class by matching the **official central-bank anchor**; the fan is a candidate set, the anchor is the selector. **Primary source of truth = the lab's anchor-selected offset per (currency, event class).**

### 3.3 Non-USD anchor coverage is rate-decision-dominant — this is a scoping fact, not a footnote (F6)

**Measured completeness of the anchor set.** Every offset ANCHOR in `build_validated_supplement.py:35–49` is a **central-bank rate decision**. A non-rate non-USD high-impact event (CPI / GDP / employment / PMI) has **no anchor to select its offset**, so the offset fan cannot be resolved for it and it becomes a **declared gap** unless a separate anchor is added. Consequence, stated plainly and carried into the manifest and the E2/E4 blast radius:

> **Non-USD backfill and correction is, for the offset-fan path, effectively scoped to rate decisions.** CPI/GDP/employment/PMI for EUR/GBP/JPY/AUD/CAD outside a rate-decision class are declared gaps unless a dedicated historical source is commissioned. GDAXI→EUR and UK100→GBP are therefore **under-blocked for non-rate events** across any window fed only by the offset fan.

Two ways forward (OWNER choice, Open Question 6):

- **(a) Scope-and-declare:** correct non-USD **rate decisions** via the anchor-selected offset; declare every non-rate non-USD high-impact class a gap in `repair_gaps.json`, surface it in the bundle manifest note, **and feed the affected symbol/window pairs into the E2 re-adjudication and E4 blast-radius inventory** (not a generic footnote). This is the E1-A-shippable path.
- **(b) Commission a proper non-USD historical source** (faireconomy archive or a per-currency official-schedule builder) for CPI/GDP/employment/PMI, then anchor those classes too. This is follow-up scope, not E1-A.

**The plan must state the measured per-currency HIGH completeness** in the verification evidence (§6.4) — how many native non-USD high rows exist per currency per year, and what fraction are rate decisions — so the under-block magnitude is quantified, not assumed.

### 3.4 Tick-volume verification (confirmation gate, not the primary source)

The task requires **3–5 anchors per currency**; only 1 (EUR/ECB) is footprint-checked so far. The verification suite (§6.5) must footprint-check a concrete anchor list **before reseal**. Critical caveat encoded as an acceptance criterion: the M5 `time` column is **broker wall-clock epoch** (`EXPORT_DWX_FX_M5.mq5:57` writes raw `rates[i].time`, GMT+2/+3), so the footprint test **must first convert M5 epochs to UTC by applying the US-DST-dependent broker→UTC offset (−2 h / −3 h)** before comparing to a candidate UTC instant — otherwise the comparison is itself off by 2–3 h.

**Concrete anchor list (min 3 per currency, all rate-decision-anchored plus at least one non-rate to size the gap):**

- **EUR** — ECB Interest Rate Decision (2025-01-30 13:15Z true; native +3 h), ECB Main Refinancing Rate 2024-09-12, plus one non-rate (Eurozone Flash CPI 2025-02) footprinted to **quantify** the non-rate gap.
- **GBP** — BoE Bank Rate 2024-08-01 & 2025-02-06 (11:00 London), plus one non-rate (UK CPI 2025-01-15, 07:00 London) for gap sizing.
- **JPY** — BoJ Policy Rate 2024-07-31 & 2025-01-24, Tokyo/National CPI 2025-01 (JPY offset raw=0 h must be *confirmed*, not assumed).
- **AUD** — RBA Cash Rate 2024-11-05 & 2025-02-18, plus AU CPI q/q 2025-01-29 for gap sizing.
- **CAD** — BoC Rate 2025-01-29 (already anchored, offset override 09:45-ET), plus CA CPI 2025-01-21 for gap sizing.

### 3.5 Declared gap policy

Where a currency-event class **fails the anchor test** (offset fan cannot reconcile to an official anchor within ±15 min after the DST-corrected footprint check) **or has no anchor at all** (non-rate classes, §3.3), that class is **declared a gap** in `repair_gaps.json` and the bundle manifest note rather than shifted on a guessed offset. A declared gap **under-blocks** the affected non-USD symbol, which is documented, quantified (§6.4), fed into E2/E4, and accepted for E1-A rather than fabricating a time. JPY raw=0 h in particular must be **confirmed** by footprint before it is trusted (it is the one currency the fan does not shift).

---

## 4. Coverage-hole backfill (2025-05 → 2026-06)

Root cause of persistence: `refresh_news_calendar.ps1:20` fetches only the **forward** weekly feed `ff_calendar_thisweek.json` — it appends the current week onward and **cannot backfill history**.

### 4.1 Fillable now from existing native exports (2025-05 → 2025-12)

- USD: `T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv` covers 2025-05..2025-12 (normal months 42–47 high rows/month); cross-check `T_EXPORT_USD_HIGH_2025_NATIVE.csv` (481 rows, all 12 months).
- **Reschedule / holiday months (F4):** native USD 2025-10 = 27 rows and 2025-11 = 26 rows vs the 38–47 normal band — the **2025 US government shutdown** delayed/cancelled BLS releases. For 2025-09..11 the fixed first-Friday / 08:30-ET schedule rule is **wrong**, and any rule-derived instant would be fabricated. **Policy: native is truth for these months; the reduced counts are recorded as native-sourced, not rule-derived; months native cannot supply are declared gaps.** The verification anchor gate (§6.1) for the zero-tolerance classes is computed **against the native/official instant, never the schedule rule**, precisely so an off-schedule shutdown release is accepted and a fabricated nominal instant is rejected.
- Non-USD: EUR/GBP/JPY/AUD/CAD natives cover through **2025-12-18**, but are **rate-decision-dominant** (§3.3). Non-rate non-USD high events in this window are declared gaps unless source (b) is commissioned. **Measured non-USD 2025 coverage ≈ 1 high event/month/currency** (AUD present only 02,04,05,07,08,09,11,12; CAD similar) — i.e. essentially rate decisions. This is stated in the manifest and fed to E2/E4, not folded into a generic footnote.
- USD medium/low events in this window are a **declared gap** (native path is HIGH-only). Inert to the EA blackout; stated in the manifest.

### 4.2 Requires a fresh export (2026-01 → 2026-06)

**Every** native export ends 2025-12-31. The 6-month window 2026-01..2026-06 needs a **new CalendarValueHistory export** from the T_Export terminal.

- **Script:** `.private/secret_strategy_lab/native_calendar_multicurrency/EXPORT_T_EXPORT_MULTI_HIGH_2018_2025.mq5`. **Change required:** raise the export upper bound from `to = D'2026.01.01'` (line 7) to **`to = D'2026.07.01'`**. (This edits a private-lab `.mq5`, not a production file — permitted; but the **run** is a manual T_Export terminal action.)
- **Runner:** OWNER/CEO, in the T_Export terminal (the one MT5 seat that owns `CalendarValueHistory`). This is an allowed manual MQL5 action per the task. **AI seats do not run it.**
- **Known failure mode:** 2025+ API extraction can time out with **error 5401** (documented). Mitigation: export **per-currency, per-year-half** (2026-H1 alone is a small range) to keep each call under the timeout; if 5401 recurs, retry the single failed currency. The static exported CSV is the deterministic input — never fall back to a live API pull inside the repair.
- **Output:** `T_EXPORT_<CCY>_HIGH_2018_2026H1_NATIVE.csv` (or an appended `_2026H1` sidecar) per currency, HIGH-only.
- **Verification of the export (before it feeds the repair):** (a) row count per **normal** month 2026-01..06 non-zero and in the 40–50/month band for USD (holiday/reschedule months allowed to run light, native is truth); (b) each currency's known 2026-H1 central-bank decision present at its official UTC instant (e.g. NFP 2026-01-09/02-06/03-06 13:30Z, FOMC 2026-01-28, ECB 2026-01-30 & 2026-03-12, BoE 2026-02-05); (c) no duplicate `event_id`; (d) monotonic `broker_time`.

### 4.3 Medium/low in the hole

Native is HIGH-only, so medium/low events across the **entire** hole (2025-05..2026-06) cannot come from the native path. **Decision:** leave as a **declared gap** for E1-A (inert to the HIGH-only EA blackout). A faireconomy archive backfill of medium/low is a **follow-up**, not part of E1-A (Open Question 2).

---

## 5. Regeneration of derived columns

The corrected instant set is projected into each file's exact schema; **all derived columns are recomputed from the corrected timestamp**, using the helpers already present in `refresh_news_calendar.ps1:159–201` (mirror them in the Codex tool so the transform matches the live refresh exactly).

### 5.1 PRIMARY (20 columns)

Recompute from corrected `datetime` (UTC verbatim):

- `day_of_week` — Monday=0 (`Get-MondayZeroDay`, :195).
- `hour` — hour of corrected `datetime`.
- `day` — day-of-month of corrected `datetime`.
- `is_first_friday` — `Get-FirstFridayFlag` (:190) on corrected date.
- `is_nfp`, `is_fomc`, `is_ecb`, `is_boe`, `is_gdp`, `is_cpi`, `is_pmi` — `Get-TitleFlag` (:182) on `event_name` (title-based; unchanged by a time shift, but recompute for consistency).
- `impact_numeric`, `is_high_impact` — from the **unchanged** `impact` string (`Get-ImpactNumber` / `ConvertTo-PrimaryImpact`). **No impact taxonomy change** (§1.3).
- `actual`, `forecast`, `previous`, `currency`, `event_name`, `impact` — carried through unchanged.

### 5.2 SECONDARY (9 columns)

- `DateTime_UTC` — the corrected instant, format `%Y.%m.%d %H:%M` (or `%H:%M:%S`). **This is the consumed event-instant column** — the 11:30Z / DST-seam rows are corrected here by the §2 native-match path and are **inside** the anchor gate (§6.1), not treated as cosmetic (F5).
- `Date` — date part of corrected `DateTime_UTC`.
- `DateTime_EET` — re-derived from corrected `DateTime_UTC`. **Note (scope of the "cosmetic/non-blocking" language — F5):** the non-blocking status applies **only** to this display column, which is **not consumed by the EA or the gate** (gate requires `DateTime_UTC`; EA prefers `DATETIME_UTC` header). Re-derive it with the **EET (Europe, broker-tz) DST rule the column name denotes**. The 7.30 % DST seam the scout flagged is a **real event-instant defect in the `DateTime_UTC`/`datetime` columns** and is caught by the §6.1 anchor gate (±5 min catches a residual 11:30 vs 12:30Z); the *display-column-only* re-derivation is what is non-blocking. Recording the chosen DST rule for `DateTime_EET` is an explicit sub-item in the Codex ticket.

### 5.3 Determinism requirement

The regeneration must be **byte-deterministic**: identical corrected input → identical output bytes (stable row order = ascending `datetime`, then a stable secondary key; fixed float formatting for actual/forecast/previous; no locale drift — force invariant culture, UTF-8 no-BOM matching the current files' `utf-8-sig`-tolerant reader). The gate reads via `utf-8-sig`; keep output plain UTF-8.

---

## 6. Verification suite (must pass BEFORE reseal)

All checks run on the **candidate** corrected files in a staging dir, never on the sealed production files. Detectors: `tools/strategy_farm/news_calendar_diagnose.py` (already exists, currently report-only).

**Baselines are captured programmatically in the same run (F7).** No gate is pinned to a hard-coded literal (r1's 46,331 / 48,627 / 48,636 disagreed with the live diagnose). At repair start the tool records the **current** production row counts (PRIMARY, SECONDARY) and the **current** cross-file identical-instant count into `baseline.json`; the no-shrink and cross-file-identity gates assert **no regression vs `baseline.json`**, not against a literal.

### 6.1 Anchor-share gate — EVERY USD high-impact class, not just Class A/ET-0830 (F2, F4, F5)

- For each scored year 2018..2026 and **every USD `impact=high` event class** (the full extended `NAME_MAP_USD` set **plus** the formerly-"Class C" events ADP / ISM Mfg / ISM Svcs / Fed Funds / FOMC Press Conf / FOMC Statement / FOMC Economic Projections / JOLTS / Crude / CB Consumer Confidence), **≥ 0.99** of rows match a native/official anchor instant within **±5 min**. This closes the r1 hole where ADP/ISM/Fed/FOMC-PC and the unclassified FOMC Statement were re-checked by **no** gate.
- **Zero-tolerance classes — 1.00, anchored to the native/official instant only, never the schedule rule (F4):** NFP / Retail Sales / Unemployment Rate / CPI m/m. A strict 1.00 gate computed from a fixed calendar rule would reject legitimately off-schedule shutdown-month releases or force a fabricated nominal time; anchoring exclusively to native avoids both.
- **Seam residual (F5):** the ±5 min tolerance catches any residual 11:30Z-vs-12:30Z / DST-seam instant in a consumed column; a class that still shows seam rows fails the gate.
- Non-USD: each **anchored** (currency, event class) matches its official anchor within ±15 min after the DST-corrected footprint (§3.4). Non-rate non-USD classes with no anchor are **declared gaps** (§3.5), reported, not silently passed.

### 6.2 Coverage gate

- **Zero** zero-row months across 2015-01 → present, **except** months explicitly listed as native-sourced-reduced (2025 shutdown, §4.1) or as declared gaps (`repair_gaps.json`). For USD HIGH, normal months in the 40–50/month band; reduced months matched to the native count, not the rule count.

### 6.3 Cross-file identity gate (F7)

- Every event present in both files carries a **byte-identical UTC instant**. The count of previously-identical instants is read from `baseline.json` (captured this run); the shared transform must keep it identical. **Regression vs the captured baseline → fail.** No literal is pinned.

### 6.4 Non-USD completeness report (F6)

- The suite emits, per currency per year, the count of native high rows and the rate-decision fraction, into the evidence dir. This quantifies the under-block magnitude of the declared non-USD non-rate gaps and is the input to the E2/E4 blast-radius inventory (§8).

### 6.5 Tick-volume footprint spot checks (concrete list)

Run the DST-corrected M5 footprint (§3.4) for at least the anchor list in §3.4 (≥3 per currency, incl. ≥1 non-rate per currency for gap sizing) plus USD spot checks: NFP 2025-06-06 12:30Z, CPI 2025-08-12 12:30Z, Fed 2025-06-18 18:00Z. Each corrected instant must sit in (or adjacent to) the elevated-volume band; each pre-repair (displaced) instant must sit in a quiet band. Record CSV evidence per check (required by Hard Rule "evidence over claims").

### 6.6 No-row-loss gate (F7)

- PRIMARY row count ≥ `baseline.primary_rows` **plus** backfill rows, minus **only** the explicitly declared drops (there are none in the USD path; Class E preserved). Any unexplained shrink → fail. This also satisfies `_assert_plausible` (§7).
- SECONDARY analogously ≥ `baseline.secondary_rows` + backfill. Baselines from the same run, not literals.

### 6.7 Detector-clean gate — all high-impact classes, reconciled with the transform (F2)

- `news_calendar_diagnose.py` on the candidate reports **zero** shifted rows **across all high-impact classes** (not just ET-0830) and **zero** unexplained coverage-hole months. Because r2 native-matches every high-impact class (no do-not-touch set), the detector's expected-instant rule and the transform now **agree** — the r1 contradiction, where the detector flagged FOMC/Fed as failing while "Class C" forbade touching them, is removed. The diagnose's scheduled-anchor assertions for FOMC_STATEMENT etc. must pass on the candidate before reseal.

### 6.8 Gate dry-run

- `news_calendar_gate.py` schema/column/format validation passes for both candidate files (PRIMARY required `{datetime,currency,event_name,impact}`, formats `%Y-%m-%d %H:%M[:%S]`; SECONDARY `{DateTime_UTC,Currency,Impact,Event}`, formats `%Y.%m.%d %H:%M[:%S]`). No NUL bytes, UTF-8 decodable, no duplicate headers.

**Reseal is blocked until 6.1–6.8 all pass.** Evidence dir: `docs/ops/evidence/2026-09-<dd>_news_calendar_repair_verification/` with `baseline.json`, per-gate JSON, the completeness report, and the footprint CSVs.

---

## 7. Reseal / repin procedure (step by step, with rollback)

The end-to-end chain any repair must traverse (`news_calendar_gate.py` + `news_calendar_repin.py` + terminal mirrors + q09 bundle). **The `record` op is executable only inside the live refresh process** (parent-PID + operation-id proof, `news_calendar_repin.py:1011–1019`), so the reseal must run **through** the controlled publish→journal→receipt→repin flow, **not by hand-editing files**.

### 7.0 Pre-condition — clean tree and no OFF/ON window (F8)

`framework/registry/dxz23_execution_contracts.json` is **git-tracked** and is **currently ` M`** (a prior repin left `coverage_end=2026-09-04` uncommitted). `refresh_news_calendar.ps1` wires only the gate multi-publish + repin (lines 37-38, 392) and **never git-commits dxz23**. `build_runtime_activation_decision.py:338-339` runs `git status --porcelain --untracked-files=all` and `_require(dirty == "", …)`, so **any** dirty file — dxz23 included — aborts the Factory_ON runtime-activation mint (flag → `OFF_RECOVERY_REQUIRED`). The reseal enlarges the dxz23 diff to every news sha. Therefore:

- **No Factory OFF/ON may be attempted while dxz23 shows repin-pending changes.** The reseal is sequenced **outside** any OFF/ON recovery window.
- **Who commits the repin-modified dxz23, and when:** the **refresh/ops process under the existing `OWNER-DEC-CALENDAR-REPIN` authority id** commits `framework/registry/dxz23_execution_contracts.json` immediately after the repin `record` completes, producing a clean tree **before** any Factory OFF/ON is contemplated. **No AI seat hand-edits dxz23**, and **this planning work item never commits it** — the commit belongs to the ops/refresh process, not to the E1-A patch. Until that commit lands, the tree is dirty by design and a mint would fail-closed; that is expected, not a wedge.

### 7.1 Pre-reseal (staging, off the production path)

1. Build candidate PRIMARY + SECONDARY in a staging dir (§2–§5), writing `baseline.json` first (§6).
2. Run the full verification suite §6; capture evidence. **Abort on any fail.**
3. Snapshot the **current sealed state** for rollback: current `news_calendar_bundle_manifest.json`, the active immutable bundle id under `.news_calendar_bundles/<bundle_id>/`, the current q09 `bundle_id`, and the current per-role sha256/coverage in `dxz23_execution_contracts.json` (read-only copy into the evidence dir). **The old bundle stays sealed and untouched = the rollback target.**

### 7.2 Publish + reseal (through the controlled flow)

4. Invoke the repair via a **controlled `refresh_news_calendar.ps1` run** (or an OWNER-authorized one-shot publish+repin path that reuses the same parent-PID proof). The repair supplies the corrected static files as the publish payload **instead of** the forward-feed append; the forward week is still re-appended by the same run so 2026-07+ stays current.
5. `news_calendar_gate.py` publishes atomically:
   - writes both corrected files to the D: source dir `D:/QM/data/news_calendar/`;
   - mirrors to **every** MetaTrader `Common\Files` root — `PRODUCTION_COMMON_DIRS` is **FOUR** dirs (`news_calendar_gate.py:56–63`): **Administrator**, **`C:\Windows\System32\config\systemprofile` (the SYSTEM account under which the SYSTEM-scheduled terminal workers run — the one the factory worker terminals actually read)**, **QMDev1**, **QMDev2**. r1 dropped the systemprofile mirror (F10); it is restored here.
   - installs a **new immutable bundle** under `.news_calendar_bundles/<new_bundle_id>/` (`_install_immutable_bundle`) and verifies each mirror with `_verify_immutable_bundle(common_dir, manifest)` (`news_calendar_gate.py:681`) — a **per-`common_dir`** byte check, i.e. the true per-mirror verification (not the repin source-dir check);
   - writes the active `news_calendar_bundle_manifest.json` (schema `qm-news-calendar-pair/v1`: `bundle_id`, `bundle_identity_sha256`, `files[]` with per-file sha256 + row_count + first/last_event_utc).
6. `news_calendar_repin.py record` (inside the refresh process) updates the calendar-identity fields (sha256, coverage_start, coverage_end) of **every** news-calendar record in `dxz23_execution_contracts.json` (≥8 records, roles SHARED_PRIMARY/SECONDARY + QMDEV1_COMMON_PRIMARY/SECONDARY across contract blocks, lines 334–421+) and appends a **create-only SHA256 hash-chain receipt** under `D:/QM/reports/news_calendar/repin_receipts/`.
7. **Commit the repin-modified dxz23 (F8):** per §7.0, the refresh/ops process (under `OWNER-DEC-CALENDAR-REPIN`) commits `framework/registry/dxz23_execution_contracts.json` so the tree is clean. This is the reconciliation step r1 omitted. **Not done by this planning patch; not hand-edited by any AI seat.**
8. `_assert_plausible` (`news_calendar_repin.py:640–660`) permits this repair: row count does not shrink (§6.6) and coverage endpoints do not regress (start unchanged, end forward). **Guard-rail note:** `_assert_plausible` will *not* by itself detect a time-shift error or a coverage hole — the **verification suite §6 is the real guard**; the repin plausibility check is necessary-but-insufficient and must never be treated as the acceptance test.
9. **Regenerate the q09 bundle as an explicit APPROVED_CORRECTION step (F9, F12).** This is **not** wired into `refresh_news_calendar.ps1` (which references only the gate and repin), so it is a **standalone step**, run by the refresh/ops process:
   - `python tools/strategy_farm/q09_news_calendar.py … --publication-reason APPROVED_CORRECTION` — **not** HORIZON_EXTENSION: a pure interior backfill does not extend `coverage_to` past the parent, so HORIZON_EXTENSION would raise (`q09_news_calendar.py:193-194`). A forward re-append of the current week may nudge `coverage_to`, but the reason of record for the correction is APPROVED_CORRECTION.
   - supply `--parent-manifest` = the prior bundle, and an **OWNER approval receipt** carrying `approved_by`, `approved_at`, `reason`, **and `correction_reason`** citing E1-A (`:148`, `:195-196`). The receipt is an OWNER manual input (§9.2 step 5).
   - new `bundle_id` `q09cal-YYYYMMDD-YYYYMMDD-<hash16>`, `content_sha256` over canonicalized events, schema `q09-news-calendar-bundle/v2`.
   - **confirm q09 `bundle_id` consumers re-point** to the new `content_sha256` (the standalone step's evidence records old→new bundle_id).

### 7.3 Post-reseal verification

10. Re-read the active manifest + `dxz23` records + q09 bundle; confirm all SHAs point at the corrected files, coverage_end advanced past the former hole, the q09 `content_sha256` updated, and the tree is clean (dxz23 committed, §7.2 step 7).
11. **Byte-compare ALL FOUR `Common\Files` mirrors to the published bundle (F10).** Per-mirror verification is the gate publish's `_verify_immutable_bundle(common_dir, manifest)` (`news_calendar_gate.py:681`), run for each of the four dirs — **not** `news_calendar_repin.py:439-449`, which compares only the D: source dir (+ the QMDev1 common record present in dxz23) and does **not** iterate the four Common\Files dirs. Write the four-mirror byte-compare result into the evidence dir.
12. Record the reseal in `decisions/` and the evidence dir; append `OPEN_ITEMS_STATUS.md`.

### 7.4 T_Live impact (confirm: CSVs advisory only)

- T_Live's EA runs the **native MT5 calendar branch** (`QM_NewsFilter.mqh:1985–2009`, DL-080). The CSVs gate T_Live **only** at OnInit for staleness/coverage (`MAX_AGE_HOURS=336`). **Confirmed:** the reseal changes T_Live's OnInit staleness input (now covering the former hole and fresh SHA) but **does not change any live blackout decision** — those come from the native terminal calendar. No T_Live AutoTrading action is required or permitted. The factory T1–T10 backtests **do** consume the CSVs and are the re-adjudication surface (§8).

### 7.5 Rollback

- Old bundle stays sealed under `.news_calendar_bundles/<old_bundle_id>/`; old q09 `bundle_id` retained. Rollback = re-publish the old bundle through the same controlled flow (repin back to the old SHAs, q09 re-point to the old bundle). Because the repin receipt chain is create-only and the immutable bundles are retained, rollback is a **forward re-pin to the prior identity**, fully audited. No file is destroyed.

---

## 8. Consequences and ordering (detectors → E2 → E4)

**Execution order (F11): E1 reseal + §6 verify pass → §8.1 detectors fail-closed → §8.2 E2 re-adjudication → §8.3 E4 OOS-2026 apply.** The detector flip comes **before** E2/E4 so that any accidental calendar mutation during the re-adjudication window is fail-closed-guarded while factory time is being spent on the EXPOSED cohort. r1 sequenced E2 before the detector flip; corrected here.

### 8.1 Detectors → fail-closed (immediately after §6 passes, before E2)

`news_calendar_diagnose.py` (and the anchor/coverage detectors) currently run **report-only**. They flip to **fail-closed gate checks** as soon as §6.7 passes on the resealed active bundle. Acceptance criterion that flips them:

- **anchor PASS share ≥ 0.99 per year per USD high-impact class** (1.00 for NFP/Retail/Unemployment/CPI m/m), across **all** high-impact classes incl. the formerly-"Class C" and FOMC Statement/Projections (F2), AND
- **zero shifted rows across all high-impact classes**, AND
- **zero unexplained coverage-hole months** (native-reduced/declared-gap months are on the allow-list, §6.2).

**Exemption:** the pre-repair **sealed old calendar** (rollback target) is **exempt** from the fail-closed detector — it is retained deliberately as the rollback and must not be re-validated against the new rule. The detector runs against the **active** bundle only.

### 8.2 E2 — re-adjudication (after detectors are fail-closed)

Blast radius (`docs/ops/evidence/2026-09-05_news_defect_blast_radius/summary.json`): **63 EXPOSED / 108 INERT** over 125 EA/symbol pairs. There is **no PASS-class Q09_NEWS / Q10_NEWS v4 verdict yet** (all REVIEW_REQUIRED / CONFIG_LOCKED / held) — so the news-specific gate has **nothing to un-do**; the re-adjudication surface is the **intraday-EXPOSED standard-gate verdicts**:

- **Priority 1 (terminal verdicts, 8 pairs):** the 7 Q11 PASS exposed pairs — QM5_10700/XAUUSD, 10706/GBPUSD, 11294/XAUUSD, 11660/NDX, 13013/NDX, 13213/USDJPY, 21501/USDJPY — plus the Q14 KEEP_INCUMBENT exposure QM5_10706/GBPUSD/H1 PRE30_POST30 (the only terminal intraday Q14 exposure).
- **Priority 2:** Q09 PASS 39 EXPOSED, Q10 PASS 11 EXPOSED.
- **Non-USD under-block cohort (F6):** the non-USD symbols whose non-rate high events are declared gaps (GDAXI→EUR, UK100→GBP and any other non-USD pair in the EXPOSED set) are flagged in the E2 inventory with their **quantified** under-block window (§6.4), so the re-adjudication reads against a calendar known to under-block non-rate non-USD events — not silently.
- **Trigger mechanism:** E2 enqueues append-only re-runs (`farmctl enqueue-backtest --append-only-rerun-of <id>`) of the EXPOSED pairs against the resealed calendar; old rows stay as evidence. **INERT pairs (108) are not re-run** (USD-N/A, news-off, or D1 bar-open entry that cannot intersect a ±30 min slot). Order: Priority 1 → Priority 2.

### 8.3 E4 — OOS-2026 apply (after backfill + E2)

OOS-2026 apply is **gated on the coverage-hole backfill** (§4) landing 2026-01..06. Until the fresh export (§4.2) is verified and resealed, OOS-2026 windows have no calendar and E4 must **wait**. Order: §4 export → reseal → §6 pass → §8.1 detectors fail-closed → §8.2 E2 → **then** E4 OOS-2026 apply on the EXPOSED cohort (carrying the same non-USD under-block annotations).

### 8.4 E5 — retention

Old bundle + all immutable bundle copies + repin receipt chain + prior q09 bundle retained per E5 (DL-090 PASS-family retention). No deletion.

---

## 9. Codex implementation ticket + manual (CEO/OWNER) steps

### 9.1 Codex ticket — `build_news_calendar_repair_transform`

**Model tier:** Codex high-effort (deterministic data transform + schema fidelity; `codex_reasoning_effort=high`). Route to Codex (implementation/tests/ops), not research.

**Deliverable:** a deterministic, offline transform tool (Python, `cwd=C:/QM/repo`, no ML libs) that reads the native exports + private-lab builders + the current production files and emits **candidate** corrected PRIMARY + SECONDARY into a staging dir, plus a verification runner.

**Acceptance list (all must hold):**

1. Emits PRIMARY (exact 20-col schema, `datetime` UTC verbatim) and SECONDARY (exact 9-col schema, `DateTime_UTC`) from the corrected instant set (§2–§5).
2. USD handled per §2 (r2): **native-match every high-impact event in the extended `NAME_MAP_USD` (Class A, idempotent); over-block or declared-gap for no-native-match ET-0830 residuals (Class B′/D); keep-as-is only for medium/low non-class events (Class E). No "do-not-touch" high-impact class; no wall-clock recompute on the stored date.** Extend `NAME_MAP_USD` with FOMC Statement, FOMC Economic Projections (→ Fed Interest Rate Decision) and Core PPI m/m / Empire State / Building Permits / Trade Balance (native names asserted present at build time, else over-block).
3. Non-USD offset fan applied per §3 with anchor selection; **rate-decision-dominant coverage is explicit**; failing/anchorless classes emitted as **declared gaps** in a machine-readable `repair_gaps.json`, never guessed; per-currency HIGH completeness + rate-decision fraction written to evidence (§6.4).
4. Coverage backfill 2025-05..2025-12 from existing natives (native is truth for the 2025 shutdown months, reduced counts recorded, not rule-derived); 2026-01..06 consumed from the OWNER-produced fresh export (§4.2) when present, else the tool **halts with a clear "awaiting 2026-H1 export" message** (does not silently ship a hole).
5. All derived columns regenerated from corrected timestamps (§5), byte-deterministic, UTF-8 no-BOM, invariant culture, stable sort. `DateTime_EET` DST rule chosen and recorded (display-only, non-blocking).
6. Cross-file identity preserved for all common events (§6.3) vs the **run-captured `baseline.json`** count (no literal); the previously-identical instant set stays identical.
7. Verification runner implements gates §6.1–§6.8 (anchor gate over **all** USD high-impact classes; native-only anchors for the 1.00 zero-tolerance classes; non-USD completeness report; four-mirror expectations documented) and writes evidence JSON + `baseline.json` + footprint CSVs; **exits non-zero if any gate fails**. Wraps/extends `news_calendar_diagnose.py`, reconciling the detector's expected-instant rule with the transform so §6.7 and §8.1 are jointly satisfiable.
8. **Never** writes to production `D:/QM/data/news_calendar/`, `dxz23_execution_contracts.json`, the bundle manifest, or any `Common\Files` — staging output only. The reseal is a **separate** controlled step (§7).
9. No pytest-heavy/RAM-heavy runs; small deterministic probes only.

**Tests:** golden-file tests on a fixture slice (a few months incl. NFP/CPI/ADP/FOMC-Statement/ECB/BoE/BoJ) asserting exact corrected instants against official anchors, **including a FOMC Statement row and a 2025-shutdown-month NFP row** (native-anchored, not rule-derived); a cross-file identity test vs captured baseline; a determinism test (run twice → identical bytes); a declared-gap test (a synthetic unanchorable non-USD non-rate class → appears in `repair_gaps.json`, not shifted); a **no-early-blackout** test (a stored-Thursday NFP row must never yield a Thursday instant).

**Evidence paths:**
- Tool + tests under `tools/strategy_farm/research/` (or `tools/strategy_farm/`), staging output under a scratch/staging dir.
- Verification evidence: `docs/ops/evidence/2026-09-<dd>_news_calendar_repair_verification/` (incl. `baseline.json`, non-USD completeness report, four-mirror expectation notes).
- `repair_gaps.json` (declared non-USD gaps + medium/low hole gaps + any USD over-block/declared-gap residuals).

### 9.2 CEO / OWNER manual steps (cannot be automated by AI seats)

1. **Fresh 2026-H1 native export (§4.2):** in the **T_Export terminal**, run the edited `EXPORT_T_EXPORT_MULTI_HIGH_2018_2025.mq5` with `to = D'2026.07.01'` (per-currency, per-half to dodge error 5401). Verify per §4.2. This is the one blocking manual input.
2. **Authorize the reseal path (§7):** confirm the repair runs THROUGH `refresh_news_calendar.ps1` (or authorize a one-shot publish+repin equivalent under the fixed repin decision id). Confirm the repin `OWNER_DECISION_ID` (existing `OWNER-DEC-CALENDAR-REPIN` vs a new E1-A id — Open Question 7).
3. **Confirm dxz23 reconciliation ownership (§7.0 / §7.2 step 7):** the refresh/ops process — **not an AI seat, not this planning patch** — commits the repin-modified `dxz23_execution_contracts.json` under the repin authority id, producing a clean tree, and **no Factory OFF/ON is attempted while dxz23 shows repin-pending changes**.
4. **q09 APPROVED_CORRECTION approval receipt (§7.2 step 9 — F9/F12):** produce the q09 publication approval receipt carrying `approved_by`, `approved_at`, `reason`, **and `correction_reason` citing E1-A**, under the E1-A decision id, so the standalone q09 regeneration step is unblockable.
5. **Trigger the reseal** (or approve Claude to trigger it) once §6 passes — the publish/mirror/repin/dxz23-commit/q09 rebuild (§7.2). AI verifies SHAs + all four mirrors + q09 re-point (§7.3); AI does **not** hand-edit `dxz23`.
6. **Nothing on T_Live.** No AutoTrading toggle; T_Live is native-calendar (§7.4). Confirmed no live action.
7. After reseal verified: approve the ordered sequence **detectors fail-closed (§8.1) → E2 re-adjudication (§8.2) → E4 OOS-2026 apply (§8.3)**.

---

## Open questions (carried to OWNER)

1. **Contract V2 §7 (impact taxonomy):** E1-A is timestamp-scoped and keeps each file's existing impact labels; the 41.7 % impact disagreement is **not** reconciled. Confirm §7 stays a separate decision, or fold it in.
2. **2026-01..06 medium/low + USD medium/low in the hole:** native is HIGH-only → medium/low across the whole hole stay a **declared gap**. Accept, or commission a faireconomy-archive medium/low backfill as follow-up?
3. **Contract V2 §3 (single source):** E1-A corrects **both** files identically (no EA change). Implementing §3 (one authoritative file) is ROT-adjacent and deferred. Confirm deferral.
4. **Non-USD footprint completeness:** only 1 EUR anchor footprint-checked so far; §6.5 requires ≥3 per currency (incl. ≥1 non-rate for gap sizing) with the DST-corrected M5 conversion. Accept the lab's 14 official anchors as primary truth with footprint as confirmation, or require full footprint before reseal?
5. **Non-USD non-rate scope (F6):** the offset fan anchors are rate-decisions only, so non-rate non-USD high events (CPI/GDP/employment/PMI) are **declared gaps** — GDAXI→EUR / UK100→GBP under-block for those across the corrected/backfilled window. Accept the **scope-and-declare** path (3.3a, E1-A-shippable, gaps surfaced + fed to E2/E4), or commission a proper non-USD historical source (3.3b) first?
6. **`DateTime_EET` DST rule:** the **display column** is not consumed → non-blocking (the consumed `DateTime_UTC`/`datetime` seam **is** corrected and gated, §5.2/§6.1). Confirm the chosen EET/EU-DST rule for the cosmetic column.
7. **Repin authority / decision id:** reseal must run through the refresh-process-only `record` gate; the repin-modified `dxz23` is committed by the ops/refresh process (§7.0), not an AI seat. Confirm E1-A reseals under `OWNER-DEC-CALENDAR-REPIN` or a new E1-A decision id, and whether a one-shot publish+repin is authorized vs a full `refresh_news_calendar.ps1` run (which also re-appends the forward week).
8. **Detector flip threshold (§8.1):** confirm the fail-closed acceptance (anchor ≥0.99 per year per **USD high-impact class** incl. formerly-"Class C" + FOMC Statement/Projections; 1.00 native-anchored for NFP/Retail/Unemployment/CPI m/m; zero shifted rows across all high-impact classes; zero unexplained hole months) and the exemption of the sealed rollback bundle.
