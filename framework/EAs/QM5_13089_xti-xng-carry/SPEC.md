# QM5_13089_xti-xng-carry - Strategy Spec

**EA ID:** QM5_13089  
**Slug:** `xti-xng-carry`  
**Source:** `KOIJEN-CARRY-2018`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a D1 market-neutral energy carry basket on `XTIUSD.DWX`
and `XNGUSD.DWX`. Once per configured broker weekday, it compares the broker
swap carry edges for the two legs:

`carry_edge = SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT`

If WTI's carry edge is better than natural gas by at least the configured
threshold, the package buys WTI and sells natural gas. If natural gas has the
better carry edge, it sells WTI and buys natural gas. If `.DWX` tester symbols
expose all swap fields as zero, the documented deterministic fallback opens
long WTI / short natural gas so the test harness does not collapse to zero
trades. A 12-month return guard blocks packages where either intended leg has
already drifted strongly against its proposed direction.

This is intentionally different from the existing XTI/XNG return-spread
reversion basket (`QM5_12840`), the XTI/XNG vol-compression breakout basket,
single-symbol XTI/XNG carry sleeves, fixed seasonal energy switches, WTI event
or inventory sleeves, and `QM5_12567` commodity RSI/pullback logic. The signal
is a cross-energy carry ranking, not price return, calendar ownership,
inventory timing, RSI, or z-score reversion.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rebalance_weekday` | 1 | 1-5 | Broker weekday for weekly package entry; Monday=1 |
| `strategy_return_lookback_d1` | 252 | 189-315 | D1 lookback for adverse-drift guard |
| `strategy_max_adverse_return_pct` | 25.0 | 15-40 | Max adverse 12M drift allowed against intended leg |
| `strategy_min_pair_swap_edge` | 0.0 | 0-1 | Minimum XTI-vs-XNG swap edge difference |
| `strategy_zero_swap_fallback_direction` | 1 | -1/0/1 | Tester tie fallback; 1 = long XTI/short XNG |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for each leg's hard stop |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | Per-leg ATR stop multiplier |
| `strategy_max_hold_days` | 7 | 3-10 | Stale package exit |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | WTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | Natural-gas entry spread cap |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13089_XTI_XNG_CARRY_D1`.
- Host symbol: `XTIUSD.DWX`, magic slot 0.
- Second leg: `XNGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 30-52 paired packages/year before Q02
  proves or rejects the hypothesis.
- Typical hold: one broker week, subject to Friday close and carry-rank flips.
- Regime preference: structural relative carry differences between WTI and
  natural gas where the package is not already fighting an extreme 12M drift.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018).
"Carry." Journal of Financial Economics, 127(2), 197-225.
DOI: https://doi.org/10.1016/j.jfineco.2017.11.002.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.

