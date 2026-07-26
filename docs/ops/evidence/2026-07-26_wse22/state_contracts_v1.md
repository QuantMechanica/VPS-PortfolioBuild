# Live-state contracts v1 — WS-E2 morning-brief live lamp

**Version:** 1 · **Date:** 2026-07-26 · **Owner surface:** `tools/strategy_farm/morning_brief.py::live_status()`
**Scope:** the read-only state files the daily 06:00 briefing's *Live-Ampel* (Section 0)
consumes. This is the ONE versioned shared contract between the producers (WS-E1
alarm state, WS-E3 deployment-contract verifier, the FTMO monitor, the DXZ DD-guard)
and the consumer (this brief + cockpit). It records **what the producers actually
emit** — the readers match these schemas exactly, so a fresh valid producer file
renders GREEN/RED by content; missing / stale / malformed always fail to
UNKNOWN/RED, never green-by-absence (Operating Rule 20: state-file only, no process
probe, no `T_Live` access).

Severity: `GRÜN(0) < GELB(1) < UNBEKANNT(2) < ROT(3)`; overall = worst sub-lamp;
UNKNOWN and RED both reach the subject line.

---

## 1. WS-E1 alarm state — `D:\QM\reports\state\live_alarm_state.json`

**Producer:** `QM_T_Live_Watchdog` (SYSTEM, ~1/min) via `Live_Alarm_State.ps1`. Single
author, atomic write. **Top-level fields (exact):**

```
schema_version, generated_utc, author, watchdog_status,
maintenance, reboot_suppressed, any_alarm, sessions{ T_LIVE, FTMO }
```

- `watchdog_status` ∈ `healthy | degraded | critical | maintenance`.
- `generated_utc` — ISO-8601 `...Z`; refreshes every cycle (freshness anchor).
- each `sessions.<S>`: `session, condition, detail, alarm, since_utc, last_change,
  transitions, previous_condition`.
- `condition` ∈ `ok | missing | duplicate | launch_failed | probe_unknown | stale | maintenance`.

**REQUIRED for interpretation** (`_e1_schema_ok`, fail-closed gate — a present,
parseable alarm file **IS** the E1 producer and must satisfy ALL of these BEFORE its
status is read; anything missing ⇒ the reader returns **UNBEKANNT `SCHEMA?`**, never
GRÜN, and does **not** silently fall through to the pre-E1 fallback):
- `generated_utc` — present **and** parseable (the freshness anchor).
- `watchdog_status` — present, non-empty.
- `sessions` — a dict containing **both** required session blocks `T_LIVE` **and**
  `FTMO` (case-insensitive key match), each a dict carrying a non-empty `condition`.

A parseable-but-incomplete object such as `{"watchdog_status":"healthy","sessions":{}}`
(no `generated_utc`, no session blocks) fails this gate and renders UNBEKANNT — it is a
broken producer, not a healthy live book. (Fallback to `live_uptime_watchdog.json`
happens only when the alarm file is **absent**, never when it is present-but-invalid.)

**Consumer mapping** (`_lamp_watchdog`, E1 branch):
- base from `watchdog_status`: healthy→GRÜN, degraded→GELB, critical→ROT, maintenance→GELB.
- **T_LIVE** (DXZ money-book terminal) session escalation: `missing|duplicate|launch_failed`
  → ROT (live trading not running); `probe_unknown` → UNBEKANNT; `stale` → GELB.
- **FTMO** session alarm conditions → at most GELB (trial, not the money book).
- `any_alarm=true` forces at least GELB.
- `generated_utc` older than **900 s** ⇒ ROT `STALE` (watchdog/recovery loop dead);
  older than **300 s** and otherwise green ⇒ GELB.
- value = `DXZ <cond> · FTMO <cond>`.

**Fallback** when `live_alarm_state.json` is absent (pre-E1-merge): read the shipped
`live_uptime_watchdog.json` (`ts|last_checked_utc, status, dxz_running, ftmo_running,
process_probe_ok, maintenance, errors`) + `live_session_supervisor.json`. Same
severity model; label reads "Live-MT5 Watchdog" (vs "Live-MT5 (E1-Alarm)").

Byte-conformant samples: `tests/fixtures/morning_brief_live/producer_samples/wse1_alarm_*.json`.

---

## 2. WS-E3 deployment-contract state — `D:\QM\reports\state\live_deployment_contract_state.json`

**Producer:** `verify_live_deployment_contract.py --json-out
D:\QM\reports\state\live_deployment_contract_state.json` (run `--trigger post_recovery`
after any recovery **and** `--trigger periodic`; scheduling is an ops action).
**Top-level fields (exact):**

```
tool, version, generated_utc, trigger, overall_status,
resolved_paths, manifest, identity, disk_profile, runtime, findings, summary
```

- `overall_status` ∈ `GREEN | AMBER | RED | UNKNOWN` (exit 0/1/2/3).
- `generated_utc` — ISO-8601 with offset + microseconds, e.g. `...+00:00`.
- `summary` = `{ critical, warn, info, headline }`.
- `disk_profile` = `{ status, chart_files_total, trading_parseable, unparseable,
  monitor_count, monitor_status, expected_present_ok, expected_missing,
  expected_field_mismatch, duplicates, orphans, sleeves[] }`.
- `runtime` = `{ status, event_log_dir, n_logs_indexed, sleeves[] }`.

**REQUIRED for interpretation** (`_e3_schema_ok`, fail-closed gate — a present,
parseable state must satisfy ALL of these BEFORE `overall_status` is trusted; anything
missing ⇒ the reader returns **UNBEKANNT `SCHEMA?`**, never GRÜN):
- `generated_utc` — present **and** parseable (freshness anchor).
- `overall_status` — present, non-empty.
- `summary`, `disk_profile`, `runtime` — each present **and** a dict (block, not scalar).
- `findings` — present **and** a list.

A parseable-but-incomplete object such as
`{"overall_status":"GREEN","disk_profile":{"expected_present_ok":24,"expected_missing":0}}`
(no `generated_utc`, no `summary`/`runtime`/`findings`) fails this gate and renders
UNBEKANNT — it must **not** render a green `24/24` from a bare disk-profile scalar.

**Consumer mapping** (`_lamp_contract`): `overall_status` consumed **directly**
(GREEN→GRÜN, AMBER→GELB, RED→ROT, UNKNOWN→UNBEKANNT). value =
`expected_present_ok / (expected_present_ok+expected_missing)`; detail =
`summary.headline`. `generated_utc` older than **7 d** ⇒ ROT STALE; older than
**36 h** ⇒ at least GELB. **Absent** ⇒ UNBEKANNT advisory ("E3 not yet scheduled"),
never GRÜN.

Byte-conformant samples: `.../producer_samples/wse3_deployment_contract_{red,green}.json`.

---

## 3. Deploy-stamp (signed-manifest authentication) — `D:\QM\reports\state\live_deployment_pointer.json`

`status==LIVE` on the manifest is **NOT sufficient** to render the Deploy lamp GRÜN.
The lamp requires an authenticated **deploy-stamp** — the record ops writes at deploy
time. The current LIVE manifest carries only `approved_by` prose (no `signed`, no
`manifest_sha256`, no `deployment_epoch`, no `expected_account/phase`), so those
authentication fields live in the stamp.

**Deploy-stamp contract — tonight's deploy MUST write these fields:**

| Field | Type | Meaning / check |
|---|---|---|
| `manifest_path` | str | absolute path to the deployed signed manifest JSON |
| `manifest_sha256` | hex str | SHA-256 of that manifest file; the lamp **recomputes** the file hash and requires an exact match (mismatch ⇒ ROT — tamper / wrong file) |
| `signed` | bool | must be `true` |
| `approved_by` | str | non-empty approver identity/signature |
| `deployment_epoch_utc` | ISO-8601 | when the book went live (must parse) |
| `expected_account` | str | e.g. `"4000090541"`; a **bindable** account (≥6 digits) must be derivable from the manifest `book` **and** this value must match it. Mismatch ⇒ ROT; **manifest with no bindable account (e.g. `book="DXZ"`) ⇒ UNBEKANNT — never green** |
| `expected_phase` | str | e.g. `"DXZ_LIVE"` / `"FTMO_TRIAL"` (non-empty) |

**Resolution order:** direct override (tests) → runtime stamp
`live_deployment_pointer.json` → repo default
`tools/strategy_farm/config/live_deployment.json`.

**Consumer mapping** (`_lamp_deployment` + `_authenticate_deploy`):
- GRÜN requires ALL: authenticated runtime stamp (not the repo default), `signed==true`,
  non-empty `approved_by`, `manifest_sha256` present **and matching** the recomputed
  file hash, parseable `deployment_epoch_utc`, a **bindable** manifest-book account that
  the stamp's `expected_account` **matches**, non-empty `expected_phase`, and manifest own
  `status==LIVE`.
- **REQUIRED bindable account:** the account is authoritative only when it can be bound.
  A manifest whose `book` yields no ≥6-digit account (e.g. `book="DXZ"`) is **unbindable**
  — the stamp's `expected_account` cannot be corroborated, so authentication is impossible
  ⇒ **UNBEKANNT** (never GRÜN), regardless of a valid `signed`/SHA/epoch/phase. This closes
  the round-2 hole where a signed stamp over a bookless manifest authenticated green.
- SHA mismatch or account **mismatch** ⇒ **ROT**. Unbindable manifest account ⇒
  **UNBEKANNT**. Any other missing auth field, or resolving only from the repo default, or
  manifest status≠LIVE ⇒ **GELB** ("manifest-derived, NOT authenticated"). No manifest at
  all ⇒ **UNBEKANNT**.
- `expected_sleeves` + `account` are always derived from the manifest (`n_sleeves` +
  `book`) so the sleeve count shows even when the stamp is unauthenticated. **Never a
  hard-coded constant** (`LIVE_BOOK_SLEEVES` removed).

**Example stamp (what ops writes after the Sunday deploy):**
```json
{
  "manifest_path": "D:\\QM\\reports\\portfolio\\portfolio_manifest_...json",
  "manifest_sha256": "8C719B08...EAB6",
  "signed": true,
  "approved_by": "OWNER (Fabian) 2026-07-27 chat countersign",
  "deployment_epoch_utc": "2026-07-27T20:30:00Z",
  "expected_account": "4000090541",
  "expected_phase": "DXZ_LIVE"
}
```
The committed repo default (`config/live_deployment.json`) is `signed:false` on purpose
⇒ Deploy lamp is GELB by design until the runtime stamp exists (never a false GRÜN).

---

## 4. Already-shipped producers (unchanged schema, verified against live files)

| Lamp | File | Fields consumed | Mapping |
|---|---|---|---|
| DD-Guard | `live_book_dd_guard_state.json` | `last_run_utc, breached, halt_dd_pct, last_dd_pct` | breached⇒ROT; >2 h stale⇒ROT; >30 m⇒GELB; else GRÜN |
| FTMO | `ftmo_trial_pulse.json` | `checked_at_utc, verdict, terminal_up, total_dd_pct, day_loss_pct, equity` | terminal down or DD≥10%⇒ROT; verdict WARN or DD≥9.9%⇒GELB; OK⇒GRÜN. Trial-dead/alive prose generated from these numbers |
| News | `D:\QM\data\news_calendar\forex_factory_calendar_clean.csv` | file mtime | ≤36 h GRÜN; ≤8 d GELB; else ROT; **absent⇒ROT** (live filter would have no data) |

Freshness SLAs are declared in `morning_brief._SLA`.
