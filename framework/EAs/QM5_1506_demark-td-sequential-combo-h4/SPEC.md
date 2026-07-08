# QM5_1506_demark-td-sequential-combo-h4 - Strategy Spec

**EA ID:** QM5_1506
**Slug:** `demark-td-sequential-combo-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (ForexFactory DeMark cluster plus cited DeMark/Perl books)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA trades DeMark TD Combo exhaustion reversals on H4 bars. A sell setup requires nine consecutive H4 closes where each close is above the close four bars earlier; a buy setup mirrors that rule below the close four bars earlier. After a valid setup, a Combo countdown counts non-consecutive bars that satisfy all four DeMark Combo inequalities. The trade fires only when the current closed H4 bar is the 13th valid countdown bar and the setup completed within the last 60 H4 bars.

Short entries require a TD Sell Setup plus 13th sell countdown, D1 close below D1 SMA(50), D1 SMA(50) sloping down over five D1 bars, ATR(14) above 0.6 times its 200-bar H4 average, and no entry in the last 30 H4 bars. Long entries mirror the setup/countdown and D1 trend direction. TP1 closes 60% at 1.5 ATR. TP2 is the TDST structural target from the setup phase. The hard stop is the signal-bar true high plus 1 ATR for shorts, mirrored from the true low for longs, with a 2.5 ATR maximum distance cap. Positions time-stop after 24 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_setup_bars` | 9 | 1-20 | TD Setup length. |
| `strategy_setup_compare_lag` | 4 | 1-8 | Close comparison lag for setup and cancellation checks. |
| `strategy_countdown_target` | 13 | 1-20 | Number of valid Combo countdown bars required for entry. |
| `strategy_valid_setup_window` | 60 | 10-120 | Maximum H4 bars between setup completion and countdown completion. |
| `strategy_d1_sma_period` | 50 | 10-200 | D1 macro-bias SMA period. |
| `strategy_d1_slope_bars` | 5 | 1-20 | D1 bars used to confirm SMA slope. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for volatility, stop, and TP1 distance. |
| `strategy_atr_baseline_bars` | 200 | 50-400 | H4 ATR sample count for the volatility floor. |
| `strategy_atr_floor_mult` | 0.60 | 0.10-2.00 | Minimum current ATR as a fraction of average ATR. |
| `strategy_sl_atr_mult` | 1.0 | 0.25-3.00 | ATR buffer beyond the signal true high or true low. |
| `strategy_max_sl_atr_mult` | 2.5 | 1.00-5.00 | Maximum allowed stop distance in ATR units. |
| `strategy_tp1_atr_mult` | 1.5 | 0.50-4.00 | TP1 distance from entry in ATR units. |
| `strategy_tp1_close_fraction` | 0.60 | 0.10-0.90 | Position fraction closed at TP1. |
| `strategy_max_spread_atr_mult` | 0.15 | 0.00-0.50 | Test-safe spread guard; zero-spread DWX bars pass. |
| `strategy_cooldown_bars` | 30 | 0-100 | Minimum H4 bars between entries on the same chart. |
| `strategy_time_stop_bars` | 24 | 1-80 | H4 bars held before time-stop exit. |
| `strategy_min_warmup_bars` | 300 | 100-600 | Required H4 history before signal evaluation. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with deep H4 history.
- `GBPUSD.DWX` - liquid FX major with H4 reversal structure.
- `USDJPY.DWX` - liquid FX major with frequent directional exhaustion swings.
- `AUDUSD.DWX` - liquid FX major and USD-risk proxy.
- `USDCAD.DWX` - liquid FX major with commodity-linked reversal regimes.
- `NDX.DWX` - index CFD where DeMark exhaustion logic is commonly applied.
- `WS30.DWX` - index CFD with H4 trend-extension behavior.
- `GDAXI.DWX` - European index CFD for regional diversification.
- `UK100.DWX` - UK index CFD for regional diversification.
- `XAUUSD.DWX` - metal contract with exhaustion-reversal behavior.
- `XTIUSD.DWX` - energy contract beyond XNG, useful for commodity diversity.

**Explicitly NOT for:**
- Non-DWX symbols - Q02 uses the farm's validated custom-symbol universe.
- `XNGUSD.DWX` - omitted here to add energy diversity beyond the already crowded XNG sleeve.
- Synthetic basket symbols - this EA expects one host symbol's OHLC series, not basket legs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` close and SMA(50) for macro-bias gating |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework default |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 100 before downstream filters; lower after D1 bias, ATR floor, and TDST validation |
| Typical hold time | 1-5 trading days |
| Expected drawdown profile | Bounded single-position reversal risk with fixed structural stop |
| Regime preference | Swing reversal within a higher-timeframe trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum cluster plus named books
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1506_demark-td-sequential-combo-h4.md`
**R1-R4 verdict (Q00):** all PASS in approved card frontmatter

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from approved card | Build task 50e31363-8132-4e43-ad9e-d8d60caf0ac7 |
