# T_Live decision — S4: 15 → 17 sleeves (first probation admits)

**Status: DEFERRED BY OWNER (2026-07-06 chat) — candidate collection through
end of week, then ONE combined session admitting the week's harvest to BOTH
books (DXZ + FTMO).** Package stays staged and valid (frozen streams); weights
will be RECOMPUTED over the final candidate set before the session (the compute
script re-runs in minutes — do not reuse these S4 weights if the set grows).
Collected so far: 10706/GBPUSD (Q09 PASS), 11708/EURUSD (Q09 PASS),
12778/AUDUSD~EURJPY pairs basket (PASS pending official re-run post
f8e79266b fix). FTMO side: same candidates feed a Round26 recomposition via the
report.htm chain once ≥3 new validated reports exist.

## Decision basis

- Candidates (both Q09 `PASS_PORTFOLIO`, daily corr basis, in `portfolio_candidates`
  Q12_REVIEW_READY):
  - **QM5_10706 / GBPUSD.DWX** (tv-mon-ls, H1, magic 107060001) — salvage lane
    (Q05 dd-waiver, OWNER-ratified 2026-07-05): max corr to book **0.006**,
    Sharpe with/without 2.323/2.318. Q08 FAIL_SOFT feeder, 367-trade stream.
  - **QM5_11708 / EURUSD.DWX** (anon-market-squeeze-d1, D1, magic 117080000) —
    regular cascade: max corr to book **−0.024**, Sharpe with/without
    **2.511/2.407**. Fills the EURUSD family gap (BOOK_GAP_SCAN_2026-07-05).
- **Probation terms** (Q05_SALVAGE_TRACK governance, applied to both admits for
  uniformity): HALF capped-inv-vol weight, 42-day burn-in review, freed risk
  redistributed pro-rata to veterans. Total summed risk **9.75% unchanged**.
- NOT admitted: QM5_1556 (Q09 PASS but build is codex_review_rework-flagged —
  blocked until OnTick rework + fresh cascade; router gap ticket pending).

## Composite evidence (frozen streams, SHA-chained)

Artifacts: `D:\QM\strategy_farm\artifacts\portfolio\s4_composite_2026-07-06\`
(`s4_composite_compute_2026-07-06.py` — faithful adaptation of the d2d compute
chain; `s4_composite_metrics_2026-07-06.json`; 17 frozen streams; 17 staged presets).

| Metric | S3 (15, reference) | **S4 (17, probation)** |
|---|---|---|
| Sharpe | 2.027 | **2.091** |
| MaxDD % | 5.156 | **5.139** |
| Monthly VaR95 % | 2.073 | **2.032** |
| Worst day % | −1.541 | **−1.486** |
| Annual return % | 11.211 | 11.187 |

S4 dominates on every risk metric at equal return. Note: S3 reference was
recomputed with the identical machinery (ratified-weight recovery from the d2d
JSON failed); its Sharpe matches the ratified package (2.027 vs 2.03), and both
scenarios share machinery, so the deltas are internally consistent.

## S4 weight table (RISK_PERCENT per sleeve, Σ = 9.75)

1.0: 10919/XTI, 11132/SP500, 11165/AUDCAD, 12567/XAU, 12567/XNG ·
0.8040 11421/AUDUSD · 0.7746 10513/XAU · 0.7479 11421/EURUSD · 0.5028 12989/XAU ·
0.3921 10939/GBPUSD · 0.3589 10715/USDJPY · **0.3004 11708/EURUSD [PROBATION]** ·
0.2755 10911/GDAXI · 0.2061 10476/USDCAD · 0.1939 10692/NDX · 0.1420 10440/NDX ·
**0.0520 10706/GBPUSD [PROBATION]**

(10706's half-weight is small by construction — high stream vol; its live value
in the burn-in period is track-record building; the 42d review can promote to
full inv-vol weight.)

## Verification (Claude, pre-approval)

- [x] 17 staged presets generated; **carry-over param-diff 15/15 clean** (only
      `RISK_PERCENT` + 2 header comments differ vs the CURRENT LIVE presets —
      the S3 C2-class protection pattern)
- [x] 2 new presets: strategy params 1:1 from validated backtest setfiles;
      ENV=live, RISK_FIXED=0, RISK_PERCENT=weight; magic slots per registry
      (107060001 / 117080000, anchored lookup)
- [x] Fresh binaries compiled vs current includes (PASS 0/0 both), committed,
      SHA-pinned in staging (`722ef7759bdf…` / `2734ae934765…`)
- [x] Frozen streams SHA-chained (15 from ratified d2d frozen + 2 fresh from
      Common, durable snapshots refreshed)
- Staging: `C:\QM\deploy\S4_2026-07-06\` (presets/, live_eas/, SHA manifests,
  ANLEITUNG_S4.md)

## Workflow ahead (Hard-Rule order)

1. **OWNER manifest approval in writing** ← YOU ARE HERE
2. Claude: file-side deploy (presets + 2 binaries → T_Live, SHA re-verify;
   backup of current 15 presets first)
3. OWNER: chart session per ANLEITUNG (15 preset reloads + 2 new attaches;
   AutoTrading untouched)
4. Claude: journal verification (17× INIT_OK, magic set 17/17), pulse
   EXPECTED_LIVE_SLEEVES 15→17, mc_reference regeneration (book changed),
   "Charts applied" recorded here
5. 42d probation review scheduled

## Sign-off

- Package: Claude, 2026-07-06
- Manifest approval: _pending OWNER_
- Charts applied: _pending_
