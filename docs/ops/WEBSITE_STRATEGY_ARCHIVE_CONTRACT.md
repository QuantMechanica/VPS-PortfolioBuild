# Website Strategy-Archive Contract v1

**Task:** QM-TODO-20260820-003 · Router task `ee42fad4`
**Status:** STAGING contract + generator landed. Publication deferred behind the
existing public-snapshot incident guard.
**Programme page:** `G:\My Drive\QuantMechanica - Company Reference\12 ToDo\04_Website.md`
**Generator:** `tools/strategy_farm/website_archive_contract.py`
**Tests:** `tools/strategy_farm/tests/test_website_archive_contract.py`
**Preview tree:** `D:\QM\exports\website_contract_preview\` (staging only)

This contract transfers the *existing* operational Strategy Archive
(`work_items` pipeline DB + approved Strategy Cards + `framework/EAs` folders)
into a versioned, redacted JSON contract for quantmechanica.com. It does **not**
build a second archive: the same pipeline database that
`tools/strategy_farm/dashboards/render_dashboards.py` renders is the sole source
of truth (programme rule "Kein zweites Strategy Archive").

---

## 1. Truth rules (from the programme page)

The contract is built to be honest and complete, never cherry-picked:

- **Every EA identity appears exactly once** in `strategy_summaries.json`.
- **Mixed-era cohorts are labelled.** A result stored under a legacy `P*` phase
  key is emitted with `era: "legacy"` and the freshness reason `GATE_CHANGED`;
  it is never silently promoted to a current-gate PASS.
- **Public gate wording is Qxx only.** Storage keeps legacy `P*` keys; the
  generator maps them to canonical Qxx (`P2 -> Q02`) for output via
  `phase_ids.phase_qid`. Internal/non-pipeline phases (`HARNESS_PP_FIXTURE`) are
  dropped, not shown as gates.
- **Card grade measures document quality, not profitability** (A/B/C/D/Blocked),
  and the missing parts that produced the grade are published alongside it so
  the grade is auditable.
- **Missing evidence is stated, never faked.** A gate result whose report file
  is absent carries `report_published: false`,
  `status: "REPORT_NOT_PUBLISHED"`, and freshness reason `EVIDENCE_MISSING` —
  there is no dead download button and no invented number.

---

## 2. Addressable chain and stable public IDs

The contract makes the chain **EA → Strategy Card → (Symbol, Gate) verdict →
Report** addressable end-to-end. Shared keys across all four files:

| Key | Meaning | Stability basis |
|---|---|---|
| `ea_id` | Public EA identity, e.g. `QM5_10000` | Canonical; derived from the framework folder / card **filename**, never a stale bare frontmatter value (see §6) |
| `card_id` | `card_<sha256[:16]>` of the card file content | Content hash — changes only when the card changes |
| `card_sha256` | Full card content hash | Integrity |
| `symbol_id` | Broker-neutral symbol token, e.g. `EURUSD.DWX` | Public-safe; no account mapping |
| `gate_id` | Canonical Qxx | `phase_ids.PHASE_ORDER` |
| `gate_contract_version` | `<gate-manifest schema>#<sha[:12]>` | Pins the gate definition the verdict was scored under |
| `run_id` | `run_<sha256[:16]>` of the work-item id | Opaque; decouples the public id from the internal UUID |
| `report_id` | `rpt_<sha256[:16]>` of the evidence path | **Opaque** — the raw path is hashed and never emitted |

### Join guarantees (verified on the live DB, §5)

- Every `strategy_summaries[].card_id` resolves in `strategy_cards_public.json`.
- Every `gate_results[].report_id` resolves in `report_manifest.json`.
- Every EA appearing in `gate_results.json` has a `strategy_summaries.json` row.

---

## 3. Files (contract v1)

Four versioned exports + an `index.json` manifest, all written into the staging
preview dir. Each file carries `contract_version`, `$schema_id`,
`generated_at`, `gate_contract_version`, and an `items` array.

| File | Row grain | Allowlisted fields |
|---|---|---|
| `strategy_summaries.json` | one per EA | `ea_id, slug, family, timeframe, card_id, card_grade, highest_pass_gate, most_advanced_gate, gate_status, n_symbols_tested, symbols_sample, n_gate_results, has_source, has_binary, era, last_reliable_check_utc, freshness` |
| `strategy_cards_public.json` | one per approved card | `card_id, ea_id, slug, card_sha256, grade, grade_missing_parts, id_reconciled_from_frontmatter, frontmatter(allowlisted subset), excerpt_redacted` |
| `gate_results.json` | one headline row per `(ea_id, symbol_id, gate_id)` | `ea_id, symbol_id, gate_id, gate_name, gate_contract_version, era, run_id, verdict, metrics, updated_at_utc, freshness, freshness_reasons, report_id, report_published` |
| `report_manifest.json` | one per referenced report | `report_id, published, status, content_sha256, media_type` |

**Headline row selection** (per `(ea, symbol, gate)` cell): prefer
non-ablation → graded (has parsed metrics) → pass-ish verdict → most recent.
This mirrors the archive dashboard's representative-attempt rule so a public row
is never an INFRA re-run that hides a genuine PASS.

**Public verdict vocabulary** (coarse, honest): `PASS`, `FAIL`, `INFRA`,
`RETIRED`, `SUPERSEDED`, `ZERO_TRADES`, `OPEN`. Storage verdicts collapse into
these; `PASS_SOFT`/`PASS_LOWFREQ`/`MULTI_SEED_PASS` map to `PASS`.

**Public metrics** (safe scalars only): `net_profit, profit_factor, trades,
drawdown_money, drawdown_pct, sharpe`. These come from the normalized
`ea_metrics` layer keyed by work-item id; backtests run `RISK_FIXED` off a public
starting balance, so these numbers leak no account state.

### Freshness

`freshness ∈ {current, stale, unknown}` with machine-readable reasons drawn from
the programme's stale-reason set: `EVIDENCE_MISSING`, `GATE_CHANGED` (legacy
era), `RECHECK_DUE` (older than 120 days). A full `build_hash` / `card_hash` /
`cost_model` staleness comparison is defined by the programme but **not yet wired
in this staging pass** — the generator exposes the hashes it can compute
(`card_sha256`, report `content_sha256`) and the age/evidence-based reasons; the
remaining `BUILD_CHANGED`/`CARD_CHANGED`/`DATA_CHANGED`/`COST_MODEL_CHANGED`
comparisons are a follow-up (§7).

---

## 4. Redaction rules (fail-closed, encoded as code)

Redaction lives in `website_archive_contract.py` as functions with unit-test
fixtures, not as prose. **Unknown field classes are DROPPED by default.**

### Record projection — `redact_record(record, allowed)`

1. Only keys in the explicit per-file allowlist survive. Any key not on the
   allowlist is **dropped** (fail-closed default).
2. Defence in depth: even an allowlisted key is refused if its name matches a
   forbidden token (`magic`, `account`, `login`, `password`, `secret`, `token`,
   `apikey`, `credential`, `server`, `host`, `hostname`, `vps`, `terminal`,
   `claimed_by`, `worker`, `path`, `dir`, `ip_addr`, …).
3. Surviving string / dict / list values are scrubbed by `scrub_text`.

### Free-text scrubbing — `scrub_text(s)`

Each forbidden class is replaced with `[REDACTED]`:

| Class | Pattern | Rationale |
|---|---|---|
| Absolute Windows path | `C:\…`, `D:\…`, `G:\…` | no local paths |
| `file://` URI | `file:///D:/…` | no local paths |
| UNC path | `\\HOST\share\…` | no VPS/hostname detail |
| POSIX system path | `/mnt`, `/home`, `/root`, `/opt`, `/var` | no host paths |
| IPv4 | `10.4.221.7` | no VPS/network detail |
| Labelled account/login/**magic** number | `account: 1234…`, `magic=100390001` | magic maps to account (`ea_id*10000+slot`) |
| Credential assignment | `password:`, `api_key=`, `bearer:` | no broker credentials |

Benign numbers (trade counts, PF, net profit) are preserved — verified by test
`test_scrub_preserves_benign_numbers`.

### What is intentionally never emitted

`evidence_path`, `setfile_path`, `claimed_by`, magic numbers, terminal/host
identifiers, broker login/server — all excluded by the allowlist **and** the
forbidden-token guard. The report path is reduced to an opaque `report_id`; the
report's `content_sha256` is exposed for later integrity verification without
revealing the path.

---

## 5. Measured run (live DB, 2026-08-21)

`python tools/strategy_farm/website_archive_contract.py`

```
eas:                 3737
cards:               3271
gate_results:        24811
reports_referenced:  23506
gate_contract_version: qm.gate-manifest/v2#721b9b8821ff
```

Leak scan (generator's own forbidden patterns applied to every parsed string
value in every output file): **0 real leaks** across all five files. Join scan:
0 dangling card refs, 0 dangling report refs, 0 gate-EAs missing a summary row.

`pytest tools/strategy_farm/tests/test_website_archive_contract.py` → **38
passed**.

---

## 6. Known upstream data-quality items (surfaced, not silently rewritten)

- **16 approved cards** carry a bare/mismatched `ea_id` in their frontmatter
  (e.g. `QM5_1143_*.md` with `ea_id: 1143`). The generator takes the **filename**
  as canonical identity, flags the row `id_reconciled_from_frontmatter: true`,
  and re-keys the card so the EA→card→gate join holds. The underlying card
  frontmatter defect should be fixed upstream (separate ticket).
- **1 bare-numeric EA id (`20022`)** exists directly in `work_items`. It flows
  through as its own summary row rather than being guessed into `QM5_20022`;
  correcting it requires OWNER/upstream confirmation of the intended identity.

---

## 7. Publication boundary and follow-ups

**This generator is staging only.** It writes exclusively to
`D:\QM\exports\website_contract_preview\` and refuses (raises `SystemExit`) any
output path inside `public-data/` — see `_assert_staging_only` and test
`test_write_refuses_public_data_dir`. It does **not** invoke the live exporter
(`scripts/export_public_snapshot.ps1`) or touch its fail-closed public-snapshot
incident guard (`tools/strategy_farm/public_snapshot_incident_guard.py`).
Publication of any of these files to `public-data/` stays behind that existing
guard, which refuses publication while either automatic Q02-bypass hold is
active.

Follow-ups (not in this staging pass):

1. Full staleness engine: `BUILD_CHANGED` / `CARD_CHANGED` / `DATA_CHANGED` /
   `COST_MODEL_CHANGED` by comparing the tested `build_hash` / card / cost-model
   against the released binary.
2. JSON Schema files (`website-strategy-archive.schema.json` family) + wiring
   into `scripts/validate_public_snapshot.ps1`, matching the v1 contract policy
   in `public-data/README.md`.
3. Q04 walk-forward fold sub-rows and other hierarchical sub-tests (the
   programme wants folds addressable under the aggregate, not counted as
   independent gate PASSes).
4. Fix the 16 card-frontmatter id defects + the bare `20022` work-item id
   upstream.

---

## 8. Rollback

Pure additive, no state mutation. To roll back: delete
`tools/strategy_farm/website_archive_contract.py`,
`tools/strategy_farm/tests/test_website_archive_contract.py`, this doc, and the
staging tree `D:\QM\exports\website_contract_preview\`. Nothing in the farm DB,
`public-data/`, the live exporter, or any scheduled task is touched.
