# QM5_10848_tv-mtf-ambush - Strategy Spec

**EA ID:** QM5_10848
**Slug:** `tv-mtf-ambush`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source pointer below)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades long only. On the closed signal bar, SMA(5) must be above SMA(8), and SMA(8) must be above SMA(13). The same bar must touch the SMA(8) ambush zone, defined as the SMA(8) plus or minus 20% of ATR(14), and then print a bullish pin bar, bullish engulfing bar, bullish doji confirmation, or morning-star confirmation. The initial stop is 2% below entry, capped to 3 * ATR(14), the target is the D5 Fibonacci/pivot extension from the prior D1 bar, and open positions trail to prior D-levels plus a 2% safety trail from highest seen price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | MT5 timeframe enum | Signal timeframe; H1 is used by the baseline setfiles. |
| `strategy_sma_fast` | `5` | `1-200` | Fast SMA period in the bullish stack. |
| `strategy_sma_mid` | `8` | `1-200` | Pullback baseline SMA period. |
| `strategy_sma_slow` | `13` | `1-300` | Slow SMA period in the bullish stack. |
| `strategy_atr_period` | `14` | `1-200` | ATR period for ambush tolerance and emergency stop cap. |
| `strategy_ambush_atr_frac` | `0.20` | `0.01-1.00` | Ambush zone half-width as a fraction of ATR. |
| `strategy_initial_stop_pct` | `2.0` | `0.1-10.0` | Percent stop distance below entry before ATR cap. |
| `strategy_emergency_atr_mult` | `3.0` | `0.5-10.0` | Maximum initial stop distance in ATR multiples. |
| `strategy_safety_trail_pct` | `2.0` | `0.1-10.0` | Dynamic trail below highest seen price. |
| `strategy_target_d_level` | `5` | `1-5` | Fibonacci/pivot D-level used as initial take profit. |
| `strategy_doji_body_ratio` | `0.10` | `0.01-0.50` | Maximum doji body as a share of candle range. |
| `strategy_morning_body_ratio` | `0.35` | `0.01-0.75` | Maximum middle-candle body share for morning-star confirmation. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary P2 FX basket member with DWX matrix coverage.
- `GBPUSD.DWX` - card primary P2 FX basket member with DWX matrix coverage.
- `XAUUSD.DWX` - card primary P2 metals basket member with DWX matrix coverage.
- `GDAXI.DWX` - deterministic DAX port because card-stated `GER40.DWX` is not in the DWX matrix.
- `NDX.DWX` - card primary P2 index basket member with DWX matrix coverage.

**Explicitly NOT for:**
- `GER40.DWX` - unavailable in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Previous `D1` OHLC for Fibonacci/pivot D-level target and trailing levels |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Not specified in frontmatter; expected multi-bar trend-pullback hold until D-level target, D-level trail, safety trail, stop, or Friday close |
| Expected drawdown profile | Not specified in frontmatter; fixed-risk long-only pullback continuation with 2%/3ATR capped stop |
| Regime preference | Trend-following pullback continuation |
| Win rate target (qualitative) | Not specified in frontmatter; medium expected from pattern-confirmed trend entries |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy script`
**Pointer:** `https://www.tradingview.com/script/FQVb4qo4/` (`MTF Matrix Strategy`, author `Okeefe06`, accessed 2026-05-22)
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10848_tv-mtf-ambush.md`

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
| v1 | 2026-06-06 | Initial build from card | 44072dca-267b-4d85-b62c-75179638829a |
