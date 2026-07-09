

---
ea_id: QM5_13101
slug: xng-1w-mom-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XNG_S01
source_id: ZHAO-ST-MOMREV-2026
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. SSRN, 2026."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. DOI 10.2139/ssrn.6425598."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598"
    quality_tier: B
    role: primary
  - type: official_market_reference
    citation: "U.S. Energy Information Administration. Natural Gas Explained: Factors affecting natural gas prices."
    location: "https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/ZHAO-ST-MOMREV-2026]]"
strategy_type_flags: [vol-regime-gate, signal-reversal-exit, atr-hard-stop, time-stop, friday-close-flatten, symmetric-long-short]
markets: [XNGUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13101_XNG_1W_MOM_VOL_D1
period: D1
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 20.0
expected_trades_per_year_per_symbol: 8
expected_trade_frequency: "Weekly-gated natural gas D1 short-term momentum with low-volatility filter; estimate 6-14 entries/year."
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-10: R1 PASS named-author academic working paper with DOI plus official EIA market context; R2 PASS deterministic weekly-gated five-D1-return continuation in a low realized-volatility regime, ATR hard stop, opposite-return exit, time exit, and Friday close; R3 PASS XNGUSD.DWX exists in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime feed. The OHLC-only signal is explicitly a falsifiable proxy for the paper's position-flow-decomposed momentum component, not a claim to reproduce that unavailable decomposition."
review_focus: "Adds a short-horizon low-volatility natural-gas continuation driver to the XAU/SP500/NDX/XNG book; unlike QM5_12567 it does not buy RSI pullbacks, and unlike existing XNG shock fades it follows moves only when volatility is subdued. Q09 must still reject it if realized returns remain correlated with the incumbent XNG sleeve."
---

# QM5_13101 XNG One-Week Low-Volatility Momentum

The EA trades `XNGUSD.DWX` on D1 only. It uses the short-horizon commodity
momentum evidence from Zhao, Ding, Yu, and Kang as structural lineage, but reads
no futures curve, COT, EIA, ETF roll, inventory, CSV, API, analyst calendar, or
ML output at runtime.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.

## hypothesis

Short-term commodity continuation can persist when the recent move is large
enough and current realized volatility is not elevated. Natural gas gives the
portfolio an energy sleeve with a different return mechanism from the existing
index, metal, and natural-gas RSI book exposure.

The source paper's empirical signal decomposes returns using investor-position
data. Darwinex backtests do not expose that series, so this card does not claim
to reproduce the paper's `R_nonQ` factor. It declares an OHLC-only proxy whose
value must be established independently by Q02 and later gates.

## source

- Primary: Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin (2026),
  *Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity
  Markets*, DOI `10.2139/ssrn.6425598`.
- Supplement: U.S. Energy Information Administration, "Factors affecting
  natural gas prices", used only to establish the target-market context.

The paper reports that short-term momentum applies across its commodity
cross-section and strengthens when volatility/uncertainty is low. No source
performance number is imported as a forecast for this XNG CFD proxy.

## non-duplicate boundary

- `QM5_12567_cum-rsi2-commodity`: two-day RSI pullback mean reversion; this
  card uses no RSI and follows a five-day move in low volatility.
- `QM5_12817_xng-volshock-fade`: fades multi-day XNG shocks in elevated
  volatility; this card rejects elevated volatility and trades continuation.
- `QM5_12620_comm-reversal-4wk-xngusd`: fades a four-week overreaction; this
  card follows one-week direction.
- `QM5_12804_xng-tsmom12m-atr`: monthly long-horizon state; this card is weekly
  and short-horizon.
- XNG storage, weather, LNG, rig-count, expiry, weekday, carry, calendar, and
  spread sleeves: this card has no event/date direction, curve, swap, or second
  leg.
- `QM5_13049` and `QM5_13055` use the same locked source proxy on WTI and
  Brent. This is the previously unbuilt natural-gas realization and inherits no
  pipeline evidence from either pending crude build.

## rules

Trade `XNGUSD.DWX` D1 only. On each new broker D1 bar, compute the prior 5
closed-D1 return and the current 20-D1 realized volatility percentile versus
the prior 120 rolling realized-vol observations. Take at most one entry per
broker week. Enter only when the absolute 5-D1 return is above threshold and
the volatility percentile is at or below threshold.

## 4. entry rules

Enter long when the prior 5 closed D1 bars have returned at least the configured
positive threshold and current 20-D1 realized-volatility percentile is at or
below the configured cap. Enter short on the symmetric negative 5-D1 return.
One position per magic and one entry per broker week.

PARAMETERS

- strategy_momentum_lookback_days = 5
- strategy_min_week_return_pct = 1.25
- strategy_vol_window_d1 = 20
- strategy_vol_rank_lookback_d1 = 120
- strategy_max_vol_pctile = 55.0
- strategy_atr_period = 20
- strategy_atr_sl_mult = 2.50
- strategy_hold_days = 7
- strategy_exit_reverse_pct = 0.50
- strategy_max_spread_points = 2500

## 5. exit rules

Use an ATR hard stop, a 7-calendar-day time exit, an opposite 5-D1 return
reversal exit, standard news handling, and Friday close. There is no fixed TP;
the edge is managed by stop, time, and reversal.

## 6. filters (no-trade module)

Require `XNGUSD.DWX`, D1, magic slot 0, valid D1 close/ATR/realized-vol data,
spread at or below cap, and standard V5 news/kill-switch guards.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
external runtime feed, cross-symbol state, adaptive PnL fitting, or ML.

## 8. parameters to test

The signal parameters are locked to the existing source-proxy realization.
Q02 uses these defaults and does not introduce an XNG-specific retune.

- `strategy_momentum_lookback_days = 5`
- `strategy_min_week_return_pct = 1.25`
- `strategy_vol_window_d1 = 20`
- `strategy_vol_rank_lookback_d1 = 120`
- `strategy_max_vol_pctile = 55.0`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 2.50`
- `strategy_hold_days = 7`
- `strategy_exit_reverse_pct = 0.50`
- `strategy_max_spread_points = 2500` (execution guard only)

## 9. author claims

"The short-term momentum effect applies to the entire cross-section of sample
commodities" (Zhao et al., 2026, abstract).

The abstract also reports that the effect strengthens when
volatility/uncertainty is low. Those claims motivate direction and regime; they
do not validate the OHLC-only XNG proxy.

## 10. initial risk profile

- expected_pf: 1.08.
- expected_dd_pct: 25.
- expected_trade_frequency: 6-14 entries/year.
- risk_class: high because XNG gaps and regime shifts can turn continuation
  into rapid reversal.
- gridding: false.
- scalping: false.
- ml_required: false.

## 11. strategy allowability check

- [x] Mechanical: fixed five-D1 return, realized-volatility percentile, weekly
  gate, ATR stop, time exit, and reversal exit.
- [x] Named-author, DOI-indexed academic source plus official EIA supplement.
- [x] `XNGUSD.DWX` is present in the local DWX symbol universe.
- [x] No ML, adaptive fitting, grid, martingale, pyramiding, or external feed.
- [x] Friday close compatible with the intended sub-week hold.
- [x] Expected frequency exceeds the binding five-trades/year Q02 floor.
- [x] Source-to-OHLC proxy gap is explicit; no flow decomposition is invented.
- [x] Non-duplicate boundary is documented above.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XNGUSD.DWX` D1 setfile. Live risk is not configured by this card.

No live setfile is created. The EA does not touch `T_Live`, AutoTrading,
deploy manifests, the T_Live manifest, portfolio admission, or the portfolio
gate.

## 12. framework alignment

- no_trade: XNG D1, slot 0, parameter, spread, history, one-position, and one
  accepted entry per W1-key guards.
- trade_entry: five-D1 direction gated by current 20-D1 realized-volatility
  percentile, with a frozen ATR stop.
- trade_management: seven-day and opposite-five-D1-return exits.
- trade_close: `QM_TM_ClosePosition` for management exits plus broker ATR stop
  and framework Friday close.

## falsification

Retire if Q02 produces fewer than five trades/year, fails PF/DD gates, or the
low-volatility gate collapses the XNG sample. Do not promote if later portfolio
evidence shows material correlation with `QM5_12567` or the certified XNG
return stream. Do not retune the locked signal to rescue a fail.

## pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial parameter-locked XNG short-horizon momentum build | Q02 | PENDING |

## pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PENDING | `artifacts/qm5_13101_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | PENDING | queue work item after build PASS |



