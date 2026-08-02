# CODEX BRIEF 2026-08-02 — FTMO-venue attested stream production (design + wiring)

**Author:** Claude. **Implementer:** Codex (Sol, effort max) via router lane.
**Reviewer:** Claude. **Context:** the approved finite-horizon evaluator
(`ftmo_timebox_eval.py`, ticket 03417827) correctly refuses every current
composition with `REFUSED_DXZ_SPREAD_INHERITANCE` — zero FTMO-cost-attested
streams exist. OWNER's design bar (bootstrap-LB P(Phase 1) ≥ 0.80 under the
60/30-day time-box, spec `FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md`) is
unreachable until such streams exist. This ticket builds the production path.

**Hard constraints:** factory keeps running; NO enqueues by you (Claude
enqueues after review); no T_Live contact; no hold releases (the
FTMO_BOOK3_*_ISOLATED_ONLY holds stay); no change to the evaluator's cost
guardrail or the OWNER horizons; explicit-pathspec commits.

## Deliverable 1 — design memo (decision-ready)

`docs/research/FTMO_STREAM_CAMPAIGN_DESIGN_2026-08-02.md` answering:

1. **Cost basis:** how a tester run attests FTMO spread/commission/swap against
   the pinned FTMO instrument snapshot (`7309310a…`). Inventory what the
   existing FTMO Q02 isolation machinery (the Book3 lanes behind the
   `FTMO_BOOK3_Q02_ISOLATED_ONLY` holds, the 20009 FTMO news-calendar path,
   `venue_cost_model.json` FTMO terms) already provides vs what is missing.
   Where FTMO swap terms are absent for an instrument, the instrument is
   excluded — never approximated (evaluator already enforces this).
2. **Stream contract:** exact `FTMO_DAILY_NET_V1` row schema the evaluator
   demands (venue=FTMO attestation, per-broker-day close-to-close net,
   conservative intraday low from broker midnight, trade count, rolling-start
   eligibility, flat-at-end state, cost-snapshot digest binding) and which
   exporter produces it from a tester run's artifacts.
3. **Candidate wave 1:** the five sealed sleeves (13301:GDAXI, 10145:XAUUSD,
   10183:XAUUSD, 13036:GDAXI, 10128:XAUUSD) — per sleeve: symbol/timeframe/set,
   full-history window, estimated tester cost, and any blocker (e.g. 13301
   build-not-clean note from the inventory). Recommend the enqueue order and
   lane (isolated FTMO lane rows vs normal queue with FTMO tester config) with
   the isolation rationale: FTMO-cost rows must never contaminate DXZ pipeline
   evidence (survivor-port purity rule).
4. **Throughput plan:** expected wall-clock on the current 10-terminal factory
   without starving the DXZ backlog (suggest a cap, e.g. ≤2 concurrent FTMO
   rows).

## Deliverable 2 — implementation

The exporter + wiring you deem necessary from the design (typically: the
`FTMO_DAILY_NET_V1` exporter with attestation fields + tests; any missing FTMO
tester-config plumbing), committed with tests green. If the design reveals the
existing Book3 lane already covers a piece, reuse it — no parallel reinvention.

## Handback

Router task → REVIEW with the design memo as artifact; include verbatim test
output and the exact enqueue commands (for Claude to execute) for wave 1.
