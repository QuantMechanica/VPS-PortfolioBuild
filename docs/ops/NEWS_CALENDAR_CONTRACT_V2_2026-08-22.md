# News Calendar Semantics Contract V2 — specification + V1 lock

Task: `agent_router` task `4fd8126c-2792-44d0-8b59-e7779a531176` (SP-B1, priority 87,
zone GELB, Schienenplan 2026-08-22). Source: consulting audit
`Consulting Audit VPS Portfolio Build und Live Control Plane 2026-08-22.md`, `§6 F-03`
("News-Seeds sind hash-stabil, aber fachlich nicht eindeutig") / `§14 S-05`. This is a
**specification**, not an implementation — per hard_constraint it does not change any
existing Q09 verdict and is Claude's own work (not delegated). Implementation of the
9 points below is follow-up work for Codex once OWNER ratifies §7 (mapping-policy
decision) and this contract.

**Naming note:** `q09_news_contract.py` already declares
`SCHEMA_VERSION = "q09-news-evidence/v2"` for the Q09 *evidence/adjudication* contract
(row states, `CONFIG_LOCKED`/`REVIEW_REQUIRED`/`INVALID_EVIDENCE`). That is a different,
unrelated contract layer — it governs how a Q09 verdict is adjudicated from already-loaded
calendar data. This document is the **calendar-semantics** contract underneath it (what
the calendar data itself means, in what time base, with what impact taxonomy). To avoid
colliding with the existing `v2` name, this contract's own schema identifier is
`qm.news_calendar_semantics_contract.v2` — never bare `"v2"` or `"News Contract V2"`
without the `news_calendar_semantics` qualifier in code or docs.

## 0. Why now (the F-03 finding)

A byte-level audit of the two calendar files under `D:\QM\data\news_calendar`
(`news_calendar_2015_2025.csv` = primary, `forex_factory_calendar_clean.csv` =
secondary — both required simultaneously by `news_calendar_gate.py`'s preflight/publish
contract) found: hashes are stable (no corruption), but of 47,565 events common to both
files, **41.7% differ in impact classification** (25.5% flip High/Not-High). Separately,
`DateTime_EET`-based rows follow **EU DST** while DarwinexZero broker time follows
**NY-close/US-DST** — 3,502/48,000 rows (7.30%) land on the wrong hour around a DST
transition. Neither disagreement is visible today because no run declares which file (or
which impact label, where they conflict) is authoritative, and no broker-time
transform is applied to the raw calendar data outside the MQL5 EA layer.

## 1. UTC as sole canonical time

Every persisted calendar row's timestamp is `timestamp_utc` (ISO-8601, UTC, no offset
ambiguity). `DateTime_EET`-derived columns in the raw seed files are **ingestion-time
only** — the ingestion step converts them to `timestamp_utc` and the EET column is
dropped from anything a gate or backtest consumes. No downstream code may read a
non-UTC timestamp column.

## 2. Deterministic broker time from UTC + versioned US-DST rule

Broker (Darwinex Zero NY-close) time is derived from UTC by a single, versioned rule —
never read from a broker clock, never independently re-implemented per language.
**Canonical definition, `qm.dst_rule.us.v1`** (verbatim from the already-validated,
already-live MQL5 implementation, `framework/include/QM/QM_DSTAware.mqh:4-139`, itself
sourced from `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`):

- US DST **starts** 07:00 UTC on the **2nd Sunday of March** (02:00 local EST, UTC-5).
- US DST **ends** 06:00 UTC on the **1st Sunday of November** (02:00 local EDT, UTC-4).
- Broker offset = **UTC+3** while `[start, end)` (US DST active), else **UTC+2**.
- `broker_time = utc + offset`. The reverse map (`broker_time -> utc`) is ambiguous for
  one hour at the November fallback; policy (already coded, `QM_BrokerToUTC`): **prefer
  the standard-time (UTC+2) candidate** when both are valid.

**Gap this closes:** this rule currently exists **only in MQL5**
(`QM_DSTAware.mqh`). The Python news pipeline (`q09_news_calendar.py`,
`news_calendar_gate.py`, `p8_news_driver.py`) stores/consumes UTC only and has **no**
broker-time derivation at all — so nothing on the Python side can currently reproduce
"was this event inside the broker-time blocking window" the same way the live EA does.
V2 requires a Python port, `qm_dst_rule.py`, implementing byte-for-bit the same four
functions (`us_dst_start_utc(year)`, `us_dst_end_utc(year)`, `is_us_dst_utc(utc)`,
`utc_to_broker(utc)`), versioned `qm.dst_rule.us.v1`, with a cross-language parity test
(§8) so MQL5 and Python can never silently diverge.

## 3. Exactly one active source per run

A run (a Q09 gate evaluation, a P8 replay, a backtest, or the live EA's own preflight)
must declare **exactly one** calendar source as authoritative for that run's evaluation
window. Zero declared sources, or more than one **without an explicit, versioned
precedence + reconciliation rule**, is **fail-closed** — the run produces no verdict,
not a merged/best-effort one.

This directly targets the F-03 finding: `news_calendar_gate.py` currently treats
`news_calendar_2015_2025.csv` + `forex_factory_calendar_clean.csv` as a **mandatory
pair** (`CALENDAR_NAMES`, both required to publish) with **no declared precedence** —
and the two disagree on impact classification for 41.7% of shared events. Under V2:
- The **publish/distribution** layer may still ship both files (that is a storage
  concern, unaffected by this contract).
- The **consumption** layer (Q09/P8/backtest/live) must pick exactly one as
  authoritative for impact classification and event membership in a given run, record
  *which* one in the run self-report (§6), and never silently interpolate/merge rows
  from the other. Which file is authoritative is an OWNER decision (§7) — this contract
  does not make that call; it makes the call **mandatory and recorded**, not implicit.

## 4. Documented impact-mapping with rules + code + version hash

Impact classification (`low`/`medium`/`high` -> a blocking-window rank) is currently a
**hardcoded, unversioned dict**, duplicated in two functions in one file:
`framework/scripts/p8_news_driver.py:254` (`matching_events`) and `:275`
(`day_has_event`), both `impact_rank = {"low": 1, "medium": 2, "high": 3}`. There is no
`impact_map` artifact, no version, no hash — a silent edit to either dict changes
historical-vs-new-evidence comparability with no trace.

V2 requires: **one** impact-mapping artifact (JSON), e.g.
`tools/strategy_farm/news_impact_mapping.json`, carrying `{schema_version:
"qm.news_impact_mapping.v1", rank: {"low":1,"medium":2,"high":3}, source_field: <which
calendar column/source this ranks>, content_sha256: <self-hash>}`. All impact-rank
lookups (the two `p8_news_driver.py` sites plus any Q09/P8 equivalents) load from this
one artifact — no inline dict literals. Every run self-report (§6) cites
`mapping_version` + `content_sha256`.

## 5. Separate schedule-view without Actual/Forecast/Previous

The **blocking/gating** consumer (which events fall in a window around a trade) must
read a view that carries only `timestamp_utc, currency, impact, event_id` — never
`actual`, `forecast`, `previous`. Those three fields are look-ahead risk: a backtest
that can see `actual` for a not-yet-elapsed event is reading the future. V2 requires a
derived, gate-facing artifact (e.g. `*_schedule_view.csv` or an in-memory projection at
load time) that structurally cannot expose those columns to
`matching_events`/`day_has_event`/their Q09 equivalents. `actual`/`forecast`/`previous`
remain available in the full calendar for **analysis/EDA only**, never for a
blocking-window decision.

## 6. Point-in-time `known_at_utc`

Every calendar row gains `known_at_utc`: the UTC instant this row's forecast/scheduling
became public (distinct from `timestamp_utc`, the event's own scheduled time). Absent
upstream provenance for the historical seed files, `known_at_utc` may be backfilled
conservatively (e.g. `timestamp_utc` minus a fixed, documented lead time per event type)
— but it must be **present and its provenance documented**, not silently equal to
`timestamp_utc` (which would hide same-day-surprise events that were not knowable in
advance at backtest time). This closes the "Actual/Forecast/Previous present without
known_at_utc (look-ahead risk)" gap the audit named.

## 7. Run self-report

Every run that consumes the calendar (Q09 gate, P8 replay, live EA preflight) emits one
consolidated self-report object — not five scattered fields across different log lines
as today. Required fields:

| Field | Today | V2 |
|---|---|---|
| source path | present (`source_dir`/paths) | unchanged, consolidated |
| content SHA | present (`content_sha256`/`manifest_sha256`) | unchanged, consolidated |
| row count | present (`row_count`) | unchanged, consolidated |
| max event date | present (`event_to_utc`) | unchanged, consolidated |
| schema version | present (`MANIFEST_SCHEMA`/`SCHEMA_VERSION`) | unchanged, consolidated |
| **mapping version** | **absent** | **new** — `qm.news_impact_mapping.v1` + its `content_sha256` (§4) |
| **which source was authoritative** | absent (two-file pair, no declared winner) | **new** — the §3 declaration |
| **DST rule version** | absent | **new** — `qm.dst_rule.us.v1` (§2) |

Consolidated shape: `{schema_version, mapping_version, dst_rule_version,
authoritative_source, source_path, content_sha256, row_count, max_event_date_utc,
generated_at_utc}`.

## 8. Test plan — DST + duplicates

**DST transition tests** (both languages, cross-checked against each other):
- For each of at least 3 consecutive years spanning a leap year and a non-leap year,
  compute the US DST start/end instants via the §2 rule and assert: (a) the Python and
  MQL5 implementations agree bit-for-bit on `is_us_dst_utc()` for every UTC timestamp in
  a dense sweep across the transition weeks; (b) a UTC timestamp one minute before the
  computed start/end boundary maps to the pre-transition offset, one minute after maps
  to the post-transition offset (no off-by-one); (c) `broker_time -> utc` at the
  November fallback ambiguous hour resolves to the standard-time (UTC+2) candidate per
  the documented policy. Dates are **computed from the nth-weekday rule at test time**,
  never hardcoded literals, so the test remains valid for any year without maintenance.
- Regression check against the F-03 finding: re-run the 48,000-row DST audit sample (or
  its successor) and assert the previously-observed 7.30% off-by-one-hour rate drops to
  0% once §2 is applied uniformly.

**Duplicate tests:**
- Assert the ingestion step rejects (or explicitly, visibly deduplicates with a recorded
  rule) any `(timestamp_utc, currency, event)` triple appearing more than once within a
  single authoritative source — the audit named "legacy double-load of primary+secondary
  files" as a named failure mode; a duplicate-detection test must fail loudly if the same
  event is silently double-counted (e.g. double-blocking a trade window, or double
  weighting an impact tally).
- Assert cross-source duplicates (same event present in both files, per §0's 47,565
  common-event sample) are classified consistently once §3/§4 apply — i.e. after the
  contract is implemented, the previously-observed 41.7% classification disagreement on
  the common-event sample becomes 0% for whichever source is declared authoritative
  (the *other* source's disagreeing rows are expected and must not raise an error, since
  by design only the authoritative source's classification is consumed).

## 9. Backtest & live evidence cite the same contract+mapping fingerprint

Both a backtest's Q09 evidence and any live-side news consumption report must carry the
same `(schema_version, mapping_version, dst_rule_version)` triple when they are meant to
be compared. A Q09 verdict and a live burn-in report citing different mapping versions
are **not comparable evidence** — any comparison across them must first check this
triple matches, and refuse (not silently compare) on mismatch. This is the same
fail-closed pattern already used for the SP-A1 deploy pointer's `manifest_sha256`
matching — apply it here too so news-driven evidence has the same falsifiability
guarantee.

## V1 lock — no new evidence against undocumented/implicit semantics

There is no single document named "News Contract V1" to supersede; V1 is the current
**undocumented, implicit** behavior described in §0 and referenced throughout §1–§9
(MQL5-only DST, unversioned inline impact dict, mandatory-but-unranked two-file pair, no
`known_at_utc`, fragmented self-report fields). Effective from this document's date:

- **No new Q09_NEWS row, P8 replay, or live-book news-consumption evidence may be
  represented as authoritative unless it can cite the §7 self-report fields** (in
  particular `mapping_version` and `authoritative_source` — the two fields V1 cannot
  produce because they do not exist yet). Evidence lacking them is V1-era and must be
  labeled as such wherever it is cited going forward (e.g. "pre-V2, mapping version
  unknown") rather than presented as equivalent to post-V2 evidence.
- Existing historical evidence generated under V1 (the entire Q09_NEWS backfill program,
  `[[project-qm-live-book-news-backfill-2026-08-05]]`, and all prior P8 runs) **remains
  valid as a historical record** — this lock does not retroactively invalidate pipeline
  verdicts already rendered. It only forbids treating V1-shaped evidence as equivalent
  to V2 evidence in any *new* comparison or admission decision from this point forward.
- Q09 adjudication states (`CONFIG_LOCKED`/`REVIEW_REQUIRED`/`INVALID_EVIDENCE`,
  `q09_news_contract.py`) are **unchanged** by this lock — this is a semantics-layer
  lock underneath that adjudication layer, per the task's own hard_constraint.

## §15-equivalent OWNER decision template — "News-Impact-Taxonomie"

This contract cannot resolve §3/§4 unilaterally: **which of the two existing sources'
impact classification is canonical** (or whether a third, reconciled classification is
built) is a policy call, not an engineering one — flagged in the consulting audit as an
OWNER decision item. Template for OWNER ratification:

> **Decision needed:** For events common to both `news_calendar_2015_2025.csv` and
> `forex_factory_calendar_clean.csv` where impact classification disagrees (41.7% of
> 47,565 common events, 25.5% High/Not-High flips), which source's classification is
> canonical going forward under `qm.news_impact_mapping.v1`?
>
> **Options:**
> 1. `forex_factory_calendar_clean.csv` canonical (it is already the file
>    `state_contracts_v1.md` §4's News lamp freshness-checks as the live-facing source).
> 2. `news_calendar_2015_2025.csv` canonical (broader historical range, per its name).
> 3. Build a third, reconciled classification (highest-impact-wins, or a manually
>    reviewed override list for the disagreeing 41.7%) — most defensible, most work.
> 4. Something else OWNER specifies.
>
> **Consequence of no decision:** §3's "exactly one source" rule cannot be satisfied for
> impact-sensitive gating until this is ratified; Q09 rows dependent on impact
> classification remain in their current (V1, unlabeled) state. This is not a blocker to
> shipping §1/§2/§5/§6/§7/§8/§9 in the meantime — those do not depend on which source
> wins.
>
> **Recorded as:** pending, no OWNER response yet as of this document's date
> (2026-08-22). Once decided, record under `decisions/YYYY-MM-DD_news_impact_taxonomy.md`
> citing this section.

## Evidence / sources consulted

- `framework/include/QM/QM_DSTAware.mqh` (live, validated DST rule — source of §2).
- `framework/scripts/p8_news_driver.py:254,275` (current unversioned impact_rank).
- `tools/strategy_farm/news_calendar_gate.py:45-47` (mandatory two-file pair, no
  precedence rule).
- `tools/strategy_farm/q09_news_calendar.py`, `q09_news_runner.py`, `q09_news_schema.py`
  (existing self-report field locations, pre-consolidation).
- `tools/strategy_farm/q09_news_contract.py:34-35` (the unrelated, already-taken
  `q09-news-evidence/v2` schema name — naming-collision note above).
- Consulting audit `§6 F-03` / `§14 S-05` / `§15` (OWNER decision item), Google Drive
  fileId `1TlfBZ2FoYLgfxTjiNiGeGhIxQjV0xG54`.
- `docs/ops/evidence/2026-08-04_ftmo_q09_news_consumption_contract.md` and
  `2026-08-04_q09_news_activation_and_q10_contract.md` — reviewed and confirmed **out of
  scope** for this lock: they govern Q09 *consumption* (which downstream FTMO/DXZ
  surface trusts a Q09 verdict), not calendar *semantics* (what the verdict is computed
  from). Unaffected by this document.
