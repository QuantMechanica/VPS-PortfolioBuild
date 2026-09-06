# FTMO M13 Free-Trial demo install — 2026-09-06

Status: **REVIEW — installed, unattached, PARKED**. This is installation and observer evidence only, not a pipeline verdict or permission to trade.

Authority: router task `35eac0e9-8568-4114-b68f-45258ad7189b`; OWNER decision `OWNER-DEC-M13-ECONOMIC-TRIAL-20260906`; account addendum is Standard 2-Step 100K Free Trial, not Swing; maximum duration 14 calendar days from first trade. Code is isolated on `agents/codex-ftmo-demo-install-20260906` at `142ef15d43cda1d8b876678b24b39ccc5dccff09` for Codex/OWNER review.

## Target and safety state

- Program: `C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe`.
- Data directory: `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850`; explicitly not T_Live and not T1-T10.
- Identity: login `1514536732`, server `FTMO-Demo`, Standard demo, USD 100,000 balance/equity, leverage 1:100, zero positions/orders, 166 symbols.
- Terminal build observed: 6182. AutoTrading remained OFF (`[Experts] Enabled=0`, IPC `terminal_trade_allowed=false`). No chart/profile other than the new preset directory changed. No terminal was manually started or stopped and no T_Live path was written.
- Swap, contract-size, and commission-capture details are in `2026-09-06_ftmo_demo_install/terminal_snapshot.json` and `2026-09-06_ftmo_demo_account_terms.md`.

## Legacy inventory decision

Before M13, `QM_AccountMonitor.ex5` (`39b8300595953a3e7ae4e08bf1d2a836067ef431156eb4077f21acdace3e4133`) and its source remained in the target, plus six legacy `QM_FTMO` binaries. The account monitor stays dormant and has a distinct output contract; it is not an M13 writer. The root `ftmo_demo_attach_map.json` (`fd89f...31d3a`) refers to the old account and is retained only as obsolete history: **do not use it for M13**. The differing legacy QM5_10706 binary was preserved at `MQL5\Experts\QM_FTMO\_pre_m13_20260906\QM5_10706_tv-mon-ls.ex5` before replacement. Full before/after hashes are in `install_receipt.json`.

## Collector acceptance

`QM_FTMO_TrialTelemetry` compiled natively with 0 errors and 0 warnings. Source SHA-256 is `6c3f8113aab6e659106e8f71f869bb421452c7b838dc7ca0365983704deed9bc`; installed EX5 SHA-256 is `411638a1ae177326070c19b28c849fda36594592279303ce7d96f36bfa458258`.

The governed native tester acceptance on idle T11 used native EURUSD and passed all four scripted cases: winter midnight, summer midnight, spring DST, and autumn DST; each emitted 901 samples and proved an exclusive writer. It also exercised restart, equity trough, and non-zero position/order observations. Acceptance SHA-256 is `727b569f3e9e7b53ef028d6f84f82575c60f36cb1b04a57dc699c701b8ab8476`. T1-T10 active work was not interrupted.

The installed collector preset binds 1-second sampling, exact login/server guards, trial ID `M13_OPTION_B_20260906_1514536732`, and sandbox output `MQL5\Files\QM\ftmo_trial\2026-09-06`. The daily durable landing path is `D:\QM\reports\ftmo_trial\2026-09-06`.

## Eight sealed sleeves

Manifest SHA-256: `d9e88358b52a1587e6a8d24b868a62ff49fb46db9f7793fe81323a01809d3de0`. Every installed preset is live mode with `RISK_FIXED=0`, `RISK_PERCENT=0.3125`, `qm_news_temporal=3`, `qm_news_compliance=2`, `qm_news_stale_max_hours=336`, `qm_friday_close_enabled=true`, and broker Friday-close hour 21. The equal allocation totals 2.5% nominal sleeve risk. The roster is the exact sealed candidate set; XAUUSD and GER40.cash are broker-offered but had no sealed candidate and were not invented.

| EA | Chart | Preset SHA-256 |
|---|---|---|
| QM5_10706 | GBPUSD H1 | `31c37ec30421a51d7938ebfe911ef13e6615c678d0727ded9def09cb5cd1d140` |
| QM5_11421 | EURUSD D1 | `9aa97843bc1b7ac164a1a72fadd8ef69316a87e94051a427fbbc166286529fef` |
| QM5_11422 | USDCAD D1 | `215615b5da7ae2f49dd3d9dae7e85cbdff522940f69892d04cdf3c0f61378ea5` |
| QM5_11910 | NZDUSD D1 | `1223b912585405273b1865fa72cb923957e15c73d9edd501a9e089e6f90ceeef` |
| QM5_13054 | USOIL.cash D1 | `c50084a4729eb117528380972909b18d7775ff300488eeaf1ec81eb83e4b1659` |
| QM5_1537 | XAGUSD D1 | `7cac68f0956ab496ff70586a4f075b1a96943323faad17b7265a8b6c53f947ba` |
| QM5_20048 | USOIL.cash D1 | `27527cfe486fbcea95bd843f8db67eb761594fdc6c7933d5f3f5cb3458fc27d8` |
| QM5_21505 | XAGUSD D1 | `a3121a740daed23646ce3982d36409726e853a76709d6d22e09feb20ae78e9a7` |

Install receipt status is `INSTALLED_UNATTACHED_PARKED`; 8 EX5 files, 8 presets, the collector, and its preset were hash-verified after atomic copy. The read-only dry pulse at 2026-09-06T17:28:43Z was **OK / PARKED_FLAT**, login/server exact, equity 100,000, 0 positions, AutoTrading false, and no warnings or alarms. The first isolated-worktree pulse saw a CRLF-only mismatch against a raw-file SHA guard; the canonical signed decision file itself matches its expected SHA and the recorded rerun used that canonical artifact.

## OWNER activation checklist

1. Review and integrate code commit `142ef15d43cda1d8b876678b24b39ccc5dccff09`; confirm the terminal still shows login `1514536732`, `FTMO-Demo`, Standard 2-Step 100K, USD 100,000, leverage 1:100, no positions/orders, and AutoTrading OFF.
2. Do **not** use the legacy attach map. Confirm a separately accepted, OWNER-signed deployment of account governor QM5_13206 as the sole halt authority. It is not installed by this ticket; without it, stop here and keep PARKED.
3. Open eight separate sleeve charts: GBPUSD H1; EURUSD D1; USDCAD D1; NZDUSD D1; two USOIL.cash D1 charts; and two XAGUSD D1 charts. Load each matching preset from `MQL5\Profiles\Presets\QM_FTMO_M13`, then attach its matching M13 binary. Keep AutoTrading OFF throughout attachment.
4. Open one separate collector chart (EURUSD M1 is suitable), load `QM_FTMO_TrialTelemetry_1514536732.set`, and attach `QM_FTMO_TrialTelemetry`. Verify the Experts log accepts login/server and reports the expected QM output path. Leave legacy `QM_AccountMonitor` unattached.
5. On every sleeve, visually verify risk 0/0.3125%, QM news 3/2 with stale maximum 336 hours, and Friday close enabled at broker hour 21. Confirm unique expected magics from the manifest and no unintended charts/EAs.
6. Capture one collector sample while AutoTrading is still OFF; verify login, server, leverage, balance/equity, positions/orders, swaps, and that realized fills will carry `DEAL_COMMISSION`/`DEAL_FEE`. Copy the raw capture to `D:\QM\reports\ftmo_trial\2026-09-06`.
7. Only after steps 1-6 and an OWNER-signed governor/deploy review, the OWNER may enable AutoTrading and separately authorize the reviewed `PARKED` to `RUNNING` source change. No agent performs either action. Re-run the pulse immediately and require RUNNING identity/roster evidence.
8. Stop no later than 14 calendar days from the first trade. Monitor the 5% daily and 10% total loss ceilings and mandatory news/weekend-flat controls. On any identity, writer, news, governor, or telemetry defect, turn AutoTrading OFF manually and use the receipt hashes/`_pre_m13_20260906` backup for reviewed rollback.

## Verification index

- `2026-09-06_ftmo_demo_install/install_receipt.json`: exact installed destinations, hashes, legacy inventory, backup.
- `2026-09-06_ftmo_demo_install/compile_probe/{contract,result}.json`: governed compile contract and result.
- `2026-09-06_ftmo_demo_install/native_tester/acceptance.json`: native tester evidence.
- `2026-09-06_ftmo_demo_install/sets/manifest.json`: sealed roster and derivation bindings.
- `2026-09-06_ftmo_demo_install/pulse_dry_read.json`: PARKED read-only pulse.
- Focused Python verification: 59 passed; Python compile and `git diff --check` passed.
