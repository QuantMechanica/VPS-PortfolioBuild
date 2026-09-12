# QM5_9354_demark-td-dwave-wave4-h4 — Strategy Spec

**EA ID:** QM5_9354
**Slug:** demark-td-dwave-wave4-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Last revised:** 2026-09-12

## 1. Strategy Logic

On closed H4 bars, detect the card's deterministic TD D-Wave Wave-1,
Wave-2, and Wave-3 skeleton. Enter the Wave-4 pullback only after its
38.2%-61.8% retracement, time, overlap, and close-confirmation gates pass.
Long and short paths are mirrored. A skeleton is consumed only after the
framework confirms that its order opened successfully.

The stop is 0.30 ATR(14) beyond the Wave-4 extreme. The target is the card's
Wave-5 projection. Close after 35 observed H4 bars or when a closed bar
invalidates the stored Wave-4 extreme.

## 2. Parameters

The strategy uses the card-locked H4 skeleton windows and ratios: Wave-1
21/13-bar pivots, Wave-2 8-bar confirmation, minimum five bars into Wave-4,
38.2%-61.8% Wave-4 retracement, 0.30 ATR stop buffer, 0.618 Wave-5 target,
and a 35-H4-bar timeout. Framework inputs control risk, news, Friday close,
magic slot, and stress behavior.

## 3. Symbol Universe

EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX, NDX.DWX,
WS30.DWX, GDAXI.DWX, and UK100.DWX, using active magic slots 0-8.

## 4. Timeframe

Base and all strategy data reads are H4. Entry evaluation is new-bar gated;
stops/targets are server-side and management/exits remain callable on ticks.

## 5. Expected Behaviour

Rare Wave-4 entries, at most one entry per detected Wave-3 skeleton. Failed
order submission must not consume a skeleton. News or spread entry blocks must
not suppress management, the 35-bar timeout, or Wave-4 invalidation exits.

## 6. Source Citation

The build is locked to the OWNER-approved runtime card
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_9354_demark-td-dwave-wave4-h4.md`
and its cited DeMark TD D-Wave/Forex Factory lineage.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live risk is not
authorized by this build review. News fail-close uses the V5 two-axis profile
with `qm_news_stale_max_hours` capped at 336; Friday close is enabled.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-12 | Codex rework contract for transactional entry state and exit-first wiring |
