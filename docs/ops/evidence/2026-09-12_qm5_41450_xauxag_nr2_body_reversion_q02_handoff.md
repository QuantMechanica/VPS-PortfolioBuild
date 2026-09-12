# QM5_41450 XAU/XAG NR2 Body Reversion — Build And Q02 Handoff

Date: 2026-09-12  
Branch: `agents/board-advisor`

## Outcome

Built and enqueued one new low-frequency market-neutral commodity candidate. `QM5_41450` forms
synchronized XAU/XAG D1 log-ratio closes for the two immediately completed broker weeks, requires
the newest ratio-close range to be strictly narrower than the prior range, and fades the strict
newest-week ratio body with an opposed equal-notional package. It is not a directional gold
system and makes no decorrelation claim before Q09.

Canonical and manual family review found no exact identity. The expected fuzzy relatives are
`QM5_41448` (range expansion plus outer-quartile reversion, body sign ignored) and `QM5_41449`
(range expansion plus body continuation). The contraction state and contrarian body direction
are load-bearing in `QM5_41450`.

## Build Evidence

- EA ID / magics: `QM5_41450`; `414500000` XAU slot 0 and `414500001` XAG slot 1.
- Governed compile: `1af3e3ce-ac8b-453e-89d6-c4c077c7971b`, T5, `COMPILE_OK`.
- Compiler: zero errors, zero warnings; strict build check `PASS`.
- Source SHA-256: `914f7b9ebb4e7d0f36dc77042a426a4443d27e9859f66a80a9adb2c7243691ca`.
- EX5 SHA-256: `b13661d6ae8e7f343dd3142fb17f3c853533c60c1f09f7defed29b55b4756ed6`.
- Reference suite: 6 tests `PASS`.
- Build guardrails: `PASS`; symbol scope: `BASKET_OK`.
- PACER pin audit on the exact generated source: `hit_count=0`, `PASS`.

The governed set generator rewrote the two physical sibling sets with empty strategy-symbol
values. Those values were repaired to the same card-bound `XAUUSD.DWX` host and `XAGUSD.DWX`
companion before intake. The read-only first-Q02 plan then selected only the manifest-bound logical
basket set and passed every fixed-risk and strategy-parameter check.

## Q02 Enqueue

A fresh five-sample whole-host CPU check returned `88.0, 84.7, 89.2, 84.4, 85.5%`; maximum
`89.2%` was below the strict `97.0%` ceiling. `intake-first-q02 --apply` appended exactly one
logical-basket Q02 row:

- work item: `e518cba9-bfd7-43bb-8e9b-5a6459d86726`;
- status at handoff: `pending`;
- logical symbol: `QM5_41450_XAU_XAG_NR2_BODY_RV_D1`;
- logical set SHA-256: `36fcf97147b684b87eb9a3e4a0d7fb84617099f40ab6e9753c57da378cdb2cee`;
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- receipt SHA-256: `9a0356f40a8e277402436824965e8c9e20b697368d9757cd4d6803e88c66ae9d`.

No manual backtest was run. No portfolio gate, portfolio admission, live/deploy manifest,
`T_Live`, AutoTrading, or terminal control was touched.
