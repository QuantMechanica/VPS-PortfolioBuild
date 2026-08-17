# P4 — Q14 cohort expansion, batch 1 of the 25 non-cohort survivors

OWNER agenda 2026-08-17 P4: expand the frozen cohort from 9 towards the full Q10-PASS
population, hypothesis-driven (Unger discipline), one named lever plus a falsifiable prose
hypothesis plus a refutation criterion per entry, in batches of five. Non-delegable design
work.

## The finding that reorders this task

Measured against the programme's own admission gates in `opt_program.v1.json`, using the
authoritative `ea_metrics` join that `q14_opt_admission.load_q10_population` uses — not my
own JSON heuristic, which found nothing because the metrics live in a table:

| Lever | Gate | Admissible among the 25 |
|---|---|---:|
| `EXIT_SURGERY` | `min_trades: 60` | **20** |
| `VOL_REGIME_FILTER` | `min_trades: 150` **and** `min_max_drawdown_pct: 12` | **0** |
| `LOCKED_PORT` | `carrier_list_required: true` | portfolio construct, not a single-pair lever |
| `MTF_ENTRY` | `backlog_only: true` | not available for new entries |

**Not one of the 25 survivors clears the 12% drawdown floor.** The whole population sits
between 1.18% and 9.81%:

```
13036/GDAXI 8.08   12969/USDJPY 2.02  11165/EURUSD 3.81  12778/AUDUSD 3.57
10403/XAUUSD 7.34  13117/EURGBP 3.05  11165/AUDCAD 4.41  11708/EURUSD 4.37
10513/XAUUSD 4.14  10123/XAUUSD 2.95  11421/EURUSD 6.45  10939/GBPUSD 6.19
11421/AUDUSD 5.59  12567/XAUUSD 2.37  11132/SP500 3.01   1567/EURUSD 8.83
13013/NDX 3.82     10142/SP500 4.61   10938/GDAXI 6.87   20048/XTIUSD 1.18
1328/EURJPY 9.81   13128/NDX 1.25     1556/XAUUSD 2.68   12989/XAUUSD 6.48
10919/XTIUSD 1.85
```

Two consequences, and the second is a question for OWNER:

1. **The binding constraint on cohort expansion is the drawdown gate, not hypothesis
   authorship.** Expansion is therefore an `EXIT_SURGERY` programme for 20 pairs, not a
   mixed-lever programme for 25. This is the same cause that produced the three existing
   `MAX_DRAWDOWN_BELOW_12` rejections (QM5_10128, 10145, 10183, all XAUUSD).
2. **`VOL_REGIME_FILTER` can never fire on this population.** A lever gated at ≥12% DD when
   the entire survivor pool tops out at 9.81% has no reachable target outside the cohort.
   Either the floor was calibrated against a different population, or the lever is
   effectively retired for survivors the current Q05/Q06 drawdown gates admit. Worth noting
   that the low drawdowns are *good news* about the pipeline — the gates are working — and
   that this lever was designed to shape drawdown that these EAs do not have. **This is a
   programme calibration question, not something to fix by lowering the floor unilaterally.**

Five pairs fall below even the 60-trade `EXIT_SURGERY` floor and are **not admissible under
any currently-enabled lever**: `QM5_1328`/EURJPY (58), `QM5_13128`/NDX (57),
`QM5_1556`/XAUUSD (53), `QM5_12989`/XAUUSD (51), `QM5_10919`/XTIUSD (30). They are recorded
here so they are not silently dropped; they need either more history or a lever that does not
exist yet.

Grounding data: `artifacts/p4_survivor_cohort_candidates_20260817.json`.

## Batch 1 — four proposed entries, one examined and set aside

Every hypothesis below is written against the EA's actual mechanics, read from source, and
against the programme's real objective for `EXIT_SURGERY`: **maximise `annual_return_pct`
with `require_maxdd_not_worse` and `require_worst_day_not_worse`, robust across Q04/Q06/Q08.**
Standalone profit factor is *not* the objective — my first draft of these hypotheses used PF
targets and was wrong on that point.

Surface discipline follows the existing profiles exactly: one integer parameter, an incumbent,
**exactly two candidate values**, bounded, `"Select on DEV only; freeze one candidate before
Q04 OOS"`.

---

### 1. `QM5_13036` / GDAXI.DWX — `EXIT_SURGERY`, profile `exit_13036_gdaxi_hhmm`

**Mechanics.** Long-only intraday: entry in a 30-minute window from broker 09:05
(`strategy_gdaxi_entry_hhmm=905`), hard clock exit at broker 22:55
(`strategy_gdaxi_exit_hhmm=2255`), SMA-200 regime permission for longs, ATR-14 × 2.5 stop.
1,352 trades, PF 1.04, DD 8.08%.

**Hypothesis.** The position is held roughly fourteen hours, through the entire US session and
past the cash close, although the regime filter and the entry window both key off the European
morning. After the US close the instrument's remaining move is dominated by overnight
positioning rather than by the intraday regime the entry was selected on. Retiring the exit to
just after the US cash close should retain the part of the day the edge was chosen for and shed
the low-information tail, raising annual return per unit of risk without touching the entry
window, the regime filter or the stop.

**Refutation.** If the edge is uniformly distributed across the holding period, truncating it
reduces annual return roughly in proportion to the hours removed. The hypothesis is refuted if
`annual_return_pct` does not improve at either candidate exit, or if `maxdd` or worst-day
worsens at both — the latter would mean the late session was hedging intraday risk rather than
diluting it.

**Surface.** `strategy_gdaxi_exit_hhmm`, incumbent `2255`, candidates `[2200, 2130]`.
*(HHMM-encoded, unlike the existing `strategy_exit_hour` profiles — the profile must validate
the encoding, not assume hours.)*

---

### 2. `QM5_11165` / EURUSD.DWX — `EXIT_SURGERY`, profile `exit_11165_hold_bars`

**Mechanics.** H1 RSI(9) mean reversion with SMA-200 regime: long below RSI 25, short above
75, exit at RSI 50, 1% stop, `strategy_max_hold_bars=60`. 260 trades, PF 1.07, DD 3.81%.

**Hypothesis.** The primary exit is a mean-line crossing (RSI 50); the 60-bar cap is a
backstop that only binds when reversion fails to complete. At PF 1.07 the marginal trades are
near breakeven, and a 60-hour backstop keeps failed-reversion positions open across two and a
half days — long enough for a trending move to run against a position the strategy has already
been wrong about. Tightening the backstop should cut the tail of failed reversions earlier
while leaving every completed reversion untouched, because completed reversions exit on RSI 50
well inside the cap.

**Refutation.** If reversions routinely complete *after* bar 36, a tighter cap converts winners
into stopped-out trades and annual return falls. Refuted if `annual_return_pct` degrades at
both candidates, or if trade count falls by more than a few percent — a large drop in count
would mean the cap is binding on ordinary trades, not just on the failed tail.

**Surface.** `strategy_max_hold_bars`, incumbent `60`, candidates `[36, 48]` — mirroring
`exit_10692_hold_bars`.

---

### 3. `QM5_11165` / AUDCAD.DWX — `EXIT_SURGERY`, profile `exit_11165_hold_bars`

Same EA, same lever, same surface, second symbol. 207 trades, PF 1.14, DD 4.41%.

**Why both symbols.** `caps.max_cards_per_parent = 2`, so two symbols × one lever is exactly
the permitted budget for this parent — no third card is possible and none is proposed. Running
the identical surface on two symbols is also the cheapest available test of whether the
failed-reversion tail is a property of the mechanic or of EURUSD: if the same cap helps on one
symbol and hurts on the other, the hypothesis is about the symbol, not the strategy, and
should not be generalised.

**Refutation.** As above, per symbol. Additionally: divergent direction between the two symbols
refutes the mechanical reading even if one symbol improves.

---

### 4. `QM5_10403` / XAUUSD.DWX — `EXIT_SURGERY`, profile `exit_10403_exit_channel`

**Mechanics.** Donchian breakout on D1: entry on the 20-bar channel
(`strategy_entry_channel=20`), exit on the 10-bar opposite channel
(`strategy_exit_channel=10`), ATR-20 × 2.0 stop, ATR regime filter present but **disabled**
(`strategy_atr_regime_filter=false`). 209 trades, PF 1.31, DD 7.34%.

**Hypothesis.** This is the classic turtle asymmetry: a 20-bar entry paired with a 10-bar exit
exits on half the lookback that admitted the trade, so a normal pullback inside an intact trend
closes the position. Gold trends persist well beyond ten daily bars. Widening the exit channel
should hold intact trends through ordinary retracement and raise annual return, while the
unchanged ATR stop still bounds the loss on genuine reversals — so drawdown should not worsen
even though positions are held longer.

**Refutation.** If gold's post-breakout moves mean-revert inside twenty bars, a wider exit
channel gives back open profit and both annual return and max drawdown worsen. Refuted if
`annual_return_pct` fails to improve at either candidate, or if `require_maxdd_not_worse`
fails at both. Note the disabled ATR regime filter is deliberately **left disabled**: enabling
it would be a second, confounded change.

**Surface.** `strategy_exit_channel`, incumbent `10`, candidates `[15, 20]`.

---

### Examined and set aside: `QM5_11708` / EURUSD.DWX

178 trades, PF 1.30, DD 4.37%, admissible for `EXIT_SURGERY` on trade count. Its strategy
inputs are `strategy_range_fraction`, `strategy_sl_range_mult`, `strategy_fallback_pips`,
`strategy_order_valid_days`, `strategy_enable_variant_b`. **None of these is an exit-timing
parameter** — `strategy_order_valid_days` is a pending-order expiry on the entry side, and the
exit lives entirely in `Strategy_ExitSignal()` with no exposed parameter.

Forcing an `EXIT_SURGERY` surface onto it would mean either tuning an entry parameter under an
exit lever, or adding a new input to the EA — the latter is what `exit_11422_new_hold_bars`
does via an explicit `implementation_contract`, so it is a legitimate pattern, but it is an EA
code change and belongs in its own batch with its own review. **Set aside rather than
lever-shopped.** It is a candidate for a later batch under that contract pattern.

## Status and next step

These four are a **draft**, not yet applied. Writing them into `opt_program.v1.json` changes
`program_config_sha256` and the frozen `cohort_freeze`, which the Q14 admission binds against
a `q10_snapshot_sha256` — so the config edit should land as one deliberate commit once the
batch is reviewed, not incrementally. Applying it is the next step, followed by a Q14
admission dry-run to confirm each new entry is admitted with the expected reason string
(`TRADES_GTE_60`).

Remaining after batch 1: 16 of the 20 `EXIT_SURGERY`-admissible pairs, plus the 5 inadmissible
ones pending a programme answer on the drawdown floor.

**Re-synchronisation, per OWNER: 34 is a state, not a target.** Once the Q09 dam clears and
Q10 grows, new survivors must be checked against the cohort and admitted under the same
discipline. A Q10 survivor with no cohort entry is from now on a finding, not a normal state —
that check belongs in the runbook as a recurring step, and the measurement above is the query
that performs it.
