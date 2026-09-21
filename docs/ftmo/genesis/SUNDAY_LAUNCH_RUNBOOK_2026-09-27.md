# RUNBOOK — Sunday 2026-09-27 representative FTMO Demo generation (v0, Fable 2026-09-21)

Authority: OWNER-DEC-FTMO-FINAL-MEGA-20260921 §P–§T (launch date, not a quality waiver; Fable launches autonomously when the
critical preflight is green; the sole OWNER approval stays the paid Challenge purchase). Operator: Fable. Pattern: the D2g6 cutover
runbook `docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/RUNBOOK.md` (every step has a readback and a stop condition; nothing
here touches `C:\QM\mt5\T_Live` or `D:\QM\mt5\T1..T10`; `demo_install` refuses them structurally). This v0 is the plan; the
executable package, the genesis manifest and the preflight report are produced by the steps below and committed under
`docs/ops/evidence/2026-09-27_ftmo_demo_generation_2/` (name fixed here so the tickets can target it).

## 0. Inputs that must exist before Saturday 2026-09-26 12:00Z (else NO-GO, launch slips to the next Sunday)

| # | Input | Source | Status 2026-09-21 |
|---|---|---|---|
| I1 | Kill-switch governed initializer (Prague day-key helper, named anchor mode, book tag, `KS_DAY_ROLLOVER`, pulse state check), build_check PASS for the six sleeves | Codex `d6189118` → Fable cross-vendor review | IN_PROGRESS |
| I2 | Demo-day retro audit of 2026-09-18..26 (`BEHAVIOR_IDENTICAL / POTENTIALLY_DIFFERENT / MATERIALLY_INVALID`) | Codex `4505b206` | APPROVED for 09-18..21 (2 valid days); re-run for 09-22..26 with rule v2 before launch |
| I3 | `genesis_manifest.py build/verify` + `sunday_preflight.py` | Codex `94a15624` | IN_PROGRESS |
| I4 | Sleeve-level P&L attribution tool + sidecar | Codex `74c41987` | IN_PROGRESS |
| I5 | News/time archive audit bound (live builds never read the archive; confirms the live news filter path is unaffected) | Codex `a36a5983` | IN_PROGRESS |
| I6 | Antigravity FTMO-compliance / failure-mode critique of this runbook's checklist and the KS spec | agy `cb0eb674` | APPROVED (4 uncovered failure modes folded into d6189118 / 94a15624 and the status checklist) |
| I7 | **Demo account identity for the new generation** — see §1 | OWNER / Fable | DECIDED A 2026-09-21; credentials pending in `.private/secrets/ftmo_demo_gen2_20260927.md` |
| I8 | FTMO rules snapshot re-verified ≤ 7 days before launch (`docs/ftmo/FTMO_RULES_SNAPSHOT_<date>.md`, official sources, timestamps) | Fable (agy critique cross-checks) | 2026-09-18 snapshot; refresh Friday |

## 1. Account decision (the one human-interface item)

OWNER §P says "the next FTMO Demo account starts on Sunday 2026-09-27". Two readings, decided by Friday 2026-09-25:

- **A — fresh FTMO Free-Trial account (preferred by §R "Demo account clean before attach" and §T "clock starts at the launch
  timestamp"):** a new login/server/password from the FTMO client area. Creating it requires the OWNER's client-area login (human
  MFA) — the smallest exact human action: create a 100k 2-Step Free Trial, hand Fable login + server (password via the existing
  secure channel, never in the repo). Fable then re-targets the terminal (new data-dir login) or installs a second FTMO terminal
  instance; the genesis manifest records the new identity.
- **B — same account 1514536732, new generation:** allowed only if the balance is flat-reset or the retro audit (I2) shows the
  pre-Sunday days are cleanly separable; the generation identity then comes from the book tag + launch timestamp, and the account
  history before the timestamp is excluded from the representative evidence. Weaker; use only if A is not available by Saturday.

**DECIDED 2026-09-21 ~19:55Z: A** (OWNER in chat; receipt `46ea4491` on card OWNER-DEC-FTMO-DEMO-ACCOUNT-GEN2-20260927, execution task
`90847e73` on the Claude lane). Handover path: OWNER creates the Free Trial (100k, 2-Step, Standard, MT5) in the FTMO client area and
writes login, server and password into `.private/secrets/ftmo_demo_gen2_20260927.md` (git-ignored, local only; the current demo's
credentials live next to it in `ftmo_demo_20260906.md`) — or names login + server in chat and puts only the password there. Fable then
retargets the terminal (`terminal64 /login /server /password` start parameters, AutoTrading off), verifies balance 100000.00 / no
positions / no orders, and binds the identity into the genesis manifest. The Auffangregel B is void.

## 2. Saturday 2026-09-26 — freeze and package (terminal untouched)

1. **Roster freeze.** Incumbent D2g6 six sleeves unless a *resolved* marginal improvement exists (`FTMO_BOOK_CURRENT.md` §2 rule: a
   financed Δ LCB ≥ +0.01 at ≥ 5,000 paths with seed replicates). Write `roster.json` (schema `qm.ftmo-demo-roster/v1`) with the
   KS-rebuilt sleeves' source/EX5/preset hashes. Book risk stays 1.71875 % unless the simulator-confidence work (`3fae43b2`) says
   otherwise.
2. **Alias builds** of the six sleeves against the new `QM_KillSwitch.mqh` / governed initializer (same procedure and receipt format
   as `RECEIPT_alias_builds.md`), `build_check` 0 errors / 0 warnings each; sealed `.ex5` sha256 recorded; magic registry consistency
   (`ea_id*10000+slot`) re-verified.
3. **Presets** via the existing generator (`trial_setpath`): ENV=live, `RISK_PERCENT` per roster, `RISK_FIXED=0`, live news filter
   (native calendar; the backtest archive is never read), FTMO book tag + anchor mode inputs as the new initializer requires;
   `sets/manifest.json` validated 6/6.
4. **Governor rebind** dry-run (`tools.strategy_farm.ftmo.governor_rebind --roster … --challenge-id M13_<GEN2>_20260927_<login>`):
   allowed magics, sleeve risks, Prague rollover mode, Daily-Loss / Max-Loss controls, server-request limits — readback equals the
   dry-run JSON; commit the three rebound files + the pulse `EXPECTED_MAGICS` rebind in one pathspec commit.
5. **Genesis manifest** (`genesis_manifest.py build`): identity (login masked), rules snapshot sha, roster, per-sleeve source/EX5/preset
   sha, magics, roles, weights, total risk, account-level limits, KS configuration, rollover semantics, news / weekend / session
   policy, governor config, server-request safety, logging paths, attribution sidecar path, `generation_id`,
   `launch_timestamp_utc = null` (filled at step 4.6). `genesis_manifest.py verify` → 0 drift.
6. **Preflight** (`sunday_preflight.py`) → every §R row GREEN or explicitly NOT_CHECKABLE-with-reason; any RED on a critical row =
   NO-GO. Attach the report to the evidence dir.
7. **Demo-day retro audit** (I2) filed; the pre-Sunday days are labelled `PRE_SUNDAY_LIVE_TRIAL` in `ftmo_demo_cycle.json`.

## 3. Sunday 2026-09-27 — install and attach (market closed; nothing can fill)

**Timing (OWNER 2026-09-21: the account is created on Sunday itself).** OWNER creates the Free Trial on Sunday morning and drops the
credentials into `.private/secrets/ftmo_demo_gen2_20260927.md`; from that moment Fable needs about three hours (steps 0–6 below plus
post-attach checks) — the market opens 22:00Z Prague-Sunday (00:00 Prague Monday = first rollover proof), so the credentials should
be in place by **Sunday 12:00Z** at the latest. Step 0: log the terminal into the new account (`terminal64 /login /server /password`,
AutoTrading off), readback login/server/balance 100000.00 / no positions / no orders; only then continue.

Follow the D2g6 runbook steps 1–7 with the new package, in this order, each with its readback:
1. Reference backup of the chart profile + presets (hashes listed).
2. AutoTrading OFF, clean terminal shutdown (`CloseMainWindow`, never `Stop-Process`), `[Experts] Enabled` reads 0, authoritative
   backup re-taken.
3. `demo_install --dry-run` then `--execute` (refusals are stop conditions: `login_mismatch`, `server_mismatch`, `preset_hash_mismatch`,
   `sealed_binary_mismatch`, `receipt_exists_refusing_overwrite`, `backup_collision`).
4. Chart profile edit (start `terminal64.exe` directly, AutoTrading grey): attach the six sleeves with the new presets via **Load**,
   governor + collector presets re-loaded, clean shutdown to persist the profile.
5. File-level verification with the terminal down (6 rows, magics `{104030002, 107000003, 107060001, 114220004, 132130000, 412190000}`,
   risk sum 1.71875, every `ex5_sha` equals the package) and re-pin of `verify_ftmo_demo_instrumentation_contract.ps1` (exit 0),
   committed by pathspec.
6. **Launch** via `FTMO_ON.ps1` (this is the AutoTrading-on event; launcher exit 0, `live_launcher_events.jsonl` `launched`). Record
   `launch_timestamp_utc` into the genesis manifest, set its sha, commit — the manifest is immutable from here; a later change is a new
   generation.

## 4. Post-attach verification (Sunday evening, before the Monday open)

| Proof | Where | Pass |
|---|---|---|
| six charts, EA smiley enabled, governor + collector running | terminal, pulse `magics_seen = 6` | yes |
| `KS_BOOK_TAG_SET` + `KS_DAY_ANCHOR_SET` (or the new initializer's configuration proof) per magic | EA event logs, pulse `kill_switch_*_magics = 6/6` | 6/6 |
| ks_state per magic: named anchor mode, Prague offset for the current season, governed book tag | pulse state-file check | 6/6 |
| governor: allowed magics = roster, limits = manifest | governor log / preset | match |
| collector snapshot fresh, sleeve attribution sidecar written (0 trades is fine) | `ftmo_trial_pulse.json`, `ftmo_sleeve_attribution.json` | fresh |
| server requests per day counter present | pulse | present |

## 5. First rollover proof (Sunday→Monday Prague midnight, 22:00Z in CEST)

`KS_DAY_ROLLOVER` events for all six magics with old/new key, server time, effective Prague time, offset/mode and the selected anchor;
the anchor equals the Prague-midnight balance from the collector to the cent. Missing or wrong → AutoTrading OFF via the governor halt
file, fix, re-prove before Monday's first session. This proof closes §N "rollover-event proof" and "Daily Loss anchor proof".

## 6. Representative clock and hard stops

The 14-calendar-day minimum starts at `launch_timestamp_utc`; extend on thin trade count, poor regime coverage, incomplete evidence or
any material configuration change (§T). Hard stops during the cycle: `docs/ftmo/FTMO_DEMO_ACCEPTANCE_CONTRACT_v1.md` §3. Research
continues; new validated candidates enter the Shadow book only (§F).

## 7. Rollback

Every step above has the D2g6 rollback: restore the profile backup, restore presets from `backup_dir`, re-pin the verifier to the
restored profile, launch. The genesis manifest of a rolled-back launch is retired (not deleted) with the reason.
