---
ea_id: QM5_12534
slug: nnfx-canonical-d1-fullstack
type: strategy
source_id: nnfx-vp-canonical-2026-06-12
sources:
  - "[[sources/no-nonsense-forex]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/indicator-stack-confirmation]]"
  - "[[concepts/atr-risk]]"
indicators:
  - "[[indicators/kijun-sen]]"
  - "[[indicators/ssl-channel]]"
  - "[[indicators/aroon]]"
  - "[[indicators/waddah-attar-explosion]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "VP / No Nonsense Forex published algorithm framework (nononsenseforex.com, 2018-2021 podcast+blog); large community replication base; named public identity."
r2_mechanical: PASS
r2_reasoning: "Full deterministic stack: Kijun baseline + SSL C1 + Aroon C2 + WAE volume gate + 1.5xATR SL / 1xATR TP-half / runner; all closed-bar D1 rules."
r3_data_available: PASS
r3_reasoning: "9 liquid .DWX FX pairs with D1 history; no external data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed-parameter indicator stack; no ML, no optimization-adaptive logic, no grid/martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 18
expected_pf: 1.35
expected_dd_pct: 12
last_updated: 2026-06-12
g0_approval_reasoning: "G0 2026-06-12 Claude: canonical-fidelity rebuild. Existing nnfx-v2 cards (QM5_2010-2014) violate NNFX doctrine (EMA20/RSI/MACD/Bollinger on H1/H4 - indicators VP explicitly bans, wrong timeframe). This card implements the ACTUAL published algorithm: D1-only, baseline+2-confirmation+volume stack, ATR money management. R1-R4 PASS."
---

# NNFX Canonical D1 Full-Stack (faithful VP algorithm)

## Source
- VP, "No Nonsense Forex" — published algorithm framework: nononsenseforex.com
  (blog + podcast, 2018-2021), esp. "The Algorithm" series and money-management
  episodes. URL: https://nononsenseforex.com/
- Community-canonical indicator pool (NNFX-tested): Kijun-sen baseline, SSL Channel,
  Aroon, Waddah Attar Explosion — all deterministic, standard MQL5 implementations.

## Why this card exists (fidelity note)
Our existing "nnfx-v2" cards (QM5_2010..2014) use EMA(20)/RSI/MACD/Bollinger on H1/H4 —
exactly the indicators VP bans, on the wrong timeframe. They are NNFX in name only.
This card is the doctrine-faithful realization. Same family, different (correct)
implementation — treat results as the fidelity experiment.

## Market Universe
Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, NZDUSD.DWX,
USDCAD.DWX, USDCHF.DWX, EURJPY.DWX, GBPJPY.DWX

## Timeframe
D1 only (signals evaluated once per day on D1 bar close; NNFX doctrine).

## Entry
All on closed D1 bars; LONG rules (SHORT = exact mirror):
1. **Baseline**: close crosses ABOVE Kijun-sen(26) on the signal bar, OR closed above
   it within the last 3 bars with the remaining conditions completing now.
2. **ATR proximity rule** (VP "bridge too far"): distance from close to Kijun at signal
   must be < 1.0 x ATR(14). If price closed > 1xATR beyond baseline, skip.
3. **C1 confirmation**: SSL Channel(10) is long (SSL-up line above SSL-down).
4. **C2 confirmation**: Aroon(25) Up > Aroon Down.
5. **Volume gate**: Waddah Attar Explosion — momentum histogram positive AND above the
   explosion line (deterministic WAE standard params 20/40/2.0/150).
6. One position per symbol per magic (HR14). News blackout per V5 framework (fail-closed
   calendar, qm_news_stale_max_hours <= 336).

## Exit
- **TP-half**: close 50% of the position at +1.0 x ATR(14) from entry.
- **Runner**: remaining 50% exits when close crosses back through Kijun-sen(26), or on
  SSL Channel flip, whichever first.
- No time exit (trend runner by design).

## Stop Loss
- Initial SL = 1.5 x ATR(14) from entry (VP money management).
- After TP-half fills, move runner SL to breakeven.

## Risk
- RISK_FIXED for backtest / RISK_PERCENT for live; 1.0% per trade with the split-exit
  treated as one risk unit.

## Falsification
- If the doctrine-faithful stack does not outperform the banned-indicator nnfx-v2
  variants (QM5_2010-2014) on identical symbols/period, the "fidelity hypothesis" for
  NNFX is rejected and the family is closed.

## Q08 / Q11 Risks
- Q08: D1 trend systems are streak-prone; expect drawdown clusters in FX range regimes.
  ~18 trades/yr/symbol x 9 symbols ≈ 160/yr aggregate clears DL-070 swing floors.
- Q11: trend-following bucket is crowded in the portfolio — anticorrelation check
  against existing TF survivors mandatory.

## FTMO Compliance Block
- Target DD: <=5% daily, <=10% total; 1% risk/trade caps daily loss at ~2 positions.
- News blackout: MANDATORY (framework standard).
- No martingale/grid/averaging. Mechanical, no ML.
