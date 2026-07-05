# FTMO decision — Round25 12-leg book, Phase 1 @ scale 9.0 (Two-Speed)

**Status: DRAFT — file-side staged 2026-07-05; awaiting OWNER manifest approval + chart session + AutoTrading**
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
- [ ] Account identity: **Free Trial first (OWNER 2026-07-05)**. Still open: trial
      account with balance/currency **USD 100,000** (sizing basis of all 12 presets and
      of the FTMO limit percentages); if the trial is a new login (terminal currently
      holds 1513845506 / FTMO-Demo, connected, 0 positions — journal 20260705.log),
      OWNER logs the terminal in; Claude then re-verifies SHA 12/12 and records the
      trial terms (duration/target per FTMO dashboard) here
- [ ] OWNER manifest approval in writing
- [ ] Charts applied (12), journal `loaded successfully` + `INIT_OK` 12/12,
      `RISK_CAP_OVERRIDE` in exactly 4 EA logs
- [ ] Server-time offset check at first tick
- [ ] AutoTrading enabled by OWNER

## Sign-off

- Package + staging: Claude, 2026-07-05
- Manifest approval: _pending OWNER_
- AutoTrading: _pending OWNER_
