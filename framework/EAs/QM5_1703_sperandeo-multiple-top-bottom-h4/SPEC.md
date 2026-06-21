# QM5_1703_sperandeo-multiple-top-bottom-h4 — Strategy Spec

**EA ID:** QM5_1703
**Slug:** `sperandeo-multiple-top-bottom-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

The EA identifies horizontal price zones where at least three distinct pivot highs (Multiple-Top) or pivot lows (Multiple-Bottom) cluster within a tight ATR-bounded range over a 50-bar lookback on H4. A short entry fires on the first H4 bar whose close breaks below the zone bottom by 0.5×ATR, provided the D1 close is below its 50-period SMA (bearish context). A long entry fires on a close breaking above the zone top by 0.5×ATR with D1 close above SMA(50,D1). The profit target is 1.5× the zone width projected from entry; the stop loss is placed beyond the far edge of the rejection zone by 0.5×ATR. Positions are also closed after 30 H4 bars (time stop) or immediately on an opposite-direction zone break.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_k` | 3 | 2–4 | Bars each side required to confirm a pivot high/low |
| `strategy_lookback_bars` | 50 | 30–80 | H4 bars to scan for pivot cluster (Vic-II ch7 spec) |
| `strategy_min_rejections` | 3 | 3–5 | Minimum pivots required inside the zone |
| `strategy_atr_period` | 14 | 10–20 | ATR period for zone-width and SL/TP sizing |
| `strategy_zone_atr_mult` | 0.5 | 0.3–0.8 | Max zone width as fraction of ATR |
| `strategy_spread_atr_mult` | 0.3 | 0.1–0.5 | Skip entry if spread exceeds this fraction of ATR |
| `strategy_break_atr_mult` | 0.5 | 0.3–0.8 | Break confirmation buffer below/above zone edge |
| `strategy_sl_atr_mult` | 0.5 | 0.3–1.0 | Stop loss buffer beyond zone edge |
| `strategy_projection_mult` | 1.5 | 1.0–2.0 | Measured-move TP multiplier (zone width × mult) |
| `strategy_d1_sma_period` | 50 | 20–200 | D1 SMA period for trend-direction filter |
| `strategy_cooldown_bars` | 12 | 6–24 | Min H4 bars between same-direction entries |
| `strategy_time_stop_bars` | 30 | 15–60 | Max H4 bars before forced close |

---

## 3. Symbol Universe

Symbol-agnostic OHLC pattern; registered for all 37 DWX symbols.

**Designed for:**
- `EURUSD.DWX` — representative liquid FX major; Sperandeo pivot patterns well-documented on majors
- `GBPUSD.DWX` — high-volume GBP major
- `USDJPY.DWX` — widely traded JPY major
- `XAUUSD.DWX` — gold CFD; strong structural pivot behaviour
- `NDX.DWX` — Nasdaq 100 index; trending environment produces clear zone clusters
- `WS30.DWX` — Dow 30 index
- `SP500.DWX` — S&P 500 (backtest-only; broker does not route live orders on SP500.DWX)
- `GDAXI.DWX` — DAX 40 index
- `UK100.DWX` — FTSE 100 index
- All other DWX FX crosses and commodity CFDs registered with dedicated magic slots

**Explicitly NOT for:**
- MN1 timeframe — MT5 tester yields 0 bars on MN1 for DWX symbols; this EA is H4-native

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` (trend filter: D1 close vs SMA(50,D1)) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` — entry fires once per closed H4 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10–30 (H4 pivot clusters form infrequently; D1 trend filter further restricts) |
| Typical hold time | 2–8 days (30-bar time stop = ~5 trading days on H4) |
| Expected drawdown profile | Moderate; fixed 1.5R target and tight zone-based SL limit per-trade risk |
| Regime preference | Trending (D1 SMA filter) with structural reversal zones (pivot clustering) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book
**Pointer:** Victor Sperandeo, *Trader Vic II — Principles of Professional Speculation*, John Wiley & Sons 1994, ch. 7 pp. 167–196; ForexFactory Sperandeo/Trader-Vic thread cluster
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1703_sperandeo-multiple-top-bottom-h4.md`

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
| v1 | 2026-06-21 | Initial build from card | ca10d025-c6b1-4516-89ca-87eee35e0736 |
