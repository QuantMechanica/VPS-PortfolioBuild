# QM5_20132 XNG storage-release live range breakout — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20132_xng-stor-orb`

Strategy ID: `EIA-XNG-STORAGE-INTRADAY-2026_S03`

## Outcome

One new low-frequency energy candidate was carded, registered, built, compiled,
and handed to the paced pipeline. On a standard Thursday, the EA freezes the
completed 09:30 and 10:00 New York XNG M30 bars. It trades at most the first
buffered executable-price escape during 10:30-11:00, uses an opposite-range
structural stop and a fixed 1.50R target, and is flat in the same New York
session.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, correlation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source and non-duplicate boundary

The existing OWNER-approved EIA packet was extended with
`EIA-XNG-STORAGE-INTRADAY-2026_S03`. Its tier-A official sources identify the
Weekly Natural Gas Storage Report and the regular/holiday release schedules.
A fresh governed retrieval request for the three official URLs returned
`DEFERRED:SOURCE_POLICY`; no bypass was attempted and no new webpage claim was
imported. The card relies only on the same-day approved repository packet.

The deterministic dedup check covered 4,189 EA-registry rows and 376 cards,
with no exact duplicate. Its two expected fuzzy neighbors were manually
resolved:

- `QM5_20124_xng-stor-m30` waits for the complete 10:30 release bar and enters
  confirmed continuation at 11:00.
- `QM5_20128_xng-stor-fade` waits for the additional 11:00 reclaim bar and
  fades the failed break at 11:30.
- `QM5_20132_xng-stor-orb` freezes only completed pre-release bars and makes
  its one decision inside the still-forming 10:30 release bar.

`QM5_12567_cum-rsi2-commodity` is also mechanically distinct: it is a D1
cumulative-RSI pullback with a multiday lifecycle. Realized correlation remains
a downstream Q09 and unchanged portfolio-gate question.

## Frozen baseline

- Host: exact `XNGUSD.DWX`, M30, slot 0, magic `201320000`
- Range: completed 09:30 and 10:00 New York bars
- Range-width band: `0.25-1.25 * ATR(20)`
- Break and structural-stop buffer: `0.10 * ATR(20)`
- Maximum trigger overshoot: `0.30 * ATR(20)`
- Target: `1.50R`
- Entry window: 10:30 inclusive to 11:00 exclusive New York
- Exit: 15:55 New York, date change, eight-hour stale guard, or broker SL/TP
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF because the scheduled release is the signal

The first observed trigger persists the New York date before history, news,
spread, geometry, stress, and broker/order gates. A rejection, restart, stop,
or blocked gate cannot retry or reverse that date. There is no parameter sweep.

## Deterministic identity and hashes

- EA registry:
  `20132,xng-stor-orb,EIA-XNG-STORAGE-INTRADAY-2026_S03`
- Magic registry: `20132,xng-stor-orb,0,XNGUSD.DWX,201320000`
- Card SHA-256:
  `9083564FDC9726988276E8795E7E59140990B42F8456344EE517EDF646B11C6C`
- MQ5 SHA-256:
  `1C80B7051FC8B4110B6D92A95911B69032A46877644CC23508FC86572932A390`
- EX5 SHA-256:
  `C9DD6D5B13B4B53E6787D89AB3C7E2610C990397328E6ACFFA0B98FB05EF135A`
- SPEC SHA-256:
  `6695DD48BD81921A5DA074B629A96EC3DCC62561238C272472643EB3715ECA77`
- Setfile SHA-256:
  `A30BD3BC61B24694EA410BCD308490D0BDE9845BE2C4E73E268145049A4DF599`
- Magic registry SHA-256:
  `5B3ACDFF0025ED99EB9E43B8A90EAF2FF264DBE5D805161CF9D5ADB82F2CCF8C`
- Generated resolver SHA-256:
  `74424B38E29360E4BE577E9A11F6706277973B77BC3F7E4409BD5E25F0646F15`

The resolver was generated from the current canonical registry. It retained
the already-registered 20129-20131 rows and added 20132; it was not hand
edited.

## Validation evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- V5 build guardrails: PASS, no findings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
  Compile log:
  `C:/QM/repo/framework/build/compile/20260725_005526/QM5_20132_xng-stor-orb.compile.log`
- Final targeted build check: PASS, 0 failures, 0 warnings.
  Report:
  `D:/QM/reports/framework/21/build_check_20260725_005541.json`

No manual smoke test or pipeline runner was started.

## Paced Q02 handoff

- Build task: `afc4bd12-c23d-4003-87d2-2a8184876944`, status `done`
- Q02 work item: `58d05406-e34a-4764-ba22-ad40b4890c0e`
- Phase/status: `Q02` / `pending`
- Attempt count: 0
- Symbol/timeframe: `XNGUSD.DWX` / M30
- Setfile:
  `QM5_20132_xng-stor-orb_XNGUSD.DWX_M30_backtest.set`
- Initial auto-enqueue: exactly 1 enqueued, 0 skipped
- Idempotent record recheck: existing pending Q02 item retained, no duplicate

At enqueue time `D:/QM/strategy_farm/state/FACTORY_OFF.flag` was present and
the farm reported zero running pipeline MT5 terminals. Smoke was therefore
deferred to paced Q02. The only observed terminal process was the pre-existing
`T_Live` terminal; it was not touched. AutoTrading, the portfolio gate, and the
T_Live manifest were not touched.
