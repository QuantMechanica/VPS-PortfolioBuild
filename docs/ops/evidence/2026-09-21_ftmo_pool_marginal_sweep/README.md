# Validated-pool marginal sweep against D2g6 (Fable, 2026-09-21 19:47–19:55Z) — OWNER §10 "pool sweep is good but not sufficient"

Engine: `tools/strategy_farm/ftmo/book_sim.py` v2 (Codex 3fae43b2), financed streams (deployable `streams_fin_full` for 8 sleeves;
7 raw-only sleeves financed on the fly with the 2026-09-18 `swap/financing_lib.py` variant `fin`, provenance in `sleeve_map.json`
and the plan), 5 paired seeds × 40,000 marginal paths, 504-bd marginal horizon, base 5,000 paths / 1008 bd, 20-day blocks, fixed
window 2019-01-22..2025-11-21. Every Q08 sleeve with a trade stream that is not in D2g6 and was not already measured
(11708/11910/11421) — 14 candidates; 9641 WS30 skipped (no financing rate); 21501/41221 skipped (duplicate lineage of 13213/11421).

## Marginal table (add at 0.3125 %; base financed LCB 0.8668)

| Candidate | Δ LCB mean | SE | Δ max-loss breach | Δ DD USD | Δ trades/bd | Δ cost USD/bd | Δ time-to-target bd | Deployability (09-18 class) |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 12855 XTIUSD D1 brent-nov-fade | **+0.109** | 0.0024 | −0.008 | 0 | +0.080 | +0.18 | −14.1 | B (symbol literal :51/:117) |
| 21505 XAGUSD D1 xag-weekly-lowvol-momentum | **+0.064** | 0.0019 | −0.006 | −238 | +0.061 | +1.07 | −4.6 | A |
| 11660 NDX H4 pp-wedge | +0.048 | 0.0006 | **+0.014** | **+3,148** | +0.726 | +5.63 | −26.0 | B+C |
| 12710 XTIUSD D1 commodity-tsmom-12m-atr | +0.025 | 0.0011 | −0.003 | +339 | +0.043 | +0.13 | −3.9 | B (:56 / :150) |
| 20266 XTIUSD D1 collins-66mom | +0.025 | 0.0013 | −0.001 | +725 | +0.211 | +0.50 | −5.9 | B (:69) |
| 12849 XTIUSD D1 brent-tsmom12m | +0.023 | 0.0010 | −0.002 | +339 | +0.045 | +0.13 | −3.4 | B (:53) |
| 13054 XTIUSD D1 brent-tom-mom | +0.020 | 0.0006 | −0.001 | −201 | +0.039 | +0.06 | −3.9 | A |
| 10145 XAUUSD D1 | −0.010 | | +0.005 | −90 | | +3.23 | | A |
| 11881 GBPUSD D1 | −0.010 | | | −443 | | | | B |
| 21507 XAUUSD D1 | −0.016 | | | +388 | | +3.47 | | B |
| 10513 XAUUSD D1 | −0.026 | | | +94 | | | | A |
| 20048 XTIUSD D1 | −0.035 | | | | | | | B |
| 13013 NDX M15 | −0.062 | | +0.008 | | | | | C |
| 1537 XAGUSD D1 | **−0.169** | | **+0.023** | | | | | A |

All fourteen deltas are RESOLVED at 5 × 40k (SE 0.0006–0.0024).

## Concentration check (financed streams, source risk 1 %) — the marginal engine is blind to rare-winner dependence

| Sleeve | Trades | Net USD | Top-3 trades / net | Years positive | Reading |
|---|---:|---:|---:|---|---|
| 12855 | 169 | +2,288 | **134 %** | 4 of 8 (2018 +2,730, 2020 −3,318) | the whole net sits in three trades — rare-winner artefact; the +0.109 is the bootstrap resampling those trades |
| 21505 | 116 | +1,023 | **362 %** | 3 of 8 (2023 +3,640, else losing) | rare-winner artefact; REJECT as a velocity sleeve |
| 13054 | 82 | +4,465 | 77 % | 4 of 8 | concentrated; modest +0.020 |
| 12710 | 82 | +6,825 | 53 % | **7 of 8** | the most robust profile in the pool; +0.025, class B (symbol-input rebuild needed) |
| 20266 | 432 | +5,773 | 68 % | 5 of 8 | dense (0.21/bd), mixed years; +0.025 |

Consequences: (1) 12855 and 21505 are NOT shadow-book candidates on this evidence despite the largest deltas — the marginal engine
needs a TAIL_CONCENTRATION / rare-winner metric and a filter (routed to ticket `bc00c556`); (2) the serious pool candidates are the
oil sleeves 12710 (+ 13054, 20266) — joint runs, dependence and cost stress in `../2026-09-21_ftmo_pool_marginal_sweep/joint/`
(follow-up); (3) the pool cannot supply the missing NY-session role at all — Track B research remains the only path to velocity.
