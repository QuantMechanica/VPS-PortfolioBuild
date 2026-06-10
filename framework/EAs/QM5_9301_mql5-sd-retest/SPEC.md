# QM5_9301_mql5-sd-retest — Strategy Spec

**EA ID:** QM5_9301
**Slug:** `mql5-sd-retest`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA detects supply and demand zones on M15 by scanning a lookback window for consolidation clusters (tight high/low range over N bars). A demand zone is validated when price closes impulsively above zone_high + zone_range within the next few bars; a supply zone is validated when price closes impulsively below zone_low - zone_range. Long entry fires when price retests a valid demand zone and the last closed bar closes at or above zone_low. Short entry fires when price retests a valid supply zone and the last closed bar closes at or below zone_high. One trade per zone (NoRetrade). Stop loss is placed below zone_low (long) or above zone_high (short) plus an ATR buffer; take profit is set at 2R. The position is closed early if the opposite zone type is retested while the trade is open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback` | 20 | 5-100 | Bars to scan back for candidate consolidation zones |
| `strategy_consolidation_bars` | 3 | 2-10 | Number of bars forming a single consolidation cluster |
| `strategy_impulse_check_bars` | 3 | 1-10 | Bars after consolidation in which impulse must occur |
| `strategy_impulse_multiplier` | 1.0 | 0.5-3.0 | Impulse threshold as multiple of zone range |
| `strategy_zone_extension_bars` | 50 | 10-200 | Bars before an untested zone expires |
| `strategy_zone_min_pts` | 50 | 10-200 | Minimum zone width in symbol points |
| `strategy_zone_max_pts` | 500 | 100-2000 | Maximum zone width in symbol points |
| `strategy_max_zones` | 8 | 2-8 | Maximum concurrently tracked zones |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop-loss buffer calculation |
| `strategy_atr_sl_mult` | 1.0 | 0.5-3.0 | ATR multiplier applied to stop distance |
| `strategy_tp_rr` | 2.0 | 1.0-5.0 | Take-profit as multiple of stop-loss distance (R:R) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major forex pair; liquid M15 data, supply/demand zones are well-formed
- `GBPUSD.DWX` — major forex pair; volatile, broad supply/demand zones suit M15 retest
- `XAUUSD.DWX` — gold; strong institutional zone respect, frequent impulsive moves
- `GDAXI.DWX` — DAX 40 index (ported from card's GER40.DWX; GDAXI.DWX is the canonical DWX name)

**Explicitly NOT for:**
- `GER40.DWX` — not in dwx_symbol_matrix.csv; GDAXI.DWX is the correct canonical symbol

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~90 |
| Typical hold time | hours to 1-2 days |
| Expected drawdown profile | moderate; fixed 2R TP limits runaway, ATR stop absorbs noise |
| Regime preference | trend / breakout (impulse-validated zones) |
| Win rate target (qualitative) | medium (zone retest frequency balanced by 2R target) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 36): Supply and Demand Trading with Retest and Impulse Model", MQL5 Articles, 2025-10-03
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9301_mql5-sd-retest.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | 6d929682-941f-4ded-a8e5-9aaa7cc0ed53 |
