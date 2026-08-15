# QM5_21527_wti-fallcorr-tr - Strategy Spec

**EA ID:** QM5_21527

**Slug:** `wti-fallcorr-tr`

**Strategy ID:** `MOP-SILV-WTI-FALLCORR-2026_S01`

**Sources:** Moskowitz, Ooi, and Pedersen (2012); Silvennoinen and Thorp
(2013)

**Last revised:** 2026-08-15

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, the EA closes prior-month exposure and consumes the new month
before every fallible entry gate. It reconstructs exactly thirteen
consecutive completed WTI broker-month endpoints and computes:

```text
trend_12m = ln(latest completed WTI month end /
               WTI month end twelve months earlier)
```

Independently, it intersects completed WTI and read-only `SP500.DWX` D1
history by exact timestamp and retains the newest exactly 127 common closes.
Those closes form 126 chronological simple-return pairs. The newest 63
returns and immediately preceding 63 returns are disjoint observations, with
only their boundary close shared. Each block uses its own means and Pearson
correlation:

```text
rho_b = sum((r_wti - mean_wti_b) * (r_sp500 - mean_sp500_b)) /
        sqrt(sum((r_wti - mean_wti_b)^2) *
             sum((r_sp500 - mean_sp500_b)^2))
```

The WTI trend is admitted only when
`abs(rho_recent) + 1e-12 < abs(rho_preceding)`. A positive admitted trend is
bought and a negative admitted trend is sold. A tie, rising absolute
correlation, exact-zero trend, invalid history, or singular block consumes
the month flat. SP500 is never traded.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_trend_months` | 12 | exact completed-month trend horizon |
| `strategy_trend_history_bars_d1` | 500 | bounded independent WTI month-end history |
| `strategy_corr_returns_per_block` | 63 | returns in each Pearson block |
| `strategy_corr_recent_block_offset` | 0 | recent block offset from newest return |
| `strategy_corr_preceding_block_offset` | 63 | preceding disjoint block offset |
| `strategy_corr_common_closes` | 127 | exact synchronized close count |
| `strategy_corr_history_bars_d1` | 350 | bounded raw intersection buffer |
| `strategy_corr_tolerance` | 1e-12 | strict decline and range tolerance |
| `strategy_variance_epsilon` | 1e-16 | block variance floor |
| `strategy_max_endpoint_gap_days` | 10 | completed-history freshness guard |
| `strategy_atr_period_d1` | 20 | completed WTI stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | stale-position guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

The Q02 baseline also locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, seed 42, slot zero, both news axes OFF, legacy news OFF,
Friday close OFF, and stress rejection zero. No alternate estimator, window,
threshold, carrier, or parameter sweep is authorized.

## 3. Symbol Universe

- Host and sole traded carrier: `XTIUSD.DWX`, D1, slot 0, magic `215270000`.
- Read-only factor: `SP500.DWX`, D1, with no magic or order authority.

No other symbol, slot, carrier, or magic is authorized. The EA fails closed
outside the exact host chart and registered identity.

## 4. Timeframe

The host, trend input, and correlation inputs are D1. All signals use only
completed bars. WTI and SP500 correlation timestamps must match exactly, be
strictly chronological, and carry positive finite closes. The newest common
close and newest completed WTI trend bar must precede the decision bar and
be no more than ten calendar days stale.

The decision cadence is the first processed host D1 bar after a broker-month
change. WTI trend endpoints must cover exactly thirteen consecutive broker
months ending in the immediately completed month. The endpoint log return
must equal the sum of the twelve adjacent monthly log returns within
`1e-10`.

## 5. Expected Behaviour

The prior is approximately five to seven completed WTI positions per full
post-warm-up year because only months with falling absolute WTI/SP500
correlation qualify. Q02 must retire the candidate on zero trades, fewer than
five completed positions per year, or nonpositive governed economics.

Expected exposure is episodic symmetric WTI trend, not a second XNG
short-horizon oscillator. A falling sample correlation is only an admission
state; it does not establish portfolio diversification. The unchanged Q09
gate alone may measure realized overlap with the certified XAU, SP500, NDX,
and XNG book.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of
Financial Economics 104(2), 228-250, supply the twelve-month own-return-sign
direction, monthly cadence, and WTI membership. Silvennoinen and Thorp
(2013), *Financialization, Crisis and Commodity Correlation Dynamics*,
Journal of International Financial Markets, Institutions and Money 24,
42-65, establish time-varying WTI/equity integration and adverse
diversification context.

Neither source tests the exact falling-correlation trading conjunction,
disjoint raw-Pearson proxy, Darwinex CFDs, fixed-dollar risk, ATR stop, costs,
density, or QM book. The governed packet is
`strategy-seeds/sources/MOP-SILV-WTI-FALLCORR-2026/source.md`; the approved
execution contract is
`strategy-seeds/cards/approved/QM5_21527_wti-fallcorr-tr_card.md`.

## 7. Risk Model

Each position receives exactly `RISK_FIXED=1000`, with `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1`. Position size is derived through the V5 framework from
a frozen `3.5 * ATR(20,D1)` broker hard stop. There is no take-profit,
trailing stop, break-even, partial close, scale-in, grid, martingale,
pyramid, or risk escalation.

The position closes before monthly replacement, after forty elapsed calendar
days, or immediately on malformed owned state. WTI roll and financing,
continuous-CFD/futures basis, gaps, geopolitics, unstable Pearson estimates,
lot granularity, stop slippage, and residual book correlation remain material
risks.

## 8. Entry And Lifecycle

- Lifecycle repair and prior-month liquidation run before entry-only gates.
- The current month is persisted before history, signal, news, spread,
  quote, ATR, sizing, or order checks; a failed or flat month cannot retry.
- Restart recovery combines the terminal-persistent marker with owned
  positions and same-month entry-deal history.
- A valid admitted positive trend opens one WTI BUY; a valid admitted
  negative trend opens one WTI SELL.
- Every position has its initial hard stop and no target. Duplicate,
  wrong-symbol, invalid-type, future-dated, or missing-stop state is closed.
- SP500 remains read-only on every execution path.

## 9. Four-Module Mapping

- No-Trade: exact host/D1/ID/slot, locked inputs, risk/news/Friday/stress
  contract, and symbol-scope guards.
- Entry: consumed-month state, independent WTI month-end trend, synchronized
  WTI/SP500 intersection, disjoint Pearson blocks, strict absolute decline,
  spread/quote/ATR checks, fixed-risk sizing, and hard stop.
- Management: malformed-state repair, monthly rollover close, and forty-day
  stale close before new entry evaluation.
- Close: framework close helper and broker hard stop; the framework kill
  switch remains authoritative.

## 10. Safety Boundary

Authorized: deterministic build, strict compile/Q01, one `XTIUSD.DWX` D1
fixed-risk backtest set, and one paced non-live Q02 enqueue when capacity
permits. Not authorized: manual backtest, optimization, live/demo/shadow/
stress artifact, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate edit, portfolio admission, or correlation waiver.

## 11. Build History

| Version | Date | Event |
|---|---|---|
| v1 | 2026-08-15 | Initial falling-equity-correlation-gated WTI trend build |
