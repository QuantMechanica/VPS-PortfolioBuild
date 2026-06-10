# QM5_9270_mql5-bos-liq-sweep — Strategy Spec

**EA ID:** QM5_9270
**Slug:** `mql5-bos-liq-sweep`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA identifies confirmed swing highs and lows (5 bars each side). It tracks Break-of-Structure (BOS) direction: a higher swing high establishes bullish BOS; a lower swing low establishes bearish BOS. In bullish BOS state, a long entry fires when the prior closed bar wicked below the current swing low (liquidity sweep) but closed back above it with a bullish body. In bearish BOS state, a short entry fires when the prior bar wicked above the swing high and closed back below it bearish. Entry is at the next bar open with one position per magic. The initial stop is placed at the sweep candle extreme plus the wider of 10 pips or 0.5×ATR(14); the target is 2×R. The trade is closed at the 2R TP, on an opposite-BOS plus opposite sweep signal, or after 36 H1 bars (time stop). A volatility filter rejects signals when ATR(14) is below its 20th percentile over the last 100 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_length` | 5 | 3–10 | Bars each side required to confirm a swing pivot |
| `strategy_atr_period` | 14 | 7–21 | ATR period for stop calculation and volatility filter |
| `strategy_atr_sl_mult` | 0.5 | 0.3–1.0 | ATR multiplier for minimum SL width |
| `strategy_sl_buffer_pips` | 10.0 | 5–20 | Fixed pip buffer added to sweep extreme for SL |
| `strategy_rr_target` | 2.0 | 1.5–3.0 | Reward-to-risk ratio for TP placement |
| `strategy_max_bars_hold` | 36 | 12–72 | Maximum bars to hold before time-stop close |
| `strategy_atr_vol_period` | 100 | 50–200 | Lookback bars for ATR percentile vol filter |
| `strategy_atr_pct_floor` | 20.0 | 10–40 | Percentile floor; signals blocked below this ATR rank |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity FX major; frequent swing structure on H1
- `GBPUSD.DWX` — high-volatility FX major; BOS+sweep setups common in London session
- `XAUUSD.DWX` — gold; strong structural sweeps and clear BOS patterns on H1
- `GDAXI.DWX` — DAX 40 index (ported from card's GER40.DWX — same instrument, canonical DWX name)

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix.csv; canonical name is GDAXI.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | 4–36 hours |
| Expected drawdown profile | Medium frequency; 2R exits keep individual losses bounded at 1R |
| Regime preference | price-action-reversal / liquidity-sweep after structural break |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum/article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 46): Liquidity Sweep on Break of Structure (BoS)", MQL5 Articles, 2025-12-12
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9270_mql5-bos-liq-sweep.md`

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
| v1 | 2026-06-10 | Initial build from card | 69551dc3-1d85-4748-9b11-5db4044b1c54 |
