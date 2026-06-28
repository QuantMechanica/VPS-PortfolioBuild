# QM5_12759 WTI Roll Relief Q02 Enqueue Evidence

Date: 2026-06-29

## Scope

- Added `QM5_12759_wti-roll-relief` as a new structural WTI commodity sleeve.
- Source lineage: CFTC Office of the Chief Economist paper
  `CFTC-ETF-ROLL-WTI-2014`, "Predatory or Sunshine Trading? Evidence from
  Crude Oil ETF Rolls".
- Runtime data: `XTIUSD.DWX` D1 OHLC and broker calendar only.
- Live safety: no `T_Live`, AutoTrading, portfolio gate, or live manifest
  change.

## Edge

- Long-only post-roll relief sleeve.
- Same-month pressure proof: completed D1 bar during broker trading days 5-9
  must be down at least `strategy_min_pressure_return_pct` and below SMA.
- Entry window: broker trading days 10-14 after prior D1 reclaim above SMA.
- Exits: relief-window end, month change, SMA failure, max hold, Friday close,
  or ATR hard stop.
- Dedup: not `QM5_12736` pressure-window short, not `QM5_12743` CME-expiry
  postroll fade, and not WTI weekday/month, WPSR, OPEC, refinery, hurricane,
  SPR, CAD/oil, XTI/XNG, XAU/XAG, or XNG pullback logic.

## Build Artifacts

- Card: `strategy-seeds/cards/approved/QM5_12759_wti-roll-relief_card.md`
- EA source:
  `framework/EAs/QM5_12759_wti-roll-relief/QM5_12759_wti-roll-relief.mq5`
- Binary:
  `framework/EAs/QM5_12759_wti-roll-relief/QM5_12759_wti-roll-relief.ex5`
- Fixed-risk Q02 setfile:
  `framework/EAs/QM5_12759_wti-roll-relief/sets/QM5_12759_wti-roll-relief_XTIUSD.DWX_D1_backtest.set`
- Build result: `artifacts/qm5_12759_build_result.json`

## Validation

- Card schema lint: PASS.
- SPEC validation: PASS.
- Symbol scope: `SINGLE_SYMBOL_OK`.
- Build guardrails: PASS.
- Compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 16 shared-framework advisory warnings.
- Full registry validator: existing corpus issues remain; no new `QM5_12759`
  formula or magic conflict found by the per-EA compile/build checks.
- `.ex5` SHA-256:
  `6b2d0de933d1a0c2659db8ff3a378201afb9e360ba2462720e1eb44288d8ece1`.
- Setfile build hash:
  `4eae07a7f9a7536f0456ef13810b81bd07e90f843351a1f78390998e81cd4896`.

## Farm Enqueue

- Build task: `b552b9a7-87ae-43e3-b6cb-5c9b630c350e`.
- `record-build`: recorded true, status `done`.
- Q02 work item:

| Field | Value |
|---|---|
| Work item | `e27655b7-739d-4cbb-8d32-f183e91111e6` |
| EA | `QM5_12759` |
| Symbol | `XTIUSD.DWX` |
| Timeframe | `D1` |
| Phase | `Q02` |
| Status at handoff | `pending` |
| Setfile | `QM5_12759_wti-roll-relief_XTIUSD.DWX_D1_backtest.set` |

No manual MT5 backtest was launched in this step. The paced worker fleet owns
Q02 dispatch.
