# Codex Failed EA V2 Rework - 2026-06-02

Single-pass router cycle task set:

- `f533c3ae-c9a5-4554-931d-424b3726a8f1` - QM5_10627
- `ea1fd06d-46c8-4476-b4f3-2fecd05e1de6` - QM5_10440
- `e8f0ddba-577c-4a70-94cf-42d92921b0e0` - QM5_10513
- `57ceb773-b51a-471e-b47a-a8e2a812126a` - QM5_10260
- `affbb364-a7d6-44bd-afc2-fe37ed890fd9` - QM5_10069

## Shared Finding

The only concrete EA/runtime defect found in the inspected failure evidence was a framework news-loader allocation hazard:

- `QM_NewsFilter.mqh:341-343` resized `g_qm_news_events` and then assigned `g_qm_news_events[n]` without checking whether `ArrayResize` succeeded.
- The failed QM5_10627 Q03 tester log shows `VirtualAlloc failed in large allocator` followed by `array out of range in 'QM_NewsFilter.mqh' (343,21)` and `OnInit critical error`.
- The patch now checks `ArrayResize(g_qm_news_events, n + 1, 1024) < n + 1` and returns `false` before assignment.

This preserves the mandatory central news path; no EA was changed to disable news blackout.

## V2 Artifacts

| Source EA | V2 source | Compile result |
| --- | --- | --- |
| QM5_10627_tq-spy-zscore | `C:/QM/repo/framework/EAs/QM5_10627_tq-spy-zscore_v2/QM5_10627_tq-spy-zscore_v2.mq5` | `COMPILED`, 0 errors, 0 warnings |
| QM5_10440_mql5-ohlc-mtf | `C:/QM/repo/framework/EAs/QM5_10440_mql5-ohlc-mtf_v2/QM5_10440_mql5-ohlc-mtf_v2.mq5` | `COMPILED`, 0 errors, 0 warnings |
| QM5_10513_mql5-ichimoku | `C:/QM/repo/framework/EAs/QM5_10513_mql5-ichimoku_v2/QM5_10513_mql5-ichimoku_v2.mq5` | `COMPILED`, 0 errors, 0 warnings |
| QM5_10260_cieslak-fomc-cycle-idx | `C:/QM/repo/framework/EAs/QM5_10260_cieslak-fomc-cycle-idx_v2/QM5_10260_cieslak-fomc-cycle-idx_v2.mq5` | `COMPILED`, 0 errors, 0 warnings |
| QM5_10069_mql5-hs-rev | `C:/QM/repo/framework/EAs/QM5_10069_mql5-hs-rev_v2/QM5_10069_mql5-hs-rev_v2.mq5` | `COMPILED`, 0 errors, 0 warnings |

Structured compile result paths:

- `D:/QM/reports/compile/QM5_10627_tq-spy-zscore_v2/result.json`
- `D:/QM/reports/compile/QM5_10440_mql5-ohlc-mtf_v2/result.json`
- `D:/QM/reports/compile/QM5_10513_mql5-ichimoku_v2/result.json`
- `D:/QM/reports/compile/QM5_10260_cieslak-fomc-cycle-idx_v2/result.json`
- `D:/QM/reports/compile/QM5_10069_mql5-hs-rev_v2/result.json`

## Evidence Limits

No MT5 backtest/smoke run was started by this Codex cycle. This was intentional:

- Hard rule: do not start `terminal64.exe` manually.
- Hard rule: do not interrupt active T1-T10 backtests. At inspection time, QM5_10627 Q08 work item `daa8ad07-9871-4e02-891c-418ab3e51299` was active on T2, and QM5_10440 Q08 work item `43e02b08-7b96-4bd1-ac3e-78410839b06c` was active on T7.

The Q07 invalid-PF evidence for QM5_10513 and QM5_10627 included terminal/history/report failures such as `NO_HISTORY`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`, and `history synchronization error`. Those are not strategy-body defects. The v2 compile artifacts are ready for review, but pipeline verdicts must come from fresh Q-phase evidence after review/enqueue.

## Working Tree Notes

Changes made in `C:/QM/repo`:

- Modified: `framework/include/QM/QM_NewsFilter.mqh`
- Added: five `_v2` EA directories listed above
- Added: this artifact

Existing unrelated dirty files/directories in `C:/QM/repo` were not reverted or modified.
