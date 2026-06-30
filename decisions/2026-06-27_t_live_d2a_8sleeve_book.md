# T_Live decision — D2-a 8-sleeve book (2026-06-27)

## Decision
OWNER approved the **8-sleeve D2-a book** for T_Live on 2026-06-27 (session: "go ahead" → "follow
your recommendation" → "go on" → "Yes — stage + I'll flip"). This **supersedes** the 5-sleeve book
approved 2026-06-26 (`decisions/2026-06-26_t_live_q12_5sleeve_book.md`): it is a strict superset —
the same 5 sleeves + GBPUSD, USDJPY (breadth-push additions), and XNGUSD.

Binding DD cap = **10% (FTMO-grade)**, account risk = **2%** (risk-parity, inverse-vol).

- Approved manifest: `D:\QM\reports\portfolio\manifest_d2a_dxz_2026-06-27.json`
  (`status=DRAFT_FOR_OWNER_APPROVAL`, `cap_met=True`, `degraded=False`, `book_source=q12-ready-all`).
- Review/verification package: `docs/ops/T_LIVE_APPROVAL_D2a_8sleeve_2026-06-27.md`.
- KPIs (canonical $100k, RISK_FIXED basis): MaxDD **0.72%**, MC-p95 **1.27%**, Sharpe **1.56**,
  net-of-cost **$8,427** over 1,716 days. Live 2%-risk-parity DD projects to **~2–4%** (< 10% cap).

## Deploy-flow progress (as of this record)
- ✅ **Step 1 — live setfiles generated** (`framework/EAs/<slug>/sets/<slug>_<sym>_<tf>_live.set`):
  ENV=live convention (RISK_FIXED=0 + RISK_PERCENT per weight), full strategy params (15/15 keys),
  `qm_magic_slot_offset` + `PORTFOLIO_WEIGHT` set.
- ✅ **Step 2 — live-sized DD gate** clears (~2–4% projected, < 10%).
- ✅ **Step 3 — staged into T_Live, SHA256-verified factory == T_Live for all 8**:
  `.ex5` → `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\QM\`, setfiles → `…\Presets\QM\`.
  News calendar: EA reads `D:\QM\data\news_calendar` (current, refreshed 2026-06-27 05:30) + FILE_COMMON fallback.
- ✅ **Setfile guardrail audit — all 8 PASS**:
  live setfiles now include explicit `strategy_*` params and no `card_defaults_source=not_found`;
  framework, Go-Live package, and T_Live preset copies are SHA256-identical per slot. Evidence:
  `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_SETFILE_GUARDRAIL_AUDIT_2026-06-27.md`.
- ✅ **Go-Live package preflight — PASS**:
  `python -m tools.strategy_farm.validate_golive_package C:\QM\deploy\GoLive_D2a_2026-06-27`
  verifies setfile guardrails, setfile framework/package/T_Live parity, and package/T_Live `.ex5`
  parity. Evidence: `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_GOLIVE_PREFLIGHT_2026-06-27.json`;
  Q12 ledger: `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_Q12_EVIDENCE_LEDGER_2026-06-27.md`.
- ✅ **Weight-cap simulation complete — no manifest change**:
  25%-30% sleeve caps reduce XNG concentration but increase MC-p95 DD and reduce Sharpe on the
  current 8-sleeve set. D2-a keeps the approved inverse-vol weights for the live mechanics tranche.
  Evidence: `C:\QM\deploy\GoLive_D2a_2026-06-27\D2A_WEIGHT_CAP_SIM_2026-06-27.md`.
- ✅ **Post-Q12 Slot 1 refresh — QM5_10513 / XAUUSD D1**:
  selected `q06_6_18_68_18` from `D:\QM\strategy_farm\scratch\q12_opt\20260627T132146Z\results.csv`
  (net 22241.07, PF 1.98, 104 trades, DD 4140.37) over baseline (net 20656.10, PF 1.88,
  DD 4236.81). Refreshed setfile is byte-identical across framework, Go-Live package, and T_Live
  preset; SHA256 `E1E43CD30783AC1F96816BC4DB8669F68C7E8E2F5651583F7BBA6EEBA8DF5A4C`.
  Evidence packet: `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_10513_Q12_SELECTION_2026-06-27.md`.
- ✅ **Post-Q12 Slot 5 refresh — QM5_10940 / XAUUSD H4**:
  selected `pullback_30_60` from `D:\QM\strategy_farm\scratch\q12_opt\20260627T175510Z\results.csv`
  (net 7528.58, PF 8.59, 8 trades, DD 1173.33) over baseline (net 5537.08, PF 6.58,
  6 trades, DD 1142.69). Refreshed setfile is byte-identical across framework, Go-Live package,
  and T_Live preset; SHA256 `C724188ABCBEAA67F21EAD06BC35D64A53BF9061C690FF45A56CC87697694B88`.
  Evidence packet: `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_10940_Q12_SELECTION_2026-06-27.md`.
- ✅ **Post-Q12 Slot 6 refresh — QM5_11132 / SP500 D1**:
  selected `strict_entry` from `D:\QM\strategy_farm\scratch\q12_opt\20260627T174037Z\results.csv`
  (net 3799.98, PF 3.93, 12 trades, DD 1076.67) over baseline (net 3002.69, PF 3.81,
  11 trades, DD 920.63). Refreshed setfile is byte-identical across framework, Go-Live package,
  and T_Live preset; SHA256 `0E847B5A51D539129C3999A0C9F6BD68440676DF03E6F569F2D82CD664A13E06`.
  Evidence packet: `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_11132_Q12_SELECTION_2026-06-27.md`.
- ✅ **Post-Q12 Slot 7 refresh — QM5_12567 / XNGUSD D1**:
  selected `entry_30` from `D:\QM\strategy_farm\scratch\q12_opt\20260627T155555Z\results.csv`
  (net 2624.30, PF 1.66, 49 trades, DD 1377.21) over baseline (net 1791.18, PF 1.31,
  58 trades, DD 2248.27). Refreshed setfile is byte-identical across framework, Go-Live package,
  and T_Live preset; SHA256 `27C12AE24CDE1C033AA31B4ED7231A1E27E3B1F286D862170C34214DC57F0489`.
  Evidence packet: `C:\QM\deploy\GoLive_D2a_2026-06-27\QM5_12567_Q12_SELECTION_2026-06-27.md`.
- ⏳ **Step 4 — AutoTrading flip: PENDING OWNER (GUI action; OWNER will flip).**

## Step-4 flip runbook (OWNER, in the T_Live terminal)
For each sleeve: open a chart for the symbol+TF → drag the EA from Navigator (Experts\QM\) onto it →
in the dialog, "Load" the matching setfile from Presets\QM\ → tick "Allow Algo Trading" → OK.
Then enable the global **AutoTrading** button once all 8 are attached.

| EA (Navigator) | symbol | TF | setfile | magic |
|---|---|---|---|---|
| QM5_10440_mql5-ohlc-mtf | NDX | H1 | QM5_10440_mql5-ohlc-mtf_NDX.DWX_H1_live.set | 104400003 |
| QM5_10513_mql5-ichimoku | XAUUSD | D1 | QM5_10513_mql5-ichimoku_XAUUSD.DWX_D1_live.set | 105130003 |
| QM5_10692_tv-ls-ms | NDX | H1 | QM5_10692_tv-ls-ms_NDX.DWX_H1_live.set | 106920005 |
| QM5_10715_tv-asian-box | USDJPY | M15 | QM5_10715_tv-asian-box_USDJPY.DWX_M15_live.set | 107150004 |
| QM5_10939_grimes-context-pb | GBPUSD | H4 | QM5_10939_grimes-context-pb_GBPUSD.DWX_H4_live.set | 109390001 |
| QM5_10940_grimes-nested-pb | XAUUSD | H4 | QM5_10940_grimes-nested-pb_XAUUSD.DWX_H4_live.set | 109400003 |
| QM5_11132_tm-cum-rsi2 | SP500 | D1 | QM5_11132_tm-cum-rsi2_SP500.DWX_D1_live.set | 111320000 |
| QM5_12567_cum-rsi2-commodity | XNGUSD | D1 | QM5_12567_cum-rsi2-commodity_XNGUSD.DWX_D1_live.set | 125670002 |

After the flip: confirm each EA shows the "smiley" (algo enabled) + correct magic in the Experts/Journal
tab, and append the AutoTrading timestamp + first-tick evidence to this record.

## Note
First V5 live portfolio. Below the ≥20%/yr mission by design (D2-a validates live execution mechanics).
The lever to mission-grade remains instrument breadth (8→~12 uncorrelated sleeves).
