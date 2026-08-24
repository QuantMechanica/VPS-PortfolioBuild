# QM5_38004_codetrading-triple-ema-momentum-scalper — Strategy Spec

**EA ID:** QM5_38004
**Slug:** codetrading-triple-ema-momentum-scalper
**Source:** codetrading-triple-ema-momentum-scalper-official-source
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each closed M5 bar, the EA buys when EMA(8) is above EMA(21), EMA(21) is above EMA(55), the bar low touches or crosses EMA(8), and the bullish close remains above EMA(21). It sells under the mirrored bearish ribbon and pullback conditions. The stop is two pips beyond EMA(55), the take-profit is two times the initial stop distance, and EMA(21) becomes the trailing stop after price reaches +1R. The EA blocks new entries during the GMT rollover window, excessive spread, or a card-defined loss halt; hard daily and total drawdown limits also close existing exposure.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | `PERIOD_M5` | Closed-bar signal and indicator timeframe |
| `strategy_fast_ema_period` | `8` | `5-12` | Fast ribbon and pullback EMA |
| `strategy_med_ema_period` | `21` | `15-30` | Medium ribbon EMA and trailing line |
| `strategy_slow_ema_period` | `55` | `40-80` | Slow ribbon baseline and initial stop anchor |
| `strategy_atr_period` | `14` | card-fixed | ATR period used by the spread filter |
| `strategy_sl_buffer_pips` | `2` | card-fixed | Whole-pip buffer beyond EMA(55) |
| `strategy_tp_rr` | `2.0` | card-fixed | Take-profit multiple of initial risk |
| `strategy_trail_enabled` | `true` | card-fixed | Enables the required EMA(21) trail |
| `strategy_trail_trigger_r` | `1.0` | card-fixed | Profit in R before trailing begins |
| `strategy_rollover_start_hhmm` | `2355` | card-fixed | GMT rollover blackout start |
| `strategy_rollover_end_hhmm` | `5` | card-fixed | GMT rollover blackout end (00:05) |
| `strategy_spread_filter_mult` | `1.8` | card-fixed | Maximum spread as a multiple of closed-bar ATR |
| `strategy_daily_loss_limit_pct` | `2.0` | card-fixed | Daily realized-loss threshold that halts new entries |
| `strategy_daily_drawdown_hard_stop_pct` | `2.5` | card-fixed | Daily equity drawdown threshold that halts and closes |
| `strategy_total_drawdown_stop_pct` | `5.0` | card-fixed | Runtime equity drawdown threshold that halts and closes |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `NDX.DWX` — primary liquid technology-index market suited to fast EMA momentum and pullbacks.
- `WS30.DWX` — liquid US blue-chip index with intraday directional movement.
- `GDAXI.DWX` — liquid European index with active M5 momentum sessions.

**Explicitly NOT for:**

- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — the tester has no canonical DWX data contract for them.
- Range-bound instruments without persistent intraday direction — ribbon alignment is prone to whipsaw in that regime.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the M5 tester chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Expected trade frequency | `80-160 high-conviction trades per year` |
| Typical hold time | Not specified in card frontmatter; the card defines an intraday M5 scalper |
| Expected drawdown profile | `12%` in frontmatter; separate card controls halt entries at 2.0% daily realized loss and close at 2.5% daily / 5.0% total drawdown |
| Regime preference | EMA-aligned intraday trend and momentum |
| Win rate target (qualitative) | No validated target; source performance claims are not pipeline evidence |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-triple-ema-momentum-scalper-official-source`  
**Source type:** video  
**Pointer:** CodeTrading (2021), *Simple EMA Scalping Trading Strategy Backtest In Python*, YouTube  
**R1-R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_38004_codetrading-triple-ema-momentum-scalper.md`

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
| v1 | 2026-08-24 | Initial build from card | 2ed36fc6-61c9-406a-a6f2-6e7c71df746b |
