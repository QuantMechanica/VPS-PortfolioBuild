# T_Live Approval Package — D2-a first live tranche, 8-sleeve book (2026-06-27)

Prepared by: Claude (operation lead). **AWAITING OWNER WRITTEN APPROVAL. No T_Live copy, no
setfile deploy, no AutoTrading performed.** This is the first V5 live portfolio (D2-a tranche).

## OWNER decisions this implements (2026-06-27)
- **D2-a** — deploy a small DXZ tranche now to validate live execution mechanics. Sizing stays
  conservative (FTMO-10% cap binds; the book sits ~8× under it).
- Admission monthly-corr fix + Q09 floor=20: already in production (`main` `dba239060`); no merge needed.
- Breadth push approved: this book grew **7→8 sleeves** (USDJPY added — see below).

## The book (manifest `D:\QM\reports\portfolio\manifest_d2a_dxz_2026-06-27.json`)
- Source: `portfolio_candidates.Q12_REVIEW_READY` (q12-ready-all), inverse-vol risk parity.
- `status=DRAFT_FOR_OWNER_APPROVAL`, `cap_met=True` (10% DD cap, `dd_basis_for_cap=mc_p95`),
  `manual_approval_required=true`, `deployment_action=NONE`, `autotrading_action=NONE`,
  `degraded=False` (all 8 commissions real).
- **KPIs (canonical $100k, RISK_FIXED basis):** Observed MaxDD **0.72%**, MC-p95 MaxDD **1.27%**,
  Sharpe **1.56**, net-of-cost **$8,427** over 1,716 trading days. `account_risk_pct = 2.0%`.
- Asset spread: **3 FX-or-index**, balanced — 2 FX (USDJPY, GBPUSD), 3 index (NDX×2, SP500),
  3 commodity (XAU×2, XNG).

| slot | sleeve | symbol | weight | RISK_PERCENT | magic (registry ✓) | sym_slot | ex5 SHA256 (16) |
|---|---|---|---|---|---|---|---|
| 0 | 10440 mql5-ohlc-mtf | NDX | 0.023 | 0.0459% | 104400003 | 3 | 336b59109aa9a419 |
| 1 | 10513 mql5-ichimoku | XAUUSD | 0.125 | 0.2501% | 105130003 | 3 | ee92f1c62949b3d4 |
| 2 | 10692 tv-ls-ms | NDX | 0.031 | 0.0626% | 106920005 | 5 | e28f8a1e452ac5c6 |
| 3 | 10715 tv-asian-box | USDJPY | 0.058 | 0.1159% | 107150004 | 4 | b3e7736199c661ef |
| 4 | 10939 grimes-context-pb | GBPUSD | 0.065 | 0.1305% | 109390001 | 1 | 555444af80318e51 |
| 5 | 10940 grimes-nested-pb | XAUUSD | 0.098 | 0.1961% | 109400003 | 3 | 363a27933f66d8d5 |
| 6 | 11132 tm-cum-rsi2 | SP500 | 0.177 | 0.3534% | 111320000 | 0 | 7b48a34c786debb4 |
| 7 | 12567 cum-rsi2-commodity | XNGUSD | 0.423 | 0.8457% | 125670002 | 2 | e66579c018d889b9 |

(RISK_PERCENT sums to the 2.0% account risk; PORTFOLIO_WEIGHT = RISK_PERCENT ÷ 2.)

## Verification evidence (Claude review, 2026-06-27)
- ✅ **Reservoir re-certified with fresh evidence** (6 transiently-EVIDENCE_STALE sleeves restored
  after an R16 false-downgrade; assembled-book KPIs reproduce the 13:38 certification exactly).
  Evidence: `D:\QM\reports\portfolio\recert_20260627T113037+0000\summary.json`.
- ✅ **USDJPY (10715) admitted through the real gate** (q09 work_item `df72b85a` PASS_PORTFOLIO,
  no regime catastrophe) — the breadth-push addition. Re-checked: corr 0.10 to book, diversifies.
- ✅ **Magic numbers**: all 8 match `framework/registry/magic_numbers.csv` (1 row each, no collision)
  and the `ea_id*10000 + symbol_slot` formula (USDJPY: 10715*10000+4 = 107150004 ✓).
- ✅ **All 8 `.ex5` present** (SHA256 above) for the factory→T_Live copy verify.
- ✅ **Set-file expectations** correct on every sleeve: ENV=live, RISK_FIXED=0, RISK_PERCENT set,
  explicit `strategy_*` params present, and `card_defaults_source=not_found` absent. Evidence:
  `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_SETFILE_GUARDRAIL_AUDIT_2026-06-27.md`.
- ✅ **Go-Live package preflight PASS**: one command now verifies setfile guardrails, setfile
  framework/package/T_Live hash equality, and package/T_Live `.ex5` equality for all 8 sleeves.
  Evidence: `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_GOLIVE_PREFLIGHT_2026-06-27.json` and
  `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_Q12_EVIDENCE_LEDGER_2026-06-27.md`.
- ✅ **Post-Q12 Slot 1 refresh** (2026-06-27 17:47 +02:00): `QM5_10513` / XAUUSD D1 setfile now
  embeds Q12-selected `q06_6_18_68_18` params (`tenkan=6`, `kijun=18`, `senkou_b=68`, `atr=18`)
  while preserving live controls (`RISK_FIXED=0`, `RISK_PERCENT=0.2501`, `PORTFOLIO_WEIGHT=0.125`,
  magic slot 3). Evidence: `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_10513_Q12_SELECTION_2026-06-27.md`;
  source results: `D:\QM\strategy_farm\scratch\q12_opt\20260627T132146Z\results.csv`.
- ✅ **Post-Q12 Slot 5 refresh** (2026-06-27 20:23 +02:00): `QM5_10940` / XAUUSD H4 setfile now
  embeds Q12-selected `pullback_30_60` params (`strategy_pullback_min_fraction=0.3`,
  `strategy_pullback_max_fraction=0.6`) while preserving live controls (`RISK_FIXED=0`,
  `RISK_PERCENT=0.1961`, `PORTFOLIO_WEIGHT=0.098`, magic slot 3). Evidence:
  `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_10940_Q12_SELECTION_2026-06-27.md`; source results:
  `D:\QM\strategy_farm\scratch\q12_opt\20260627T175510Z\results.csv`.
- ✅ **Post-Q12 Slot 6 refresh** (2026-06-27 19:54 +02:00): `QM5_11132` / SP500 D1 setfile now
  embeds Q12-selected `strict_entry` params (`strategy_cum_rsi_entry=38.0`, `strategy_rsi_exit=66.0`,
  `strategy_sma_period=165`, `strategy_atr_period=12`, `strategy_atr_sl_mult=2.0`) while preserving
  live controls (`RISK_FIXED=0`, `RISK_PERCENT=0.3534`, `PORTFOLIO_WEIGHT=0.177`, magic slot 0).
  Evidence: `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_11132_Q12_SELECTION_2026-06-27.md`; source
  results: `D:\QM\strategy_farm\scratch\q12_opt\20260627T174037Z\results.csv`.
- ✅ **Post-Q12 Slot 7 refresh** (2026-06-27 18:16 +02:00): `QM5_12567` / XNGUSD D1 setfile now
  embeds Q12-selected `entry_30` params (`strategy_cum_rsi_entry=30.0`, with the remaining
  cum-RSI2 defaults explicit) while preserving live controls (`RISK_FIXED=0`,
  `RISK_PERCENT=0.8457`, `PORTFOLIO_WEIGHT=0.423`, magic slot 2). Evidence:
  `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_12567_Q12_SELECTION_2026-06-27.md`; source results:
  `D:\QM\strategy_farm\scratch\q12_opt\20260627T155555Z\results.csv`.
- ✅ **News calendar seed** present + current: `D:\QM\data\news_calendar` refreshed 2026-06-27 05:30.
- ✅ Safety flags hard-set (DRAFT / manual_approval / deploy NONE / autotrading NONE).

## Breadth-push outcome (honest)
Screened the gap-instrument sleeves already at Q08/Q09. Of three flagged: **USDJPY admitted**
(added, above); **GDAXI (10115) and AUDCAD (11165) were correctly REJECTED** by the real gate for
`q08_regime_catastrophe` — a genuine regime-stability defect my quick correlation-only screen
missed. The gate did its job. The easy "sleeves-near-the-line" pool is now largely tapped; further
breadth needs new low-freq gap edges (silver XAG, oil XTI, more FX, UK100/WS30, the bumped FX
cointegration baskets) through the full funnel.

## Risks / things to weigh before approving
- **Single-sleeve concentration**: 12567:XNGUSD carries ~42% of portfolio weight (lowest-vol →
  highest inverse-vol weight). It is now Q12-refreshed (`entry_30`), but the capital concentration
  remains. Diversified by correlation, concentrated by capital. Acceptable for a *validation*
  tranche. Weight-cap simulation completed: 25%-30% caps reduce XNG concentration but increase
  MC-p95 DD and reduce Sharpe on the current 8-sleeve set, so no manifest change is recommended.
  Evidence: `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_WEIGHT_CAP_SIM_2026-06-27.md`.
- **Live-sized DD not yet confirmed**: KPIs are the RISK_FIXED basis; live RISK_PERCENT DD is
  confirmed in the deploy flow (step 2) before the flip.
- **Below mission by design**: D2-a validates mechanics; ≥20%/yr needs breadth (8→~12 sleeves).

## What OWNER is asked to approve
Approve **this manifest** (the 8-sleeve D2-a book, 10% DD cap, 2% account risk) in writing.

## Post-approval deploy flow (only AFTER written approval — none done yet)
1. Generate live setfiles via `framework/scripts/gen_setfile.ps1` (ENV=live, RISK_PERCENT per weight,
   RISK_FIXED=0, qm_magic_slot_offset = registry symbol_slot).
2. **Confirm the live-sized (RISK_PERCENT) book DD < 10%** on the $100k account.
3. SHA256 match factory → `C:\QM\mt5\T_Live`; magic-registry recheck; **stage news calendar into
   T_Live `Common\Files` and confirm current**.
   Post-Q12 refresh note: Slot 1 setfile SHA256 is
   `E1E43CD30783AC1F96816BC4DB8669F68C7E8E2F5651583F7BBA6EEBA8DF5A4C`, Slot 5 is
   `C724188ABCBEAA67F21EAD06BC35D64A53BF9061C690FF45A56CC87697694B88`, Slot 6 is
   `0E847B5A51D539129C3999A0C9F6BD68440676DF03E6F569F2D82CD664A13E06`, and Slot 7 is
   `27C12AE24CDE1C033AA31B4ED7231A1E27E3B1F286D862170C34214DC57F0489` across framework,
   Go-Live package, and T_Live preset.
4. **OWNER or Claude** flip AutoTrading on T_Live.
5. Record `decisions/2026-06-27_t_live_d2a_8sleeve_book.md` with verification evidence.

**No step 1–4 will be taken without OWNER's written approval.**
