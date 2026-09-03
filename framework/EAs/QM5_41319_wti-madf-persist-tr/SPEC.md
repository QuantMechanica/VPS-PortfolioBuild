+# QM5_41319 — WTI Monthly Lag-One ADF Persistence Trend
+
+**EA ID:** QM5_41319
+
+**Slug:** `wti-madf-persist-tr`
+
+**Strategy ID:** `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903_S01`
+
+**Author:** Development
+
+**Last revised:** 2026-09-03
+
+## 1. Strategy Logic
+
+This EA implements the G0-approved card
+`strategy-seeds/cards/approved/QM5_41319_wti-madf-persist-tr_card.md` as a
+direct, low-frequency `XTIUSD.DWX` D1 commodity sleeve. Sixty completed
+monthly WTI log-price levels feed a constant/no-time-trend augmented
+Dickey–Fuller regression with one lagged first difference. An inclusive
+lagged-level t-statistic state of at least `-2.594` gates the sign of the
+newest twelve-month log return.
+
+The threshold is a frozen persistence-state classifier, not a translated
+p-value or proof of a unit root. The conjunction is a QuantMechanica
+synthesis; Q09 alone can establish portfolio diversification.
+
+## 2. Locked Parameters
+
+| input | value | purpose |
+|---|---:|---|
+| `strategy_level_count` | 60 | completed chronological month-end closes/log levels |
+| `strategy_regression_observations` | 58 | rows after first difference and one lag |
+| `strategy_residual_dof` | 55 | observations less three coefficients |
+| `strategy_energy_floor` | `1e-18` | reject degenerate variance/residual paths |
+| `strategy_determinant_relative_floor` | `1e-12` | reject ill-conditioned two-regressor systems |
+| `strategy_adf_t_min` | `-2.594` | inclusive persistence-state boundary |
+| `strategy_momentum_months` | 12 | continuation direction horizon |
+| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
+| `strategy_history_bars` | 1200 | bounded D1 endpoint scan |
+| `strategy_entry_grace_minutes` | 180 | first-month-bar entry window |
+| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
+| `strategy_atr_period` | 20 | completed-D1 stop estimator |
+| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
+| `strategy_stale_days` | 40 | survivor repair ceiling |
+| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |
+
+Q02 has one set only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
+`PORTFOLIO_WEIGHT=1`.
+
+## 3. Exact Signal
+
+The host, traded carrier, and slot are `XTIUSD.DWX`, D1, slot zero, magic
+`413190000`. On the first executable tick after a genuine broker-month
+change, reconstruct exactly 60 immediately prior consecutive month-end
+closes, oldest to newest. The current month never enters the sample.
+
+For `C[0..59]`, let `x[t]=ln(C[t])`. For `t=2..59`, form:
+
+```text
+y[t] = x[t] - x[t-1]
+z[t] = x[t-1]
+w[t] = x[t-1] - x[t-2]
+y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
+```
+
+Compute the three sample means and centered cross-products
+`Szz,Sww,Szw,Szy,Swy`. Then:
+
+```text
+det   = Szz*Sww - Szw^2
+gamma = (Szy*Sww - Swy*Szw) / det
+phi   = (Swy*Szz - Szy*Szw) / det
+alpha = mean(y) - gamma*mean(z) - phi*mean(w)
+SSE   = sum(error[t]^2)
+s2    = SSE / 55
+se_g  = sqrt(s2*Sww/det)
+ADF_t = gamma/se_g
+mom12 = x[59]-x[47]
+
+BUY  iff ADF_t >= -2.594 and mom12 > +1e-12
+SELL iff ADF_t >= -2.594 and mom12 < -1e-12
+FLAT otherwise
+```
+
+All closes and arithmetic must be finite; closes must be positive.
+`Szz`, `Sww`, and `SSE` must exceed `1e-18`. The determinant must
+exceed `1e-12*Szz*Sww`, and `se_g` must exceed `1e-18`. Statistic
+magnitude never changes side or risk.
+
+## 4. Clock, Attempt, And Lifecycle
+
+Persist the normalized broker-month attempt before history reconstruction,
+signal, news, spread, quote, ATR, sizing, margin, or order gates. A consumed
+month is never retried. Reject late decisions, previous entry deals, owned
+exposure, or foreign `XTIUSD.DWX` exposure. Entry spread must be finite and
+within `[0,1500]` points.
+
+A qualified decision opens at most one market position through the V5
+fixed-dollar risk path with a frozen completed-bar `3.5*ATR(20,D1)` hard
+stop and no target. Close on the first processed tick in a later normalized
+broker month or after forty elapsed calendar days. Duplicate, wrong-symbol,
+invalid-type, wrong-side, missing-stop, malformed entry time, or inconsistent
+entry-month state triggers a defensive close. Restart recovery may use only
+matching owned deal history.
+
+There is no statistic exit, intramonth flip, Friday flatten, trail,
+break-even move, partial close, resize, scale-in, grid, martingale, pyramid,
+or retry. Both news axes, legacy news, Friday close, and stress rejection are
+locked off. Framework kill switch and broker hard stop remain authoritative.
+
+## 5. Source And Validation Boundary
+
+Chan supplies the lag-one ADF mechanics and displayed `-2.594` example
+boundary. Moskowitz, Ooi, and Pedersen supply monthly own-return continuation
+and WTI membership. Neither source validates this conjunction, sixty-month
+continuous-CFD sample, threshold transport, activity, economics, or
+correlation. Non-rejection-like state language must not be upgraded into a
+statistical or causal claim.
+
+Initialization runs deterministic qualifying-up, qualifying-down,
+mean-reverting-rejection, and degenerate fixtures. The independent Python
+suite checks the regression arithmetic, fixture receipt, additive-level
+invariance, boundary, direction, endpoints, attempt order, set/card/registry
+binding, and source guards.
+
+Q02 must retire the unchanged variant on zero positions, fewer than five
+completed positions in any full post-warm-up year, nonpositive governed
+economics, nondeterminism, or any formula, fixed-risk, stop, attempt, or
+lifecycle defect. No result-based parameter repair is authorized.
+
+## 6. Risk And Safety
+
+The baseline is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
+`PORTFOLIO_WEIGHT=1`; gaps can exceed modeled stop risk. Principal risks are
+continuous-CFD roll/basis/financing, single-carrier concentration,
+broker-month labeling, small-sample regression instability, overlapping
+windows, and persistence unrelated to tradable continuation.
+
+This build and Q02 queue item do not authorize live use, portfolio admission,
+correlation waiver, terminal control, `T_Live`, or AutoTrading.
+
+## Framework Alignment
+
+- `Strategy_NoTradeFilter`: identity, magic, fixed-risk and framework locks.
+- bounded helpers: month clock, attempt state, endpoints, ADF, side, restart.
+- `Strategy_EntrySignal`: exposure, spread, quote, ATR, frozen stop, order.
+- `Strategy_ManageOpenPosition`: malformed-state repair and time exits.
+- `Strategy_ExitSignal`: no discretionary exit.
+
+## Revision History
+
+| Version | Date | Reason | Notes |
+|---|---|---|---|
+| v1 | 2026-09-03 | approved-source build | G0-approved card; magic `413190000`; Q01 pending |
+
