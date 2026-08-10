# QM5_1626_hopwood-bermaui-stoch-h4 — Strategy Spec

**EA ID:** QM5_1626
**Slug:** `hopwood-bermaui-stoch-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Trend-following H4 oscillator strategy built on the Bermaui-family double-smoothing
kernel applied to the Stochastic %K line.

Signal construction (all on closed bars):
1. `%K_raw` = Stochastic %K (period 14, slowing 3) via the pooled `QM_Stoch_K` reader.
2. `%K_smooth1` = Wilder MA (period 7) of `%K_raw` — first (noise-reduction) pass.
3. `%K_smooth2` = Hull MA (period 7) of `%K_smooth1` — second (directional) pass. The
   Wilder and Hull passes are hand-rolled over a local array because the pooled MA
   readers only smooth a raw price series, not a derived buffer like `%K`.
4. `delta = smooth2[shift1] - smooth2[shift2]` (current-vs-previous closed bar).

The double-smoothed line and its delta are recomputed once per new H4 bar and cached
(`g_berm_cur` / `g_berm_prev` / `g_berm_delta`) so per-tick calls are O(1).

**Long entry:** `smooth2` mid-crosses up through 50 (`smooth2[shift2] < 50` and
`smooth2[shift1] >= 50`) AND `delta > 0` AND D1 close(1) > D1 SMA(200). Market-buy at
the next H4 bar open.
**Short entry:** mirror (mid-cross down, `delta < 0`, D1 close(1) < D1 SMA(200)).

**Exits:**
- *Reverse-signal* — an opposite-direction mid-cross with a confirming delta sign
  closes the position immediately (`QM_EXIT_OPPOSITE_SIGNAL`).
- *Time-stop* — 30 completed H4 bars close the position (`QM_EXIT_TIME_STOP`). Held-bar
  count is derived restart-safely from `POSITION_TIME` via `QM_TM_HeldPeriods` (walks the
  bar series; an EA restart cannot reset the clock).
- *Trailing* — at +1.0×ATR(14) open profit the stop moves to breakeven+spread
  (`QM_TM_MoveSL`, gated so it only ever tightens); at +2.0×ATR(14) open profit 50% of
  the position is closed once (`QM_TM_PartialClose`, `QM_EXIT_PARTIAL`).
- *Initial stop* — SL = 2.5×ATR(14) from entry (`QM_StopATR`); optional P3 swing anchor.

Implementation notes (judgment calls):
- The card lists both a "profit-target TP = 2.0×ATR" and a "close 50% at +2.0×ATR"
  trailing rule at the same level. A hard broker TP at 2.0×ATR would make the mandated
  partial-close unreachable (a limit TP fills intrabar before the bar-gated partial
  can evaluate). The 2.0×ATR profit target is therefore realized as the partial
  scale-out; no hard `tp` is placed on the order and the remaining half rides on the
  breakeven stop / reverse-signal / time-stop.
- Partial-close idempotency is tracked in a same-EA-run file-scope array keyed by
  `POSITION_TICKET` (not persisted across an EA restart — an accepted simplification;
  a mid-trade restart could allow one extra 50% scale-out).
- Breakeven / partial thresholds are measured against the current ATR(14) on the
  closed bar (stateless), not a frozen entry-time ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 14 | 9-21 | Raw Stochastic %K period |
| `strategy_stoch_d_period` | 3 | 1-5 | %D period (handle only; %D unused) |
| `strategy_stoch_slowing` | 3 | 1-5 | Stochastic slowing |
| `strategy_wilder_period` | 7 | 5-14 | Wilder MA first smoothing pass |
| `strategy_hma_period` | 7 | 5-14 | Hull MA second smoothing pass |
| `strategy_mid_line` | 50.0 | 45-55 | Cross threshold on the smoothed line |
| `strategy_sma_period` | 200 | 100-300 | D1 regime SMA period |
| `strategy_atr_period` | 14 | 10-20 | ATR period for SL/TP/BE distances |
| `strategy_range_atr_period` | 50 | 30-80 | Slow ATR for the range-sanity gate |
| `strategy_range_sanity_mult` | 0.5 | 0.3-0.8 | Skip entry if ATR14 < mult×ATR50 |
| `strategy_sl_atr_mult` | 2.5 | 1.5-3.0 | Initial SL distance = mult×ATR from entry |
| `strategy_tp_atr_mult` | 2.0 | 1.5-3.0 | Partial scale-out at mult×ATR open profit |
| `strategy_be_atr_mult` | 1.0 | 0.5-1.5 | Move to breakeven at mult×ATR open profit |
| `strategy_time_stop_bars` | 30 | 10-60 | Close after N completed H4 bars |
| `strategy_cooldown_bars` | 6 | 2-10 | No same-direction re-entry within N H4 bars |
| `strategy_max_spread_atr_mult` | 0.3 | 0.1-0.5 | Skip entry if spread > mult×ATR14 |
| `strategy_sl_swing_anchor` | false | true/false | Use swing-low/high SL instead of ATR SL |
| `strategy_swing_lookback` | 14 | 5-30 | Swing-anchor lookback (bars) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; the Bermaui-Stoch trend filter suits its
  multi-day H4 swings.
- `GBPUSD.DWX` — liquid FX major with higher volatility; benefits from the ATR-scaled
  stops and range-sanity gate.
- `NDX.DWX` — index CFD with persistent trend regimes that the D1 SMA(200) filter and
  double-smoothed cross capture well.
- `XAUUSD.DWX` — gold; strong directional runs suited to a slower oscillator cross.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (not broker-routable); a T6 live promotion would require
  parallel validation on `NDX.DWX` / `WS30.DWX` first.
- Sub-H1 timeframes / thin exotic FX crosses — the double-smoothing lags too far and
  the 12 trades/yr/symbol frequency assumption breaks down.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 (SMA-200 regime gate + close read)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~12 (range 8-18)` |
| Typical hold time | `several days (bounded by 30-bar / ~5-trading-day time-stop)` |
| Expected drawdown profile | `~20% peak-to-trough; ATR-scaled stops + partial scale-out` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` (ForexFactory
Trading-Systems — Hopwood-archive Bermaui-family cluster; Mohammed Bermaui's
Bermaui-Stochastic indicator)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1626_hopwood-bermaui-stoch-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | build_ea task 4ee453be |
