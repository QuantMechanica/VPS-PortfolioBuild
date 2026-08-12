# QM5_20259_xng-mom-vote — Strategy Spec

**EA ID:** QM5_20259

## 1. Strategy Logic

At the first processed `XNGUSD.DWX` D1 bar of a genuine new broker month, the
EA reconstructs exactly thirteen consecutive completed broker-month-end closes
in chronological order. From the common newest endpoint it calculates:

```text
R1  = ln(C[12] / C[11])
R3  = ln(C[12] / C[9])
R12 = ln(C[12] / C[0])
vote = sign(R1) + sign(R3) + sign(R12)
```

All components must be finite and strictly nonzero. A positive two-of-three
majority buys XNG; a negative majority sells it. Invalid history or arithmetic
consumes the month flat. An actionable state opens one position with a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, no scale-in, and no intramonth
signal reversal. The prior package closes at the next broker-month boundary;
a forty-calendar-day guard closes a stale package.

The evaluated month is persisted before signal and execution gates. Owned
positions and entry-deal history provide restart recovery, so a flat, rejected,
failed, or stopped attempt cannot retry during the same month.

## 2. Parameters

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_fast_months` | 1 | newest completed return horizon |
| `strategy_medium_months` | 3 | intermediate completed return horizon |
| `strategy_slow_months` | 12 | slow completed return horizon |
| `strategy_required_votes` | 2 | fixed majority threshold |
| `strategy_history_bars_d1` | 800 | bounded D1 endpoint-recovery buffer |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale lifecycle guard |
| `strategy_max_spread_points` | 3000 | entry spread ceiling |

Every strategy parameter and the framework identity, risk, news, Friday, and
stress inputs are fail-closed to the authorized Q02 baseline.

## 3. Symbol Universe

- Exact host and traded symbol: `XNGUSD.DWX`.
- Slot: 0.
- Registered magic: `202590000`.
- This is a direct XNG energy carrier; no basket leg or external data feed is
  read at runtime.

## 4. Timeframe

- Host timeframe: D1.
- Decision cadence: the first D1 bar whose broker-month key differs from the
  immediately preceding completed D1 bar.
- Formation data: thirteen completed month endpoints derived from bounded D1
  history because custom-symbol MN1 data is not assumed.
- Entry frequency: at most one consumed attempt and one package per month.

## 5. Expected Behaviour

After warm-up, the strategy should produce approximately twelve completed
monthly packages per year. Fewer than five completed packages per full
post-warm-up year is a retirement condition. The expected directional states
are positive vote to long and negative vote to short, with equal fixed cash
risk for vote magnitudes one and three.

The EA must remain flat on stale or nonconsecutive endpoints, nonpositive
prices, zero component returns, invalid logarithms, invalid ATR/stop geometry,
excess spread, owned exposure, or any unlocked baseline input. It closes the
old package before considering the next month's state and repairs duplicate,
wrong-symbol, invalid-type, or missing-stop exposure bearing its magic.

The non-duplicate boundary is the XNG completed-calendar-month
one/three/twelve nested-return majority. Existing XNG EAs use a single horizon,
monthly-sign breadth, volatility-memory, calendar/event/carry/breakout states,
or the incumbent two-day cumulative-RSI pullback. The generic 20/60/120-D1 vote
does not trade XNG and has a daily reversal lifecycle. None combines this XNG
carrier, fixed calendar-month vote, consumed attempt, and monthly renewal.

## 6. Source Citation

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete-read record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded mechanization is
`strategy-seeds/sources/MOP-XNG-MOMVOTE-2026/source.md`.

The paper supplies natural-gas membership and the monthly own-return-sign family. The
two-of-three aggregation, CFD endpoint reconstruction, fixed cash risk, ATR
stop, spread cap, and lifecycle controls are transparent QM hypotheses and are
not attributed to the authors. No source performance or diversification claim
transfers.

## 7. Risk Model

The sole setfile is a non-live `XNGUSD.DWX` D1 backtest configuration with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The V5 risk
layer sizes from the frozen ATR hard stop. Both news axes and legacy news are
off, Friday close is disabled, and the stress rejection probability is zero.

Risk is high: continuous-CFD roll and financing, natural-gas gaps, weather and
storage shocks, false trends, hard-stop slippage, and single-energy
concentration may dominate the signal. Q02 owns density and baseline
economics; Q09 alone may establish whether the new monthly trend P&L is
sufficiently distinct from the incumbent short-horizon XNG pullback. No live,
demo, shadow, stress, or optimization setfile,
AutoTrading action, T_Live change, deployment manifest, portfolio-gate edit,
or correlation waiver is authorized.

## Kill Criteria

Retire on zero trades, fewer than five completed packages per full post-warm-up
year, wrong or nonconsecutive endpoints, wrong return orientation, incorrect
vote, entry with a zero component, repeated monthly attempt, missing hard stop,
risk-mode mismatch, nondeterminism, nonpositive governed economics, or any
later unchanged gate failure. No post-result horizon, vote, direction, stop,
hold, spread, retry, or carrier rescue is authorized.
