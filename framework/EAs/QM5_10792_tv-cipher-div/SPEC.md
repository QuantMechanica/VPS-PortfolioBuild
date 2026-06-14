# QM5_10792_tv-cipher-div - Strategy Spec

**EA ID:** QM5_10792
**Slug:** `tv-cipher-div`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source URL in card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades a fixed oscillator reversal/divergence trigger inspired by the TradingView Cipher B card. A long setup requires the oscillator-divergence proxy to turn up, current price to trade above the local SMA, and the configured global trend filter to be bullish. A short setup mirrors the rule with a bearish oscillator-divergence proxy, price below the local SMA, and bearish global trend. Entries use a market order with ATR(14) times 1.5 stop distance and a 2.0R target; optional SMA-cross exit closes a long below the local SMA or a short above it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_mode` | 1 | 0-1 | 0 trades all oscillator reversals; 1 trades the divergence proxy only. |
| `strategy_local_sma_period` | 100 | 50-200 | Local SMA trend filter length from the card test range. |
| `strategy_global_filter_mode` | 1 | 0-2 | 0 off; 1 same-symbol H4 EMA trend; 2 NDX.DWX H4 EMA trend proxy. |
| `strategy_global_proxy_symbol` | NDX.DWX | DWX symbol | Cross-symbol risk proxy used when global filter mode is 2. |
| `strategy_global_tf` | PERIOD_H4 | M5-H4 | Timeframe for the global EMA filter. |
| `strategy_global_ema_period` | 200 | 50-300 | EMA period for the global trend proxy. |
| `strategy_cipher_cci_period` | 20 | 5-50 | CCI period used as fixed Cipher-style oscillator proxy. |
| `strategy_cipher_extreme` | 100.0 | 50-250 | Positive and negative oscillator extreme threshold. |
| `strategy_rsi_period` | 14 | 5-50 | RSI period used in oscillator reversal confirmation. |
| `strategy_rsi_oversold` | 35.0 | 10-50 | Bullish RSI recovery threshold. |
| `strategy_rsi_overbought` | 65.0 | 50-90 | Bearish RSI rollover threshold. |
| `strategy_stoch_k` | 5 | 3-30 | Stochastic K period for oscillator confirmation. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic D period for oscillator confirmation. |
| `strategy_stoch_slow` | 3 | 1-20 | Stochastic slowing value. |
| `strategy_stoch_oversold` | 30.0 | 10-50 | Bullish stochastic cross zone. |
| `strategy_stoch_overbought` | 70.0 | 50-90 | Bearish stochastic cross zone. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.0 | ATR stop multiplier from the card baseline. |
| `strategy_target_rr` | 2.0 | 1.5-3.0 | Fixed reward-to-risk target. |
| `strategy_exit_on_sma_cross` | true | true/false | Enables the card's optional SMA-cross cancel rule. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Listed in the card's primary P2 basket and present in the DWX matrix.
- `GBPUSD.DWX` - Listed in the card's primary P2 basket and present in the DWX matrix.
- `USDJPY.DWX` - Listed in the card's primary P2 basket and present in the DWX matrix.
- `XAUUSD.DWX` - Canonical DWX matrix symbol for the card's `XAUUSD` entry.
- `GDAXI.DWX` - Available DAX custom symbol used for the card's unavailable `GER40.DWX` name.
- `NDX.DWX` - Listed in the card's primary P2 basket and usable as a global risk proxy.
- `WS30.DWX` - Listed in the card's primary P2 basket and present in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in the DWX symbol matrix; mapped to `GDAXI.DWX`.
- `XAUUSD` - Unsuffixed symbol is not registered for backtest; mapped to `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_H4` EMA200 same-symbol by default; optional `NDX.DWX` H4 EMA200 proxy |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday, minutes to hours inferred from M5/M15 fixed SL/TP design |
| Expected drawdown profile | Medium, fixed-risk divergence reversal with ATR-normalized stop |
| Regime preference | Divergence reversal gated by trend filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/iYHnmIQB-Cipher-B-divergencies-for-Crypto-Finandy-support/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10792_tv-cipher-div.md`

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
| v1 | 2026-06-14 | Initial build from card | 430001cd-92d3-4577-8fef-d224a4f3a97a |
