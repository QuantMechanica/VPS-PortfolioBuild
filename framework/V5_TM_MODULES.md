# V5 Trade-Management Modules — Centralized Specs

> **Status (2026-04-28):** Initial entry — `TM-3BAR-TRAIL` ratified by CEO 2026-04-28 in QUA-298 closeout (comment `cc655c56`); back-port tracked in QUA-334 (= QUA-335 — duplicate sibling issue on board; this commit closes both). Source: Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley Trading. New York: John Wiley & Sons. PDF p. 21 § "Amazing 3 Bar Entry/Exit Technique".
> **Owner:** Research Agent.
> **Scope:** This file is the **centralized specification for V5 trade-management modules** — exit-only mechanisms (or trade-management overlays) that are reused across multiple V5 Strategy Cards, but which do not on their own qualify as standalone Strategy Cards because they lack a `trade_entry` per `cards/_TEMPLATE.md` § 12. New modules MUST cite a source location (page / timestamp / section) and CEO ratification record before being added.

## Why this file exists

V5 Strategy Cards each carry their own § 5 Exit Rules with self-contained pseudocode. When a single trade-management primitive (e.g., the Williams 3-bar trailing stop) is the DEFAULT trail across many cards, repeating its full spec in every card is duplication-prone — divergent edits in one card vs another would silently fork the primitive.

This file consolidates the canonical spec once. Per-card § 5 Exit Rules retain the trail spec inline (no breaking change to existing cards, and per-card parameter values may differ for the specific strategy's hold horizon and instrument). Per-card § 5 ALSO carries a cross-reference link back to the relevant module here so reviewers can verify the mechanic against the ratified canonical form.

This file does **not** introduce new trade-management primitives — every module here cites a source.

## How modules are referenced from a Strategy Card

Each Strategy Card whose default trail is module `TM-XXX` carries the line in its § 5 Exit Rules:

```text
TRAIL spec ratified at framework/V5_TM_MODULES.md § TM-XXX.
```

If the card overrides any module parameters for its specific hold horizon or instrument, the override is documented inline in the card's § 5 alongside the cross-reference.

---

## TM-3BAR-TRAIL — Williams 3-Bar Trailing Stop ("Amazing 3 Bar Entry/Exit Technique")

**Source citation.** Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley Trading. New York: John Wiley & Sons. PDF p. 21 (Inner Circle Workshop companion volume), § "WHEN TO EXIT — 2. Amazing 3 Bar Entry/Exit Technique".

**Verbatim Williams text** (PDF p. 21):

> "If so, and we are long, determine the highest close in the up move so far. Count that as day one and go back to get two more days. None of these can be an inside day. Once all three days have been noted, then determine the lowest true low of those three days. Place your stop to exit ... at that price."
>
> "If short determine the lowest close in the down move so far. Count that as day one and go back to get two more days. None of these can be an inside day. Once you have all three days note the highest true high. Place your stop to exit ... at that price."

**Activation qualifier (verbatim, PDF p. 21):**

> "the market is in a run away move ... Price must be out of a trading range"

**ESCALATE_NO_CARD rationale.** This technique is exit-only (no `trade_entry` per Strategy Card template § 12). CEO ratified Research's ESCALATE_NO_CARD recommendation 2026-04-28 (QUA-298 closeout, comment `cc655c56`): document as TM-module spec rather than draft a standalone Strategy Card. Already DEFAULT trail in 7 of 14 SRC03 cards (S01/S07/S08/S09/S10/S11/S12 — `williams-vol-bo`, `williams-smash-day`, `williams-fakeout-day`, `williams-naked-close`, `williams-spec-trap`, `williams-8wk-box`, `williams-18bar-ma`).

### Parameters

| Parameter | Default | Sweep / notes |
|---|---|---|
| `TRAIL_BARS` | 3 | Williams' literal "three days" — count of non-inside bars in the trail window. P3 sweep: {2, 3, 4, 5}. Williams does not parameterize — 3 is the verbatim value. |
| `TRAIL_NO_INSIDE` | true | Williams: "None of these can be an inside day" — only non-inside bars are counted toward the window. Inside-bar definition: `High[t] <= High[t-1] AND Low[t] >= Low[t-1]`. |
| `TRAIL_ACTIVATE` | `first_close_in_profit` | Williams: trail engages once "the market is in a run away move ... Price must be out of a trading range". V5 operationalization: activate at the first bar that closes in profit (long: Close[t] > entry_price; short: Close[t] < entry_price). Alternative activation: position has held N non-inside bars (default N = `TRAIL_BARS`). P3 sweep options: `{first_close_in_profit, first_close_in_profit_OR_held_3_non_inside_bars, on_entry_no_delay}`. |
| `TRAIL_ANCHOR` | `highest_close_since_entry` (long) / `lowest_close_since_entry` (short) | The "day one" of the 3-bar trail window is the bar that printed the most-favorable close so far in the move. Re-evaluated every bar — anchor advances whenever a new highest close (long) / lowest close (short) prints. |
| `TRAIL_LEVEL_FORMULA` | long: `MIN(true_low(b) for b in trail_window)`; short: `MAX(true_high(b) for b in trail_window)` | True-low = `MIN(Low[b], Close[b-1])`; true-high = `MAX(High[b], Close[b-1])`. Williams uses true-range bars to absorb gaps into the level. |

### Pseudocode (V5 canonical)

```text
INPUTS:
- TRAIL_BARS              : int    (default 3)
- TRAIL_NO_INSIDE         : bool   (default true)
- TRAIL_ACTIVATE          : enum   (default first_close_in_profit)

STATE (per open position):
- trail_active            : bool   (default false)
- trail_anchor_close      : double (long: highest close since entry; short: lowest close since entry)
- trail_anchor_bar        : int    (the bar index whose close == trail_anchor_close)
- trail_level             : double (the actual trail price)

ACTIVATION (each bar in position, before exit-eval):
  if NOT trail_active:
    if TRAIL_ACTIVATE == first_close_in_profit:
      if (LONG  and Close[t] > entry_price) or
         (SHORT and Close[t] < entry_price):
        trail_active = true
    elif TRAIL_ACTIVATE == on_entry_no_delay:
      trail_active = true
    elif TRAIL_ACTIVATE == first_close_in_profit_OR_held_3_non_inside_bars:
      cnt_non_inside = count(b in [entry_bar..t] where NOT inside_bar(b))
      if (cnt_non_inside >= TRAIL_BARS) or
         (LONG  and Close[t] > entry_price) or
         (SHORT and Close[t] < entry_price):
        trail_active = true

ANCHOR + WINDOW (each bar while trail_active):
  if LONG:
    if Close[t] > trail_anchor_close OR trail_anchor_bar == NULL:
      trail_anchor_close = Close[t]
      trail_anchor_bar   = t
  if SHORT (mirror):
    if Close[t] < trail_anchor_close OR trail_anchor_bar == NULL:
      trail_anchor_close = Close[t]
      trail_anchor_bar   = t

  // Build the 3-bar window: anchor bar + walk backward, skipping inside bars
  window = []
  i = trail_anchor_bar
  while len(window) < TRAIL_BARS and i >= entry_bar:
    if NOT TRAIL_NO_INSIDE or NOT inside_bar(i):
      window.append(i)
    i = i - 1

  if len(window) < TRAIL_BARS:
    // Insufficient non-inside bars yet — defer trail level update; rely on hard stop
    skip_trail_update_this_bar
  else:
    if LONG:
      trail_level = MIN( true_low(b)  for b in window )    // true_low(b)  = MIN(Low[b],  Close[b-1])
    else: // SHORT
      trail_level = MAX( true_high(b) for b in window )    // true_high(b) = MAX(High[b], Close[b-1])

EXIT-EVAL (each bar after trail level computed):
  if LONG  and Low[t]  <= trail_level: CLOSE_LONG  at trail_level (or next-bar open if gap-through)
  if SHORT and High[t] >= trail_level: CLOSE_SHORT at trail_level (or next-bar open if gap-through)

INTERACTION WITH HARD STOP:
- The hard stop (typically atr-hard-stop, set at entry) ALWAYS applies in parallel.
- Whichever stop fires first closes the position.
- The 3-bar trail can only TIGHTEN against the position direction relative to entry — i.e., once trail_level
  is more favorable than the hard stop (long: trail_level > hard_stop_level), the trail effectively
  supersedes the hard stop as the binding exit. The hard stop never moves; the trail moves
  monotonically (non-loosening) once activated.
```

### Inside-bar definition

```text
inside_bar(b) := (High[b] <= High[b-1]) AND (Low[b] >= Low[b-1])
```

A bar that is exactly equal on both sides counts as inside (Williams' rule is conservative). Equal-high-only or equal-low-only does NOT count as inside.

### Williams' qualitative framing (PDF p. 21, surrounding context)

Williams positions the 3-bar trail as the SECOND of four exit options on PDF pp. 20-21 § "WHEN TO EXIT":

1. **Least Favorite Exit** — fixed dollar stop ("$1,500 as final proof I am wrong").
2. **Amazing 3 Bar Entry/Exit Technique** — this module.
3. **18 Day Moving Average** — close on cross of MA(18).
4. **Channel Breaks** — close on N-bar opposite-extreme channel break.

The four are presented as a menu the trader picks per-strategy. For V5 Strategy Cards in the SRC03 family that designate `TM-3BAR-TRAIL` as their default trail, the other three options are P3 alternative-exit axes (the card's § 7 may sweep them as comparison runs).

### V5 framework integration

- **Friday-close interaction.** When the per-card `friday-close-flatten` flag is active, the Friday-close fires unconditionally regardless of trail state — i.e., the Friday-close exit overrides the trail. No waiver required because Williams' typical hold (~3-5 sessions) rarely pushes positions across a weekend; the trail typically resolves before Friday.
- **News-blackout interaction.** When the standard P8 news-blackout fires (`PAUSE` mode), the trail level is preserved across the blackout window — the trail does not reset, but new bars during the blackout do not add to the window. On blackout exit, normal trail eval resumes from the existing anchor and level.
- **Hard-stop precedence on first bar.** If TRAIL_ACTIVATE has not yet fired by the second bar, only the hard stop is active — exits during the first bar use the hard-stop level, not the trail.
- **Gap-through behavior.** If price gaps through the trail level at next bar's open, the close fills at the next-bar open (not the trail level) — V5 framework default fill behavior. Slippage is accounted for in P5b stress.

### Per-card overrides (SRC03 references)

The 7 SRC03 cards designating `TM-3BAR-TRAIL` as their default trail may carry per-card overrides (e.g., different `TRAIL_BARS` if the card's hold horizon differs):

| Card | Override notes |
|---|---|
| SRC03_S01 `williams-vol-bo` | Reference implementation — § 5 carries the canonical pseudocode inline; no override |
| SRC03_S07 `williams-smash-day` | Default; menu of 4 exit options exposed as P3 axis variants per Williams PDF pp. 20-21 |
| SRC03_S08 `williams-fakeout-day` | Default; same menu |
| SRC03_S09 `williams-naked-close` | Default; same menu |
| SRC03_S10 `williams-spec-trap` | Default; menu + Williams' "It may go on, or it may not" qualifier (acknowledged moderate-edge regime — P5c crisis-slice load-bearing) |
| SRC03_S11 `williams-8wk-box` | Default for breakout-confirmation legs; Williams' "Keep Swinging" framing implies trail-then-re-enter on subsequent breakouts |
| SRC03_S12 `williams-18bar-ma` | Default; alternates with the 18-bar MA cross exit per Williams' menu |

Cards using `TM-3BAR-TRAIL` MUST cross-link this module from § 5 Exit Rules. The per-card § 5 retains the inline pseudocode (so a card review is self-contained) and adds:

```text
TRAIL spec ratified at framework/V5_TM_MODULES.md § TM-3BAR-TRAIL (Williams PDF p. 21).
```

### Ratification record

CEO ratified `TM-3BAR-TRAIL` as a TM-module spec on 2026-04-28 (QUA-298 closeout, comment `cc655c56`), accepting Research's ESCALATE_NO_CARD recommendation that the technique is exit-only and does not qualify as a standalone Strategy Card. Back-port into this file tracked under QUA-334. CTO technical-correctness ratification of the V5 canonical pseudocode is pending.

---

## Future modules

This file currently contains one module (`TM-3BAR-TRAIL`). Candidate future modules — CEO-ratification required before adding:

- Williams' 18-Day Moving Average exit (PDF pp. 16-17, 20-21) — already partially captured as `trend-filter-ma` for entry-side; the EXIT-side variant ("close on cross of MA(18)") is a candidate `TM-18BAR-MA-CROSS` module if multiple cards adopt it as default exit.
- Williams' Channel-Break exit (PDF p. 21) — if multiple cards adopt as default exit.
- Padysak-Vojtko time-stop variants (V4 inspiration spec) — already captured as `time-stop` flag for the exit family; per-card pseudocode currently inline. Centralize if multiple V5 cards adopt the same parameterization.

The addition process matches the `strategy-seeds/strategy_type_flags.md` addition-process: a Research issue + source citation + CEO ratification before appending here under a new `## TM-XXX` section.
