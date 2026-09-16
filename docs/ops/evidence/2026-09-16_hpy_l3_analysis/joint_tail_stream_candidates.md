# Joint-tail stream candidates — H-PY / H-PY2L vs H-CW / H-MR overlap testing

**Date:** 2026-09-16 · **Read-model source:** `D:/QM/reports/state/book_evolution_dxz.json`
(2026-W38, generated 2026-09-15T14:23Z) · **Protocol:** TAIL_RISK programme §8 +
`PORTFOLIO_TAIL_RISK_RESEARCH.md` §4 (wave-2 engine, f1/f2 assigned to Fable).
All streams below are read-only inputs; nothing here claims any overlap result.

## 1. Same-symbol sealed streams already on the farm (primary overlap candidates)

H-PY / H-PY2L trade NDX.DWX / GDAXI.DWX / SP500.DWX in the cash session. The
sealed streams sharing that symbol factor:

| ea_id | symbol | role in DXZ read-model | magic |
|---|---|---|---|
| 13128 | NDX.DWX | incumbent live_24 sleeve | 131280000 |
| 10440 | NDX.DWX | incumbent live_24 sleeve | 104400003 |
| 13301 | GDAXI.DWX | incumbent live_24 sleeve | 133010010 |
| 10911 | GDAXI.DWX | incumbent live_24 sleeve | 109110003 |
| 11132 | SP500.DWX | incumbent live_24 sleeve | 111320000 |
| 11660 | NDX.DWX | challenger, Q14 stream | — |
| 13013 | NDX.DWX | challenger, Q14 stream | — |

These seven are the first-pass pair set for co-exceedance / lower-tail
dependence / worst-day overlap once an H-PY-family stream exists.

## 2. The three FTMO candidates' planned streams (do not exist yet)

The joint-tail protocol needs per-sleeve sealed Q08/Q14 streams; none of the
FTMO session-flat candidates has been built yet (cards only, G0 APPROVED,
review_status REVIEW_PENDING; the programme is SPECIFICATION_ONLY at family
level):

| card ea_id | research source | stream status |
|---|---|---|
| QM5_41475 (H-CW cash-window continuation) | QM-RESEARCH-2026-0002 | planned — build lane pending |
| QM5_41476 (H-MR cash-open mean reversion) | QM-RESEARCH-2026-0006 | planned — build lane pending |
| QM5_41479 (H-PY 3-level pyramid) | QM-RESEARCH-2026-0007 | planned — build lane pending |
| QM5_41480 (H-PY2L two-level pyramid) | QM-RESEARCH-2026-0008 (variant of 0007) | planned — minted 2026-09-16 |

Note for the engine: H-PY (41479) and H-PY2L (41480) realize the identical
path by construction (the 3-level pilot never filled L3), so once either
stream exists the other adds no new joint-tail information; the protocol only
needs one of them against H-CW/H-MR.

## 3. Full passive-book reference set (worst-day overlap baseline)

- Incumbent `live_24`: all 24 sleeves in the DXZ read-model (index sleeves
  above plus EURUSD/GBPUSD/AUDUSD/USDJPY/USDCAD/AUDCAD/EURGBP FX sleeves and
  XAUUSD/XAGUSD/XTIUSD/WS30 commodity/index sleeves — full list in the
  read-model `incumbent.sleeves`).
- Challengers: 20 Q14-stream candidates in `challengers` (1537, 9641, 10145,
  10700, 11422, 11660, 11881, 11910, 12710, 12849, 12855, 13013, 13054, 20048,
  20266, 21501, 21505, 21507, 41219, 41221).
- Method: 2000 seed-pinned permutations independence baseline, block
  bootstrap block=10d (mirrors the book-evolution convention), λ_L estimator
  at α ∈ {0.05, 0.025, 0.01}, per PORTFOLIO_TAIL_RISK_RESEARCH.md §4 and
  programme §8 steps 1-12. Outcome until the engine runs: EVIDENCE_MISSING.
