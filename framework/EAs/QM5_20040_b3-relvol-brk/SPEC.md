# QM5_20040_b3-relvol-brk — Strategy Spec

**EA ID:** QM5_20040
**Slug:** `b3-relvol-brk`
**Source:** SILVA-FORCA-WIN-V16-2026
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

On each completed M15 bar, the EA multiplies signed candle body fraction by
relative broker tick count and clamps the result to a force score from -100 to
+100. A threshold cross qualifies only with a close beyond the prior bar and
aligned 5/20-bar close averages, then enters at that exact next M15 open during
the approved US session. The frozen stop is one Wilder ATR(14), the target is
1.5R, and any surviving trade exits after six completed holding bars or at
15:55 New York time (earlier on an approved early close).

Tick volume is explicitly a broker tick-count proxy, not traded volume,
aggression, order flow, book data, or tape evidence. The practitioner source
and its performance comments remain **UNVERIFIED**.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `B3_RELVOL_BRK_BASELINE` | locked | Approved variant identity. |
| `strategy_signal_tf` | `PERIOD_M15` | locked | Signal, execution, and timeout timeframe. |
| `strategy_force_level` | 70 | locked | Symmetric force-cross threshold. |
| `strategy_rearm_level` | 25 | locked | Absolute-force level below which both directions may rearm. |
| `strategy_volume_sma_period` | 20 | locked | Tick-count normalization window. |
| `strategy_fast_sma_period` | 5 | locked | Fast close-alignment average. |
| `strategy_slow_sma_period` | 20 | locked | Slow close-alignment average. |
| `strategy_atr_period` | 14 | locked | Wilder ATR window frozen on the signal bar. |
| `strategy_atr_stop_mult` | 1.0 | locked | Initial hard-stop distance in ATR units. |
| `strategy_reward_r` | 1.5 | locked | Frozen target in initial-risk units. |
| `strategy_timeout_bars` | 6 | locked | Completed holding bars before time exit. |
| `strategy_max_cost_r` | 0.10 | locked | Maximum commission plus entry spread relative to initial risk. |
| `strategy_round_turn_commission_usd_per_lot` | 0.0 | governed value required | Per-symbol commission; zero fails closed. |
| `strategy_cash_calendar_file` | `QM5_20040_us_cash_calendar.csv` | immutable file | Common-Files official US sessions and early closes. |
| `strategy_cash_calendar_sha256` | empty | SHA-256 | Required exact calendar-file hash. |
| `strategy_calendar_valid_through` | `2025.12.31` | locked | Required official calendar coverage. |
| `strategy_tzdb_version` | empty | governed value required | Pinned America/New_York tzdb identity. |
| `strategy_expected_tick_feed_server` | empty | governed value required | Frozen broker tick-feed server identity. |

## 3. Symbol Universe

**Designed for:**

- `WS30.DWX` — primary card route for the US index participation proxy.
- `SP500.DWX` — card-authorized US large-cap sibling route.
- `NDX.DWX` — card-authorized US technology-index sibling route.

**Explicitly NOT for:**

- Other `.DWX` symbols — no other route is approved for this card's
  feed-specific relative-tick-volume hypothesis.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` edge advances the cached force/rearm state before entry gating |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 135 after all gates |
| Typical hold time | no more than six completed M15 holding bars; often shorter at stop, target, or session exit |
| Expected drawdown profile | approximately 12% card prior; losses may cluster across the correlated US-index family |
| Regime preference | intraday directional participation / relative-tick-volume breakout |
| Win rate target (qualitative) | unverified; expectancy must survive feed and price-only ablations |

## 6. Source Citation

This card was mechanised from:

**Source ID:** SILVA-FORCA-WIN-V16-2026
**Source type:** unverified practitioner NTSL source code
**Pointer:** Wesley Silva (2026), `FORCA_WIN_V16`, Git commit
`38e83c24070054d78d82842c7c1b37043127ef58`; implementation card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20040_b3-relvol-brk_card.md`.
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20040_b3-relvol-brk.md`; source performance and
US `.DWX` portability remain unverified hypotheses.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The approved baseline authorizes fixed-risk testing only; live sizing remains a
later governed promotion decision.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | 4648f988-fd51-45e5-95db-e080e5108c03 |
