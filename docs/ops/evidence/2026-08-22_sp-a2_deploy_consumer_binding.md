# SP-A2 — Deploy-Consumer binden + Live-Burn-in reparieren

Task: `agent_router` task `039d65c8-37c7-44be-804c-b1a7fc8c0c45` (SP-A2, priority 88,
zone GELB, Schienenplan 2026-08-22, `depends_on: SP-A1`). Consulting audit `§4 F-01` /
`§14 S-03`. Goal: Pulse, `run_live_burnin.ps1`, `sunday_livevsbook_compare.ps1`, Morning
Brief and the live-book Inventory all resolve `manifest_path`/epoch from the SP-A1
authenticated runtime deploy pointer (`D:\QM\reports\state\live_deployment_pointer.json`)
instead of five independently-drifting hardcoded defaults, with `RequireSigned` enforced
on the scheduled-task path and no silent fallback for a binding verdict.

## Starting state (per-consumer)

| Consumer | Before | Gap |
|---|---|---|
| Morning Brief (`morning_brief.py`) | Already reads the runtime pointer (`_resolve_deploy_stamp`, wse23) | none — verified only |
| Pulse (`live_book_pulse.py`) | `DEFAULT_BOOK_MANIFEST` = env var or hardcoded 24-sleeve path; own default, not pointer-derived | could silently drift from the authenticated pointer with no visibility |
| Burn-in (`run_live_burnin.ps1`) | `$Manifest` hardcoded to a **stale June 13-sleeve draft** (`GoLive_D2c_13sleeve_2026-06-28`); no `--deployment-epoch`/`--require-signed` passed | burn-in report defaulted to epoch 1970, 0 observed days, verdict UNKNOWN for the wrong reason |
| Sunday comparator (`sunday_livevsbook_compare.ps1`) | `-Manifest`/`-DeploymentEpoch` hardcoded (epoch `2026-07-19`, stale vs the 07-24 manifest); `-RequireSigned` an **opt-in switch**, not enforced by default | manual re-pointing required on every new-book deploy; unsigned manifests could pass silently on the scheduled-task path |
| Inventory (`audit_live_book_inventory.py`) | No manifest cross-reference at all; docstring claimed "no current authoritative manifest... DRAFT... 2026-06-26... six sleeves" | stale prose, no drift detection between per-EA logs and the deployed roster |

## Changes made

1. **`tools/strategy_farm/live_book_pulse.py`** — `DEFAULT_BOOK_MANIFEST` now resolves via
   `_default_book_manifest_source()`: env override (`QM_DXZ_BOOK_MANIFEST`, explicit
   operator pin) → runtime pointer's `manifest_path` (new) → hardcoded repo default
   (unchanged fallback, only reached if both prior tiers are absent). Added
   `reconcile_against_deploy_pointer()`: every run compares the manifest Pulse actually
   loaded against the pointer's declared `manifest_sha256`; a mismatch raises a **FAIL**
   alarm (`deploy_pointer_manifest_sha_mismatch`) — the F-01 "all five consumers report
   the same hash" bar, made observable and alarmable rather than assumed. New snapshot
   field `deploy_pointer_reconciliation`; `book_manifest.source` now shows which
   resolution tier fired. 15/15 existing tests pass unchanged.
2. **`tools/strategy_farm/portfolio/audit_live_book_inventory.py`** — fixed the stale
   docstring (no longer claims no manifest exists / cites the June DRAFT). Added
   `load_manifest_reconciliation()`: reads the pointer's `expected_sleeves.roster` magic
   list and diffs it against the magics actually observed in the per-EA logs, reporting
   `OK`/`DRIFT`/`UNKNOWN` — evidence added on top of, never a replacement for, the
   log-based ATTACHED/EMITTING/TRADING read (which remains the primary source per the
   module's own stated design). Real run today surfaced genuine drift (5 stale
   ea/magic combos still on disk with logs, one unconfigured `ea_id=0` entry) — a
   pre-existing condition now visible, not something this task's scope resolves.
3. **`tools/strategy_farm/run_live_burnin.ps1`** — reads `manifest_path` and
   `deployment_epoch_utc` from the runtime pointer via regex extraction on the raw JSON
   text (see "PowerShell JSON pitfall" below), passes `--deployment-epoch` and
   `--require-signed` to `portfolio_live_forward_from_logs.py` (both already supported by
   that tool but never wired through this wrapper). Fails closed (exit 2, explicit
   `Write-Error`) if the pointer is missing or lacks either field — never falls back to
   the old hardcoded manifest.
4. **`scripts/sunday_livevsbook_compare.ps1`** — `-Manifest`/`-DeploymentEpoch` default to
   `$null` and are resolved from the runtime pointer at run time (same regex approach);
   explicit `-Manifest`/`-DeploymentEpoch` args still override (e.g. to inspect a
   candidate manifest by hand). `-RequireSigned` changed from an unenforced `[switch]`
   to `[bool] = $true` — enforced by default on every invocation including the
   scheduled task; an operator must pass `-RequireSigned:$false` explicitly to bypass.
   Fails closed if the pointer is absent/incomplete and no explicit args were given.
5. **Morning Brief** — no code change; verified `_resolve_deploy_stamp`/
   `_authenticate_deploy` (`morning_brief.py:622-723`) already implement the pointer
   resolution order and fail-closed authentication (GREEN only with `signed==true` +
   matching SHA + bindable account + non-empty phase; unbindable account ⇒ UNKNOWN,
   never GREEN).

## PowerShell JSON pitfall (found + worked around in both .ps1 files)

`ConvertFrom-Json` followed by string interpolation of an ISO-8601-looking property
(e.g. `deployment_epoch_utc`) auto-coerces it to `[datetime]` and re-renders it in the
current culture's date format on interpolation (observed: `'07/24/2026 08:42:00T00:00:00'`
instead of `'2026-07-24T06:42:00+00:00'`), which Python's `datetime.fromisoformat()`
cannot parse — the burn-in run failed with exactly this error before the fix. Both
scripts now extract `manifest_path`/`deployment_epoch_utc` via regex on the raw JSON
text instead of property access, preserving the literal bytes.

## Verification — same manifest SHA across all consumers (today's run)

All four re-run this cycle report **`manifest_sha256 = 8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`**
(the SP-A1 pointer's declared hash), sourced from the same manifest
`D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`:

- **Pulse**: `book_manifest.sha256` = `8c719b08…eab6`, `source=runtime_pointer`,
  `deploy_pointer_reconciliation.match=true`.
- **Inventory**: `manifest_reconciliation.manifest_sha256` = `8c719b08…eab6` (read from
  the pointer directly).
- **Burn-in**: stdout `manifest_sha256=8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`,
  `n_days=24` (window 42, immature=True — real observation count, not the prior 1970/0
  pathology), `manifest_signature=SIGNED (status=LIVE, signed=True)`. Verdict is still
  `UNKNOWN`, but now for two **honest, pre-existing** reasons unrelated to this task's
  scope: no manifest-bound SUM-of-sleeves Monte-Carlo reference exists for this book
  (`--mc-artifact`/`--build-mc` not supplied), and the manifest carries no backtest
  Sharpe. This is correct fail-closed behaviour (§ "no silent fallback verdict"), not a
  regression — the epoch bug that produced the *dishonest* 1970/UNKNOWN report is fixed.
- **Sunday comparator**: identical output, `manifest_sha256=8c719b08…eab6`, exit 0,
  `RequireSigned=True` enforced and satisfied (manifest is SIGNED).

## Not done in this task (explicitly out of scope)

- Binding a SUM-of-sleeves Monte-Carlo DD reference to the current 24-sleeve book (would
  turn the burn-in/comparator verdict from UNKNOWN toward an actual PASS/FAIL) — separate
  work, `make_live_burnin_mc_reference.py`.
- Reconciling the newer, unreconciled 2026-07-26 manifest candidates that
  `farmctl.py health`'s `ks_baseline_dormancy` check flagged
  (`portfolio_manifest_sunday_FINAL22/23/24b_TOTALRISK12_20260726*.json`) against the
  currently-pointed 07-24 manifest — an OWNER decision (see SP-A1 schema doc §4), not a
  consumer-wiring change.
- Signing the pointer itself (OWNER/ROT only, see SP-A1).

## Evidence

- Code: `tools/strategy_farm/live_book_pulse.py`,
  `tools/strategy_farm/portfolio/audit_live_book_inventory.py`,
  `tools/strategy_farm/run_live_burnin.ps1`, `scripts/sunday_livevsbook_compare.ps1`.
- Test run: `python -m pytest tools/strategy_farm/tests/test_live_book_pulse.py -q` →
  15 passed.
- Live runs (read-only, this cycle): `live_book_pulse.py` →
  `D:\QM\reports\state\live_book_pulse.json`; `audit_live_book_inventory.py` →
  `C:\QM\repo\artifacts\audit_live_book_inventory_20260819.json`; `run_live_burnin.ps1` →
  `D:\QM\reports\portfolio\live_burnin\portfolio_live_burnin_report.json`;
  `sunday_livevsbook_compare.ps1` →
  `D:\QM\reports\portfolio\live_burnin\livevsbook_sunday_20260822.json`.
