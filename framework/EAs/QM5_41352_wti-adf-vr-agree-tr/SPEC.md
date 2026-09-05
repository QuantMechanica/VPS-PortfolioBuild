# QM5_41352 — WTI Monthly ADF and Robust Variance-Ratio Agreement Trend

**EA ID:** QM5_41352

Strategy `AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905_S01`; carrier
`XTIUSD.DWX`; timeframe D1; slot 0; magic `413520000`.

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, consume the month before
any fallible gate. Reconstruct exactly 60 consecutive completed broker-month-
end closes, oldest to newest, excluding all current-month prices, and set
`x[t]=ln(close[t])`.

Fit `delta(x[t]) = alpha + gamma*x[t-1] + phi*delta(x[t-1]) + error[t]`
for `t=2..59` using centered cross-products, 58 observations, residual
variance `SSE/55`, and `ADF_t=gamma/se_gamma`. Require inclusively
`ADF_t >= -2.594`.

On the newest 32 adjacent monthly returns, compute the q=4
heteroskedasticity-robust Lo-MacKinlay variance ratio:

```text
VR4=1+1.5*rho1+rho2+0.5*rho3
theta4=2.25*delta1+delta2+0.25*delta3
vr_z=(VR4-1)/sqrt(theta4)
```

Require strictly `vr_z > 1.64485362695147`. A negative significant VR state
is disagreement and stays flat. When both diagnostics qualify, buy if
`x[59]-x[47] > 1e-12`, sell below `-1e-12`, and otherwise stay flat.

## 2. Parameters

- 60 levels; ADF 58 observations, 55 residual degrees of freedom, energy
  floor `1e-18`, determinant relative floor `1e-12`, boundary `-2.594`.
- Newest 32 returns; q=4 robust VR; strict positive z boundary
  `1.64485362695147`.
- D1 history scan 1800 bars; endpoint staleness 10 days; entry grace 180
  minutes.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Completed-D1 ATR(20), frozen `3.5*ATR` hard stop, no target.
- Spread ceiling 1500 points; next-month exit and 40-day stale repair.
- No retry, scale-in, trail, news gate, Friday flatten, stress rejection, or
  discretionary intramonth exit.

## 3. Symbol Universe

The only host and traded symbol is registered native energy carrier
`XTIUSD.DWX`. No proxy, basket, or fallback symbol is allowed.

## 4. Timeframe

Attach and test only on D1. Decisions occur once per broker month from
completed D1 bars; all monthly observations are completed endpoints.

## 5. Expected Behaviour

Fail closed on incomplete/nonconsecutive endpoints, nonpositive prices,
nonfinite arithmetic, singular ADF, invalid VR energy, foreign exposure,
malformed owned state, or invalid quote, ATR, sizing, margin, or stop.
Initialization covers executable up/down agreement, both one-gate
disagreement directions, and a degenerate path.

Q02 retires the unchanged baseline on zero trades, fewer than five completed
positions in any full post-warm-up year, nondeterminism, nonpositive governed
economics, or a contract defect.

## 6. Source Citation

The approved synthesis is `AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905`.
Complete supporting records are Chan (2013), *Algorithmic Trading*, Wiley;
Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), DOI
`10.1080/1351847X.2023.2220118`; and Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. None validates this exact conjunction or
continuous-CFD transport.

## 7. Risk Model

The sole backtest mode is fixed USD 1,000 with weight one and percent risk
zero. Continuous-CFD roll, basis, financing, gaps, small-sample diagnostic
size, and shared WTI trend overlap remain material. Only Q09 may determine
realized portfolio correlation.

This build authorizes no live use, portfolio admission, portfolio-gate or
T_Live-manifest change, terminal control, or AutoTrading.

## Revision

2026-09-05: governed Q01 implementation from the approved card; Q02 pending.
