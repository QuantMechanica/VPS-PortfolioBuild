# Portfolio Deploy-Cap — Decision Memo for OWNER Sign-off (2026-06-26)

Author: Claude (operation lead). Trigger: the certified 5-sleeve Q12-ready book exists but
the T_Live deploy manifest will not approve. OWNER asked whether the deploy DD cap is the
intended policy or an un-tuned default. **The cap value is the wrong question** — the real
blocker is that the book's drawdown is reported inconsistently across manifest generators.
This memo lays out the decision OWNER needs to make. Every number is cited to an artifact.

## 1. The deploy blocker was TWO things, both now diagnosed

The **same** 5-sleeve Q12-ready risk-parity book (10440 NDX, 10513 XAU, 10692 NDX, 10940 XAU,
11132 SP500 — identical Sharpe 1.49, identical net $9,598, identical 799 trading days) was
reported with two drawdowns ~9× apart across manifest generators:

| Manifest artifact | Starting-capital base | MaxDD | Cap | Verdict |
|---|---|---|---|---|
| `portfolio_manifest_q12_ready_all_DRAFT_20260626.json` | canonical **$100k** | **1.53 %** | 10 % | cap_met=true |
| `portfolio_manifest_q12_ready_5sleeve_DRAFT_20260626.json` | legacy **$10k** | **13.83 %** | none | KPIs only |
| `portfolio_manifest_tlive_DRAFT_20260626_rp.json` | observed, 64-day window | 15.04 % | 20 % | 2-sleeve fallback |

**Root cause #1 — starting-capital base (already fixed in code).** The q08_trades streams are
generated on the canonical $100k / 1%-fixed-risk tester account. Pricing DD against a $10k base
overstates it ~10×, turning a 1.5 % book into a 13.8 % one. `portfolio_manifest._canonical_starting_capital()`
already pins the base to `tester_defaults.json` ($100k), so the **13.83 % figure is the stale
$10k artifact; 1.53 % is the correct-base observed DD.** (This also means the "MC-p95 13.96 %" in
`book_analysis_2026-06-26.json` was computed on the $10k base — it is NOT the canonical-base
robust number; do not size on it.)

**Root cause #2 — observed single path vs robust distribution (this is what D1 fixes).** Even at
the correct base, the manifest cap decision read the *observed* daily-equity DD — one lucky path
on a series that is ~99 % zeros (these sleeves trade 14–457× over 7.74 years). The honest basis is
the Monte-Carlo p95 DD **computed at the same canonical base**.

## 2. The trustworthy number (now computed inline)

D1 (below) makes the manifest compute the MC-p95 DD **at the canonical $100k base** via
`portfolio_montecarlo.build_artifact` (seeded → deterministic, numpy-free) and decide the cap on
it. At the canonical base this lands well below the legacy $10k-base 13.96 %; the cap decision is
now on a distribution estimate, not a single path, and both `observed_max_drawdown_pct` and
`mc_p95_max_drawdown_pct` are written into the manifest KPIs for transparency.

## 3. What the robust number means for deploy

DD% scales ~linearly with leverage, so sizing the book to a drawdown budget B uses
`leverage = B ÷ MC-p95-DD`:

| Budget | Source | Leverage vs base | Sized return |
|---|---|---|---|
| **DXZ 20 % total DD** | the live DXZ Zero constraint | ~1.43× | **~9.5 %/yr** |
| **FTMO 10 % total DD** | the stricter Edge-Lab target (binds) | ~0.72× (de-lever) | **~4.7 %/yr** |

(`sized_return_dxz20_pct=9.5`, `sized_return_ftmo10_pct=4.7`, same artifact.) Both are **below
the ≥20 %/yr mission** — confirming breadth, not leverage, is the lever.

## 4. The decisions OWNER needs to make

**D1 — Canonical DD basis for deploy sizing.**
Recommend: **MC-p95 (robust), never the observed daily-series DD.** Retire or fix the
`q12_ready_all` generator so deploy-prep emits one DD number. This is a correctness fix, not a
policy call — the 1.53 % path should never reach a T_Live manifest.

**D2 — Initial deploy budget / whether to deploy today's 5-sleeve book at all.**
Three honest options:

- **(D2-a) Deploy a small de-levered tranche now on the DXZ 20 % budget** (book fits at
  MC-p95 13.96 %; ~9.5 %/yr sized) to validate live execution, magic registry, news-blackout,
  and cost realism on real fills — then scale as breadth grows. *Recommended* if the goal is to
  start the live track and de-risk the deploy mechanics early. Below mission, but real.
- **(D2-b) Hold until the book reaches ~8 uncorrelated sleeves**, where MC-p95 DD falls toward
  ~8 % and the book can be levered into the 20 % budget at ~20 %/yr. *Recommended* if OWNER
  wants the first live deploy to already be mission-grade.
- **(D2-c) FTMO-10 %-binding de-lever now** (~0.72×, ~4.7 %/yr). Strictly conservative; only if
  the first live account is FTMO, not DXZ.

This is OWNER's risk call — it trades "live-validation now, sub-mission return" against
"wait for a mission-grade first book."

**D3 — The 6 % cap referenced earlier.**
The 6 %-cap rejection ("no nonempty Q12-ready subset is 6 %-feasible", watchlist §6) was the
assembler trying to meet the cap by **dropping sleeves** (subset search) rather than
**de-levering the whole book**. Dropping to a 2-sleeve XAU+SP500 book *loses the
diversification we just built* (and that 2-sleeve draft itself shows 15 % DD on a 64-day
window — also untrustworthy). Recommend: **the deploy path should meet a DD cap by de-levering
the full diversified book, not by subset-dropping.** Then any cap (6/10/20 %) just sets the
sizing multiplier; it never throws away sleeves.

## 5. Implementation status (2026-06-26)

- **D1 — DONE.** `portfolio_manifest` now computes the robust MC-p95 DD at the canonical base
  and decides the cap on it (`dd_basis_for_cap`, `kpis.mc_p95_max_drawdown_pct`,
  `kpis.observed_max_drawdown_pct`). New `--mc-runs` flag. Falls back to observed DD only if the
  MC run can't load a stream. Helper `_mc_p95_max_drawdown_pct` + tests.
- **D3 — DONE.** `finalize_cap_decision` + `apply_leverage_scale`: an over-cap book is now
  **de-levered to fit** (scale = cap ÷ DD, applied to `account_risk_pct` and every sleeve's
  `risk_percent`/`RISK_PERCENT`), keeping all sleeves. A `de_levered_to_cap` block records the
  scale + basis. `DRAFT_REJECTED_DD_CAP` now only fires when there is no DD to size on (empty
  book / missing KPI). Tests cover de-lever, reject, and the helpers.
- **D2 — OWNER's call (below).** No T_Live action taken; manifests remain deploy-prep drafts.

## 6. Net recommendation

1. ✅ D1 implemented (MC-p95 basis; the 1.53 %/13.8 % numbers no longer drive the decision).
2. ✅ D3 implemented (de-lever the full book to the cap, never drop sleeves).
3. OWNER picks D2: my default is **D2-a** — deploy a small DXZ tranche to start the live track
   and validate mechanics, while breadth (the FX baskets + new asset-class sleeves) grows the
   book toward the mission-grade ~12-sleeve target. If OWNER prefers the first live book to be
   mission-grade out of the gate, **D2-b** (hold) is the call.

Either way, the lever to ≥20 %/yr is unchanged: **more uncorrelated instruments.** The two
OOS-validated FX cointegration baskets (12533 EURJPY~GBPJPY, 12532 AUD~NZD) were just
priority-bumped to the front of the Q02 queue (ranks 33–35 / 884) to add the empty FX column.

Evidence: `D:/QM/reports/portfolio/book_analysis_2026-06-26.json`,
`D:/QM/reports/portfolio/portfolio_manifest_q12_ready_{all,5sleeve}_DRAFT_20260626.json`,
`D:/QM/reports/portfolio/portfolio_manifest_tlive_DRAFT_20260626_rp.json`,
`docs/ops/portfolio_candidate_watchlist_20260626.md` §6,
`docs/research/PORTFOLIO_PATH_TO_PROFITABLE_2026-06-26.md` §1.
