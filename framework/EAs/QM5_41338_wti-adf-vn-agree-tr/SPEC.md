# QM5_41338 — WTI Monthly ADF and Raw von Neumann Agreement Trend

**EA ID:** QM5_41338

Strategy `AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905_S01`; carrier
`XTIUSD.DWX`; timeframe D1; slot 0; magic `413380000`.

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, consume the month before
any fallible gate. Reconstruct exactly 60 consecutive completed broker-month-
end closes, oldest to newest, excluding every current-month price. Let
`x[t]=ln(close[t])`.

The ADF path fits `delta(x[t]) = alpha + gamma*x[t-1] +
phi*delta(x[t-1]) + error[t]` for `t=2..59` using centered cross-products,
58 observations, residual variance `SSE/55`, and `ADF_t=gamma/se_gamma`.
It qualifies inclusively at `ADF_t >= -2.594`.

The raw von Neumann path uses the newest 20 returns
`r[i]=x[40+i]-x[39+i]`. It computes their mean, centered sum of squares `V`,
19 squared successive differences `D`, and `eta=D/V`. It qualifies strictly
at `V>1e-18` and `eta<2.0`.

Trade only when both states qualify. Direction is the sign of
`x[59]-x[47]`: buy above `+1e-12`, sell below `-1e-12`, otherwise stay flat.
Pinned ADF-only/high-eta and von-Neumann-only/ADF-reject paths abstain.

## 2. Parameters

- 60 levels; ADF 58 observations and 55 residual degrees of freedom.
- Energy floor `1e-18`; determinant relative floor `1e-12`; inclusive ADF
  boundary `-2.594`.
- Newest 20 returns; raw `D/V`; strict eta boundary `2.0`.
- D1 history scan 1800 bars; endpoint staleness 10 days; entry grace 180
  minutes.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- ATR(20) from the completed D1 bar, frozen `3.5*ATR` hard stop, no target.
- Spread ceiling 1500 points; no retry, scale-in, trail, news gate, Friday
  flatten, stress rejection, or discretionary intramonth exit.
- Exit on the first processed tick in a later normalized broker month; 40-day
  stale repair is a defensive ceiling.

## 3. Symbol Universe

The only logical, host, and traded symbol is registered native commodity
carrier `XTIUSD.DWX`. No proxy, basket, or fallback symbol is allowed.

## 4. Timeframe

Attach and test only on D1. Decisions occur once per broker month from
completed D1 bars; all 60 observations are completed monthly endpoints.

## 5. Expected Behaviour

Fail closed on incomplete/nonconsecutive endpoints, nonpositive prices,
nonfinite arithmetic, singular ADF regression, invalid variance or eta,
foreign carrier exposure, malformed owned state, or invalid quote, ATR,
sizing, margin, or stop. Initialization runs executable up/down, both
one-gate disagreement, smooth-return, and degenerate reference paths.

Q02 retires the unchanged baseline on zero trades, fewer than five completed
positions in any full post-warm-up year, nondeterminism, nonpositive governed
economics, or a contract defect.

## 6. Source Citation

The exact synthesis is approved source
`AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905`. Supporting complete records are
Chan (2013), *Algorithmic Trading*, Wiley; the NIST/SEMATECH Mean Successive
Differences Test and von Neumann et al. (1941), DOI
`10.1214/aoms/1177731677`; and Moskowitz, Ooi, and Pedersen (2012), *Journal
of Financial Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`. None
validates this exact conjunction or continuous-CFD transport.

## 7. Risk Model

The sole backtest mode is fixed USD 1,000 with weight one and percent risk
zero. Continuous-CFD roll, basis, financing, gaps, small-sample ADF size,
raw-return outlier sensitivity, and shared WTI trend overlap remain material
risks. Only Q09 may determine realized portfolio correlation.

This build does not authorize live use, portfolio admission, portfolio-gate
changes, T_Live manifest changes, terminal control, or AutoTrading.

## Revision

2026-09-05: governed Q01 implementation from the approved card; Q02 pending.
