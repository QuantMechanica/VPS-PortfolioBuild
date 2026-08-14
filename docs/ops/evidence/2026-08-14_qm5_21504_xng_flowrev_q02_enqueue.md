# QM5_21504 XNG Flow-Reversal Q02 Enqueue

Date: 2026-08-14

Branch: `agents/board-advisor`

Owner: Codex

## Edge built

- EA: `QM5_21504_xng-flowrev`
- Strategy ID: `ZHAO-ST-MOMREV-2026_XNG_S03`
- Symbol/timeframe: `XNGUSD.DWX`, D1
- Signal: at the framework broker-week transition, fade the latest completed
  five-D1 return only when the same five bars' tick-volume sum ranks at or
  above 75% of 40 earlier non-overlapping five-bar sums.
- Exit: frozen `2.5 * ATR(14,D1)` hard stop, five completed-D1-bar time stop,
  and framework Friday close; no take-profit or position modification.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Source and porting boundary

The source is Zhao, Ding, Yu, and Kang (2026), "Momentum and Reversal on the
Short-Term Horizon: Evidence from Commodity Markets," SSRN 6425598, DOI
`10.2139/ssrn.6425598`.

The governed source packet preserves the attributable URL/DOI, metadata,
accessible abstract/methodology summaries, retrieval status, and the porting
gap. Deterministic full-text retrieval returned `DEFERRED:SOURCE_POLICY`; no
access-control workaround was attempted. The paper's investor-position-derived
speculative-flow component is unavailable at runtime. Native MT5 tick volume
is therefore an explicit falsifiable proxy, not a claimed replication.

R1-R4 are recorded PASS on the approved card: durable single-source lineage,
mechanical rules, native D1 close/tick-volume availability, and no ML or
PnL-dependent adaptation.

## Non-duplicate boundary

- `QM5_12567_cum-rsi2-commodity` is a long-only cumulative-RSI pullback with a
  slow trend filter. This EA is symmetric, weekly, raw-return based, and gated
  by non-overlapping tick-volume rank.
- `QM5_13102_xng-1w-rev-vol` requires a minimum five-day shock and elevated
  realized-volatility percentile, then allows a neutral-band exit. This EA has
  no shock-size threshold, realized-volatility state, or neutral exit.
- XNG event, calendar, carry, trend, expiry, and relative-value sleeves use a
  different state object or clock.

Dedup verdict:
`CLEAN_XNG_WEEKLY_TICK_VOLUME_CONDITIONED_REVERSAL_AFTER_FAMILY_REVIEW`.
The related `QM5_13102` Q04 failure remains adverse evidence and was not
treated as validation.

## Artifacts

- Card: `strategy-seeds/cards/QM5_21504_xng-flowrev_card.md`
- Source packet:
  `strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`
- G0 decision: `decisions/2026-08-14_qm5_21504_xng_flowrev_g0.md`
- EA: `framework/EAs/QM5_21504_xng-flowrev/QM5_21504_xng-flowrev.mq5`
- EX5: `framework/EAs/QM5_21504_xng-flowrev/QM5_21504_xng-flowrev.ex5`
- SPEC: `framework/EAs/QM5_21504_xng-flowrev/SPEC.md`
- Q02 setfile:
  `framework/EAs/QM5_21504_xng-flowrev/sets/QM5_21504_xng-flowrev_XNGUSD.DWX_D1_backtest.set`
- Build record: `artifacts/qm5_21504_build_result.json`

Registry allocation:

- EA ID: `21504,xng-flowrev,ZHAO-ST-MOMREV-2026_XNG_S03`
- Magic: slot 0, `XNGUSD.DWX`, `215040000`

## Q01 validation

- Card schema lint: PASS; no ML hits or missing sections.
- SPEC schema: PASS, 1/1.
- Reference arithmetic tests: PASS, 5/5, including exact 75% threshold,
  ties, non-overlap, and exact history length.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`.
- Build guardrails: PASS.
- Compile command:
  `python tools/strategy_farm/compile_ea.py --ea-label QM5_21504_xng-flowrev --force --json --fail-on-error`
  - Result: COMPILED, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260814_025900\QM5_21504_xng-flowrev.compile.log`
  - EX5 size: 377854 bytes.
- Framework check:
  `framework/scripts/build_check.ps1 -EALabel QM5_21504_xng-flowrev -Strict -SkipCompile`
  - Result: PASS, 0 failures, 0 warnings.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260814_025929.json`.
- EX5 SHA-256:
  `8F70765B45403F7B0096D5106CCD2201AFF9413D36C3F4980EF023E20CA8F16C`.

## Q02 queue

The paced fleet's never-tested sweep materialized the row when the fresh EX5
appeared. The row was read back before handoff; no duplicate enqueue was made.

- Work item: `3231be16-d309-46c8-945f-d3dc30d03136`
- Phase/kind: `Q02` / `backtest`
- Symbol/timeframe: `XNGUSD.DWX` / D1
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_21504_xng-flowrev\sets\QM5_21504_xng-flowrev_XNGUSD.DWX_D1_backtest.set`
- Status at verification: `pending`, attempt count 0, unclaimed.
- Created UTC: `2026-08-14T02:52:58+00:00`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`

The pre-handoff slot scan at `2026-08-14T03:03:07+00:00` showed two active
factory terminals (`T4`, `T7`) out of ten and five total `terminal64`
processes including non-factory terminals. The backtest CPU ceiling was not
hit. No manual tester or smoke run was launched; the paced fleet owns Q02.

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live` file, deploy manifest,
portfolio gate, portfolio admission, or portfolio KPI file was touched.
