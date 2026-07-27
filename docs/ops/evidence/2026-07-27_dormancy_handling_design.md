# Dormancy handling design — how an EA should treat FTMO's 30-day idle block

**Date:** 2026-07-27
**Author:** Claude (board-advisor worktree)
**Scope:** How the V5 framework and the challenge book should handle the rule
"30 calendar days with no trade = account blocked."
**Status:** recommendation for OWNER.

---

## Provenance of the rule (read this first)

The 30-day dormancy block is **OWNER-directed and treated as FIXED/binding**, it is
**not an officially published FTMO number**. FTMO's own communication says only that
it contacts a trader after "a few weeks" of inactivity and that a freeze can be
requested; it does not publish a hard threshold
(`tools/strategy_farm/portfolio/challenge_book_60d.py:46-49`;
`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`). Treating 30 days as a
hard failure is the conservative choice. It must never be cited to OWNER or anyone else
as an official FTMO rule.

The FX rule we *do* know: a "Trading Day" for the 4-day minimum requires a position to
be **OPENED**, not closed
(`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`).

---

## Executive recommendation

1. **Dormancy is a sleeve-selection constraint, not an EA trading behaviour.** The
   load-bearing control is option (a): only run sleeves whose maximum historical
   inter-trade gap sits under 30 days with margin. Nothing the EA *does* (as opposed to
   *reports*) should change because of the idle clock.

2. **The single-account plan is not structurally threatened by dormancy.** 9936:USDJPY
   — the single-account best (`MEASUREMENT STATE`, 35.7% at 3x) — has a maximum
   historical open-to-open gap of **27 days** and a structural
   P(60-day window hits a >30d gap) of **0.0%**. It is admissible. The caveat is a thin
   **3-day** margin (see §2).

3. **One thing belongs in the EA: telemetry.** A warn/critical `QM_LogEvent` as idle
   days climb, emitted from the existing `QM_PropFirm.mqh` state machine, with the
   operator deciding what to do. No forced trade, no auto-freeze, no entry-logic change.
   (§4.)

4. **A forced "heartbeat" trade is ruled OUT** — it manufactures activity outside the
   strategy's edge and falls under FTMO's forbidden-practices ("not replicable in real
   markets"). (§1c.)

---

## 1. The legitimate options, ruled in or out

### (a) Select only sleeves whose max historical inter-trade gap is safely under 30 days — **IN (primary control)**

This is the first-class answer. It manufactures nothing, is fully evidence-based, and
is measured below. The only design decision is how much margin to demand below 30.

- **Hard structural line (max gap ≤ 30):** admits 7 sleeves; P60 = 0 for all of them
  (§2). Includes 9936:USDJPY and 13213:USDJPY at a thin 3–4 day margin.
- **Prudent-buffer line (max gap ≤ 24, i.e. ≥6-day margin):** admits 5 sleeves. Guards
  against non-stationarity — a *future* gap exceeding the historical maximum. Excludes
  9936/13213.

Recommendation: adopt the **hard line for admission**, tag ≤24 as "robust" and 25–30 as
"thin", and cover the thin band with telemetry (§4) rather than throwing the sleeve
away. Discarding 9936 purely for a 3-day dormancy margin would trade away the
single-account KPI (35.7%) for a risk that telemetry already surfaces.

### (b) EA-level warning / telemetry that surfaces approaching dormancy without trading — **IN**

Pure observation. It changes no order flow, interacts with no rule, and is the only
mechanism that knows *live* how long the account has actually been idle (the backtest
gap distribution is history, not a guarantee). It is the safety net for the thin-buffer
sleeves and for the gap between historical max and live reality. Design in §4.

### (c) A deliberately tiny, strategy-consistent "heartbeat" position — **OUT**

This is the trap. A position opened *because the idle clock is near 30* — rather than
because the strategy signalled — is activity "not replicable in real markets", which is
exactly what FTMO's forbidden-practices list covers. "Tiny" and "strategy-consistent"
do not rescue it: if the strategy did not signal, the trade is manufactured, and a
rule-gaming design is unacceptable regardless of size. Ruled out as a runtime behaviour.

Boundary note — the *legitimate cousin*: choosing, at **selection time**, a
higher-frequency parameterization of the strategy (one that naturally trades more often)
is fine, because it changes the strategy and is re-measured through the gates. What is
forbidden is injecting a trade at **runtime** keyed off the idle clock.

### (d) Request FTMO's published account freeze — **IN as a manual break-glass; OUT as a design dependency**

FTMO's own communication allows requesting a freeze for inactivity
(`challenge_book_60d.py:46-49`). It is legitimate and is the cleanest escape hatch.
Caveats that keep it out of the automated design:

- It is an **operator action**, not something the EA should trigger (an EA that phones a
  prop firm is out of scope and cannot be evidence-controlled).
- It is not a published SLA; OWNER directed we treat 30d = blocked as FIXED, so we do
  **not rely** on the freeze to run an otherwise-disqualified sleeve.
- A freeze **pauses the clock but not the KPI**: no P&L accrues toward target during a
  freeze, so under the 60-day Phase-1 KPI it is dead time. It protects the account and
  costs the deadline.

Keep it documented as an operator escalation of last resort, reached only when telemetry
(b) fires and no strategy signal is imminent.

---

## 2. Measured exposure — every gate-clean sleeve

Method (`tools/strategy_farm/portfolio/dormancy_exposure.py`, read-only against
`D:/QM/strategy_farm/state/farm_state.sqlite` and the sleeve streams
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/*.jsonl`):

- **Pool** = the exact gate-clean pool `challenge_book_60d.py:112-166` builds: passes
  Q02–Q08 gate verdicts, ≥99% `entry_time` coverage, ≥250 distinct close-days. **15
  sleeves** (matches the book's "7 → 15" pool statement, `challenge_book_60d.py:78-83`).
- **Gap distribution** = calendar-day gaps between consecutive trading days.
- **P60** = P(a *fully-observable* 60-calendar-day window started on a trading day
  contains a >30-day idle trigger), walked day-by-day exactly as
  `challenge_book_60d.py:202-231` does (expire at >60, dormant at >30, reset on a
  trading day). Windows whose 60-day forward span runs past the last observed trade are
  skipped, so "no data after the stream ends" is not counted as a gap — a sleeve whose
  max real gap ≤30 therefore scores exactly 0.
- **buf** = 30 − max historical open-to-open gap (calendar-day safety margin).
- Three trading-day calendars (see §3): **O**pen (conservative), **C**lose,
  **A**ctive-set (book-lenient, holding resets).

```
sleeve           multi%  n_td  med  p90  p95  max  buf  >30   P60_O   P60_C   P60_A   verdict
---------------------------------------------------------------------------------------------
10553:XAUUSD        45%  1593    1    4    4    7   23    0    0.0%    0.0%    0.0%   SAFE
10848:XAUUSD        40%  1187    2    5    6   11   19    0    0.0%    0.0%    0.0%   SAFE
13108:XTIUSD        93%   553    5    7    8   17   13    0    0.0%    0.0%    0.0%   SAFE
10291:SP500         94%   411    7    7   10   20   10    0    0.0%    0.0%    0.0%   SAFE
10183:XAUUSD        99%   347    7    7   14   21    9    0    0.0%    0.0%    0.0%   SAFE
13213:USDJPY         0%  1596    1    4    5   26    4    0    0.0%    0.0%    0.0%   SAFE-THIN
9936:USDJPY          0%  1252    2    5    6   27    3    0    0.0%    0.0%    0.0%   SAFE-THIN
13301:GDAXI          0%   551    3    8   11   36   -6    1    1.7%    1.7%    1.7%   MARGINAL
12969:USDJPY        99%   300   10   16   20   36   -6    2    2.4%    2.4%    1.4%   DISQUALIFIED
11063:USDJPY        28%   480    6   12   14   39   -9    2    2.1%    2.1%    2.0%   DISQUALIFIED
10700:XAUUSD        58%   326    7   20   24   42  -12    8   11.0%   11.2%    9.2%   DISQUALIFIED
9403:GDAXI          39%   287    5   23   36  110  -80   21   27.8%   28.2%   28.5%   DISQUALIFIED
10128:XAUUSD        89%   433    6   11   14  137 -107    2    1.4%    1.4%    1.6%   MARGINAL
10145:XAUUSD        92%   314    7   16   28  151 -121    9   12.1%   11.5%    9.7%   DISQUALIFIED
13036:GDAXI          0%  1352    1    3    3  279 -249    3    4.5%    4.5%    4.5%   DISQUALIFIED
```

Cross-check: the four sleeve maxima in `MEASUREMENT STATE` reproduce exactly — 13213=26,
9936=27, 13301=36, 13036=279.

**Safe for a single-account run (max gap ≤ 30, structural P60 = 0):**

| sleeve | max gap | margin | note |
|---|---|---|---|
| 10553:XAUUSD | 7d | 23d | most dormancy-robust; also a best-book member (`challenge_book_60d.py:62-63`) |
| 10848:XAUUSD | 11d | 19d | robust; best-book member |
| 13108:XTIUSD | 17d | 13d | robust |
| 10291:SP500 | 20d | 10d | robust |
| 10183:XAUUSD | 21d | 9d | robust |
| 13213:USDJPY | 26d | 4d | **thin** — cover with telemetry |
| 9936:USDJPY | 27d | 3d | **thin** — the single-account best; cover with telemetry |

**Disqualified (a real >30-day gap exists in history):** 13301:GDAXI (36d),
12969:USDJPY (36d), 11063:USDJPY (39d), 10700:XAUUSD (42d), 10145:XAUUSD (151d),
9403:GDAXI (110d), 13036:GDAXI (279d). 10128:XAUUSD has a single 137-day open-to-open
gap and is disqualified despite a low P60. 13036:GDAXI is the clearest kill: it can sit
idle the better part of a year.

Note the multi-day sleeves that survive on dormancy (10553, 10848 at 45%/40% multi-day)
still carry the funded-phase **weekend-close** obligation separately
(`challenge_book_60d.py:60-63`); that is a different rule, out of scope here.

---

## 3. Does the clock run on opens, closes, or either? Conservative choice and its cost

We do not know FTMO's wording for what resets the dormancy clock. Three candidates:

- **Opens only** — only a new position OPEN resets it; holding and closing do not.
- **Closes only** — only a close resets it.
- **Either / held** — any position activity (including a day merely holding an open
  position) resets it. This is the lenient model `challenge_book_60d.py` itself
  simulates via its `active` set (`challenge_book_60d.py:176-188, 205-208`).

**Recommended conservative choice: model the clock as reset ONLY by a new position OPEN.**
Rationale: (i) it is the interpretation under which we get blocked most easily, so
designing to it is safe; (ii) it is internally consistent with the one FTMO rule we do
know — a "Trading Day" requires a position OPENED — so using the same event for dormancy
is the least surprising reading; (iii) assuming that merely holding a position does not
protect you is strictly safer than assuming it does.

**What it costs us: essentially nothing in the current pool.** Compare the P60_O
(open), P60_C (close) and P60_A (active/held) columns in §2. For every SAFE and
SAFE-THIN sleeve all three are 0.0% — identical. The largest divergence anywhere is
10145 (12.1% open vs 9.7% held) and 10700 (11.0% vs 9.2%), and both are already
DISQUALIFIED under all three models. **No admission verdict flips** between
interpretations. Dangerous sleeves are dangerous under every reading and safe sleeves
are safe under every reading, so adopting the strict open-only model buys safety at zero
selection cost today.

The choice would only start to cost us if we ever tried to admit a sleeve that bridges a
long *flat* stretch with a single *held* position — open-only would disqualify it while
the reality (a held position almost certainly is "activity" to FTMO) might be fine. We
have no such sleeve in the gate-clean pool, and any that appears is independently blocked
by the funded-phase weekend-close rule. So: adopt open-only now; revisit only if a
long-hold sleeve ever becomes the marginal admit.

---

## 4. What belongs in the EA (and what does not)

**The admission decision does NOT belong in the EA.** Whether a sleeve is dormancy-safe
is a property of its historical gap distribution, decided in the portfolio/book layer
(this document + `dormancy_exposure.py`) before deployment. An EA cannot and must not
decide whether it is allowed to be run on a given sleeve.

**Exactly one thing belongs in the EA: dormancy telemetry.** The EA is the only actor
that knows, live, how long it has actually been since its last trade. It should surface
that and stop there. This folds into `framework/include/QM/QM_PropFirm.mqh`, which is
already the challenge-awareness home and already has the state machine and the shared,
per-account, restart-safe state file this needs.

### Inputs (add to the `input group "Prop Firm (challenge accounts)"`, `QM_PropFirm.mqh:61`)

```mql5
input int  prop_dormancy_days      = 30;   // OWNER-fixed idle-block threshold (telemetry only)
input int  prop_dormancy_warn_days = 20;   // first WARN once idle reaches this
```

Both are informational. **Neither ever gates or triggers an order.** `prop_dormancy_days`
is not a hard block inside the EA — we never open a trade to avoid it; it only sets the
countdown the telemetry reports against.

### State (extend the existing state file, `QM_PropFirm.mqh:98-145`)

The state line is currently `login;balance;target` and load already rejects `< 3` fields
(`QM_PropFirm.mqh:124`). Append a 4th field `last_open_epoch` and read it defensively
(`if StringSplit(...) >= 4`), so old files stay loadable. Record `TimeCurrent()` as the
last open whenever the EA opens a position (a one-line `QM_PropNoteOpen()` call the EA
makes right after a successful entry), and persist via the existing `QM_PropSaveState()`.
This survives the terminal restarts a weeks-long challenge will see.

### Telemetry events (`QM_LogEvent(level, event, payload_json)`, `QM_Logger.mqh:166`)

Evaluate once per day in the day-rollover block that already exists
(`QM_PropFirm.mqh:257-263`), computing `idle = today − last_open_day`:

- `prop_dormancy_warn` — `QM_WARN`, when `idle >= prop_dormancy_warn_days`:
  `{"idle_days":N,"warn_days":20,"block_days":30,"last_open_utc":"...","days_to_block":M}`
- `prop_dormancy_critical` — `QM_ERROR`, when `idle >= prop_dormancy_days - 3`:
  `{"idle_days":N,"days_to_block":M,"last_open_utc":"..."}`

Emit at most once per day per level (a `g_qm_prop_dormancy_warned_key` day-guard) so the
log is not spammed.

**Suppress when the challenge is already won.** Once `g_qm_prop_target_reached` is true
(`QM_PropFirm.mqh:265-296`) the EA has *correctly* stopped opening trades and idle days
will climb by design; dormancy telemetry must go quiet in that state, otherwise a passed
challenge generates false alarms.

### What the operator sees

These events flow through the QM logger to `MQL5\Files\QM\` (per the QM event-log
convention), are picked up by the aggregator, and should raise a **cockpit attention
flag** and a line in the existing **06:00 HTML / FAIL-digest** mail — not a new ping
channel (mail-channel policy). The operator's response is a human decision: let it ride
(a signal is likely imminent), or, only as break-glass, request the FTMO freeze (§1d).
The EA never makes that decision.

### What must NOT go in the EA

- No forced/heartbeat trade of any size (§1c).
- No auto-request of an FTMO freeze (§1d).
- No change to entry logic, sizing, or filters keyed off the idle clock. The EA
  **observes and reports**; it never trades to stay alive.

### Connection to OWNER's phase selector

OWNER also directed (2026-07-27) that the framework gain a Phase 1 / Phase 2 / Funded
selector. Dormancy telemetry is **phase-independent in mechanism** but the operator
response differs: in Phase 1/2 a target-reached halt legitimately suppresses it (above);
in **Funded** there is no target, `prop_flatten_at_target` is off, and the dormancy
warning is arguably *most* important — a funded account can idle between sprints and lose
the entire funded account to a block. The phase selector should therefore carry the
dormancy threshold forward into all three phases, changing only the suppression logic,
not the telemetry itself. (The phase selector as a whole is a separate change; only its
dormancy interaction is in scope here.)

---

## Evidence and reproduction

- Measurement script (committed, re-runnable, read-only):
  `tools/strategy_farm/portfolio/dormancy_exposure.py`
  Run: `python tools/strategy_farm/portfolio/dormancy_exposure.py`
- Gate-clean pool definition reused verbatim: `challenge_book_60d.py:112-166`.
- Dormancy day-walk reused verbatim: `challenge_book_60d.py:202-231`.
- Sleeve streams: `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/*.jsonl`
  (`time` = close epoch, `entry_time` = open epoch, `net` = P&L).
- FTMO rules: `docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`.
- Framework hooks cited: `framework/include/QM/QM_PropFirm.mqh`,
  `framework/include/QM/QM_Logger.mqh:166`, `framework/include/QM/QM_Common.mqh:179-182,315`.

### Risks / caveats

- The 30-day threshold is OWNER-fixed, **not** an official FTMO number. If FTMO's real
  behaviour is looser, we are leaving safe sleeves on the table; if stricter, telemetry
  is what saves us. Do not cite it as official.
- Gap maxima are historical. A future gap can exceed the historical max, which is exactly
  why the thin-buffer sleeves (9936, 13213) need telemetry and why a ≤24-day buffer is
  the robust (not the minimum) admission line.
- P60 is a raw window probability; it ignores that many windows pass on target before
  day 60 (single-account median ~34 days, `MEASUREMENT STATE`), so realised dormancy
  exposure is lower than P60 — P60 is the conservative upper bound.
