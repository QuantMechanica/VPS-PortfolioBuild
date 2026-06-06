# QM5_10932_grimes-volshock - Strategy Spec

**EA ID:** QM5_10932
**Slug:** grimes-volshock
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates completed D1 bars and looks for an absolute close-to-close return at least 2.0 standard deviations above the prior 20 return sample. The same bar must also have true range at least 1.5 times ATR(20). On the next D1 bar it places a buy-stop above the shock high and a sell-stop below the shock low, both buffered by 0.10 ATR, cancels the opposite pending order after one side fills, moves the stop to breakeven at 1R, targets 1.5R, and exits after 5 D1 bars or when the closed bar moves back through the shock midpoint.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 only | Base timeframe used for the shock and bracket. |
| `strategy_return_std_period` | `20` | `2+` | Number of close-to-close returns used for the shock standard deviation. |
| `strategy_atr_period` | `20` | `2+` | ATR period used for true-range validation and bracket buffers. |
| `strategy_z_threshold` | `2.0` | `>0` | Minimum absolute return z-score for a shock setup. |
| `strategy_tr_atr_mult` | `1.5` | `>0` | Minimum true range as a multiple of ATR(20). |
| `strategy_entry_buffer_atr` | `0.10` | `>=0` | ATR buffer added beyond the shock high or low for stop entries. |
| `strategy_stop_buffer_atr` | `0.10` | `>=0` | ATR buffer beyond the opposite shock extreme for stop loss placement. |
| `strategy_target_r_mult` | `1.50` | `>0` | Take-profit distance in initial risk units. |
| `strategy_breakeven_r` | `1.00` | `>0` | Profit in R before stop moves to breakeven. |
| `strategy_pending_bars` | `2` | `1+` | Number of D1 bars before unfilled bracket orders expire. |
| `strategy_max_hold_bars` | `5` | `1+` | Maximum age of a filled trade in D1 bars. |
| `strategy_trade_cooldown_bars` | `10` | `1+` | Minimum D1 bars after a filled trade before a new bracket is allowed. |
| `strategy_max_stop_atr_mult` | `4.50` | `>0` | Rejects setups whose stop distance exceeds this ATR multiple. |
| `strategy_spread_stop_fraction` | `0.08` | `>0` | Rejects setup if spread is more than this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the card's R3 basket.
- `GBPUSD.DWX` - liquid major FX pair from the card's R3 basket.
- `XAUUSD.DWX` - liquid metals contract from the card's R3 basket.
- `XTIUSD.DWX` - liquid oil contract from the card's R3 basket.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's `GER40.DWX` DAX intent.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | Up to 5 D1 bars after bracket fill |
| Expected drawdown profile | Volatility-expansion breakouts with bounded 1R stop and 1.5R target |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Volatility Clustering", 2014-08-11, https://www.adamhgrimes.com/volatility-clustering/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10932_grimes-volshock.md`

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
| v1 | 2026-06-06 | Initial build from card | 2e5ef374-dff8-42e1-8413-2435f3a4d706 |
