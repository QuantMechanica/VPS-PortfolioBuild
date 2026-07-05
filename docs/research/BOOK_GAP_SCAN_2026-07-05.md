# Book Gap Scan — DXZ-15 + FTMO-12 vs. candidate pool (2026-07-05)

**Trigger:** OWNER 2026-07-05 („Was fehlt uns noch in den Büchern? Welche EAs brauchen
wir dazu noch?") — quantitative follow-up to the structural gap assessment.

## Method

- Streams: 15 frozen DXZ S3 book streams
  (`D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\frozen_streams`,
  10940 excluded per S3 swap) + 12 FTMO Round25 legs (DWX-proxy q08 streams; FTMO
  trades .cash translations of the same underlyings) + all candidate streams with
  pipeline standing (Q08 `FAIL_SOFT` — the soft-fail Q09 feeder per DL-075 — or any
  `Q09_PORTFOLIO` verdict), 40 streams total after dedupe; 0 plausibility-quarantined.
- Correlation: `portfolio_correlation.py` daily basis was too sparse for the low-freq
  sleeves (52/780 pairs ≥60 overlap days) → **monthly net-P&L basis** computed from raw
  streams (zero-filled shared active span, Pearson, ≥24 shared months) — mirrors the
  `portfolio_admission.py` monthly fallback used in the D2-d composite.
- Artifacts: `D:\QM\strategy_farm\artifacts\portfolio\book_gap_scan_20260705\`
  (`correlation_40streams.json`, `gap_scan_monthly_summary.json`).

## Findings

**1. The DXZ book is orthogonality-saturated.** Max within-book |corr| = 0.34 — and it
is *negative* (10939/GBPUSD vs 11165/AUDCAD). No positive within-book pair exceeds
+0.25. More of any existing family adds nothing; only genuinely new families move the
needle (consistent with the VaR-filled → orthogonal-growth directive).

**2. The FTMO book has real clusters.** Largest: 10700+10848 (both XAUUSD H1) +0.46;
12990→10700 +0.43; 10440→10700 +0.40; plus the known US100×4 concentration. Best
internal hedges: 10847/GBPUSD vs 12958/XAU −0.46, 10286/USOIL vs 12958 −0.45.

**3. The candidate pool reproduces the book's families instead of filling gaps.**
All 16 measurable candidates are NDX/SP500/GDAXI/XAUUSD. The index candidates sit at
+0.55…+0.71 vs 11132/SP500 (admission FAIL_PORTFOLIO — correctly rejected). Best
orthogonal candidate: 10938/GDAXI (max |corr| 0.22, `NEED_MORE_DATA`). **Zero
candidates exist in:** FX crosses, silver, energy, defensive/vol, calendar (family
still pre-Q08). The pipeline's survivor tail is family-inbred.

**4. Card inventory says most "gaps" are BUILD gaps, not research gaps**
(2 448 ready approved cards; inventory cross vs `framework/EAs/`):

| Family | approved cards | unbuilt | verdict |
|---|---|---|---|
| EURUSD-targeted | 922 | **62** | build gap — prime builds |
| JPY-crosses | 189 | 9 | build gap |
| NZD / CHF | 92 / 148 | 5 / 5 | build gap (same H4 card set) |
| Calendar/seasonal | 27 | 1 real (12933) | family runs via calendar sweep Wave 2 |
| XAG | 32 | **0** | **research gap** — bench exhausted, 0 survivors |
| Defensive/long-vol | 37 | 7 (bear-pattern only) | **research gap** — no true crisis-alpha |
| Pairs/spread | ~1 survivor family | — | **research gap** (AUDUSD~NZDUSD has no siblings) |

## Actions taken (2026-07-05 evening)

1. **29 builds primed** via `farmctl build-ea` (0 failures): 8× EURUSD mql5-series
   (12946–12955), 5× NZD/CHF H4 set (9451/9453/9502/9504/9505), 8× JPY-cross,
   1× calendar (12933 turn-of-month), 7× defensive/bear-pattern (incl. 1572
   ls-mom-bear24, 9410 boom-crash).
2. **Router tickets enqueued** (explicit gap-directed routing; generic replenishment
   remains frozen — reservoir is 2 448, far above the <5 threshold):
   - `ba0dbed9` research_strategy/video (agy): pairs/cointegration mechanics.
   - `d2bc5e78` research_strategy/video (agy): XAG mechanical strategies.
   - `d5199d43` research_strategy/text (claude): CFD-implementable crisis-alpha
     (no options — long-vol via options is not V5-expressible).
3. agy video watchlist (in ticket payloads): pairs — youtube 1zz91G0nR14,
   HLCUde6Afdc, YDMSqal-RZ4; XAG — Fq0U04C5jB8, -QBjgRnPhG8, g9nuAS7TzQM.

## Caveats

- FTMO-leg correlations are DWX-proxy based (contract specs differ on FTMO .cash
  symbols; correlation structure carries over, levels are approximate).
- Monthly basis with zero-fill measures *portfolio contribution* correlation, not
  trade-level dependence; consistent with the admission fallback but coarser.
- 3 candidates had <24 shared months (10069, 10569, 12847 — the latter DEFECTIVE per
  07-02 audit) and are unmeasured.
