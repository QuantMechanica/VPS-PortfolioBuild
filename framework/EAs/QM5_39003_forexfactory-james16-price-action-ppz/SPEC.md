# QM5_39003_forexfactory-james16-price-action-ppz — Strategy Spec

**EA ID:** QM5_39003
**Slug:** `forexfactory-james16-price-action-ppz`
**Source:** `forexfactory-james16-price-action-ppz-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each completed D1 bar, the EA treats the lowest low and highest high of the preceding 20 bars as the card's otherwise undefined PPZ support and resistance levels. It buys a bullish pinbar whose lower wick is at least 65% of its range, whose body is at most 25% of its range, whose low is within 0.5 ATR(14) of PPZ support, and whose close is above EMA(21); the short rule is the exact inverse at PPZ resistance.

The server-side stop is two pips beyond the pinbar tail and the deterministic target is 2.5R. While a position is open, the stop can only improve and trails the rolling 20-bar structural low or high; the framework also enforces Friday close and entry-only news filtering. The card does not define how to choose a "next institutional PPZ" or a break-even trigger, so no unquantified level-selection or break-even rule is added.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpPPZLookback` | 20 | 10–50 | Number of preceding D1 bars used to identify PPZ support/resistance and the rolling structural trail. |
| `InpTrendEMA` | 21 | 14–34 | D1 EMA period used for trend alignment. |
| `strategy_atr_period` | 14 | card-fixed | D1 ATR period used for PPZ tolerance and the spread filter. |
| `strategy_ppz_zone_atr_fraction` | 0.50 | card-fixed | Maximum distance between the pinbar tail and PPZ level, in ATR units. |
| `strategy_pinbar_wick_fraction` | 0.65 | card-fixed | Minimum dominant-wick share of total candle range. |
| `strategy_pinbar_body_fraction` | 0.25 | card-fixed | Maximum real-body share of total candle range. |
| `strategy_spread_atr_multiplier` | 1.80 | card-fixed | Blocks a genuinely positive spread wider than this multiple of ATR; zero modeled spread remains valid. |
| `strategy_sl_buffer_pips` | 2 | card-fixed | Whole-pip buffer beyond the pinbar tail and trailing structure. |
| `strategy_reward_risk` | 2.50 | card-fixed | Take-profit distance as a multiple of initial risk. |
| `strategy_slippage_tolerance_ticks` | 3.00 | card-fixed | Maximum market-order deviation in trade ticks, converted to MT5 points before framework entry. |
| `strategy_max_open_positions` | 1 | card-fixed | Maximum concurrent positions for the active EA magic. |
| `strategy_daily_entry_loss_limit_pct` | 2.00 | card-fixed | Blocks new entries after account realized loss reaches 2% of reconstructed day-start balance. |
| `strategy_daily_drawdown_stop_pct` | 2.50 | card-fixed | Closes exposure and blocks entries at 2.5% daily equity drawdown. |
| `strategy_total_drawdown_stop_pct` | 5.00 | card-fixed | Closes exposure and blocks entries at 5% drawdown from the EA session's initial equity. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — the card's primary liquid FX-major baseline.
- `GBPUSD.DWX` — the card explicitly ports the same D1 PPZ-rejection mechanic to this liquid FX major.
- `XAUUSD.DWX` — the card explicitly includes gold for its liquid D1 level-rejection behaviour.

**Explicitly NOT for:**
- All other DWX symbols — the approved card names only the three symbols above, so the build does not expand beyond its authorized universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (D1 setfile/chart) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 (`expected_trades_per_year_per_symbol`) |
| Expected trade frequency | 80–160 high-conviction trades per year (card frontmatter claim) |
| Typical hold time | Not specified in the approved card; bounded by SL, 2.5R TP, rolling structure trail, and Friday close. |
| Expected drawdown profile | 18% conservative prior (`expected_dd_pct`); the source's lower drawdown claim is not treated as evidence. |
| Regime preference | Trend-aligned PPZ rejection combining the card's trend-following and mean-reversion concepts. |
| Win rate target (qualitative) | Not independently evidenced at G0; source performance claims are not gate evidence. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-james16-price-action-ppz-official-source`
**Source type:** `forum`
**Pointer:** `James16 (2005–2024), All Things Price Action, Forex Factory (>30M views)`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_39003_forexfactory-james16-price-action-ppz.md`

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
| v1 | 2026-08-24 | Initial build from card | ba2adc36-49f2-414d-8e59-ff0e756137ad |
