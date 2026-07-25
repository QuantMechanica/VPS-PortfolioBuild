# STR-132 — Codex independent mechanization spec

## 1. Scope and source boundary

- Strategy: USD/JPY pre-Tokyo range breakout with a two-hour OCO entry window and split 40/70-pip profit objectives.
- Source read: `00_source.md`, especially posts #1, #7, #10-11, #18, #34-36, #61-63, #75, #83-85, #95-99, and #107.
- Ledger row: `STR-132` in `SOURCE_LEDGER.csv`.
- Mandated overlap implementations checked: `QM5_20107_asian-range-straddle-m15` and `QM5_9936_ff-range-breakout-gmt3-h1`.

## 2. Cohort, timeframe, and clock

- Sole instrument: `USDJPY.DWX`.
- Execution and range-reconstruction timeframe: `M15`.
- Daily key and all source session boundaries use America/New_York civil time ("ET"), resolved with the approved `QM_DSTAware` pattern after `QM_BrokerToUTC`.
- Range window: ET `[18:00, 20:00)`, comprising the eight completed M15 bars opened from 18:00 through 19:45.
- Entry window: ET `[20:00, 22:00)`. At 22:00 ET, unfilled orders expire and no new entry is allowed.
- Do not hard-code the source's parenthetical `22:00-00:00 GMT`; it conflicts with literal "EST" during part of the year. See FLAG-132-01.
- Broker feed: DarwinexZero New-York-close GMT+2/GMT+3.

## 3. Numbered mechanized rules

1. For each ET trading date, load exactly the completed M15 bars whose ET opens fall in `[18:00, 20:00)`.
2. Set `range_high` to their maximum high and `range_low` to their minimum low, including wicks.
3. If all eight bars are not fresh and complete, or the range is non-positive, block the ET date and emit setup/data-missing evidence.
4. Define one pip with the framework symbol-aware pip helper; on three-digit USD/JPY quoting, two pips are not two `_Point` units.
5. At 20:00 ET, calculate `buy_stop = range_high + 2.0 pips` and `sell_stop = range_low - 2.0 pips`, normalized outward to the trade tick.
6. Submit both pending sides as an OCO pair only when both sides and their protective stops are simultaneously legal. Never leave a one-sided straddle because the other request failed.
7. The first filled side is the sole directional entry for that ET date. Immediately delete the opposite pending order.
8. If neither side fills before 22:00 ET, delete both and mark the date no-trade.
9. After any fill, stop, target, rejection, or OCO anomaly, do not re-enter or reverse that ET date.
10. Size one total position so its full protective-stop loss equals `RISK_FIXED` in backtests or at most `1%` of live equity. The source's 3% is overridden by house policy.
11. Implement the source's two equal lots as one position per magic with a 50% partial close at `fill +/- 40 pips` and a runner objective at `fill +/- 70 pips`.
12. The position volume must be splittable into two legal halves after volume-step normalization. If not, reject the date rather than distort the 50/50 payoff.
13. Initial protective-stop distance is `15.0 pips + captured spread`, in the adverse direction from the entry reference defined in FLAG-132-02. Apply the same total-risk distance to the full position.
14. Do not move the protective stop before the 40-pip objective is confirmed filled.
15. When the 50% partial close at 40 pips is confirmed, move the remaining position stop to actual fill break-even (`+0 pips` primary) and retain the 70-pip runner objective.
16. Server-side stop/target and framework recovery logic must make partial-close and break-even transitions idempotent across restart.
17. The source defines no ordinary end-of-day exit for a filled position. Hold until stop, 40/70 management, or a mandatory framework Friday/risk exit.
18. If a prior position remains open when the next ET setup begins, skip the new date; never stack positions.
19. Apply mandatory high-impact news blackout and stale-calendar fail-closed behavior. A blackout intersecting the two-hour entry window blocks the date rather than leaving triggerable pendings.
20. No grid, martingale, ML, averaging, trailing-stop variant, trend filter, or second-chance trade belongs in the primary projection.

## 4. Inputs

| Input | Primary value | Status |
|---|---:|---|
| `strategy_range_start_et_hhmm` | `1800` | Source-fixed civil ET |
| `strategy_range_end_et_hhmm` | `2000` | Source-fixed civil ET |
| `strategy_entry_cutoff_et_hhmm` | `2200` | Source-fixed civil ET |
| `strategy_entry_offset_pips` | `2.0` | Source-fixed; do not optimize in primary |
| `strategy_stop_base_pips` | `15.0` | Source-fixed |
| `strategy_stop_add_spread` | `true` | Source-fixed; timing flagged |
| `strategy_tp1_pips` | `40.0` | Source-fixed |
| `strategy_tp1_fraction` | `0.50` | Source-equivalent |
| `strategy_tp2_pips` | `70.0` | Source-fixed |
| `strategy_runner_be_plus_pips` | `0.0` | Primary; `+1.0` is a separate source variant |
| `strategy_one_entry_per_et_date` | `true` | Source-fixed |
| `RISK_FIXED` | `> 0` in backtests | House-required |
| `RISK_PERCENT` | `0` in backtests; `> 0` and `<= 1.0` live | House-required |
| `qm_news_stale_max_hours` | `<= 336` | Guardrail; never weaken |

## 5. Five-hook sketch

### `Strategy_NoTradeFilter`

- Validate `USDJPY.DWX`, M15 history, ET conversion, exactly eight range bars, both-side pending geometry, splittable volume, one-entry/day state, no carried position, news freshness, and framework risk state.
- Before placing the OCO pair, query the mandatory blackout over the full `[20:00, 22:00)` ET entry window. If it intersects, block the date.
- Fail closed if one pending side cannot be protected or placed.

### `Strategy_EntrySignal`

- At the first eligible tick at/after 20:00 ET, construct both pending requests at exactly `range +/- 2.0 pips`.
- Use a two-phase/idempotent placement routine so restart cannot duplicate either side.
- After the first deal, cancel the sibling pending immediately and mark the ET date consumed.
- At/after 22:00 ET, remove unfilled requests and return no entry.

### `Strategy_ManageOpenPosition`

- Before TP1: leave the initial stop unchanged.
- On confirmed 50% close at +40 pips: record the partial state, move the runner stop to fill break-even, and retain +70 pips as target.
- On restart, reconstruct state from deal/order history before taking another management action.
- Do not trail or re-arm the opposite direction.

### `Strategy_ExitSignal`

- Ordinary strategy exits are the initial stop, the 40-pip partial, runner break-even, and 70-pip target.
- Return no daily time exit because the source supplies none.
- Mandatory framework Friday, daily-loss, and portfolio drawdown exits remain active.

### `Strategy_NewsFilterHook`

- Apply the fail-closed high-impact blackout for USD and JPY.
- If calendar freshness fails or a blocked event intersects the pending window, remove any unfilled strategy orders and consume the date.

## 6. Interpretation flags

- **FLAG-132-01 — ET versus fixed GMT conflict.** The source repeatedly says 18:00-20:00 Eastern and 22:00 cutoff, but also labels this 22:00-00:00 GMT while calling the clock EST. April 2011 New York was on daylight time, making that conversion EDT-specific. Primary interpretation follows ET civil time with DST awareness; a fixed-UTC window would be a separate cohort.
- **FLAG-132-02 — spread snapshot timing is unstated.** "15 pips + spread" is explicit, but the source does not say whether spread is captured at order placement or fill. Primary implementation captures the live spread used when the protected pending pair is placed and never widens the stop later. An on-fill spread snapshot is a separately labeled variant; no constant spread may be invented.
- **FLAG-132-03 — two orders versus one position.** The source opens two equal lots; post #75 describes one double-sized position with a 50% partial close as mechanically equivalent. House policy permits one position per magic, so the primary uses one position and an idempotent partial close.
- **FLAG-132-04 — break-even versus +1 pip.** The source permits either. Primary is exact break-even; `+1 pip` must be a separately declared variant and must not be pooled.
- **FLAG-132-05 — OCO race.** The source explicitly requires deleting the other side after the first trigger. If both sides fill before cancellation can complete, treat the later fill as an execution anomaly, flatten it safely, block the date, and preserve evidence. It is not a second valid trade.
- **FLAG-132-06 — no filled-position time exit.** The 22:00 cutoff governs entry only. Once filled, the source leaves the trade to stop/targets; the only additional exits are mandatory house safety exits.
- **FLAG-132-07 — hype and empirical disagreement.** The claimed 60% win rate and 100% monthly growth are not specification inputs. A participant's 180-day test reports roughly 40% wins/60% losses and at least 25% no-trade dates; only Q-phase evidence may determine a verdict.

## 7. Mandatory overlap analysis

| Dimension | STR-132 primary | `QM5_20107_asian-range-straddle-m15` (STR-016) | Live `QM5_9936_ff-range-breakout-gmt3-h1` |
|---|---|---|---|
| Instrument / TF | USDJPY, M15 | USDJPY, M15 | USDJPY plus GBPUSD/NDX, H1 |
| Range clock | 18:00-20:00 ET, 2 hours | 01:00-06:00 broker time, 5 hours | 01:00-06:00 fixed GMT+3, 5 hours |
| Entry level | Exactly 2.0 pips outside range | At range borders | At range borders |
| Pending window | 20:00-22:00 ET, 2 hours | Until 13:00 broker time | Until 13:00 GMT+3 |
| OCO / entries | Opposite deleted; one direction/date | Opposite survives a fill; up to two sides/date | Opposite deleted after fill |
| Initial stop | Fixed 15 pips plus observed spread | Opposite range border | Opposite range border |
| Profit logic | 50% at +40, runner +70, then BE | No TP; previous completed M15-bar extreme trail | No TP; after +1R, prior-two-H1-bar trail |
| Other exits | No ordinary filled-position time exit | Flat at 20:00 broker time | Flat at 20:00 GMT+3 and opposite-border touch |
| Range filters | None | Invalid/boundary-pre-cross date blocking | ATR range filter, 0.4x-2.5x ATR |

Concrete conclusion: STR-132 belongs to the same Asian-session range-breakout family, but it is materially different from both implementations. Its two-hour ET clock, exact two-pip offset, fixed spread-aware stop, one-trade OCO rule, and fixed split-target payoff are all independent economic mechanics. Reusing either existing EA with only parameter changes would not reproduce STR-132. Dedup review should retain it as a distinct candidate, with portfolio correlation assessed downstream.

## 8. Risk and policy notes

- Source 3% weekly-compounded risk is incompatible with house policy and is not carried forward. Total live position risk is `<=1%`.
- Backtests use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- Mandatory news blackout, Friday close, daily drawdown, and total drawdown protections are house safety overlays.
- No commission, swap, slippage, spread, or DST value is fabricated; Q evidence must use observed/modelled values.
- The strategy is mechanical, non-HFT, and contains no ML, martingale, grid, or stacking.
