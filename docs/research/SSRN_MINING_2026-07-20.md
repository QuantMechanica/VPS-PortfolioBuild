# SSRN Deep Mine — Anomalies Literature → Card Candidates (2026-07-20)

**Authority:** OWNER directive 2026-07-20 ("Hier habe ich eine tolle Strategie Quelle
gefunden, da kannst du auch noch tief graben: ssrn.com").
**Method:** ultracode workflow `wf_81749b44-d3f` — 5 domain miners (calendar/seasonality,
macro-announcement drift, FX structural flows, index structural, TSMOM/cross-sectional)
+ 1 read-only farm-coverage mapper, portfolio-first synthesis, then one adversarial
citation/effect refuter per kept candidate. 30 papers mined → 24 unique → 12 adjudicated
→ **9 card candidates, all 9 with real, verified citations** (one leg refuted in
verification and demoted, see rank 7). Full agent returns:
session `subagents/workflows/wf_81749b44-d3f/journal.jsonl`.
**Access note:** SSRN itself 403s the VPS (Cloudflare); discovery + verification ran via
web search metadata and mirror full-texts (NBER, RePEc, journal pages, author PDFs) —
every kept paper was confirmed against at least one live source, several against the
extracted full text.

Slots into **LEVELUP_CAMPAIGN_2026-07-20.md Cohort 4** (standing research drip). Doctrine
filters applied throughout: limit-to-arbitrage story mandatory, no ML, floor 5 trades/yr,
dead lists respected, parameter-free/structural rules preferred, McLean-Pontiff decay
checked per candidate (flows > risk premia > stat patterns).

## Verified shortlist (rank order; verify = adversarial refuter outcome)

| # | Paper (verified citation) | Verdict | Verify | One-line rule |
|---|---|---|---|---|
| 1 | Stivers & Sun 2013, JBF 37(11) — OpEx week, SSRN 1571786 | NEW_CARD | exists ✓ effect ✓ | Long index into third-Friday week; exit third-Friday close |
| 2 | Etula, Rinne, Suominen & Vaittinen 2020, RFS 33(1) — Dash for Cash, SSRN 2528692 | VARIANT of TOM (20004) | exists ✓ effect ✓ (3 material corrections) | Long T-4→T+3 around month-end + flat/short T-8..T-4 |
| 3 | Moskowitz, Ooi & Pedersen 2012, JFE 104(2) — TSMOM, SSRN 2089463 | VARIANT (spec-feed to Cohort-4 skeletons) | exists ✓ effect ✓ | sign(12m return), monthly rebalance, 40%/σ vol-scaling |
| 4 | Fan, Fernandez-Perez, Fuertes & Miffre 2020, JFM 40(4) — Speculative Pressure, SSRN 3279425 | VARIANT (spec-feed to cot-spec-momo) | exists ✓ effect ✓ (1 material divergence) | COT non-commercial 52w pressure, monthly rebalance |
| 5 | Evans 2018, JBF 87 — WMR fix reversion, SSRN 2487991 (+ Melvin-Prins 2015 leg, SSRN 2019274) | VARIANT (respec of killed month-end draft) | exists ✓ effect ✓ (4 caveats) | Month-end: fade the pre-fix move after 16:00 London fix |
| 6 | Lustig, Roussanov & Verdelhan 2014, JFE 111(3) — Dollar carry via AFD, SSRN 1541230 | NEW_CARD | exists ✓ effect ✓ (decay documented) | sign(avg G10 forward discount) → G10 basket vs USD, monthly |
| 7 | Ito & Yamada 2017, JIE 109 — Tokyo fix, SSRN 2868918 | VARIANT of live gotobi — **DEMOTED** | exists ✓ **effect ✗** | Post-fix fade leg NOT supported by the paper (see below) |
| 8 | Savor & Wilson 2013, JFQA 48(2) — announcement-day premium, SSRN 1312091 | NEW_CARD | exists ✓ effect ✓ (post-2015 FOMC-leg decay) | Long index on scheduled CPI/NFP/FOMC days, day-flat |
| 9 | Gao, Han, Li & Zhou 2018, JFE 129(2) — market intraday momentum, SSRN 2440866 | NEW_CARD | exists ✓ effect ✓ (unconditional variant dead OOS) | First-half-hour sign → last-half-hour, high-vol filter only |

Rejected in synthesis (no card): **Lucca-Moench pre-FOMC drift** (ALREADY_COVERED — 13128
live; attach the 2020 decay citation to its Q10 monitoring notes), **Boyarchenko et al.
overnight drift** (DEAD_ALIGNED — authors' own July-2026 follow-up shows ~0% 2021-2025,
mechanism fuel gone; decisive evidence to NOT naively rebuild `aa-overnight-mom`),
**Menkhoff carry + Clarida vol-regime** (INFEASIBLE until swap-injection machinery exists;
rank 6 is the feasible way to hold FX-rate-premium exposure meanwhile).

## Verification deltas that must reach the cards (the refuters earned their keep)

1. **Rank 2 (Etula) — settlement anchor is stale.** The paper itself proves the trough
   moves with the settlement convention. Germany is T+2 since Oct-2014, US is T+1 since
   May-2024 → expected trough today is ~T-2/T-3 (DE40) and ~T-1/T-2 (NDX), and the Q08 ±1
   lattice does NOT span a 1-3 day regime shift. **Card rule: day-offsets must be
   settlement-derived per venue/era (era-split backtest), not fixed T-4.** Short leg
   (T-8..T-4) has no OOS confirmation anywhere — ship as flat-filter first.
2. **Rank 2 side-finding for the LIVE program:** the Quantseeker replication finds the
   classical [0:3] TOM window statistically dead in US ETFs post-2015; the [-3:3] window
   stays significant but decaying. **Watch-item for 20004 (NDX leg) at Q02/Q09 — not a
   gate change, an expectation-setting.**
3. **Rank 4 (COT) — cross-section vs time-series.** All published evidence is
   cross-sectional; the drafted per-symbol raw-sign rule is untested extrapolation and
   mostly-long beta (SP>0 in 60-71% of months). **Card rule: demean SP vs its own history
   or cross-basket, or label the TS transposition as untested.**
4. **Rank 5 (Evans) — four executable corrections:** (a) EURUSD unconditional month-end
   reversal ≈ 1bp = below cost; pick from Evans' net-survivor list (AUDUSD is in-universe)
   and/or condition on >75th-pct pre-fix moves; (b) reversal is complete by ~16:15 London
   — pre-register a 16:15 exit, not 17:00/18:00; (c) enter ≥16:03 (16:02 is inside the
   post-2015 fix window); (d) all magnitudes predate the Feb-2015 window reform —
   existence persisted (Ito-Yamada JIMF), magnitude is the open question.
5. **Rank 7 (Tokyo fix) — leg refuted.** Ito & Yamada Table 4 finds NO pre/post
   return-reversal at the Tokyo fix (unlike London); the quantified combined strategy is
   ~1.8bp on interbank spreads, concentrated on exactly the gotobi/month-end days the
   proposed ex-gotobi leg excludes. **If this family is ever pursued: the correct academic
   backbone is Krohn, Mueller & Whelan (J. Finance 2024) for an every-day post-fix fade,
   and the edge would rest entirely on our own backtest. Deprioritized to last.**
6. **Rank 9 (intraday momentum) — only the filtered route is alive.** Unconditional
   sign-rule ≈ dead OOS post-2013 (QuantConnect 2015-2020 Sharpe −0.63); high-vol
   conditioning is where the economics live; mechanism attribution belongs to Baltussen
   et al. 2021 (gamma-hedging demand), and our range-vs-median filter is an unpublished
   adaptation — label it pre-registered.
7. **Rank 6 (dollar carry) — decay is documented, not hypothetical** (Hsu et al. 2025;
   ZIRP 2009-15 pinned AFD>0 through the 2014-15 dollar rally). Run Q02/Q08 expectations
   on post-2010 data, never on the paper's Sharpe 0.66. Only the ~145bp/100bp spot
   component is CFD-capturable; Q09 residual-swap flag mandatory.
8. **Rank 8 (Savor-Wilson) — set + timing nuances.** Paper's inflation leg is CPI→PPI
   from Feb-1971 (fn. 11 says CPI-inclusive is robust — cite it); the measured object is
   close-to-close on announcement days, which our broker-day open→close on NY-close
   charts approximates (a cash-session variant would miss the 8:30 ET prints). Post-2015
   FOMC-leg decay (Kurov et al. 2021) → post-2015 OOS is the falsification window.

## Cross-cutting integration rules (bind at card/admission time)

- **DL-083 marginal contribution is the admission bar for every calendar keep** — the
  book is already calendar/structural-heavy; rank 8 correlates with live 13128 on FOMC
  days (cluster-cap the announcement family). Deferred for the same reason: FOMC-cycle
  even-weeks (Cieslak et al., SSRN 2687614) — revisit only if rank 8 is admitted and the
  cluster has room.
- **Swap:** every multi-night index hold routes to DXZ with swap injected at Q09 per
  `venue_cost_model.json`; FTMO index swap kills overnight holders. Intraday-flat
  variants (ranks 8, 9) are the FTMO-compatible ones.
- **Q08:** all calendar-discrete integer params take ±1 lattice perturbation per the
  param-type spec (2026-07-17), never ±%.
- **Sidecar plumbing amortizes:** ranks 3/4/6 share one pattern (external public data →
  per-symbol signal file, news-calendar-seed style): weekly CFTC COT, monthly G10 policy
  rates. One plumbing job serves three families.
- **Overflow verdicts** (no slots consumed): Halloween/gold-autumn fail the 5/yr floor
  standalone → fold as legs into the scheduled seasonal calendar-battery re-draft; Ulrich
  pre-ECB (SSRN 3020899) → cheapest path is retrying 12972 (Q02 INFRA_FAIL, never
  adjudicated) with the D-2→D-1 spec, queued behind rank-8 adjudication;
  Neuhierl-Weber monetary momentum → point the Cohort-2 NFP/CPI gating fix at FOMC/ECB
  events too; Menkhoff momentum + AMP value-momentum = the published spec for the task
  #41 G8-rotation fair rebuild (budget the developed-subset momentum leg as a cheap
  falsification — Menkhoff's own Table A.12 predicts it dies net).

## Sequencing (Cohort-4 drip, ~2 cards/week alongside Cohort-2 rebuilds)

1. **Rank 1 OpEx** — but gate on task #33 (own-data .DWX index-level probe) first; the
   published effect is stock-level, the index-level strength is our open question.
2. **Rank 2 Etula TOM-variant** — settlement-derived offsets, after 20004's Q02 verdicts
   land (never touch 20004 mid-pipeline; sibling card, DL-083 vs 20004 at admission).
3. **Ranks 3+4 spec-feeds** — fold into the already-scheduled Cohort-4 skeleton re-drafts
   (tsmom-12m, aa-tsmom-1-3-12, cot-spec-momo) so those re-drafts are faithful; build the
   shared sidecar plumbing once.
4. **Rank 6 dollar-carry AFD** — new family, needs the rates sidecar from step 3.
5. **Rank 5 Evans fix-fade** — cheap falsification probe (ad-hoc harness, free terminal)
   before carding; both legs are one-session probes.
6. **Ranks 8+9** — after the announcement-cluster question resolves at the next admission
   round.
7. **Rank 7 Tokyo-fix variants** — last, only with Krohn-Mueller-Whelan as backbone.

Research throttle respected: none of this preempts the 318-card build reservoir; these
are drafting-queue entries, not build-queue jumps. Card drafting = Claude lane; admission
= OWNER, per DL-083.
