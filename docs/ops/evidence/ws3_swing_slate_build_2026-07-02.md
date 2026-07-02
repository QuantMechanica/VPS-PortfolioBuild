# WS3 Swing Slate Review + Build Evidence - 2026-07-02

## Scope

- Factory state: OFF. No work items enqueued and no smoke terminals started.
- T5 backtest matrix: left untouched.
- Reviewer: Codex independent G0 review of Claude-authored swing cards.
- Card source directory: `D:\QM\strategy_farm\artifacts\cards_review\`
- Approved card directory: `D:\QM\strategy_farm\artifacts\cards_approved\`

## G0 Review Verdicts

| EA | Card | Verdict | Independent G0 rationale |
|---|---|---|---|
| QM5_12914 | xau-weekly-donchian-swing | APPROVED | R1 passes on canonical Donchian/Turtle and Kaufman trend-system sources; R2 is closed-bar deterministic 55/20 Donchian plus ATR trail; R3 XAUUSD.DWX D1 covered; R4 no ML/grid/martingale. Distinct vs QM5_10513 Ichimoku and QM5_12897 XAG Donchian+ADX, with downstream correlation gates expected to judge metal cluster overlap. |
| QM5_12915 | sp500-weekly-oversold-swing | APPROVED | R1 passes on Connors/Alvarez and 200-SMA timing evidence; R2 is deterministic 200-SMA/10-day-low/SMA10-time-stop logic; R3 SP500.DWX D1 covered; R4 no ML/grid/martingale. Distinct vs live QM5_11132 because this is a deeper 10-day-low, 5-15 day swing hold rather than fast cumulative-RSI2. |
| QM5_12916 | chfjpy-carry-trend-swing | APPROVED | R1 passes on peer-reviewed carry and FX momentum evidence; R2 is deterministic SMA200 plus 63-day momentum, SMA10 recovery entry, SMA50 exit; R3 CHFJPY.DWX D1 covered; R4 no ML/grid/martingale. Adds missing carry-trend/JPY-cross exposure. |
| QM5_12917 | xti-driving-season-swing | APPROVED | R1 passes on official EIA seasonality/demand sources; R2 is deterministic calendar-key plus closed-bar SMA/ATR logic; R3 XTIUSD.DWX D1 covered; R4 no ML/grid/martingale. Distinct from existing crude trend/carry, Brent January fade, and generic supertrend sleeves. |
| QM5_12958 | nnfx-hma-wae-swing | APPROVED | R1 sufficient for OWNER-directed NNFX hypothesis test using public deterministic NNFX/HMA/WAE components, not video performance claims; R2 is mechanical HMA baseline plus WAE confirmation with ATR stop/partial and HMA exit; R3 XAUUSD.DWX, GDAXI.DWX, EURJPY.DWX D1 covered; R4 no ML/grid/martingale. Distinct as canonical HMA+WAE fidelity rebuild. |
| QM5_12959 | elder-triple-screen-swing | APPROVED | R1 passes on Elder Triple Screen books; R2 is deterministic D1/H4/H1 alignment with H1 stop-entry/expiry, fixed 2R target, and framework swing primitive stop placement; R3 NDX.DWX and XAUUSD.DWX D1/H4/H1 covered; R4 no ML/grid/martingale. Distinct vs grimes-style pullback sleeves due RSI wave plus H1 stop-entry trigger stack. |
| QM5_12960 | keltner-pullback-swing | APPROVED | R1 passes on Keltner/Kaufman ATR-band literature; R2 is closed-bar deterministic EMA/ATR channel, EMA50 trend gate, band touch/re-entry, ATR stop, opposite-band exit; R3 SP500.DWX and XAGUSD.DWX H4 covered; R4 no ML/grid/martingale. Distinct vs QM5_12897 XAG Donchian trend and QM5_12915 D1 lowest-close SP500 mean reversion. |

Action taken: all seven cards were updated in frontmatter with `g0_status: APPROVED`, independent `g0_approval_reasoning`, and moved to `D:\QM\strategy_farm\artifacts\cards_approved\`.

## Build Pre-flight

EA ID rows exist in `framework/registry/ea_id_registry.csv` for all seven cards:

- `12914,xau-weekly-donchian-swing,...`
- `12915,sp500-weekly-oversold-swing,...`
- `12916,chfjpy-carry-trend-swing,...`
- `12917,xti-driving-season-swing,...`
- `12958,nnfx-hma-wae-swing,...`
- `12959,elder-triple-screen-swing,...`
- `12960,keltner-pullback-swing,...`

Hard build blocker: no exact rows exist in `framework/registry/magic_numbers.csv` for EA IDs `12914`, `12915`, `12916`, `12917`, `12958`, `12959`, or `12960`.

The active build skill requires magic rows for every `(ea_id, symbol_slot)` before implementation and says to stop if they are missing. Because of that pre-flight failure, no EA folders, `.mq5` files, setfiles, or `.ex5` artifacts were created in this pass.

## Build List

Priority order requested by WS3, all pending magic allocation:

| Priority | EA | Target symbols | Build status |
|---:|---|---|---|
| 1 | QM5_12914_xau-weekly-donchian-swing | XAUUSD.DWX | TODO - blocked by missing magic_numbers row |
| 2 | QM5_12915_sp500-weekly-oversold-swing | SP500.DWX | TODO - blocked by missing magic_numbers row |
| 3 | QM5_12958_nnfx-hma-wae-swing | XAUUSD.DWX, GDAXI.DWX, EURJPY.DWX | TODO - blocked by missing magic_numbers rows |
| 4 | QM5_12917_xti-driving-season-swing | XTIUSD.DWX | TODO - blocked by missing magic_numbers row |
| 5 | QM5_12916_chfjpy-carry-trend-swing | CHFJPY.DWX | TODO - blocked by missing magic_numbers row |
| 6 | QM5_12960_keltner-pullback-swing | SP500.DWX, XAGUSD.DWX | TODO - blocked by missing magic_numbers rows |
| 7 | QM5_12959_elder-triple-screen-swing | NDX.DWX, XAUUSD.DWX | TODO - blocked by missing magic_numbers rows |

## Compile / Guardrail Evidence

No compile command was run because no EA was built after the registry pre-flight failure. Required command for each future build remains:

```powershell
python tools/strategy_farm/compile_ea.py --ea-label <label> --force --json --fail-on-error
```

Expected next governance action before build can resume: allocate/activate `magic_numbers.csv` rows for each approved card symbol and regenerate `framework/include/QM/QM_MagicResolver.mqh` via the canonical resolver update flow.

