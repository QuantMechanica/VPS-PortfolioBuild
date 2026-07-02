# WS1 Card Inventory Hygiene Evidence - 2026-07-02

Scope: CEO WS1 card-inventory hygiene task. Factory terminals were not started and no work items were enqueued by this pass.

## Approved-pool EA-ID dedup

Detector: parsed frontmatter `ea_id` for every `D:\QM\strategy_farm\artifacts\cards_approved\*.md`, normalized `QM5_<n>`, and grouped by card filename slug.

Result:
- Initial collisions: 41 `ea_id` groups / 85 card files.
- Renumbered: 40 unbuilt claimants using `python tools/strategy_farm/farmctl.py reserve-ea-ids`.
- Registry rows added: `QM5_12918` through `QM5_12957`, `strategy_id=ws1-card-inventory-hygiene-2026-07-02`.
- Remaining collisions: 4 built-protected groups. They were not renumbered because an existing built EA directory with `.ex5` exists for the claimant slug.

| Old file | New file |
|---|---|
| `QM5_1142_jegadeesh-1w-reversal-fx.md` | `QM5_12918_jegadeesh-1w-reversal-fx.md` |
| `QM5_1143_amp-value-momentum-xasset.md` | `QM5_12919_amp-value-momentum-xasset.md` |
| `QM5_1156_qp-pre-election-sp500.md` | `QM5_12920_qp-pre-election-sp500.md` |
| `QM5_1158_qp-january-barometer.md` | `QM5_12921_qp-january-barometer-card.md` |
| `QM5_1159_ariel-first-half-month-idx.md` | `QM5_12922_ariel-first-half-month-idx.md` |
| `QM5_1223_hopwood-dmi-cross-h1.md` | `QM5_12923_hopwood-dmi-cross-h1-card.md` |
| `QM5_1228_hopwood-stochastic-cross-h1.md` | `QM5_12924_hopwood-stochastic-cross-h1.md` |
| `QM5_1229_hopwood-ma-rainbow-h4.md` | `QM5_12925_hopwood-ma-rainbow-h4.md` |
| `QM5_1230_renko-color-streak-h1.md` | `QM5_12926_renko-color-streak-h1.md` |
| `QM5_1327_chande-vidya-trend-h4.md` | `QM5_12927_chande-vidya-trend-h4.md` |
| `QM5_1330_renko-double-flip-confirm-h1.md` | `QM5_12928_renko-double-flip-confirm-h1.md` |
| `QM5_1404_brooks-expanded-micro-channel-h1.md` | `QM5_12929_brooks-expanded-micro-channel-h1.md` |
| `QM5_1405_classical-ascending-triangle-breakout-h4.md` | `QM5_12930_classical-ascending-triangle-breakout-h4.md` |
| `QM5_1424_classical-triple-top-reversal-h4.md` | `QM5_12931_classical-triple-top-reversal-h4.md` |
| `QM5_1428_wyckoff-phase-e-markdown-continuation-h4.md` | `QM5_12932_wyckoff-phase-e-markdown-continuation-h4.md` |
| `QM5_1551_aa-tom-sma10.md` | `QM5_12933_aa-tom-sma10-card.md` |
| `QM5_1554_aa-comm-spot-rev.md` | `QM5_12934_aa-comm-spot-rev-card.md` |
| `QM5_1583_sperandeo-tlb-refinement-h4.md` | `QM5_12935_sperandeo-tlb-refinement-h4.md` |
| `QM5_1601_demark-td-reverse-differential-h4.md` | `QM5_12936_demark-td-reverse-differential-h4.md` |
| `QM5_1617_demark-td-termination-count-alt-h4.md` | `QM5_12937_demark-td-termination-count-alt-h4.md` |
| `QM5_1618_hopwood-bermaui-dss-h4.md` | `QM5_12938_hopwood-bermaui-dss-h4.md` |
| `QM5_1635_carney-alternate-bat-h4.md` | `QM5_12939_carney-alternate-bat-h4.md` |
| `QM5_1637_bressert-cycle-trigger-line-h4.md` | `QM5_12940_bressert-cycle-trigger-line-h4-card.md` |
| `QM5_1647_hopwood-bermaui-macd-h4.md` | `QM5_12941_hopwood-bermaui-macd-h4-card.md` |
| `QM5_1648_ehlers-ebsw-cycle-composite-h4.md` | `QM5_12942_ehlers-ebsw-cycle-composite-h4.md` |
| `QM5_1649_robopip-hlhb-trend-catcher-h1.md` | `QM5_12943_robopip-hlhb-trend-catcher-h1.md` |
| `QM5_1649_sperandeo-trend-fault-line-h4.md` | `QM5_12944_sperandeo-trend-fault-line-h4.md` |
| `QM5_9166_tv-kn-ema-cross-atr-tp.md` | `QM5_12945_tv-kn-ema-cross-atr-tp.md` |
| `QM5_9197_mql5-macd-obv-div.md` | `QM5_12946_mql5-macd-obv-div-card.md` |
| `QM5_9198_mql5-ha-ema-trend.md` | `QM5_12947_mql5-ha-ema-trend-card.md` |
| `QM5_9199_mql5-mfi-trend.md` | `QM5_12948_mql5-mfi-trend-card.md` |
| `QM5_9220_mql5-rvi-ma.md` | `QM5_12949_mql5-rvi-ma-card.md` |
| `QM5_9221_mql5-ad-price.md` | `QM5_12950_mql5-ad-price-card.md` |
| `QM5_9221_mql5-chaikin-zero.md` | `QM5_12951_mql5-chaikin-zero-card.md` |
| `QM5_9222_mql5-force-ema.md` | `QM5_12952_mql5-force-ema-card.md` |
| `QM5_9222_mql5-gator-ma.md` | `QM5_12953_mql5-gator-ma-card.md` |
| `QM5_9283_pring-coppock-h4-variant.md` | `QM5_12954_pring-coppock-h4-variant.md` |
| `QM5_9284_mql5-aroon-cross.md` | `QM5_12955_mql5-aroon-cross-card.md` |
| `QM5_12708_commodity-tsmom-6m_card.md` | `QM5_12956_commodity-tsmom-6m-card.md` |
| `QM5_12709_commodity-reversal-1m_card.md` | `QM5_12957_commodity-reversal-1m-card.md` |

Built-protected collision groups left unchanged:
- `QM5_1101`: `qp-comm-mom12` and `turn-around-tuesday` both have built EA dirs.
- `QM5_1157`: `plastun-crude-oil-autumn` has a built EA dir; `qp-stress-reversal-sp500` is the registry-matching claimant.
- `QM5_1328`: `brooks-3bar-reversal-h4` and `wave59-quickstrike-pivot-of-pivot-h1` both have built EA dirs.
- `QM5_12784`: `intraday-config-engine` and `progo-xti` both have built EA dirs.

## Requeue exclusion list

Created `D:\QM\strategy_farm\state\requeue_excluded_eas.txt`.

Selection rule: approved + built + FX-only symbol classes + `expected_trades_per_year_per_symbol > 100`, derived from `cards_parsed.json` beside the Claude scratchpad. Count: 160 EAs (108 cost-doomed `>150/yr` plus 52 borderline `100-150/yr`).

Wired code paths:
- `tools/strategy_farm/farmctl.py`: shared `REQUEUE_EXCLUDED_EAS_FILE`, loader, and Q02 exclusion checks in `_detect_unenqueued_eas`, `_create_backtest_work_items`, `enqueue_backtest`, and `_auto_enqueue_q02_for_build`.
- `tools/strategy_farm/sweep_enqueue_built_eas.py`: exclusion loader and skips in Part 1 never-tested Q02, Part 2 stranded Q02 requeue, and Part 3 deferred-symbol Q02 promotion.
- `tools/strategy_farm/r_eval_drain.py`: reviewed; no Q02 enqueue path exists, so no code change was required.

Existing pending/active rows are untouched. Q04+ cascade reruns are untouched.

## Review-pile compliance rejects

Moved from `D:\QM\strategy_farm\artifacts\cards_review\` to `D:\QM\strategy_farm\artifacts\cards_rejected\` and prepended an HTML rejection comment:
- `QM5_12040_ru-catboost-classifier.md`: ML hard-banned.
- `QM5_12007_ssrn-agentic-factor-miner.md`: ML/data-mining hard-banned.
- `QM5_11956_waka-waka-grid.md`: martingale sizing banned.

Read-only check of `agent_tasks` found no rows referencing these three card IDs; no task state was changed.

## XBRUSD tradability verification

Verdict: `XBRUSD.DWX` is present as a local custom-symbol history/tick folder on T1/T5, but it is not canonical Q02-tradable in the current DWX matrix/history registry.

Evidence:
- Build/setfile exists: `framework/EAs/QM5_12871_brent-jan-fade/sets/QM5_12871_brent-jan-fade_XBRUSD.DWX_D1_backtest.set`.
- Runtime work item exists but is only pending: `work_items.id=da441d49-ccac-477e-9bab-fa13a44a5e96`, `phase=Q02`, `symbol=XBRUSD.DWX`, `status=pending`, `verdict=NULL`.
- Local MT5 custom history exists only as 2026 files:
  - `D:\QM\mt5\T1\Bases\Custom\history\XBRUSD.DWX\2026.hcc`
  - `D:\QM\mt5\T5\Bases\Custom\history\XBRUSD.DWX\2026.hcc`
- Canonical registry check:
  - `framework/registry/dwx_symbol_matrix.csv` has `XTIUSD.DWX` at line 38, but no `XBRUSD.DWX`.
  - `framework/registry/dwx_symbol_history_ranges.csv` has `XTIUSD.DWX` D1/H1/M15/M5/H4 rows, but no `XBRUSD.DWX`.
  - `framework/registry/tester_defaults.json` contains tester policy only; no `XBRUSD.DWX` symbol entry.
  - `farmctl._p2_history_window_for_symbol("XBRUSD.DWX", "D1", 2017, 2022)` returns `{"skip": true, "reason": "SYMBOL_NO_HISTORY_FOR_PERIOD"}`.

Therefore the 19 XBRUSD cards remain stale for canonical Q02 until `XBRUSD.DWX` is promoted into the DWX symbol matrix and history-range registry with sufficient 2017-2022 D1 history. They remain a priority class after that data/matrix promotion because they are low-frequency commodity calendar/seasonality cards.
