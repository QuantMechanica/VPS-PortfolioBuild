# QM5_41319 — WTI Monthly Lag-One ADF Persistence Trend

**EA ID:** QM5_41319
**Slug:** `wti-madf-persist-tr`
**Source:** `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903`
**Author of this spec:** Codex
**Last revised:** 2026-09-06

## 1. Strategy Logic

This EA is a direct, low-frequency `XTIUSD.DWX` sleeve. On the first eligible
tick of each broker month it reconstructs 60 completed monthly WTI closes and
fits the approved constant/no-time-trend ADF regression with one lagged first
difference. It trades in the direction of the newest 12-month log return only
when the lagged-level t-statistic is at least `-2.594`; otherwise the month is
consumed flat.

An entry receives a frozen `3.5 * ATR(20,D1)` broker stop and no target. The EA
closes at the next broker-month transition or after 40 calendar days as stale
repair. Statistic magnitude never changes position size, and no intramonth
flip, retry, scale-in, grid, martingale, trailing stop, or partial close exists.

## 2. Parameters

All strategy parameters are locked for Q02; changing any value creates a new
strategy identity.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_level_count` | 60 | locked: 60 | Completed chronological month-end log-price levels |
| `strategy_regression_observations` | 58 | locked: 58 | ADF regression rows |
| `strategy_residual_dof` | 55 | locked: 55 | Residual degrees of freedom |
| `strategy_energy_floor` | `1e-18` | locked: `1e-18` | Degenerate-variance and residual-energy floor |
| `strategy_determinant_relative_floor` | `1e-12` | locked: `1e-12` | Ill-conditioned-regression rejection floor |
| `strategy_adf_t_min` | `-2.594` | locked: `-2.594` | Inclusive persistence-state boundary |
| `strategy_momentum_months` | 12 | locked: 12 | Completed-month continuation horizon |
| `strategy_direction_epsilon` | `1e-12` | locked: `1e-12` | Symmetric neutral-return band |
| `strategy_history_bars` | 1200 | locked: 1200 | Bounded D1 endpoint scan |
| `strategy_entry_grace_minutes` | 180 | locked: 180 | First-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked: 10 | Newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked: 20 | Completed-D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked: 3.5 | Frozen hard-stop multiplier |
| `strategy_stale_days` | 40 | locked: 40 | Survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | locked: 1500 | Inclusive entry spread ceiling |

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved continuous WTI CFD carrier, registered at slot 0
  with magic `413190000`.

**Explicitly not for:**

- `XNGUSD.DWX` — natural gas has distinct weather and storage drivers and is
  outside this direct-WTI card.
- FX, indices, and metals — the fixed ADF threshold and source translation were
  not approved for those carriers.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Completed broker-month endpoints reconstructed from D1 history |
| Decision gate | First executable tick after a genuine broker-month transition |
| Current-bar policy | Current-month prices are excluded; only completed endpoints are used |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 7–11; planning center 8; Q02 requires at least 5 in every full scored year |
| Typical hold time | Until the next broker month, with a 40-day stale-repair ceiling |
| Expected drawdown profile | High-risk single-energy sleeve; card prior 30%, with gap and CFD roll risk |
| Regime preference | Persistent directional WTI regimes with weak negative error correction |
| Win rate target | Unspecified; governed economics are established only by Q02 and later gates |

## 6. Source Citation

**Source ID:** `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903`
**Source type:** Governed synthesis supported by a complete Wiley book
extraction and peer-reviewed trading paper
**Pointer:** `strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md`
**R1–R4 verdict:** G0 `APPROVED`; see
`strategy-seeds/cards/approved/QM5_41319_wti-madf-persist-tr_card.md`.

Chan (2013) supplies the lag-one ADF mechanics and displayed `-2.594`
boundary. Moskowitz, Ooi, and Pedersen (2012) supply monthly own-return
continuation and explicit WTI membership. Neither source validates this exact
conjunction, continuous-CFD implementation, activity, economics, or portfolio
correlation.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | `RISK_FIXED` | $1,000 per trade; `RISK_PERCENT=0`; `PORTFOLIO_WEIGHT=1` |
| Live burn-in (Q13) | Not authorized by this build | Requires OWNER-signed manifest and the Q13 convention |
| Full live | Not authorized by this build | Requires completed gates and OWNER allocation |

The framework enforces the risk-mode contract. This build does not authorize
portfolio admission, `T_Live`, AutoTrading, or any deploy/live manifest change.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, magic, fixed-risk, news, Friday, stress,
  period, and locked-input checks.
- Bounded helpers: month clock, durable attempt state, completed endpoints,
  centered OLS, direction, and restart checks.
- `Strategy_EntrySignal`: exposure, spread, quote, ATR, stop, sizing, and margin.
- `Strategy_ManageOpenPosition`: malformed-state repair and time exits.
- `Strategy_ExitSignal`: no discretionary exit; lifecycle exits are handled by
  the management hook and framework kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | Initial build from approved card | Source and EA implementation committed |
| v1.1 | 2026-09-06 | Q01 spec repair and compile recovery | Restored the seven canonical Q01 headings; build task `cd3a3f60-895d-49cc-850c-c2c42f09cc9d` |
