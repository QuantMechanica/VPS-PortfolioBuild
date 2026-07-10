# QM5_13108 XTI Partial-Moment MTSM-S2 Q02 Enqueue

Date: 2026-07-10  
Branch: `agents/board-advisor`

## Outcome

One new structural energy sleeve was carded, built, compiled, and enqueued:

- EA: `QM5_13108_xti-mtsm-s2`.
- Signal: `XTIUSD.DWX` D1 managed time-series momentum using five-day upper
  and lower partial-moment tail states to retain, reverse, or flatten a 30-day
  momentum target.
- Q02 work item: `c95eb757-f320-4187-87dc-c62126b46f31`.
- Handoff: `pending`, unclaimed, `XTIUSD.DWX`, D1.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Magic: `131080000`, slot 0.

No manual MT5 run was launched. At the CPU guard scan, T1/T4/T6/T7/T8 were
actively backtesting and seven paced terminal workers were present. The build
therefore used `deferred_p2_smoke` and handed the setfile to Q02 without
competing with factory automation.

## Source And Mechanization

Primary source: Liu, Zhenya; Lu, Shanglin; and Wang, Shixuan (2021),
"Asymmetry, tail risk and time series momentum," *International Review of
Financial Analysis* 78, 101938,
https://doi.org/10.1016/j.irfa.2021.101938. Complete accepted manuscript:
https://centaur.reading.ac.uk/100824/1/FINANA-D-21-00329-R1.pdf.

The full paper was reviewed. Its MTSM-S2 rule starts with the sign of a
30-trading-day cumulative return, separates the latest five daily returns into
mean squared positive and negative partial moments, and compares those values
with separate recursive 80th-percentile references. Both tails produce flat;
an LPM-only tail produces long; a UPM-only tail produces short; neither tail
retains base momentum.

The paper tests diversified Chinese commodity futures rather than WTI. The
card therefore labels `XTIUSD.DWX` as a carrier port, replaces daily volatility
targeting with the mandatory V5 fixed-dollar risk contract, and bounds the
reference distribution to 252 older no-lookahead observations. These are kill
risks, not hidden equivalence claims. Q02 and later gates are the only evidence.

## Non-Duplicate Decision

Repository dedup was `CLEAN` before atomic EA-ID reservation, and content
search found no MTSM or upper/lower partial-moment implementation. The selected
rule is materially different from:

- WTI 12-month and 9-month return-sign momentum;
- monthly 1/6 dual-moving-average state;
- WTI four-week and 63-day price reversals;
- Donchian/ADX trend, NR7/IDNR4, RSI pullback, and volatility-shock rules;
- WTI calendar, inventory, OPEC, event, roll, carry, ratio, and commodity-FX
  systems.

The new state variable is the joint asymmetric tail map, not another lookback
or threshold variant.

## Build Evidence

- Approved card:
  `strategy-seeds/cards/approved/QM5_13108_xti-mtsm-s2_card.md`.
- Source packet:
  `strategy-seeds/sources/LIU-MTSM-2021/source.md`.
- EA source, binary, setfile, SPEC, and build-time card:
  `framework/EAs/QM5_13108_xti-mtsm-s2/`.
- Build record: `artifacts/qm5_13108_build_result.json`.
- Enqueue record: `artifacts/qm5_13108_q02_enqueue_20260710.json`.

Verification:

- EA-ID allocation: `QM5_13108`, atomic reservation.
- Card schema lint: `PASS`.
- SPEC validation: `PASS`.
- Symbol scope: `SINGLE_SYMBOL_OK`, zero violations.
- Magic resolver: `131080000` present after directory-first registration.
- Strict compile: `PASS`, 0 errors, 0 warnings.
- Build check: `PASS`, 0 failures, 0 warnings.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, Friday close enabled.
- Q02 enqueue: one pending row, zero skipped.

Resolver generation repeated three pre-existing missing-directory warnings for
EA IDs 1001, 1015, and 1016. They are unrelated to QM5_13108 and were not
repaired or normalized in this mission.

## Guardrails

- No `T_Live` file or process action.
- No AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio gate, admission, KPI, or correlation code touched.
- Existing unrelated dirty FTMO/Q08 paths were left untouched.

