# QM5_11418_nordstrom-abc-fib-reversal-h1 - Strategy Spec

**EA ID:** QM5_11418
**Slug:** nordstrom-abc-fib-reversal-h1
**Source:** ce671b89-6c69-5b90-8af7-071cbd395e3c
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA counts the last 20 closed D1 candle bodies and trades only when at least 12 bodies point in the same direction. In a D1 downtrend, it scans H1 bars for an ABC corrective rally using confirmed HIP/LOP swing points, requires the latest C high to reach the 1.279 Fibonacci extension of the A-to-B leg, then places a sell-stop at the open of the latest green H1 candle in the extension zone. In a D1 uptrend it mirrors the structure, looking for a descending correction and placing a buy-stop at the open of the latest red H1 candle in the lower extension zone. Stops sit beyond C and the nearest 10-pip extension round number with a 5-pip buffer, targets use the A swing bar open rounded to the nearest 10-pip level, and trades must satisfy at least 2:1 reward-to-risk with an 80-pip stop cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_d1_lookback_bars | 20 | 15-30 | Number of closed D1 bars used for macro body-count trend. |
| strategy_d1_majority_pct | 60.0 | 50.0-80.0 | Required same-colour body majority for D1 trend confirmation. |
| strategy_swing_scan_bars | 96 | 24-240 | H1 closed-bar window scanned for HIP/LOP swing structure. |
| strategy_min_swing_pips | 5.0 | 3.0-10.0 | Minimum local swing prominence used to filter small H1 pivots. |
| strategy_fib_zone_low_mult | 1.279 | 1.0-1.618 | Lower Fibonacci extension bound for setup activation. |
| strategy_fib_zone_high_mult | 1.618 | 1.272-2.0 | Upper Fibonacci extension reference for stop placement. |
| strategy_sl_buffer_pips | 5.0 | 0.0-20.0 | Extra buffer beyond C/round-number stop reference. |
| strategy_max_sl_pips | 80.0 | 20.0-120.0 | Maximum allowed stop distance for P2. |
| strategy_min_rr | 2.0 | 1.0-4.0 | Minimum reward-to-risk before a pending entry is submitted. |
| strategy_spread_cap_pips | 20.0 | 0.0-30.0 | Maximum current bid/ask spread allowed for entry evaluation. |
| strategy_pending_bars | 1 | 1-6 | H1 bars before an unfilled stop order expires. |
| strategy_c_max_age_bars | 12 | 2-24 | Maximum age of the confirmed C swing accepted for a setup. |

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - Nordstrom's example pair and a liquid DWX FX major.
- GBPJPY.DWX - Card-listed GBP cross with H1 and D1 DWX data available.
- EURUSD.DWX - Card-listed liquid FX major with H1 and D1 DWX data available.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the card's R3 universe is FX H1 + D1 and names only FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 body-count trend filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | H1 swing reversal trades, usually hours to a few days |
| Expected drawdown profile | Moderate, capped by fixed per-trade risk and 80-pip stop cap |
| Regime preference | Macro trend with corrective counter-trend exhaustion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ce671b89-6c69-5b90-8af7-071cbd395e3c
**Source type:** book
**Pointer:** Johan Nordstrom (TradingWalk), Winning Trading Strategy (2015), local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\313229969-WINNING-TRADING-STRATEGY-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11418_nordstrom-abc-fib-reversal-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 0756c784-7cc6-4e89-a571-9572b584b2ef |
