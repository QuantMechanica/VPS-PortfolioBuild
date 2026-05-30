# QM5_10404_et-lbr-1cross - Strategy Spec

**EA ID:** QM5_10404
**Slug:** `et-lbr-1cross`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades the Elite Trader LBR first-cross pullback on M1 index CFDs. It computes MACD(3,10,16); a long regime begins when the MACD signal line crosses above zero after being below zero, then the EA waits for the histogram to pull below zero and turn upward before buying. The short side is symmetric after a signal-line cross below zero, a positive histogram pullback, and a histogram turn downward. Entries use fixed 0.20% stop and target distances, move the stop to breakeven after 0.15% favorable movement, and close any open trade outside the configured liquid-session hours.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 3 | 1-50 | Fast EMA period for the MACD calculation. |
| `strategy_macd_slow` | 10 | fast+1-100 | Slow EMA period for the MACD calculation. |
| `strategy_macd_signal` | 16 | 1-50 | Signal-line period for the MACD calculation. |
| `strategy_stop_pct` | 0.20 | >0 | Fixed stop distance as percent of entry price. |
| `strategy_target_pct` | 0.20 | >0 | Fixed target distance as percent of entry price. |
| `strategy_be_trigger_pct` | 0.15 | >=0 | Favorable movement percent required before moving SL to breakeven. |
| `strategy_use_ema_filter` | false | true/false | Optional EMA9/EMA34 directional filter from the card's ablation notes. |
| `strategy_ema_fast` | 9 | 1-100 | Fast EMA period for the optional trend filter. |
| `strategy_ema_slow` | 34 | fast+1-200 | Slow EMA period for the optional trend filter. |
| `strategy_session_start_hour_broker` | 0 | 0-23 | Broker-time hour when entries are allowed to begin. |
| `strategy_session_end_hour_broker` | 21 | 0-23 | Broker-time hour when entries stop and open trades are flattened. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical S&P 500 custom symbol for the source ES logic; backtest-only per DWX discipline.
- `NDX.DWX` - liquid US large-cap index fallback for live-routable validation.
- `WS30.DWX` - liquid US large-cap index fallback for live-routable validation.
- `GDAXI.DWX` - available DAX custom symbol used in place of the card's unavailable `GER40.DWX` name.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is canonical.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | intraday minutes to hours |
| Expected drawdown profile | High turnover intraday momentum with whipsaw risk in non-trending sessions. |
| Regime preference | trend-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/free-es-trading-strategy-that-works.162375/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10404_et-lbr-1cross.md`

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
| v1 | 2026-05-25 | Initial build from card | ebb08acc-b33f-43b6-a0ba-2669b1d85daa |
