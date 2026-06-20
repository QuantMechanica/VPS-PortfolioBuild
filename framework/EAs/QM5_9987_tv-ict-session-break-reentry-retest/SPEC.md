# QM5_9987_tv-ict-session-break-reentry-retest - Strategy Spec

**EA ID:** QM5_9987
**Slug:** `tv-ict-session-break-reentry-retest`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA builds a broker-time session range on M15 bars for the enabled Asia, London, and NY-AM windows. If a closed bar breaks above the active session high, then later closes back inside the range and waits below that level for the configured number of bars, a retest of the high enters short at the next bar's market price. The long side is symmetric after a break below the session low, reentry above the low, wait, and retest of the low. Exits are the fixed pips-from-fill stop and take-profit, plus a market close after the session end buffer if the trade is still open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trade_asia` | `true` | `true/false` | Enable the Asia broker-time session. |
| `strategy_trade_london` | `true` | `true/false` | Enable the London broker-time session. |
| `strategy_trade_nyam` | `true` | `true/false` | Enable the NY-AM broker-time session. |
| `strategy_asia_start_min` | `0` | `0-1439` | Asia session start minute of broker day. |
| `strategy_asia_end_min` | `420` | `0-1439` | Asia session end minute of broker day. |
| `strategy_london_start_min` | `480` | `0-1439` | London session start minute of broker day. |
| `strategy_london_end_min` | `720` | `0-1439` | London session end minute of broker day. |
| `strategy_nyam_start_min` | `810` | `0-1439` | NY-AM session start minute of broker day. |
| `strategy_nyam_end_min` | `1020` | `0-1439` | NY-AM session end minute of broker day. |
| `strategy_wait_bars` | `2` | `0-20` | Closed M15 bars required after reentry before arming the retest. |
| `strategy_sl_pips` | `15` | `1-500` | Stop-loss distance from the market entry price. |
| `strategy_tp_pips` | `30` | `1-1000` | Take-profit distance from the market entry price. |
| `strategy_session_end_buffer_bars` | `2` | `0-20` | M15 bars after session end before forcing a strategy close. |
| `strategy_spread_filter_mult` | `0.30` | `0.0-1.0` | Blocks only non-zero modeled spreads wider than this multiple of TP distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with M15 session liquidity.
- `GBPUSD.DWX` - card-listed FX major with London and NY-AM session liquidity.
- `USDJPY.DWX` - card-listed FX major with Asia and NY-AM session liquidity.
- `AUDUSD.DWX` - card-listed FX major with Asia and London session liquidity.
- `XAUUSD.DWX` - card-listed metal with NY-AM session liquidity.
- `NDX.DWX` - card-listed US index, live-tradable DWX equivalent.
- `WS30.DWX` - card-listed US index, live-tradable DWX equivalent.
- `SP500.DWX` - card-listed supplementary S&P 500 backtest-only custom symbol.

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX symbol matrix; `SP500.DWX` is the canonical S&P 500 custom symbol.
- `SPY.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, from retest entry until fixed SL/TP or session end plus two M15 bars. |
| Expected drawdown profile | Bounded per-trade pips-from-fill stop; no pyramiding. |
| Regime preference | Session liquidity sweep / false-break retest. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/7IFb4Zx7/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9987_tv-ict-session-break-reentry-retest.md`

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
| v1 | 2026-06-20 | Initial build from card | 4e0cd9f0-e6a1-41c6-ad08-30f642463c13 |
