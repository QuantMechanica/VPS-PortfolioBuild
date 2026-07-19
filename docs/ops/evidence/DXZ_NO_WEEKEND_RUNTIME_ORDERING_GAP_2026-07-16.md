# DXZ No-Weekend Runtime Ordering Gap — 2026-07-16

Status: **BLOCKING_REMEDIATION_REQUIRED / NO RUNTIME MUTATION**

## Decision impact

The OWNER requires no weekend holdings. The currently bound framework and
Top-3 sources do not yet prove that contract under all broker sessions:

1. the framework Friday gate is a fixed day/hour check and has no bound
   holiday or early-close session fallback;
2. in the affected EA wiring, the news filter returns before the mandatory
   Friday-close handler, so a news blackout can suppress the close path.

This is an execution-contract defect, not a statistical weakness. A matching
historical close sequence does not waive it.

## Hash-bound source evidence

| File | SHA-256 | Relevant behavior |
|---|---|---|
| `framework/include/QM/QM_Common.mqh` | `2e49d3395adb45b41c3ac4398b903a0ec32996e0546a016211eb880cd71387aa` | `QM_FrameworkFridayCloseNow` checks Friday and fixed broker hour only; `QM_FrameworkHandleFridayClose` acts on the first later tick |
| `framework/EAs/QM5_10706_tv-mon-ls/QM5_10706_tv-mon-ls.mq5` | `fbb632c78461abc858218207768a53b50fa56a4cb63d1fa237d60de99318c5f6` | Card-specific 18:30 exit plus framework 21:00 fallback; neither binds an early-close calendar |
| `framework/EAs/QM5_10939_grimes-context-pb/QM5_10939_grimes-context-pb.mq5` | `2ad956417a71486a46f5bd4eab079475e1b9a43abbb17ea3db2e455b9d021461` | legacy and two-axis news returns occur before `QM_FrameworkHandleFridayClose` |
| `framework/EAs/QM5_12567_cum-rsi2-commodity/QM5_12567_cum-rsi2-commodity.mq5` | `e40bea7e231ca7366feaa7e4ce0e9f6cc823a39cd6640535a157fe8747bb4025` | two-axis news return occurs before `QM_FrameworkHandleFridayClose` |

All three bound sources default to `PRE30_POST30` plus DXZ news compliance.
For 10706, the live preset's `qm_filter_news_*` keys are not declared inputs and
do not override those source defaults. Therefore the ordering defect is
reachable whenever a news blackout or fail-closed stale calendar overlaps the
mandatory close window. All three also lack the session/holiday fallback.

## Required remediation contract

Before any of these sleeves can qualify under the no-weekend directive:

1. mandatory risk-reducing exits must execute before entry/news filters can
   return; a news gate may block new risk, never a required close;
2. the hard weekly deadline must be the earliest applicable Card exit,
   framework broker-hour-21 fallback, or final tradable pre-weekend session;
3. an OWNER-approved positive safety buffer before an early session close must
   be declared, because an exact session-close timestamp may have no executable
   tick;
4. new entries and pending orders must be forbidden after the effective cutoff;
5. the session/DST/holiday input and chosen cutoff must be logged and included
   in Q08/native identity receipts;
6. tests must cover normal Friday, early-close Friday, a news blackout spanning
   the cutoff, no tick exactly at close, close failure, and retry behavior;
7. Card/source/include closure, EX5 and preset must then be rebuilt and
   requalified on literal `.DWX` data in isolated Base-derived sandboxes.

Until that sequence passes, the valid state is `BLOCKING_REMEDIATION_REQUIRED`,
even if signal identity, PF and all five cost axes pass.

## Safety

This audit only read repository sources and existing evidence. It did not edit
an EA, include, Card, preset, EX5 or MT5 terminal; it did not run MT5 and did
not touch AutoTrading, orders or live risk.
