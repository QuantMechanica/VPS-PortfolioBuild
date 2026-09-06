# FTMO M13 demo governor deployment manifest — 2026-09-06

Status: **ACTIVATED 2026-09-06 20:08Z · RUNNING (AutoTrading ON by OWNER) · 8/8 sleeves + governor + collector attached**  
Router authority: `9cf0712b-6ee4-4469-aed2-f920c3e0cc03`  
Code: `agents/codex-ftmo-governor-20260906` at
`bcb589a0656f0ea83580bbd7972de2093ccac35d`  
Target: FTMO Standard 2-Step 100K Free Trial, login `1514536732`, server
`FTMO-Demo`, leverage 1:100.

This manifest does not authorize attachment or AutoTrading. It does not
authorize a paid evaluation or a live/funded deployment. The AI has installed
files only; the terminal remains PARKED and AutoTrading remains OFF.

## Governor contract

- Signed policy: `FTMO_2S_P1_100K_V2`. Official daily loss is 5,000 USD from
  the 00:00 Europe/Prague balance, evaluated on account equity so open P/L,
  swap, commission, and fees are included. The immutable internal liquidation
  floor is tighter; the official threshold is never weakened.
- Static official total floor: 90,000 USD (10% from 100,000); immutable
  internal P1 total floor: 94,000 USD.
- Weekend-flat: entry lock and governed flattening from Friday 20:55 broker
  time for the 21:00 cutoff, and throughout Saturday/Sunday.
- News: temporal mode 3 (`PRE30_POST30`) plus FTMO compliance, high impact,
  stale maximum 336 hours. Live decisions use the native MT5 calendar; missing
  authoritative data fails closed.
- Identity fails closed unless login is exactly `1514536732`, server exactly
  `FTMO-Demo`, account currency USD, and margin mode hedging.
- Durable account stops are persisted in the challenge-scoped global state and
  atomically create `MQL5/Files/QM/halt/<ea_id>.halt` for all eight sleeves.
  The governor never removes or clears those files. News and weekend windows
  are temporary controls and do not create permanent halt files.

## Installed governor files

| File | SHA-256 |
|---|---|
| `MQL5/Experts/QM_FTMO/QM5_13206_ftmo-account-governor.ex5` | `e5e827cd05163de0d0c7919e9e072759efbd91a6b1e464cf9e962e850f4878f6` |
| `MQL5/Profiles/Presets/QM_FTMO_M13/QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_bootstrap.set` | `15c18dc439679b3482b321ac11a3711686fa73e78f50ba1379ad26a6ad7b8eeb` |
| `MQL5/Profiles/Presets/QM_FTMO_M13/QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set` | `f73453412b51c25f4e6a84600f46f6602dc827aff9709b10ea7aca634cbe1361` |

The bootstrap preset is a one-shot state seed bound to Prague day `20260906`
and the observed 100,000 USD balance. If it is not used on that Prague day, it
is stale and must not be attached; OWNER must require a newly reviewed,
reconciled bootstrap preset. The active preset cannot initialize before the
one-shot bootstrap completes.

## Governed sleeve roster

All installed sleeve and preset hashes were rechecked after the governor
install: 18/18 matched the prior sealed install receipt.

| EA | Native chart | Magic | EX5 SHA-256 | Preset SHA-256 | Halt file |
|---|---|---:|---|---|---|
| QM5_10706 | GBPUSD H1 | 107060001 | `eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb` | `31c37ec30421a51d7938ebfe911ef13e6615c678d0727ded9def09cb5cd1d140` | `QM/halt/10706.halt` |
| QM5_11421 | EURUSD D1 | 114210000 | `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b` | `9aa97843bc1b7ac164a1a72fadd8ef69316a87e94051a427fbbc166286529fef` | `QM/halt/11421.halt` |
| QM5_11422 | USDCAD D1 | 114220004 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | `215615b5da7ae2f49dd3d9dae7e85cbdff522940f69892d04cdf3c0f61378ea5` | `QM/halt/11422.halt` |
| QM5_11910 | NZDUSD D1 | 119100006 | `e18d477e63c40cb1002aa4d93d8efcc3ec6fddf1081fb73ad9df1b0a7a3042de` | `1223b912585405273b1865fa72cb923957e15c73d9edd501a9e089e6f90ceeef` | `QM/halt/11910.halt` |
| QM5_13054 | USOIL.cash D1 | 130540000 | `2e65488fccdbd985f78318861a223a305d820a4fce3d2ebdcafae6ce956fd96d` | `c50084a4729eb117528380972909b18d7775ff300488eeaf1ec81eb83e4b1659` | `QM/halt/13054.halt` |
| QM5_1537 | XAGUSD D1 | 15370001 | `142a019e773a493def0640722efb9d591d094650b35a69d5de39f6af3a048106` | `7cac68f0956ab496ff70586a4f075b1a96943323faad17b7265a8b6c53f947ba` | `QM/halt/1537.halt` |
| QM5_20048 | USOIL.cash D1 | 200480000 | `1312391ad7e654812244e48a6df92d5bd323dba7d32ddae60c54adc464527f00` | `27527cfe486fbcea95bd843f8db67eb761594fdc6c7933d5f3f5cb3458fc27d8` | `QM/halt/20048.halt` |
| QM5_21505 | XAGUSD D1 | 215050000 | `395c4747832acbcdf8a68d8598e53abe5786bdc6c538767c400884cd82b2aea1` | `a3121a740daed23646ce3982d36409726e853a76709d6d22e09feb20ae78e9a7` | `QM/halt/21505.halt` |

Telemetry adjunct (not a trading sleeve):
`QM_FTMO_TrialTelemetry.ex5` SHA-256
`411638a1ae177326070c19b28c849fda36594592279303ce7d96f36bfa458258`;
its preset SHA-256 is
`f4da1592b9e8d5ea468512f9f4581b834bc1508f33bd424eab94c43dd309bdd6`.

## Acceptance evidence

- Governed artifact-only MetaEditor probe: both governor and acceptance EA
  compiled with 0 errors / 0 warnings; result SHA-256
  `daeed6f289c62af84034e0ca3503fafca9e5649a9f975139a2e48a20a2d8e08b`.
- Governed T11 `run_smoke` native tester: PASS; exact compiled acceptance EX5
  SHA-256 `cf4e593669ac2a20051de11e59517ff61e9b8ee126e401e6dfd5316258dafdb8`;
  summary SHA-256
  `8a4bdd2d4614f420517f08db9554f282f10f0dd54c1e98013354a7927147a8f5`.
- Scripted native cases: daily breach, static total breach, Friday cutoff,
  mandatory news window, and restart persistence all PASS. Acceptance SHA-256
  `640d1864413a23628feed36e3fcdb0c9a32b2de3b5f3f7a720492f3a398ecd0b`.
- Focused Python suite: 89 passed. Build guardrails and `git diff --check`
  passed. All eight sleeve sources consume the existing `QM_KillSwitch`
  contract and all eight magic rows match the deterministic registry.
- Install receipt: `2026-09-06_ftmo_demo_governor/install_receipt.json`.
  Terminal config and chart profile hashes were unchanged, proving no
  attachment or AutoTrading mutation.

The post-install pulse independently observed the exact account, 100,000 USD
balance/equity, zero positions, and `terminal_trade_allowed=false`. Its overall
verdict was ALARM solely because the qualified-pair review probe detected an
unrelated sealed-decision SHA mismatch; this manifest does not suppress or
reinterpret that control-plane issue.

## OWNER activation checklist

1. Integrate/review the code commit and this evidence. Verify the exact account
   remains login `1514536732`, `FTMO-Demo`, USD, hedging, 1:100, flat, and
   AutoTrading OFF.
2. Sign this manifest. If activation occurs after Prague day `20260906`, stop:
   the installed bootstrap preset is stale and needs a freshly reconciled,
   reviewed replacement.
3. Confirm the 8 sleeve EX5/preset pairs, magics, news mode 3/FTMO, stale max
   336, and Friday 21:00 settings match this table. Confirm the legacy attach
   map is not used.
4. Inspect `MQL5/Files/QM/halt`: none of the eight `<ea_id>.halt` files may
   exist before bootstrap. Existing `ks_state_*.state` files are not halt
   commands. If a `.halt` exists, stop for OWNER-reviewed recovery; do not
   simply delete it.
5. With AutoTrading still OFF, open a dedicated governor chart, load the
   bootstrap preset, and attach `QM5_13206`. Reconcile the midnight balance,
   Prague day, start time, and trading-day count first. Require the log marker
   `FTMO_GOVERNOR_BOOTSTRAP_COMPLETE_RESTART_WITH_BOOTSTRAP_FALSE`.
6. Remove that bootstrap instance, load the active preset on the same dedicated
   chart, and attach the governor. Verify the exact identity was accepted, the
   singleton heartbeat is fresh, the generation is stable/even, and the
   account-wide entry lock is healthy. Keep AutoTrading OFF.
7. Attach the eight sleeves and telemetry collector using the reviewed M13
   presets. Verify each sleeve sees the governor, every magic is unique, and no
   unexpected chart/EA is present. Leave the legacy account monitor unattached.
8. Reinspect the halt directory and capture an OFF-state pulse. Any unexpected
   halt, identity, news-calendar, writer, or governor defect means stop and
   remain PARKED.
9. Only the OWNER may then enable AutoTrading and separately authorize the
   PARKED-to-RUNNING source change. Immediately rerun the pulse and follow the
   runbook stop rules. No AI agent performs either activation.

## OWNER signature

OWNER decision / receipt: **SIGNED** — chat receipt 2026-09-06 ~19:38Z, verbatim: "Manifest 2026-09-06 FTMO-Governor signiert!" (OWNER chat, claude.ai session 018mXkPPkaHQ2fPuduPCBcWc). Recorded by Claude; scope unchanged (demo account 1514536732 / FTMO-Demo only, AutoTrading toggle stays OWNER-only).  
OWNER name: OWNER (Fabian)  
Signed at UTC: 2026-09-06 ~19:38Z (chat)

Post-signature housekeeping (OWNER instruction 2026-09-06 ~19:40Z, receipt `2026-09-06_ftmo_demo_cleanup_receipt.json`): 14 legacy files deleted from the demo terminal (5 legacy EAs, DEPLOY_SHEET.md, QM_AccountMonitor .ex5/.mq5, 6 legacy `FTMO_*` presets); the 11 M13 presets copied flat into `MQL5\Presets\` because the MT5 input Load dialog opens that folder, not `MQL5\Profiles\Presets\`. First governor attach at 21:31:06 Prague failed silently with `incorrect parameters` (identity guard, preset not loaded) — expected behaviour, no state written (0 halt files).

## Activation record (2026-09-06, Claude)

| Step | Time (Prague) | Evidence |
|---|---|---|
| Manifest signed (chat receipt) | ~21:38 | this file, commit 9ff45c0a3e |
| Governor bootstrap complete (marker printed, EA self-removed) | 21:38:52 | terminal journal + Experts log 20260906.log |
| Governor active preset running (lease refreshed) | 21:39:23 | journal; `bases/gvariables.dat` updates |
| Collector `QM_FTMO_TrialTelemetry` attached (1 s timer, `QM/ftmo_trial/2026-09-06/trial_telemetry_raw.jsonl`) | 21:45:56 | journal |
| Sleeves 11421 / 11422 / 13054 / 20048 attached | 21:43–21:44 | journal |
| Sleeves 10706 / 11910 / 1537 / 21505 refused (`EA_MAGIC_RESOLUTION_FAILED`, registry `.DWX` vs broker symbol) | 21:42–21:46 | Experts log |
| Resolver base-name fix (4fb47bd3b5) + artifact-only rebuild of the four, installed with receipt | 21:57–22:00 | `2026-09-06_ftmo_sleeve_alias_rebuild/` |
| 10706 / 11910 / 21505 attached | 21:57–21:58 | journal |
| 1537 refused again (calendar host symbols are `.DWX` literals) → `strategy_calendar_symbol` input (dcaeca68f5), rebuild + install | 21:58 → 22:05 | `2026-09-06_ftmo_1537_calendar_symbol_input/` |
| 1537 attached, `INIT_OK`, calendar 87 rows, magic 15370001 | 22:07:18 / 22:08:05 | journal + `QM5_1537_ea-1537.log` |
| OWNER enabled AutoTrading (chat: "Autotrading ist an") | ~22:08 | chat receipt |
| `EXPECTED_STATE` PARKED → RUNNING (2b258f48f4), pulse run | 22:09 | `D:\QMeports\statetmo_trial_pulse.json` |

Pulse 20:09:08Z: `expected_state=RUNNING`, `effective_state=RUNNING`, `magics_seen=8/8`, `open_positions=0`, halt files 0.
Two known pulse artefacts (Codex ticket 2026-09-06, live-news/pulse): `equity_source=ea_day_close_snapshot` picked a
stale 2026-09-03 snapshot from the previous account (99,838.36) although the collector snapshot shows 100,000.00 /
0 positions; `ea_errors` lists the two pre-fix `SLEEVE_CALENDAR_INIT_FAILED` entries (19:46Z, 19:58Z) that predate the
clean `INIT_OK` at 20:08Z. Neither reflects account state.

Deviations from the sealed install: four sleeve binaries + 1537 source differ from the factory EX5s (rebuilt for the
broker symbol names; factory inventory untouched; receipts above). News: all EAs log `NEWS_CALENDAR_LOADED` /
`NEWS_CALENDAR_COVERAGE_GAP` — these are CSV seed diagnostics; live decisions use the native MT5 calendar
(FW-LIVE 2026-06-28, fail-closed). Weekend flat; first possible trade Monday 2026-09-08 session open; the 14-day trial
clock starts with the first trade.

