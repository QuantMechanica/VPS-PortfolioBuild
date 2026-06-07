# QM5_11183_ft005-vol-sma — Strategy Spec

**EA ID:** QM5_11183
**Slug:** ft005-vol-sma
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades long-only M5 reversal entries after a high-volume selloff below SMA(40). On each closed M5 bar it requires tick volume above four times the rolling 150-bar mean, close below SMA(40), stochastic D above stochastic K, RSI(14) above 26, stochastic D above 1, and normalized Fisher RSI below 5. It exits through the source RSI/MACD/minus-DI branch when RSI crosses above 74 while MACD main is below zero and minus-DI is above 4; it also applies the source ROI ladder as a profit-taking fallback.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `buy_volumeAVG` | 150 | `>=1` | Rolling closed-bar tick-volume mean window. |
| `buy_volume_spike_mult` | 4.0 | `>0` | Current closed-bar volume must exceed mean volume by this multiple. |
| `buy_rsi` | 26.0 | `0-100` | Minimum RSI(14) for long entry. |
| `buy_fastd` | 1.0 | `0-100` | Minimum stochastic D for long entry. |
| `buy_fishRsiNorma` | 5.0 | `0-100` | Maximum normalized Fisher RSI for long entry. |
| `strategy_sma_period` | 40 | `>=1` | SMA period for the discount filter. |
| `strategy_rsi_period` | 14 | `>=1` | RSI period for Fisher RSI, entry, and exit. |
| `strategy_stoch_k` | 5 | `>=1` | Stochastic K period. |
| `strategy_stoch_d` | 3 | `>=1` | Stochastic D period. |
| `strategy_stoch_slow` | 1 | `>=1` | Stochastic slowing period; `1` = STOCHF fast stochastic per the card. |
| `strategy_macd_fast` | 12 | `>=1` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | `> fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | `>=1` | MACD signal period. |
| `strategy_di_period` | 14 | `>=1` | ADX/DI period for minus-DI exit branch. |
| `sell_rsi` | 74.0 | `0-100` | RSI cross-above threshold for source exit. |
| `sell_minusDI` | 4.0 | `>=0` | Minimum minus-DI for source exit. |
| `strategy_stop_loss_pct` | 10.0 | `>0` | Source stoploss percentage converted to V5 risk-sized SL distance. |
| `strategy_max_spread_points` | 0 | `>=0` | Optional spread cap in points; `0` leaves the unspecified card threshold disabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid DWX forex pair with tick volume available for the volume-spike filter.
- `GBPUSD.DWX` — liquid DWX forex pair with tick volume available for the volume-spike filter.
- `USDJPY.DWX` — liquid DWX forex pair with tick volume available for the volume-spike filter.
- `XAUUSD.DWX` — liquid DWX metals symbol with tick volume available for the volume-spike filter.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — the build only registers canonical DWX symbols with available tester data.
- Symbols with missing or zero tick volume — the entry guard rejects them because the source edge is volume-sensitive.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the skeleton OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | README source table reports average duration `156.2` minutes. |
| Expected drawdown profile | Medium risk; card marks expected drawdown percentage as TBD. |
| Regime preference | M5 volume-spike mean reversion below SMA discount, scalping profile, news blackout. |
| Win rate target (qualitative) | Medium; card leaves PF and win-rate target TBD. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** public GitHub strategy repository
**Pointer:** Gerald Lonlas / freqtrade community, `Strategy005.py`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy005.py
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11183_ft005-vol-sma.md`

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
| v1 | 2026-06-07 | Initial build from card | 85c62ac2-39d7-43ba-8e86-e4f016c016e9 |
