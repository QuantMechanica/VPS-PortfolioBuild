# FTMO decision — Round25 12-leg book, Phase 1 @ scale 9.0 (Two-Speed)

**Status: DEPLOYED ON FREE TRIAL (account 1513845506, OWNER-confirmed) — charts
applied + AutoTrading ON 2026-07-05 16:47–16:54 local; Claude-verified 12/12
(checklist below). Sole open item: server-time offset check at first tick.**
**OWNER direction 2026-07-05 (chat): run the book on an FTMO Free Trial first — dress
rehearsal (plumbing verification: symbols, sizing, server-time offset, risk-cap events,
first fills), not a pass attempt; challenge purchase deferred.**

## Decision basis

- Composition + evidence: `docs/ops/evidence/ROUND25_FTMO_RECOMPOSITION_PACKAGE_2026-07-04.md`
  (greedy recomposition over 49 validated report.htm bases, 5000×5 full-fidelity,
  true-OOS protocol, fair Round24 baseline; realistic overall pass ~85–90% time-unbound).
- Scale plan: **OWNER Two-Speed decision 2026-07-05 (chat)** — Phase 1 @ 9.0
  (Σ $9.000 RISK_FIXED, chases the ~⅓ 30d-chance), Phase 2 @ 6.0–7.0 via setfile
  redeploy. Execution trigger: OWNER 2026-07-05 („wir wollen nun … das FTMO Book
  auf FTMO deployen").
- Per-leg translation: RISK_FIXED(i) = 1000 × 9.0 × wᵢ (source reports verified
  12/12 at RISK_FIXED=1000, deposit 100000, 2023–2025, Model 4).

## The 12 legs (Σ RISK_FIXED = $8.999, rounding of $9.000)

| Leg | FTMO chart | Magic | RISK_FIXED | cap_pct |
|---|---|---|---|---|
| QM5_11476 lien-k-double-bb-trend-h1 | USDJPY H1 | 114760002 | 1435 | 2.0 |
| QM5_10911 grimes-complex-pb | GER40.cash H1 | 109110003 | 1256 | 2.0 |
| QM5_12958 nnfx-hma-wae-swing | XAUUSD D1 | 129580000 | 1256 | 2.0 |
| QM5_10692 tv-ls-ms | US100.cash H1 | 106920005 | 1117 | 2.0 |
| QM5_10848 tv-mtf-ambush | XAUUSD H1 | 108480002 | 838 | 1.0 |
| QM5_10700 tv-liq-break | XAUUSD H1 | 107000003 | 624 | 1.0 |
| QM5_10286 cinar-supertrend | USOIL.cash D1 | 102860036 | 518 | 1.0 |
| QM5_10440 mql5-ohlc-mtf | US100.cash H1 | 104400003 | 459 | 1.0 |
| QM5_10163 tv-rsi-macd-long | US100.cash H1 | 101630000 | 422 | 1.0 |
| QM5_10847 tv-inside-gem | GBPUSD H1 | 108470001 | 389 | 1.0 |
| QM5_12990 grimes-context-pb-v2 | GBPUSD H4 | 129900001 | 360 | 1.0 |
| QM5_12475 gh-macd-cross | US100.cash H1 | 124750003 | 325 | 1.0 |

Magic registry verified 12/12 against `framework/registry/magic_numbers.csv`
(ea_id/slot/magic consistent; resolver validates (ea_id, slot) only — FTMO chart
symbol names need no registry rows; collision check covers open positions).

## Framework change required (and made) — per-trade risk cap

`QM_FrameworkInit` hard-caps per-trade risk money at **1% of account equity**
(`QM_Common.mqh`, `risk_cap_money = equity * 0.01`, silently clamped in
`QM_RiskSizerRiskMoney`). On a 100k account this would have silently cut the four
largest legs (1435/1256/1256/1117 → 1000) and distorted the ratified composition —
the MT5 validation runs dodged this in the tester via 1M deposit
(`PROP_CHALLENGE_MT5_VALIDATION_FTMO_2STEP_2026-06-29.md`); live cannot.

Change (2026-07-05): new `QM_FrameworkSetRiskCapPct(cap_pct)` in `QM_Common.mqh`
(bounds (0, 5.0], logs `RISK_CAP_OVERRIDE`, default-preserving) + input
`qm_risk_cap_pct` (default 1.0) in the 12 book EAs, called after `QM_FrameworkInit`.
Only these 12 EAs rebuilt; **T_Live binaries untouched**. Presets set 2.0 for the
four legs above 1%; all other EAs framework-wide keep the 1% default.

## Deployment artifacts

- Staging: `C:\QM\deploy\FTMO_Round25_2026-07-05\` (12 presets `r25p1_*.set` +
  `preset_manifest.json` with SHA256 + binaries; OWNER guide
  `ANLEITUNG_FTMO_SONNTAG.md`).
- Presets = validation setfile params 1:1 (survivor purity), only
  RISK_FIXED/RISK_PERCENT/PORTFOLIO_WEIGHT/qm_risk_cap_pct overridden; provenance
  header per file (base setfile + source report path).
- Terminal: FTMO Global Markets MT5, data dir
  `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850`,
  account 1513845506 (FTMO-Demo server).
- News calendar: machine-wide Common Files (`news_calendar_2015_2025.csv`),
  refreshed 2026-07-05 15:42 local — visible to the FTMO terminal (same user,
  non-portable install).

## Known deviations vs simulation basis (documented, all conservative or neutral)

1. Framework 3% account-daily-loss halt per EA (`QM_KillSwitchInit` constant) —
   more conservative than FTMO's 5% daily limit; sim did not model it.
2. FTMO symbol translation (NDX→US100.cash, GDAXI→GER40.cash, XTIUSD→USOIL.cash):
   contract specs/commissions differ from the .DWX validation basis; RISK_FIXED
   sizing adapts via SL distance × tick value at runtime.
3. FTMO server time expected UTC+2/+3; empirical offset check at first tick is a
   go-live verification item (bar-boundary parity vs .DWX NY-close). DST-transition
   windows (US vs EU switch dates) are a known watch item.
4. FTMO news-trading restriction applies to FUNDED accounts, not challenge/
   verification — evidence news params kept 1:1; funded stage will need the FTMO
   compliance profile pass.

**Repo-artifact note:** the 12 rebuilt `.ex5` in `framework/EAs/` were reverted to
their prior committed content by farm automation shortly after deploy (manual
compile = no build-lane record; sources remain committed via `dd53213e8` +
`a83d01fc6`). The DEPLOYED binaries are pinned + SHA256-verified in
`C:\QM\deploy\FTMO_Round25_2026-07-05\live_eas\` (+ `live_eas_sha256.txt`), and
staging-vs-old-backup overlap = 0/12 (all genuinely fresh builds). Runtime proof
at attach: `RISK_CAP_OVERRIDE` must appear in exactly the 4 cap-2.0 EA logs. Any
future factory rebuild of these EAs compiles from the committed source and gets
the cap input natively.

## Verification log (Claude)

- [x] 12/12 validation setfiles located; param-carry 1:1, risk fields only overridden
- [x] Magic registry 12/12 consistent
- [x] News calendar current (2026-07-05 15:42)
- [x] 12/12 compile clean after `qm_risk_cap_pct` change (0 errors, 0 warnings;
      reports under `D:\QM\reports\compile\`)
- [x] SHA256 framework == staging == terminal `Live EAs` (12/12;
      `C:\QM\deploy\FTMO_Round25_2026-07-05\live_eas_sha256.txt`)
- [x] SHA256 staged presets == terminal `MQL5\Presets` copies (12/12; old 13 demo
      presets + 11 old binaries moved to `pre_deploy_backup\`)
- [x] Account identity: **Free Trial first (OWNER 2026-07-05)**; OWNER confirms trial
      account created with USD 100,000. Equity evidence: `RISK_CAP_OVERRIDE`
      `cap_money=2000.00` at `cap_pct=2.0` in all 4 big legs → equity exactly 100,000.
      Virgin account: journals 06-29/06-30 show logins only (no experts, no deals),
      07-05 sync `0 positions`. ✅ **OWNER confirmed (2026-07-05 chat): the FTMO-portal
      trial account number IS 1513845506** („ja, das ist die richtige Trial Nummer!") —
      terminal, trial, and book are on the same account. Trial terms (web-verified
      07-05): 14 days, target 5%, daily 5% / max 10%.
- [x] OWNER manifest approval — 2026-07-05 chat chain: „deployen!" (deploy order) +
      Trial-first direction + „EAs sind alle auf den Charts, überprüfe!" (execution
      confirmation). Recorded as written approval for the TRIAL run; to be re-confirmed
      explicitly before the paid challenge.
- [x] Charts applied (12) by OWNER 2026-07-05 16:47–16:54 local. Verification:
      journal `loaded successfully` 12/12 (20260705.log); QM EA logs `INIT_OK` 12/12
      with magic set matching the leg table 12/12, 0 unexpected (magic comes from the
      preset → proves correct preset per chart); `RISK_CAP_OVERRIDE` in exactly the
      4 cap-2.0 legs (10692/10911/11476/12958). Post-session SHA re-verify: EAs 12/12
      vs `live_eas_sha256.txt`, presets 12/12 vs staging. News calendar: 10/12
      `NEWS_CALENDAR_LOADED` (fresh 2026-07-05 15:42 file, identical hash);
      10700 + 11476 `NEWS_CALENDAR_SKIPPED` (all news axes off per their preset /
      compiled defaults — identical params ran through the MT5 validation, so live
      behavior == evidence behavior; funded-stage compliance = deviation 4, still
      open). Transient `unconfigured` (magic 0) pre-preset inits during attach were
      all superseded within the session; market closed → no trade risk.
- [x] Server-time offset VERIFIED at first tick (2026-07-06 market open):
      `ts_utc 2026-07-05T21:05:02.062Z` vs `ts_broker 2026-07-06T00:05:02` =
      **UTC+3 exactly** (expected for US-DST period). Same-tick evidence:
      `EQUITY_SNAPSHOT equity=100000.00` (live account basis confirmed) and
      `NEWS_LIVE_CALENDAR_SELFTEST healthy=true` (217 events/7d, next HIGH:
      USD S&P Global Services PMI 2026.07.06 16:45 srv). Logs: QM5_11476/10847/
      12990 first 2026-07-06 broker events.
- [x] AutoTrading enabled 16:47:47 local by OWNER (during chart session; market
      closed, 0 positions)

## Reboot resilience (added 2026-07-05 evening)

- `QM_FTMO_AtLogon` scheduled task registered (mirrors `QM_T_Live_AtLogon`):
  runs `tools/strategy_farm/FTMO_ON.ps1` at logon — idempotent start of the FTMO
  terminal; pins `ProfileLast=Default` + `Experts Enabled=1` in the data-dir
  `common.ini` before a cold start, so the 12-leg book reloads and AutoTrading
  resumes (login 1513845506 is pinned in `common.ini` by the terminal itself).
  Idempotency verified live (no-op while terminal running).
- Recovery hardening 2026-07-22: before any cold/recovery start,
  `verify_ftmo_round25_live_contract.ps1` now fails closed unless account/server,
  the exact 12-chart/12-EA semantic profile, packaged preset inputs, and all 12
  deployed + package `.ex5` SHA-256 values still match this approved deployment.
  Normal chart window/object state is intentionally ignored; trading inputs are not.
- Factory kill scripts (`Factory_OFF.ps1`/`Factory_ON.ps1`) are positively
  path-anchored to `D:\QM\mt5\` since commit `da5a42979` — the FTMO terminal and
  T_Live can structurally never match the factory kill selection.

## Sign-off

- Package + staging: Claude, 2026-07-05
- Manifest approval: OWNER, 2026-07-05 chat (trial run; re-confirm before paid challenge)
- Charts + AutoTrading: OWNER, 2026-07-05 16:47–16:54 local
- Post-session verification (SHA/INIT/magic/risk-cap/equity): Claude, 2026-07-05
