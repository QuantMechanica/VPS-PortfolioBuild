# EURUSD Design 1 / Design 2 — release evidence

Status: final Design 2 installed on the original FTMO-Demo EURUSD D1 chart.
Installed EX5 SHA256:
`4ff02978ae5d205355f81850fdbad1dac5daf8a8cb4313eaae08c616b1940e0a`.
Final properties confirmation: 2026-09-07 23:24:05 UTC; INIT_OK: 23:24:27.375 UTC.
See final_deployment_confirmation.json and final_post_install_verification.json.
The prior b91f81a2 checkpoint and its original receipts remain historical evidence.

Scope: existing QM5_11421 EURUSD D1 chart on FTMO-Demo 1514536732. No factory,
pipeline, backtest or other-terminal launch is authorized by this design work.
AutoTrading settings and all non-visual EA inputs must remain unchanged.

## Design and comparison

- Both designs preserve the real © character; the previous ASCII-only display
  contract has been superseded by the user's explicit request.
- Design 1 is the compacted first design. Design 2 is a separately implemented
  dashboard with a separate, reversible chart presenter.
- The header's 01/02 control changes only cached presentation state, without EA
  restart, history refresh, quote refresh, or trade calls.
- The chart presenter uses actual supplied range/order/position values. Native
  QA scenarios are synthetic and must not be presented as live trade evidence.

## On-chart use

Click **02** to show Design 1, then **01** to return to Design 2. The Full / Compact
/ Minimal button changes information density. Overview, Checks and Performance
are separate tabs; longer contents are paginated and clipped copy retains its
complete native tooltip. These are runtime presentation preferences; startup
preferences are the qm_design_version and qm_dashboard_mode inputs. A chart
button does not modify inputs or restart the EA.

The final original-EA native click comparison is preserved in design_1_final_ftmo.png
and design_2_final_ftmo.png. Those are actual terminal observations, not mockups. Quotes
and countdowns may differ because the real EA continues its five-second refresh.
design_2_pending_synthetic_fixture.png is explicitly a no-trade synthetic fixture,
not an actual pending order on this account.

The post-install check found INIT_OK, account-wide zero orders and zero positions,
unchanged terminal PID 15464, unchanged common.ini and unchanged nine other FTMO
expert binaries. Risk/strategy/news inputs match the fresh pre-install export;
only the display build label and the new design-selection input differ.

The initial blank chart lasted while the unchanged framework loaded its 97,431-row
news calendar (approximately 20 seconds), before INIT_OK. No extra EA reattach was
performed to address that normal initialization delay. Subsequent native 01/02
clicks did not produce another INIT/DEINIT event.

Historical pre-resize-hardening proof: 638 focused tests PASS; 9 UI headers match across
repository, native QA build and installed canary build. final_ab_acceptance.json
proves the calibrated 501→502→503 round-trip plus native failed-start rollback
and render-failure recovery. This is presentation acceptance, not trading or
FTMO-contract certification.

## Final release proof

- Final production source SHA256:
  `3307ae62ce1e7b10625ccaa9b7e2cfd7ea2581eb3e2d66d0f4170e499d4b6155`.
- 814 focused unit/contract tests PASS in the final 14-module run (17.68 seconds).
  The deployed build passed 805 before a later read-only census footer correction;
  that correction and its added tests changed no renderer or deployed binary.
- Final QA2320Z compiled with zero errors/warnings; all nine UI headers match the
  installed Canary2312Z and repository. QA EX5:
  `ccf3119a5c1b2ca8b890964c46b3dd0f9f94ff99f40b92bc4485949cfda15a6a`.
- Native 801 -> 802 -> 803, V2 -> V1 -> V2: PASS. Full-client 1243 x 403 at 96 DPI,
  26 chart properties compared, same cached quote, 83 -> 50 -> 83 owned objects,
  both V2 PNGs byte-identical. Ten native suite receipts include formatter, model,
  data, news, chart geometry, property round-trip, zoom, start-failure rollback,
  render-failure recovery and initial-start failure with explicit Retry.
- Final original-EA 02 -> 01 -> 02 clicks were executed at 23:26:25 and 23:27:04 UTC.
  These ordinary presentation clicks did not reinitialize the EA. The original
  chart was also switched Full -> Compact -> Minimal -> Full; screenshots and
  native measurements are preserved. Compact and Minimal census both PASS.
- The loaded 45-key native input export differs from the previous installed
  Design 2 export only in qm_panel_build_hash. All strategy/risk/news inputs,
  EA/global trading permissions, nine other expert binaries and factory EX5 are
  unchanged. Current balance/equity observed 100,000; no account-wide orders or
  positions at the preflight and post-install observations.
- Final build freezes 333 Include files: 324 non-UI files equal the captured v4
  snapshot, nine explicitly allowed UI files equal current sources. Historical
  v4 source/binary binding remains not_attested as explained below.

Evidence: final_release_ab_acceptance.json, final_canary_build_receipt.json,
native_2320Z/, native_final_live_canary/, final_density_census.json,
final_live_canary_review.json and native_resize_observation.md.

Final original-chart review: all three V2/V1/V2 observations PASS (47/39/47
objects); V2-owned overlays 10/0/10; no retry or orphan objects; all 28 observed
chart properties return exactly. The original V1 consumer failure is retained
in final_live_canary_review.json: the first validator wrongly rejected V1's
legitimate version suffix after the copyright text. The fix is exact and
design-specific, not relaxed substring matching; no chart change was needed.

At 23:36:58 UTC the guard-bound, self-created no-trade QA chart was confirmed
closed through its normal window-close action. Its own trading permission was
verified OFF immediately beforehand. The two now-stale fixture binding files
were moved recoverably to closed_fixture_binding/; all native receipts and images
remain archived. The original EURUSD chart is active, Design 2 / Full, and the
existing terminal PID is unchanged. No factory worker or pipeline was started.

### Recovery and honest limits

The old strict shift restoration could block a design switch after resizing.
Same-raster restoration remains exact; a genuinely changed stable raster allows
at most one current bar of visual normalization. The real 1187 -> 872 pixel QA
resize exercised this path: 1.453 pixel error below a 7.927 pixel bar. Native zoom
and integer settings are preserved; the production presenter never sets zoom.

A first display initialization failure now leaves an explicit Retry control.
There is no timer-driven renderer restart. Only successful explicit recovery can
start the EA's normal five-second observer; the click itself reads no new data.
Permanent invalid-prefix failure, retry handling and cleanup are tested natively;
successful recovery from injected transient CAPTURE_UNSTABLE is not natively proved.

The first QA2313Z native initialization failed its immediate zoom-setup assertion.
It is retained in native_2313Z_failed_zoom_setup/, not relabeled PASS. A QA-only,
bounded settle phase now waits for two temporally separated matching target
rasters and real bar-capacity change. Production thresholds were not relaxed.

Live-chart captures are non-atomic observations, not synthetic QA. Their time/price
overlay geometry is not certified by the pixel census. Audit-script screenshots
can show the native script name over the chart's observation timestamp; the normal
desktop screenshots have no running audit-script overlay. Native checks cover
96 DPI, not all possible desktop DPI values. No profitability/FTMO approval follows.

Recovery backup before the final update:
`D:/QM/console_design_20260907/backup_before_final_resize_2308Z` contains the prior
b91f81a2 binary and the fresh runtime input export. Final native loaded preset:
`D:/QM/console_design_20260907/ftmo_11421_final_loaded_verified_2323Z.set`, SHA256
`e72f9bff239e173f8fdc817f1992fc46ece9480f02ec66725e91042d74d15902`.

Reattachment has an actual configuration window: final old-EA DEINIT at
23:22:44.828 UTC, new properties confirmed 23:24:05 UTC, normal news-calendar load
completed before INIT_OK at 23:24:27.375 UTC. The account was checked flat and the
D1 entry condition false before copy and immediately before properties OK.

## Completed evidence before final hardening

- 612 focused unit/contract tests passed independently. These are not a substitute
  for native MT5 rendering checks or profitable trading validation.
- Native calibrated A/B captures 401 → 402 → 403: V2 → V1 → V2 PASS, 1243×403
  full client image for an 1187×380 plot at 96 DPI. Same cached quote, same
  chart properties after round-trip, no V2-owned overlay remnants in V1.
  The two V2 PNGs are byte-identical:
  `bec42d863ed0ea174217ae43789601461584b83c91bc4203e933cbd049ba5856`.
- Older captures 301–315 used uncalibrated plot-sized PNGs that crop the footer;
  they are not valid full-frame visual acceptance evidence. The corrected QA
  harness checks a chart/HWND/plot/DPI-bound client-size calibration.
- Independent review found two additional error paths being corrected before
  final build: recovery after failed design initialization; explicit notice for
  price labels outside the visible label area.

## Recovery copy (before any production-EA replacement in this task)

Directory: `D:/QM/console_design_20260907/backup_before_design2_2156Z`.
Actual directory creation UTC: 2026-09-07T21:54:18.3168624Z. Folder suffix is only
an identifier, not evidence of wall-clock time.

| File | SHA256 |
|---|---|
| QM5_11421_ohlc-daily-squeeze-reversal-d1.ex5 | 5be0846344014fee1b87036e496cc6573cd13986cf840b7732afd40610895614 |
| installed_v4_preset.set | 556044b6b3b50003d77604e5358dd9578462eeec8764ba4be10187649d689a50 |
| runtime_inputs_before.set | 95cc02573c911806345029186af6e9fd6a2dc2e5bfd83fc35b9366e150e624af |

The installed preset and a preset exported from the running EA are different
artifacts. Before applying a replacement, export and verify the actual current
runtime inputs again; never substitute EA defaults. In particular preserve
RISK_PERCENT=0.3125, RISK_FIXED=0 and PORTFOLIO_WEIGHT=1.

Fresh read-only runtime export completed via the existing chart's properties
dialog (then Cancel, not OK):
`D:/QM/console_design_20260907/ftmo_11421_runtime_fresh_2201Z.set`, SHA256
`5b71efd984ff16d7d59fdea407d769c52f4dae7fee5dcd59c461f3d914bbd799`.
Its 44 keys retain all 37 previously exported values and include the seven v4
display defaults. The EA's own Allow Algo Trading checkbox was observed as 1,
without changing it. The V2 candidate must differ from this fresh export only
in qm_panel_build_hash and the newly added qm_design_version.

The factory repository EX5 is not a deployment target and remains pinned to
`9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b`.

## Reattach safety boundary

Reattaching an EA resets the new-bar tracker; it is not inherently trading-neutral.
Require a fresh exact-account check, zero account-wide positions and pending
orders, and valid D1 closed prices that are neither strictly increasing nor
strictly decreasing. Recheck immediately before confirming EA properties and
abort on any account, chart, parameter, binary or broker-bar drift. Keep the
existing terminal PID and global/EA trading permissions unchanged. No terminal
restart is part of this task.

## Build provenance limitation

New isolated build receipts pin every effective Include dependency and whitelist
UI overrides. Non-UI dependencies are checked against the captured frozen v4
Include tree. The historical v4 receipt did not hash its Include tree; its EX5 hash
alone does not attest a historical source-to-binary binding. Do not claim otherwise.
