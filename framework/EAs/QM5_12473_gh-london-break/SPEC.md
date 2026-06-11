# QM5_12473_gh-london-break - Strategy Spec

**EA ID:** QM5_12473
**Slug:** gh-london-break
**Source:** af7930c8-6c65-52d1-9c01-040490b5ad39 (see `strategy-seeds/sources/af7930c8-6c65-52d1-9c01-040490b5ad39/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA builds the pre-London range from M1 bars in the hour before London open. It records the highest high and lowest low of the broker-time threshold hour, then trades only the first breakout in the first 30 minutes after the open. A long is opened when the ask trades above the range high, and a short is opened when the bid trades below the range low, provided the breach is no farther than the card's `risky_stop` distance. The position uses symmetric stop and profit distances of half `risky_stop`, and any remaining position is closed at the broker-time London close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_threshold_start_hour_broker` | 9 | 0-23 | Broker hour used for the pre-London range start. |
| `strategy_threshold_minutes` | 60 | 1-240 | Number of M1 minutes used to build the opening range. |
| `strategy_london_open_hour_broker` | 10 | 0-23 | Broker hour treated as London open for the entry window. |
| `strategy_open_minutes` | 30 | 1-240 | Minutes after the open during which the first breakout can be traded. |
| `strategy_london_close_hour_broker` | 19 | 0-23 | Broker hour used for forced same-session time exit. |
| `strategy_risky_stop_price` | 0.0100 | >0 | Source absolute price interval; SL and TP each use half this distance. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread gate in points; 0 disables the spread cap. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX major with M1 DWX data.
- `GBPUSD.DWX` - Card-listed London-session FX major with M1 DWX data.
- `USDJPY.DWX` - Card-listed liquid FX major with M1 DWX data.
- `XAUUSD.DWX` - Card-listed liquid metal with M1 DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use canonical `.DWX` symbols.
- Symbols outside the registered basket - This build mechanises only the card's R3 P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday, from first 30 minutes after London open until SL/TP or London close. |
| Expected drawdown profile | Fixed-risk intraday breakout losses capped by the half-`risky_stop` stop distance. |
| Regime preference | Session breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

Expected trade frequency from the card: one London-session opportunity per weekday, but only threshold breaches inside the first 30 minutes are traded; conservative estimate 60-120 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Source type:** GitHub repository
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/London%20Breakout%20backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12473_gh-london-break.md`

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
| v1 | 2026-06-11 | Initial build from card | ecf67433-7432-40fa-b5da-eb10813c69de |
