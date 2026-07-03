# D2-c 13-sleeve exit-surgery audit - 2026-07-03

Task: `2baa3918-1bea-418f-94cd-007fe886d735`
Status: evidence report only. No live params touched; no live files changed.

## Data Availability

The 13 live sleeve Q08 `TRADE_CLOSED` streams are legacy close-only rows. Across the 13 streams:

- `entry_time` streams: 0 / 13
- `mae_acct` streams: 0 / 13
- MFE streams: 0 / 13

So true MAE/MFE distributions and hold-time-vs-outcome gradients cannot be reconstructed from these artifacts. The ranked table below uses computable proxies: net-of-cost outcome distribution, scratch rate (`abs(net) <= $100`, roughly <=0.1R on the $1000 fixed-risk basis), payoff ratio, profit factor, and source-level exit mechanics. A definitive MAE/MFE audit requires rerunning the sleeves after the framework `entry_time`/`mae_acct` stream change; MFE still needs a new field if required.

## Ranked Exit-Amputation Suspicion

| rank | slot | EA | symbol | trades | net | win% | scratch<=100 | payoff | PF | exit flags | score |
|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---|---:|
| 1 | 6 | QM5_10940 | XAUUSD.DWX | 35 | 6963 | 31.4% | 20.0% | 3.11 | 1.49 | fixed_tp,breakeven,time_exit | 59.0 |
| 2 | 5 | QM5_10939 | GBPUSD.DWX | 24 | 3654 | 37.5% | 12.5% | 2.20 | 1.32 | fixed_tp,breakeven,time_exit | 53.8 |
| 3 | 8 | QM5_11165 | AUDCAD.DWX | 41 | 3203 | 75.6% | 39.0% | 0.71 | 2.20 | time_exit,signal_exit | 45.1 |
| 4 | 9 | QM5_11421 | AUDUSD.DWX | 53 | 5678 | 69.8% | 0.0% | 0.58 | 1.35 | fixed_tp | 23.3 |
| 5 | 10 | QM5_11421 | EURUSD.DWX | 23 | 6409 | 78.3% | 0.0% | 0.61 | 2.21 | fixed_tp | 22.7 |
| 6 | 11 | QM5_12567 | XAUUSD.DWX | 28 | 16448 | 89.3% | 0.0% | 0.52 | 4.30 | time_exit,signal_exit | 21.7 |
| 7 | 7 | QM5_11132 | SP500.DWX | 23 | 4929 | 78.3% | 0.0% | 0.71 | 2.56 | time_exit,signal_exit | 17.8 |
| 8 | 2 | QM5_10692 | NDX.DWX | 195 | 29647 | 48.7% | 7.7% | 1.48 | 1.41 | time_exit | 17.4 |
| 9 | 1 | QM5_10513 | XAUUSD.DWX | 31 | 798 | 35.5% | 3.2% | 1.90 | 1.04 | fixed_tp | 17.3 |
| 10 | 0 | QM5_10440 | NDX.DWX | 343 | 70092 | 40.8% | 0.0% | 1.93 | 1.33 | fixed_tp | 15.0 |
| 11 | 4 | QM5_10911 | GDAXI.DWX | 268 | 13226 | 38.8% | 3.0% | 1.77 | 1.12 | time_exit,signal_exit | 14.1 |
| 12 | 3 | QM5_10715 | USDJPY.DWX | 468 | 11704 | 50.0% | 19.4% | 1.20 | 1.20 | none | 13.6 |
| 13 | 12 | QM5_12567 | XNGUSD.DWX | 19 | 15271 | 89.5% | 0.0% | 2.39 | 20.28 | time_exit,signal_exit | 12.0 |

## Top v2 Proposals

### QM5_10940 grimes-nested-pb XAUUSD H4 v2

- Reason: Rank #1. Source-level amputation risk is high: 2R target, BE at 1R, EMA exit, and 20 H4-bar time exit; live 06-30 scratch is consistent with BE-amputation class.
- Evidence row: n=35, net=6963, win_rate=31.4%, scratch_abs_100=20.0%, payoff=3.11, PF=1.49.
- Variant: New EA version only: delay BE trigger from 1.0R to 1.5R or replace BE with ATR trail after 1.5R; widen time exit from 20 to 40 H4 bars; keep initial stop/news/friday unchanged. Full Q02->Q08, challenger-swap only at Q09.

### QM5_10939 grimes-context-pb GBPUSD H4 v2

- Reason: Rank #2. Same BE/time-exit family as 10940, but on GBPUSD; this is a controlled paired challenger for the Grimes pullback sleeve family.
- Evidence row: n=24, net=3654, win_rate=37.5%, scratch_abs_100=12.5%, payoff=2.20, PF=1.32.
- Variant: New EA version only: remove BE move or move BE trigger to 1.5R, replace 18 H4-bar time exit with structure exit only or 36 H4 bars; no live parameter edit.

### QM5_11165 weiss-rsi-ma AUDCAD H1 v2

- Reason: Rank #3. The stream has a high scratch rate and payoff below 1.0 while using RSI midpoint exit plus a hard H1 max-hold; that shape can indicate exits harvesting many small wins while clipping right tail.
- Evidence row: n=41, net=3203, win_rate=75.6%, scratch_abs_100=39.0%, payoff=0.71, PF=2.20.
- Variant: New EA version only: test later RSI exit threshold and/or longer max hold, plus an ATR trail alternative after RSI recovers. Keep entry thresholds and initial stop unchanged. Full Q02->Q08 before any Q09 challenger decision.


## Watchlist

`QM5_11421` AUDUSD/EURUSD remains a fixed-TP family worth watching, but it ranked below the three proposals on this pass because the close-only streams show 0% scratch rate. A no-fixed-TP or wider-TP challenger can be queued later if OWNER wants to test target amputation specifically.

## Non-Proposals

- Do not touch T_Live params. Each proposal is a new EA version and must enter at Q02, clear Q08, and only challenge-swap at Q09.
- Do not infer real MAE/MFE from close-only rows. This report ranks likely candidates for controlled challenger tests, not final proof of exit amputation.

## Artifacts

- Ranked metrics JSON: `D:\QM\strategy_farm\artifacts\portfolio\d2c_exit_surgery_2026-07-03\d2c_exit_surgery_metrics_2026-07-03.json`
- Ranked CSV: `D:\QM\strategy_farm\artifacts\portfolio\d2c_exit_surgery_2026-07-03\d2c_exit_surgery_ranked_2026-07-03.csv`
- Proposal JSON: `D:\QM\strategy_farm\artifacts\portfolio\d2c_exit_surgery_2026-07-03\d2c_exit_surgery_v2_proposals_2026-07-03.json`

## Verdict

PASS_FOR_REVIEW_WITH_DATA_GAP: ranked proxy audit and three v2 proposals produced. True MAE/MFE and hold-gradient work is blocked until rerun streams carry `entry_time`, `mae_acct`, and ideally MFE.
