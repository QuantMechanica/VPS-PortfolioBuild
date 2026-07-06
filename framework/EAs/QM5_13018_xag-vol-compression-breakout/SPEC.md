# QM5_13018_xag-vol-compression-breakout — Strategy Spec

**EA ID:** QM5_13018
**Slug:** `xag-vol-compression-breakout`
**Source:** `GR-COMMODITY-FACTS-2006` (see `strategy-seeds/sources/GR-COMMODITY-FACTS-2006/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-06

---

## 1. Strategy Logic

On each completed `XAGUSD.DWX` D1 bar, compute ATR(10) and the min/max of
ATR(10) over the trailing 120 D1 bars. The market is "compressed" when the
current ATR(10) sits at or below `ATR_min + (ATR_max - ATR_min) * 33.3%` —
the bottom tercile of its own trailing range. While compressed, a D1 close
above the Donchian(20) high (prior 20 bars) signals a long entry; a D1 close
below the Donchian(20) low signals a short entry. One position at a time.
Exit via a fixed ATR(14) x 2.5 hard stop set at entry, a Donchian(10)
channel-trail full close (long closes on a D1 close below the trailing
10-bar low, short closes on a D1 close above the trailing 10-bar high), or a
40-bar time stop — whichever comes first. No stop tightening beyond the
channel trail; no pyramiding, gridding, martingale, or partial close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_compress_period` | 10 | 7-14 | ATR period used for the compression gate. |
| `strategy_compress_window_d1` | 120 | 80-160 | Trailing D1 bars spanning the ATR min/max range. |
| `strategy_compress_pct` | 33.3 | 25.0-40.0 | Bottom-tercile threshold, as % of the ATR_min..ATR_max span. |
| `strategy_donchian_entry` | 20 | 15-30 | Donchian breakout lookback (entry trigger, prior bars only). |
| `strategy_donchian_trail` | 10 | 8-15 | Donchian channel-trail lookback (exit trigger). |
| `strategy_atr_period` | 14 | 10-20 | ATR period used for the hard-stop distance. |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | Hard-stop distance = ATR(strategy_atr_period) * this multiple. |
| `strategy_max_hold_bars` | 40 | 30-55 | Time stop: close after this many D1 bars in the trade. |
| `strategy_max_spread_points` | 200 | 120-300 | Entry-only spread cap in points; never blocks management/exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `XAGUSD.DWX` — silver is the sole subject of the card's compression/breakout
  hypothesis (Gorton/Rouwenhorst and Erb/Harvey commodity vol-cycle
  literature); card frontmatter sets `single_symbol_only: true`.

**Explicitly NOT for:**
- Any other symbol — the card is a deliberately single-symbol volatility-cycle
  breakout on silver, distinct from existing XAU/XAG ratio, oil/silver or
  gas/silver basket, RSI pullback, or calendar silver sleeves already in the
  factory.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default chart symbol/period) via the framework's single-consume gate in `OnTick`; strategy state (Donchian-trail reading, hold-bar counter) is refreshed once per closed bar inside `Strategy_EntrySignal` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8-14 (estimate 10) |
| Typical hold time | days to ~40 D1 bars (time-stop bound) |
| Expected drawdown profile | expected_dd_pct 18% — ATR hard stop and time stop bound each trade, but silver gaps/vol bursts are real |
| Regime preference | volatility-expansion / breakout, gated to compression-phase transitions only |
| Win rate target (qualitative) | medium — expected_pf 1.15; breadth is deliberately traded for follow-through quality |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `GR-COMMODITY-FACTS-2006`
**Source type:** `paper`
**Pointer:** Gorton, Gary and K. Geert Rouwenhorst. "Facts and Fantasies about
Commodity Futures." Financial Analysts Journal, 62(2), 2006.
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=560042; supplement Erb,
Claude B. and Campbell R. Harvey. "The Strategic and Tactical Value of
Commodity Futures." Financial Analysts Journal, 62(2), 2006.
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=650923.
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_13018_xag-vol-compression-breakout.md`

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
| v1 | 2026-07-06 | Initial build from card | e6a032bf-0d38-4fa7-94d9-533340353b19 |
