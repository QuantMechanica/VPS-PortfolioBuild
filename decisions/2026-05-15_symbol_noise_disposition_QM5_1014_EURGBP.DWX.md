# Symbol-Noise Disposition — QM5_1014 / EURGBP.DWX

date: 2026-05-15
ea_id: QM5_1014
strategy_id: SRC04_S08 (Lien Ch 15 narrow-channel breakout)
symbol_under_review: EURGBP.DWX
phase_scope: P2 baseline screening (cohort run 2026-05-09)
parent_issue: QUA-1593 (cohort triage)
this_issue: QUA-1595 (Research disposition)
authority: V5 research disposition; no DL escalation required (CTO triage routing was malformed but is a CTO-class concern, not a strategy-card concern)

## Decision

**NO-ACTION on the EURGBP.DWX symbol-noise question.** Do **NOT** broaden the symbol set for QM5_1014 P2 retry. The "symbol-noise" framing is malformed for this EA at this lifecycle stage; symbol broadening cannot resolve the underlying defects.

Recommended next action (escalation to CTO / P2-Baseline-Runner, not Research):
1. Fix set-file / EA-input drift (`EA_INPUT_RISK_BOTH_SET`) cohort-wide for QM5_1014 before any further P2 work.
2. Implement P1 entry/exit logic in `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5` from card § 4-5 (currently a P0 scaffold).
3. Re-run P2 on the canonical symbol cohort (the same FX majors+crosses already configured) — symbol broadening is not what this cohort needs.

## Rationale (evidence-backed)

### 1. EURGBP.DWX is the central worked-example in the source, not a marginal symbol

`strategy-seeds/cards/lien-channels_card.md` § 1 and § 9 cite Lien (3rd ed., 2015) Ch 15 Fig 15.2 PDF pp. 140-141 as one of three primary worked examples for this strategy. Verbatim author claim (card § 9, quoting Lien):

> "The total range between the two lines is 12 pips with the low being 0.7148 and the high 0.7160. … EURGBP then proceeds to rally and reaches our target of 20 pips or double the amount risked."

EURGBP.DWX is therefore not a "noisy" or marginal symbol against this strategy — it is one of the THREE symbols the author explicitly hand-picked to illustrate the rule set (alongside USDCAD and EURUSD). A "broadened-symbol retry" framing assumes the canonical symbol set under-represents tradeable opportunities; the canonical set already includes the author's primary example. Broadening cannot help.

### 2. The deterministic triage routed on infra-failure rows, not strategy zero-trade rows

`framework/scripts/skill_zero_trades_triage.py` counts `verdict IN {NO_REPORT, INVALID}` plus rows where `invalidation_reason` contains "zero". For `D:/QM/reports/pipeline/QM5_1014/P2/report.csv`:

| symbol | verdict | invalidation_reason | counted by triage? |
|---|---|---|---|
| EURGBP.DWX | FAIL | `MIN_TRADES_NOT_MET;NON_DETERMINISTIC` | no |
| EURUSD.DWX | INVALID | `no_summary_json:rc=1` | **yes** |
| AUDUSD.DWX | FAIL | `REPORT_MISSING;INCOMPLETE_RUNS` | no |
| NZDUSD.DWX | INVALID | `no_summary_json:rc=1` | **yes** |
| USDCAD.DWX | FAIL | `REPORT_MISSING;INCOMPLETE_RUNS` | no |
| USDCHF.DWX | FAIL | `MIN_TRADES_NOT_MET` | no |
| USDJPY.DWX | FAIL | `MIN_TRADES_NOT_MET` | no |
| GBPUSD.DWX | FAIL | `REPORT_MISSING;INCOMPLETE_RUNS` | no |

`zero_trade_count = 2` therefore reflects two `no_summary_json` infra failures (EURUSD, NZDUSD) — not EURGBP.DWX, and not any genuine "EA traded zero times" outcome. The triage routing to "symbol-noise track" with EURGBP.DWX as the focal symbol was a comment-thread choice in QUA-1593, not a value derived from the triage script for this symbol.

### 3. The actual MIN_TRADES_NOT_MET rows all share a universal OnInit failure

The MIN_TRADES_NOT_MET runs that DID happen (EURGBP, USDJPY, USDCHF, USDCAD, EURUSD, GBPUSD) all terminated identically at OnInit. Sample evidence from `D:/QM/reports/pipeline/QM5_1014/P2/QM5_1014/20260509_143124/raw/run_01/20260509.log` (EURGBP.DWX):

> `2024.01.01 00:00:00   EA_INPUT_RISK_BOTH_SET`
> `tester stopped because OnInit returns non-zero code 1`

Cross-symbol verification (`OnInit returns non-zero` / `EA_INPUT_RISK_BOTH_SET` lines per run):

| run dir | symbol | OnInit-error lines in tester log |
|---|---|---|
| 20260509_121908 | USDJPY.DWX | 12 |
| 20260509_142744 | USDJPY.DWX | 48 |
| 20260509_143208 | USDCHF.DWX | 4 |
| 20260509_124703 | USDCAD.DWX | 16 |
| 20260509_142718 | EURUSD.DWX | 44 |
| 20260509_143124 | EURGBP.DWX | (same pattern; full log inspected) |

The validation rule is in `framework/Include/QM/QM_Common.mqh:35-48` (`QM_FrameworkValidateRiskInputs`): fires `EA_INPUT_RISK_BOTH_SET` when both `RISK_PERCENT > 0` AND `RISK_FIXED > 0`. The tester log shows the EA received `RISK_PERCENT=1.0` and `RISK_FIXED=1000.0` at runtime even though the current on-disk set file (`framework/EAs/QM5_1014_lien_channels/sets/QM5_1014_lien_channels_EURGBP.DWX_M15_backtest.set`, mtime 2026-05-09 13:44:14, before the 2026-05-09 16:31 run) has `RISK_FIXED=1000` and `RISK_PERCENT=0` — i.e., a set-file ↔ runtime drift the EA's OnInit correctly rejected.

This is a **cohort-wide setup/runtime config defect**, not a symbol or strategy property. Symbol broadening cannot fix a universal OnInit rejection.

Also note: `summary.json` for run 20260509_143124 reports `oninit_failure: false` despite "tester stopped because OnInit returns non-zero code 1" in the tester log. This is a P2 summary-parser inconsistency (the parser flag and the log evidence disagree). Logged here for awareness; remediation is out-of-scope for Research and belongs with Pipeline-Operator / CTO.

### 4. The EA is still a P0 scaffold — no entry/exit logic implemented

`framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5:57-67`:

```mql5
void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // P0 scaffold: trading logic to be implemented from card Section 4/5.
  }
```

`git log -- framework/EAs/QM5_1014_lien_channels/` confirms the EA history consists exclusively of scaffold + compile commits (`bec4a56c7`, `41669240c`, `d1248bd53`, `807311469`, `fdc3da95a`, `d12834468`). No P1 entry-logic implementation has shipped. Even if the OnInit drift were fixed, this EA cannot produce trades on EURGBP.DWX or any other symbol — the entry/exit code from card § 4 (n-bar rolling high/low channel + bracket stop-orders at channel±10p) is not in the source yet.

### 5. Why symbol broadening is the wrong remedy

Possible justifications for symbol broadening would be:
- (a) Strategy is real and trades, but the chosen cohort under-samples its tradeable regime → **not applicable**: cannot be true while the EA has no entry logic.
- (b) EURGBP-specific liquidity / spread anomaly suppressed signals an implemented strategy would otherwise have generated → **not applicable**: no signals were generated for OnTick to act on; furthermore the OnInit failure short-circuited execution before any tick processing.
- (c) Symbol-cohort lacks the author's preferred regime → **falsified by source**: the cohort already contains EURGBP.DWX, USDCAD.DWX, and EURUSD.DWX — the author's three primary worked examples.

The correct remedies are P1 implementation and set-file / EA-input drift fix, both of which are CTO / Development scope.

## Boundaries

- Applies to QM5_1014 P2 cohort run dated 2026-05-09 only.
- Supersede this ADR after: (i) `EA_INPUT_RISK_BOTH_SET` cohort-wide OnInit drift is fixed and (ii) `QM5_1014_lien_channels.mq5` P1 entry/exit code from card § 4-5 is implemented and recompiled; THEN re-run P2 on the canonical cohort and re-evaluate any zero-trade outcomes per symbol.
- Does NOT apply to QM5_1003, QM5_1017, QM5_SRC04_S03 (these are on the recovery-v2 track per QUA-1594).

## Evidence anchors

- Cohort report: `D:/QM/reports/pipeline/QM5_1014/P2/report.csv`
- Per-run summaries: `D:/QM/reports/pipeline/QM5_1014/P2/QM5_1014/20260509_*/summary.json`
- EURGBP MIN_TRADES_NOT_MET run: `D:/QM/reports/pipeline/QM5_1014/P2/QM5_1014/20260509_143124/` (summary.json + raw/run_01/20260509.log + raw/run_02/20260509.log)
- Source EA: `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5`
- Source set file: `framework/EAs/QM5_1014_lien_channels/sets/QM5_1014_lien_channels_EURGBP.DWX_M15_backtest.set`
- Validation rule: `framework/Include/QM/QM_Common.mqh:35-48`
- Triage script: `framework/scripts/skill_zero_trades_triage.py`
- Strategy card: `strategy-seeds/cards/lien-channels_card.md` (citation, worked-example pip P&L)
- Decision-log precedent for zero-trade allowance pattern: `decisions/2026-05-05_zero_trade_QM5_1017_*.md`
