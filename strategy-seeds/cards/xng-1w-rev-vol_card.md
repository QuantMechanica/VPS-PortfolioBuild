---
ea_id: QM5_13102
slug: xng-1w-rev-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XNG_S02
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
logical_symbol: QM5_13102_XNG_1W_REV_VOL_D1
period: D1
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 22.0
expected_trades_per_year_per_symbol: 10
expected_trade_frequency: "Weekly-gated natural gas D1 short-term reversal with high-volatility filter; estimate 8-18 entries/year."
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-10: R1 PASS named-author academic working paper with DOI plus official EIA market context; R2 PASS deterministic weekly-gated five-D1-return fade in an elevated realized-volatility regime, ATR hard stop, neutral-return exit, time exit, and Friday close; R3 PASS XNGUSD.DWX exists in the DWX matrix; R4 PASS no ML/grid/martingale/external runtime feed. The OHLC-only signal is explicitly a falsifiable proxy for the paper's position-flow-decomposed reversal component, not a claim to reproduce that unavailable decomposition."
review_focus: "Adds a short-horizon high-volatility natural-gas reversal driver to the XAU/SP500/NDX/XNG book. Unlike QM5_12567 it does not use RSI or a two-day trend-filtered pullback; unlike longer XNG reversal sleeves it isolates five-day shocks and requires elevated realized volatility. Q09 must still reject it if realized returns remain correlated with the incumbent XNG sleeve."
---

# QM5_13102 XNG One-Week High-Volatility Reversal

The EA trades `XNGUSD.DWX` on D1 only. It uses the short-horizon commodity
reversal evidence from Zhao, Ding, Yu, and Kang as structural lineage, but reads
no futures curve, position-flow series, COT, EIA, inventory, CSV, API, analyst
calendar, or ML output at runtime.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.

## hypothesis

Large one-week commodity moves can partially reverse when realized volatility
is elevated and price discovery has become disorderly. Natural gas expresses
this high-volatility overreaction driver independently from the book's index
and metal sleeves and from the incumbent XNG two-day RSI pullback logic.

The source paper decomposes short-horizon returns using investor-position data.
Darwinex backtests do not expose that series, so this card does not claim to
reproduce the paper's flow factor. It declares an OHLC-only proxy whose value
must be established independently by Q02 and later gates.

## source

- Primary: Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin (2026),
  *Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity
  Markets*, DOI `10.2139/ssrn.6425598`.
- Supplement: U.S. Energy Information Administration, "Factors affecting
  natural gas prices", used only to establish the target-market context.

The paper documents both short-horizon momentum and reversal in its commodity
sample and attributes the reversal side to a different component than the
low-volatility continuation branch. No source performance number is imported
as a forecast for this XNG CFD proxy.

## non-duplicate boundary

- `QM5_12567_cum-rsi2-commodity`: two-day RSI pullback with a slow trend
  filter; this card uses no RSI or moving-average direction and fades a
  five-D1 shock only in elevated realized volatility.
- `QM5_12817_xng-volshock-fade`: generic multi-day shock fade; this card adds a
  formal 20-D1 volatility percentile regime, weekly cadence, locked five-D1
  source-family return, and neutral-band exit.
- `QM5_12620_comm-reversal-4wk-xngusd`: 20-D1 overreaction with up to 28-day
  hold; this card uses a five-D1 shock and a five-calendar-day maximum hold.
- `QM5_12895_xng-6m-reversal`: 120-D1 monthly overextension; this card is
  weekly and short-horizon.
- `QM5_13101_xng-1w-mom-vol`: follows the five-D1 move only in low volatility;
  this card fades the move only in high volatility.
- `QM5_13050` and `QM5_13056` use the same locked reversal proxy on WTI and
  Brent. This is the previously unbuilt natural-gas carrier and inherits no
  pipeline evidence from either crude build.
- XNG storage, weather, LNG, rig-count, expiry, weekday, carry, calendar, and
  spread sleeves: this card has no event/date direction, curve, swap, or
  second leg.

## rules

Trade `XNGUSD.DWX` D1 only. On each new broker D1 bar, compute the prior five
closed-D1 return and the current 20-D1 realized-volatility percentile versus
the prior 120 rolling realized-volatility observations. Take at most one entry
per broker week. Enter only when the absolute five-D1 return is above threshold
and the volatility percentile is at or above threshold.

## 4. entry rules

Enter long when the prior five closed D1 bars have fallen at least the
configured negative threshold and current 20-D1 realized-volatility percentile
is at or above the configured floor. Enter short when the prior five closed D1
bars have risen at least the configured positive threshold under the same
volatility gate. One position per magic and one accepted entry per broker week.

PARAMETERS

- strategy_reversal_lookback_days = 5
- strategy_min_week_return_pct = 2.00
- strategy_vol_window_d1 = 20
- strategy_vol_rank_lookback_d1 = 120
- strategy_min_vol_pctile = 65.0
- strategy_atr_period = 20
- strategy_atr_sl_mult = 2.25
- strategy_hold_days = 5
- strategy_exit_neutral_pct = 0.25
- strategy_max_spread_points = 2500

## 5. exit rules

Use an ATR hard stop, a five-calendar-day time exit, and a mean-reversion exit
when the prior five-D1 return has normalized back inside the configured neutral
band. Standard news handling and Friday close remain enabled. There is no fixed
take-profit; the edge is managed by stop, time, and return normalization.

## 6. filters (no-trade module)

Require `XNGUSD.DWX`, D1, magic slot 0, valid D1 close/ATR/realized-volatility
data, spread at or below cap, and standard V5 news/kill-switch guards.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
external runtime feed, cross-symbol state, adaptive PnL fitting, or ML.

## 8. parameters to test

Signal parameters are locked to the existing WTI/Brent source-family reversal
realization. Q02 uses these defaults and does not introduce an XNG-specific
retune. Only the execution spread cap changes for the XNG carrier.

- `strategy_reversal_lookback_days = 5`
- `strategy_min_week_return_pct = 2.00`
- `strategy_vol_window_d1 = 20`
- `strategy_vol_rank_lookback_d1 = 120`
- `strategy_min_vol_pctile = 65.0`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 2.25`
- `strategy_hold_days = 5`
- `strategy_exit_neutral_pct = 0.25`
- `strategy_max_spread_points = 2500` (execution guard only)

## 9. author claims

"We document both short-term momentum and reversal in commodity futures"
(Zhao et al., 2026, abstract).

The source's reversal claim motivates direction and the separate regime branch;
it does not validate this OHLC-only XNG realization.

## 10. initial risk profile

- expected_pf: 1.08.
- expected_dd_pct: 22.
- expected_trade_frequency: 8-18 entries/year.
- risk_class: high because XNG gaps can continue after an apparent shock and
  overwhelm a contrarian entry before the ATR stop executes.
- gridding: false.
- scalping: false.
- ml_required: false.

## 11. strategy allowability check

- [x] Mechanical: fixed five-D1 return, realized-volatility percentile,
  weekly gate, ATR stop, time exit, and neutral-return exit.
- [x] Named-author, DOI-indexed academic source plus official EIA supplement.
- [x] `XNGUSD.DWX` is present in the local DWX symbol universe.
- [x] No ML, adaptive fitting, grid, martingale, pyramiding, or external feed.
- [x] Friday close is compatible with the intended sub-week hold.
- [x] Expected frequency exceeds the binding five-trades/year Q02 floor.
- [x] Source-to-OHLC proxy gap is explicit; no flow decomposition is invented.
- [x] Same-source and same-asset neighbors are distinguished by horizon,
  volatility regime, and direction.

## risk

Q02 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XNGUSD.DWX` D1 setfile. Live risk is not configured by this card.

No live setfile is created. The EA does not touch `T_Live`, AutoTrading,
deploy manifests, the T_Live manifest, portfolio admission, or the portfolio
gate.

## 12. framework alignment

- no_trade: XNG D1, slot 0, parameter, spread, history, one-position, and one
  accepted entry per W1-key guards.
- trade_entry: fade the five-D1 direction only when current 20-D1 realized
  volatility ranks at or above the locked percentile floor, with frozen ATR
  stop distance.
- trade_management: five-day time exit and five-D1 return normalization exit.
- trade_close: `QM_TM_ClosePosition` for management exits plus broker ATR stop
  and framework Friday close.

## falsification

Retire if Q02 produces fewer than five trades/year, fails PF/DD gates, or the
high-volatility gate collapses the XNG sample. Do not promote if later
portfolio evidence shows material correlation with `QM5_12567` or the
certified XNG return stream. Do not retune the locked signal to rescue a fail.

## pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial parameter-locked XNG short-horizon high-volatility reversal build | Q02 | PENDING |

## pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PENDING | `artifacts/qm5_13102_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | PENDING | queue work item after build PASS |

