# QM5_10359_et-gap-fade - Strategy Spec

**EA ID:** QM5_10359
**Slug:** et-gap-fade
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see approved strategy card)
**Author of this spec:** Codex / Claude
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

This EA trades an opening-gap fade on M5 index bars. On the first completed primary-session bar, it compares the session open with the previous daily close and requires the absolute gap to be at least 0.6% of the previous close. If the session opens above the previous day's high, it places a sell stop through the first-bar low; if the session opens below the previous day's low, it places a buy stop through the first-bar high. The take profit is one opening-gap unit from entry, the protective stop is 1.25 gap units, and any still-open position is closed after 15 M5 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_gap_percent | 0.006 | 0.004-0.010 | Minimum opening gap as a fraction of previous close. |
| strategy_inactive_stop_bars | 15 | 10-30 | Maximum holding time in M5 bars before strategy exit. |
| strategy_stop_gap_mult | 1.25 | 1.0-2.0 | Protective stop distance in opening-gap units. |
| strategy_first_range_atr_max | 0.8 | >0 | Skips first bars wider than this multiple of ATR(14). |
| strategy_atr_period | 14 | >=1 | ATR period used for the first-bar range filter. |
| strategy_us_session_open_hhmm | 1630 | broker HHMM | Broker-time open used for SP500, NDX, and WS30. |
| strategy_eu_session_open_hhmm | 1000 | broker HHMM | Broker-time open used for GDAXI. |
| strategy_entry_window_minutes | 10 | >=0 | Time window after session open in which first-bar setup is allowed. |
| strategy_min_stop_spreads | 4 | >=1 | Minimum stop distance measured in current spreads. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index proxy explicitly named in R3; backtest-only per platform caveat.
- NDX.DWX - Nasdaq 100 index proxy matching the source's Nasdaq futures origin.
- WS30.DWX - Dow 30 liquid US index CFD in the approved R3 basket.
- GDAXI.DWX - Matrix-valid DAX custom symbol used as the available port for the card's GDAXI.DWX basket item.

**Explicitly NOT for:**
- GER40.DWX - Card-stated DAX name is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols for this platform.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | PERIOD_D1 previous close/high/low |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 (card frontmatter `expected_trades_per_year_per_symbol`; the prior-day H/L containment gate is stricter than the source's plain 0.6%-gap count, so qualifying days are rare - see card `expected_trade_frequency`) |
| Typical hold time | Up to 15 M5 bars after entry. |
| Expected drawdown profile | Mean-reversion losses cluster on trend-day continuation after large gaps. |
| Regime preference | Mean-revert / opening-gap fade. |
| Win rate target (qualitative) | Medium-high; source claim was 62.04% profitable (source's own backtest lacked the prior-day H/L gate this V5 build enforces). |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** WarEagle / Kirk, "Fading The Opening Gap", Elite Trader, 2002-01-08, https://www.elitetrader.com/et/threads/fading-the-opening-gap.3473/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10359_et-gap-fade.md`

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
| v1 | 2026-06-05 | Initial build from card | 8f2cd142-8faa-4228-89ab-b384696b6640 |
| v2 | 2026-07-23 | Rebuild-in-place: resolved build_check EA_FRAMEWORK_RAW_SERIES_CALL by tagging the D1/M5 OHLC reads `// perf-allowed` (bespoke gap-fade structure); corrected § 5 trades/year/symbol from a stray 45 to the card frontmatter's authoritative 6; fixed § 3 NOT-for row (GER40.DWX, not GDAXI.DWX) | 8f2cd142-8faa-4228-89ab-b384696b6640 |
