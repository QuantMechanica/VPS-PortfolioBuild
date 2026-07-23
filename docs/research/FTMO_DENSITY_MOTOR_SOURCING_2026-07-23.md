# FTMO Density-Motor Sourcing Doctrine — 2026-07-23

**Author:** Claude · **Status:** standing sourcing directive (supersedes commodity-momentum as the
primary research target for the FTMO campaign) · **OWNER-authorized:** 2026-07-23 ("2 ja").

**Primary evidence:** `D:/QM/reports/portfolio/carry_budget_audit_20260722/audit.md` (read-only
carry-audit over the 317 approved-but-unbuilt cards, health snapshot `2026-07-22T21:23:19Z`).

---

## 1. The finding that forces a retarget

The approved-but-unbuilt backlog is **not** a hidden density reservoir:

- **2 / 317** cards are genuine FTMO-motor canaries — `QM5_20007` and `QM5_1581`.
- **315 / 317** are structurally incapable of closing the 30-day carry gap at any admissible risk:
  163 declare <100 tr/yr, 98 omit frequency, 295 are pure chart/indicator lore, only 7 prove
  same-session flat, and 247 index/port cards fail the conservative overnight-swap screen.
- The structural whitelist (session / event / calendar / relative-value cause) is **only 22 cards**
  in the entire backlog.

**Conclusion:** the binding constraint is a genuine **density-motor shortage**, and the backlog
cannot fill it. Sourcing must be retargeted to *manufacture* motors, not mined for hidden ones.

## 2. The arithmetic the sourcing must satisfy

Measured gap ≈ **+$556 / weekday** under the 3% concurrent-risk governor (FTMO Phase-1: +10% /
≤30 trading days / P(pass) ≥ 0.80). At 0.5% risk on $100k, one 0.10R trade ≈ $50, so a single
250/yr intraday-flat sleeve ≈ **$49.60 / weekday**. Therefore the campaign needs on the order of
**6–11 uncorrelated 250/yr sleeves** (or fewer at higher per-trade R), *net of FTMO cost, after
the 3% governor de-rates concurrent slots*. Two canaries alone (~$100/day) do not close it — which
is exactly why the sourcing target, not the build queue, is the deliverable.

Cost basis (`framework/registry/venue_cost_model.json`): FX $5/lot RT; **indices $0 commission**;
XAU/XAG 0.005% notional RT (≈$20.37/$9.50 per full lot); oil/gas cash CFDs $0 commission. Swap is
unresolved in the registry, so **any non-intraday-flat card is conservatively failed** — the motor
archetype must be EOD-flat.

## 3. The motor archetype (what qualifies for sourcing)

A card is a **density motor** only if it clears ALL of:

1. **Structural cause** — session / event / calendar / relative-value anchor with a limit-to-
   arbitrage story. Pure chart-pattern lore (Wyckoff/SMC/ICT/first-swing) is falsified and excluded.
2. **Density** — ≥250 tr/yr/symbol is the target band; 180–249 acceptable; <100 is not a motor.
3. **Intraday-flat** — single-session entry, forced MOC flat, **no overnight hold** (no swap exposure).
4. **Net-carry-positive after real FTMO cost** — an explicit cost gate (expected move > k×(spread+
   commission)) is a strong prior; a bare PF *target* is not evidence.
5. **Orthogonal** — distinct session/mechanism/symbol from existing survivors and from each other;
   a duplicate ORB/session slot adds exposure, not density.

**Hunt** (retarget the research lane here): session-open range/ORB variants across *different*
sessions and symbols (Frankfurt/London/US cash opens), last-N-minutes index momentum, broker-clock
session-arithmetic motors (the proven 12969 gotobi archetype), first-half-hour→rest-of-day and
rest-of-day→last-half-hour index-momentum expressions, and event-anchored intraday fades that
force same-day flat. **Stop** (deprioritize as the *primary* target): generic commodity-momentum
(Miffre-Rallis / SSRN metals-energy) — it produces D1/multi-day, low-frequency, swap-exposed
sleeves that are diversification satellites, not FTMO motors.

## 4. The two canaries — and why 20007 is a factory, not a sleeve

### QM5_20007 `intraday-config-engine` (audit rank 1, score 93) — the decisive experiment
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20007_intraday-config-engine.md`

One parameterized EA, **not** one sleeve: signal LANES {`MOMENTUM_BAND` (Gao-Han-Li-Zhou JFE 2018 /
Concretum noise-band), `ORB` (Zarattini-Aziz SSRN 4416622), `GOLD_BREAKOUT` (XAU only, untested)} ×
conditioning GATES {vol-regime, time-of-day, cost `move>3×cost`} on GER40/US100/US500/XAU
(DWX: GDAXI/NDX/SP500/XAUUSD). Target cadence 150–2500 tr/yr; PF target 1.20; EOD-flat; M5/M15.

Because 20007 is a **grid**, it is the motor-yield experiment: build it, run the curated grid through
`Q02 (gross + trade floor) → Q04 (net-of-cost walk-forward, the decisive gate) → Q08 (PBO/DSR, the
crowding/decay defense)`, and **count the lane×symbol cells that survive AND are mutually
uncorrelated** under the 3% governor. The card states the honest bar explicitly: a standalone lane at
Sharpe ~1.0–1.3 net is a PASS; the win is 3–4 uncorrelated sleeves whose *portfolio* Sharpe clears
1.5 — and *"if NO lane/instrument clears Q04+Q08 net-of-cost, intraday-on-our-instruments is
empirically closed."*

### QM5_1581 `aa-rod-lh-mom` (audit rank 2, score 88) — orthogonality-gated satellite
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1581_aa-rod-lh-mom.md`

Baltussen-Da-Lammers-Martens market-intraday-momentum (via Alpha Architect / Wesley Gray 2021):
rest-of-day return (prior close → second-to-last 30m) predicts the **final-30m** return sign; one
directional trade/session, close at session close, 1.5×ATR(M30) stop. NDX/WS30 live, SP500 backtest;
≈250/yr inferred (1/session × ~252). Live promotion needs NDX/WS30 parallel-validation (SP500.DWX is
not broker-routable).

## 5. The 20007 ↔ 1581 correlation gate (mandatory before both run)

The concern is **not** identical sources — they are different papers (Gao *first-half-hour*→last vs
Baltussen *rest-of-day*→final-30m) — but a shared **intraday-momentum autocorrelation** on the same
index symbols in the final-30m window: on strong rest-of-day-momentum days both may take the same
final-30m direction on NDX/SP500.

Gate (run after both build, before both trade concurrently):
- On the SAME symbol (NDX and SP500.DWX backtest), compute the **daily return correlation** between
  1581 and 20007's index MOMENTUM_BAND sleeve, and separately restrict 20007 to the **final-30m
  window** to isolate the overlap.
- **Decision:** corr ≥ 0.40 (DL-083 admission boundary) ⇒ 1581 adds no orthogonal density; run only
  20007's broader engine. corr < 0.40 ⇒ 1581 earns a distinct density slot (different predictor →
  different entry-timing/direction distribution). Never run both un-gated.

## 6. Sourcing decision tree (driven by 20007's survivor count)

The retarget depth depends on the 20007 grid yield — the experiment tells us whether the vein is rich:

- **≥4 uncorrelated Q04+Q08 survivors** → the intraday-momentum/ORB vein *is* the motor source.
  Deepen it first (more sessions: Frankfurt/London opens; more symbols; ORB `orb_minutes`/`tp_r`
  cells) before opening new veins. This is the cheapest path to 6–11 sleeves.
- **2–3 survivors** → partial vein. Keep 20007's survivors, add 1581 if the §5 gate passes, and open
  ONE adjacent session/event vein (e.g. session-open ORB on a non-US session) to de-concentrate.
- **≤1 survivor** → the card's own falsification trigger: intraday-on-our-instruments is near-closed;
  pivot sourcing to genuinely different session/event motors (broker-clock arithmetic à la 12969,
  event-anchored intraday fades) rather than more intraday-momentum variants.

## 7. Build sequencing & coordination (gated — not started here)

- Build **20007 first** (grid experiment), **then 1581** — both are approved-unbuilt; the pump does
  not sweep unbuilt cards, so they must be primed via `farmctl build-ea` on a **clean tree**.
- **Blocker:** the build lane is dirty-guard-blocked by an active Codex live-ops workstream
  (factory-watchdog session-resilience, reboot-diagnostic-mail — uncommitted at time of writing).
  Priming must wait until that tree clears (Codex commits its own live-ops), and must **not** be run
  as a competing headless Codex session while that work is active (factory-isolation hazard).
- Backtests are never throttled; the grid runs T1–T10 once 20007 is built. Q11 portfolio assembly and
  any T_Live step remain OWNER+Claude gates.

**Recommended first execution step (once the tree clears):** prime `QM5_20007` via `farmctl build-ea`,
smoke-canary the trade floor, then run the curated grid to Q04/Q08 and count survivors per §6.
