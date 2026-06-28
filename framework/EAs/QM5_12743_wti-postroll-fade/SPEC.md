# QM5_12743_wti-postroll-fade - Strategy Spec

**EA ID:** QM5_12743
**Slug:** `wti-postroll-fade`
**Source:** `CME-WTI-EXPIRY-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI post-roll fade on
`XTIUSD.DWX`. It approximates the monthly CME WTI expiry day from the broker
calendar, waits until the post-expiry window after the existing breakout
window, then fades a stretched D1 impulse back toward a short D1 mean. Positions
exit when mean reversion occurs, the post-roll window ends, max hold is reached,
or the framework Friday close applies.

The strategy is intentionally not a duplicate of `QM5_12600_cme-wti-exp-brk`:
that EA follows channel breakouts during the expiry window, while this EA starts
after that default window and takes the opposite side of a short post-roll
impulse. It is also distinct from early-month ETF roll fade, WTI month/weekday
calendar sleeves, WPSR/event sleeves, WTI trend sleeves, and XNG logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_post_start_days` | 3 | 3-5 | Calendar days after approximated expiry before entries start |
| `strategy_post_end_days` | 7 | 6-8 | Calendar days after approximated expiry when entries stop |
| `strategy_impulse_days` | 3 | 2-4 | D1 close-to-close impulse lookback |
| `strategy_min_abs_return_pct` | 2.0 | 1.0-3.0 | Minimum absolute D1 impulse to fade |
| `strategy_reversion_sma` | 10 | 8-14 | Short D1 mean used for entry stretch and exit |
| `strategy_close_location` | 0.65 | 0.60-0.70 | Required close location in the D1 range |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR stop multiplier |
| `strategy_max_hold_days` | 5 | 3-7 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` - the Darwinex WTI CFD proxy, registered at magic slot 0, used
  because the card targets only WTI post-roll behavior.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8.
- Expected frequency: 6-10 entries/year after post-roll window and impulse filters.
- Typical hold: one to five trading sessions.
- Regime preference: stretched WTI impulses after the immediate expiry/roll
  breakout window has passed.

## 6. Source Citation

Source packet: `CME-WTI-EXPIRY-BRK-2026`, using CME Rulebook Chapter 200, CME
futures expiration education, and CME WTI contract specifications. All R1-R4
checks are marked PASS in `strategy-seeds/cards/wti-postroll-fade_card.md` and
`strategy-seeds/cards/approved/QM5_12743_wti-postroll-fade_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, or live-terminal file is
touched by this build.

## Revision History

| Version | Date | Change | Author |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from card | Codex |
