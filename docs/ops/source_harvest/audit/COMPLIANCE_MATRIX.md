# Compliance Matrix — Live Book + Candidates, 2026-07-24

Synthesized from three independent per-EA evidence agents + framework ground truth,
then cross-diffed against Codex's independent audit
(`D:\QM\reports\audit\codex_compliance_2026-07-24\COMPLIANCE_MATRIX_CODEX.md`, 232
applicable cells, captured 05:34Z). **All divergent cells resolved to the more
restrictive verdict** (§ Divergence resolution). Verdicts: PASS / FAIL / MISSING /
N_A (not applicable, excluded from denominators).

**Live totals (24 instances × 8 checks = 192 cells): 150 PASS / 40 FAIL / 2 MISSING.**

## Evidence key (per-cell shorthand → concrete path)

| key | evidence file | content |
|---|---|---|
| Q | `evidence/compliancefinal__qm_event_scan.json` (key = magic) | per-magic KILL_SWITCH_INIT (daily_loss_halt_pct, portfolio_dd_halt_pct, manual_halt_file), NEWS_CALENDAR_LOADED/SELFTEST, FRIDAY_CLOSE from `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_<id>_ea-<id>.log` |
| S | `evidence/compliancefinal__set_risk_scan.txt` | ENV/RISK_FIXED/RISK_PERCENT/risk_mode-header per deployed preset (`C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\NN_*.set`) |
| R | `evidence/compliance*__magic_registry_scan.txt` / `compliance1__registry_scan.json` | `framework/registry/magic_numbers.csv` row + registry-wide duplicate scan (0 collisions; Codex confirms 15,186 rows clean) |
| V | `evidence/compliance2__live_ex5_restat.txt` + `D:\QM\reports\state\tlive_ks_vintage_20260720.csv` | deployed `.ex5` mtime vs KillSwitch fix commit `47f1d9709` (2026-07-05 21:12) |
| F | `evidence/framework__facts.txt`, `framework__killswitch_portfolio_dd.txt` | framework ground truth (file:line) |
| CX | `D:\QM\reports\audit\codex_compliance_2026-07-24\FINDINGS_CODEX.md` #n | Codex finding adopted |

Framework facts applied to every row: daily-loss halt hardcoded 3% (`QM_Common.mqh:215`,
no set input); KS_PORTFOLIO_DD default 0.0 = signal-file-existence-trip mode, polled 1×/s
live (`QM_KillSwitch.mqh:435-436,495-496`) — **no live process writes any signal file**
(only writer `ftmo_trial_pulse.py:231-241` gated on absent `FTMO_DD_FLOOR_ARMED.flag`;
halt dirs empty) ⇒ max-DD kill column is FAIL book-wide; Friday close default-on 21h
broker (`EA_Skeleton.mq5:65-66`), no separate weekend filter (documented, not scored);
risk mode has **no runtime ENV enforcement** — values drive mode (`QM_Common.mqh:171-173`).

## Live book (24 instances, T_Live acct 4000090541)

| # | EA | Symbol | Magic | 1 Magic | 2 RiskMode | 3 Cap≤1% | 4 News | 5 DailyLoss 3% | 6 MaxDD | 7 FridayClose | 8 KS channel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 01 | 13301 balke-minute | GDAXI | 133010010 | PASS R | PASS S | PASS S(0.069) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q(`QM\halt`),V(07-16) |
| 02 | 13213 balke-gmt3 | USDJPY | 132130000 | PASS R¹ | PASS S | PASS S(0.043) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-14) |
| 03 | 1567 demark-td-rev | EURUSD | 15670007 | PASS R | PASS S | PASS S(0.179) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-15) |
| 04 | 10919 grimes-overshoot | XTIUSD | 109190001 | PASS R | **FAIL** S,CX#4 (header `environment=backtest, risk_mode=FIXED` on live preset; values live-conform RF=0/RP=0.9181) | PASS S(0.918) | **MISSING** Q,CX#5 (calendar loaded rows=96123 but no per-magic native SELFTEST) | PASS Q | FAIL Q,F | PASS F | **FAIL** Q(`D:\QM\data\halt`),V(07-03) |
| 05 | 11165 weiss-rsi-ma | AUDCAD | 111650002 | PASS R | PASS S | PASS S(0.523) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-17) |
| 06 | 12778 cointegration | AUDUSD | 127780000 | PASS R | PASS S | PASS S(0.491) | **FAIL** S(`qm_filter_news_enabled=0`),Q(`all_news_axes_off`),CX#9 | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-13) |
| 07 | 11421 ohlc-squeeze | AUDUSD | 114210003 | PASS R | PASS S | PASS S(0.361) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 08 | 11165 weiss-rsi-ma | EURUSD | 111650000 | PASS R | PASS S | PASS S(0.413) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-17) |
| 09 | 11421 ohlc-squeeze | EURUSD | 114210000 | PASS R | PASS S | PASS S(0.336) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 10 | 11708 anon-squeeze | EURUSD | 117080000 | PASS R | PASS S | PASS S(0.508) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-13) |
| 11 | 10706 tv-mon-ls | GBPUSD | 107060001 | PASS R | PASS S | PASS S(0.053) | PASS Q | PASS Q | FAIL Q,F | PASS S(custom 18:30, stricter) | PASS Q,V(07-13) |
| 12 | 10939 grimes-context | GBPUSD | 109390001 | PASS R | PASS S | PASS S(0.189) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 13 | 10911 grimes-complex | GDAXI | 109110003 | PASS R | PASS S | PASS S(0.128) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 14 | 13128 pre-fomc-drift | NDX | 131280000 | PASS R | PASS S | PASS S(1.000, at ceiling) | **FAIL** Q(`all_news_axes_off`; compiled-in FOMC list, no stale-guard),CX#22 | PASS Q | FAIL Q,F | PASS Q | PASS Q,V(07-13) |
| 15 | 10440 mql5-ohlc-mtf | NDX | 104400003 | PASS R | PASS S | PASS S(0.058) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 16 | 11132 tm-cum-rsi2 | SP500 | 111320000 | PASS R | PASS S | PASS S(0.456) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 17 | 12969 gotobi-nakane | USDJPY | 129690000 | PASS R | PASS S | PASS S(0.510) | **MISSING** Q,CX#28 (loaded rows=96123, no native SELFTEST) | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-13) |
| 18 | 10403 et-turtle20x | XAUUSD | 104030002 | PASS R | PASS S | PASS S(0.220) | PASS Q | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-13) |
| 19 | 10513 mql5-ichimoku | XAUUSD | 105130003 | PASS R | PASS S | PASS S(0.305) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 20 | 12567 cum-rsi2-cmdty | XAUUSD | 125670003 | PASS R | PASS S | PASS S(0.747) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 21 | 12989 grimes-nested | XAUUSD | 129890003 | PASS R | **FAIL** S,CX#35 (header `PERCENT_DRAFT_INVOL_SUMRISK_CAPPED_S3-D2D-15` — draft label on live preset; values conform) | PASS S(0.242) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(07-04) |
| 22 | 1556 aa-zak-mom12 | XAUUSD | 15560004 | PASS R | PASS S | PASS S(0.602) | PASS Q | PASS Q | FAIL Q,F | PASS Q(closed=1 07-17) | PASS Q,V(07-13) |
| 23 | 12567 cum-rsi2-cmdty | XNGUSD | 125670002 | PASS R | PASS S | PASS S(0.980) | PASS Q | PASS Q | FAIL Q,F | PASS F | **FAIL** Q,V(06-28) |
| 24 | 13117 eurgbp-audjpy | EURGBP | 131170000 | PASS R | PASS S | PASS S(0.420) | **FAIL** S(`qm_filter_news_enabled=0`),Q,CX#41 | PASS Q | FAIL Q,F | PASS F | PASS Q,V(07-14) |

¹ 13213 was missing from `ea_id_registry.csv` (not `magic_numbers.csv`) at audit start — backfilled, commit `51778300b`.

**Column readings:**
- **Max-DD kill FAIL ×24** — not a per-EA defect: the channel is armed in existence-trip
  mode but **no producer writes any signal file** (framework facts above). One decision
  fixes all 24 → ESC-01.
- **KS channel FAIL ×11** (9 EAs: 10440, 10513, 10911, 10919, 10939, 11132, 11421×2,
  12567×2, 12989): binaries predate fix `47f1d9709`; runtime `manual_halt_file` shows
  the dead absolute `D:\QM\data\halt\...` path in KILL_SWITCH_INIT — these sleeves
  cannot be halted via the file channel (KS_MANUAL + KS_PORTFOLIO_DD both dead).
  Retired by the planned 26.07 recompile wave → ESC-03.
- **News FAIL ×3** are deliberate set/source-level opt-outs (12778/13117 basket EAs,
  13128 event-EA with compiled-in FOMC dates and no stale-guard) — policy decision
  needed → ESC-05. MISSING ×2 (10919, 12969) = native-calendar proof gap on old
  binaries; self-resolves with the 26.07 rebuild (current template emits SELFTEST).
- **Additionally (not a column):** ALL 24 deployed binaries predate the 2026-07-20
  P0/P1 framework bundle (newest live build 07-17) — every live sleeve still carries
  P0.1 (unguarded Q08 history walk in live OnDeinit = deinit-kill risk) and lacks
  P0.2/P0.5/P0.6/P1.x fixes. Fixed in tree, waiting on the 26.07 wave → ESC-03.

## Candidates (Q11–Q13 queue + portfolio-candidate pool; not deployed — checks 5/6/8 N_A)

| EA | Symbol | Source of candidacy | 1 Magic | 2 RiskMode (factory set) | 3 Cap | 4 News | 7 Friday |
|---|---|---|---|---|---|---|---|
| 10123 | XAUUSD.DWX | Q10 PASS | PASS R | PASS (backtest FIXED 1000/0) | PASS | PASS | PASS |
| 10128 | XAUUSD.DWX | Q10 PASS | PASS R | PASS | PASS | PASS | PASS |
| 10145 (3 ablation configs) | XAUUSD.DWX | Q10 PASS | PASS R | PASS | PASS | **FAIL ×3** CX#43-45 (sets carry only legacy `qm_filter_news_*` keys the current source no longer reads → effective OFF, while Q10 aggregates claim PRE30_POST30/DXZ compliance — metadata contradicts effective inputs) | PASS |
| 10183 | XAUUSD.DWX | Q10 PASS | PASS R | PASS | PASS | PASS | PASS |
| 13013 | NDX.DWX | Q10 PASS | PASS R | PASS | PASS | PASS | PASS |
| 20048 | XTIUSD.DWX | Q10 PASS | PASS R | PASS | PASS | PASS | **FAIL** CX#46 (source hardcodes `qm_friday_close_enabled=false`, EA holds over weekends by design — needs OWNER sign-off at Q12) |
| 10700 | XAUUSD.DWX | Q12_REVIEW_READY | PASS R | PASS | N_A | UNKNOWN | N_A |
| 10815 | EURUSD.DWX | Q12_REVIEW_READY | PASS R | PASS | N_A | UNKNOWN | N_A |
| 10815 | GDAXI.DWX | Q12_REVIEW_READY | PASS R | PASS | N_A | UNKNOWN | N_A |
| 12474 | GBPUSD.DWX | Q12_REVIEW_READY | PASS R | PASS | N_A | UNKNOWN | N_A |
| 1567 | XAGUSD.DWX | Q12_REVIEW_READY | PASS R | PASS | N_A | UNKNOWN | N_A |
| 10476 | USDCAD.DWX | former-live (swapped out) | PASS R | **MISSING** (no factory backtest set; only staged-live draft) | N_A | N_A | N_A |
| 10715 | USDJPY.DWX | former-live (swapped out) | PASS R | **MISSING** | N_A | N_A | N_A |
| 10940 | XAUUSD.DWX | former-live (retired) | PASS R | **MISSING** | N_A | N_A | N_A |

Scope note: Codex audited the strict Q10-PASS-not-live set (8 configs, 6 ids); this
matrix is the union with the portfolio-candidate pool and former-live rows from the
inventory reconciliation. Cells only Codex evidenced carry CX refs; UNKNOWN cells were
outside both sweeps and belong to the Q12 pre-live review anyway.

## Divergence resolution (cross-review round, stricter-wins)

| cell | Claude initial | Codex | resolved | rationale |
|---|---|---|---|---|
| 10919 risk_mode | PASS+note | FAIL | **FAIL** | live preset carries `environment=backtest, risk_mode=FIXED` header — deploy-contract violation even though values behave PERCENT (no runtime enforcement exists to catch it) |
| 12989 risk_mode | PASS+note | FAIL | **FAIL** | draft header label on a live preset — same contract violation class |
| 10919 news | PASS | MISSING | **MISSING** | NEWS_CALENDAR_LOADED alone does not prove NATIVE-calendar operation; per-magic SELFTEST absent on this 07-03 binary |
| 12969 news | PASS | MISSING | **MISSING** | same proof gap (07-13 binary, no SELFTEST event) |
| 10145 news (cand., ×3) | UNKNOWN | FAIL | **FAIL** | legacy news keys ineffective vs current source inputs; Q10 metadata contradicts effective config |
| 20048 friday (cand.) | UNKNOWN | FAIL | **FAIL** | source hardcodes friday_close=false |

The table's 6 resolution rows cover **8 cells** (2 live risk-mode, 2 live news, 3×10145
candidate news, 1×20048 candidate Friday). No unresolved verdict divergences remain;
policy-level questions escalated in `ESCALATIONS.md`. Codex's evidence CSV:
`D:\QM\reports\audit\codex_compliance_2026-07-24\EVIDENCE_EXTRACT_CODEX.csv`.

## Cross-review outcome (Codex reviewing the merged matrix — single round, closed)

`D:\QM\reports\audit\codex_compliance_2026-07-24\CROSS_REVIEW_CODEX.md`: 6× CONFIRM
(totals arithmetic, max-DD ×24 with fresh external scan, killswitch 11-instance set
re-derived from primary logs, stricter-wins completeness, 10 fresh spot-checked cells,
registry/preset arithmetic), 2× DISPUTE — **both accepted and fixed in this file**:

1. Six magic cell identities in the dual-symbol rows (05/08, 07/09, 20/23) were
   pair-swapped — a transcription defect inherited from
   `evidence/inventory__live_eas.json` (the agent's magic↔symbol pairing for the three
   dual-symbol EAs is reversed there; the JSON is retained unmodified as originally
   captured — THIS table, verified against preset primary evidence lines 7/10/17, is
   authoritative). Verdict totals unaffected.
2. The earlier "5 divergent cells" phrasing undercounted — corrected to 8 cells in 6
   divergence classes (above).
