# QM5_41355_xauxag-mtrim2-rv - Strategy Spec

**Status:** G0 APPROVED; non-live build only  
**Slug:** `xauxag-mtrim2-rv`  
**Strategy ID:** `AI-CODEX-XAUXAG-MTRIM2-RV-20260905_S01`  
**Card:** `strategy-seeds/cards/approved/QM5_41355_xauxag-mtrim2-rv_card.md`

## Mechanic

On the first synchronized executable D1 bar of a broker month, collect the
latest common XAUUSD.DWX/XAGUSD.DWX completed close in each of the immediately
prior thirteen consecutive broker months. Form twelve chronological adjacent
log-ratio returns, sort ascending, delete indexes `0,1,10,11`, and average
indexes `2..9` over exactly eight. Fade the sign outside `1e-12`:

- positive middle-eight mean: sell XAU, buy XAG;
- negative middle-eight mean: buy XAU, sell XAG;
- otherwise: consume the month flat.

Open only an equal-target-notional opposed pair. Divide one
`RISK_FIXED=1000` aggregate frozen-stop budget across `3.5*ATR(20,D1)` stops,
hold to the next broker month, and repair after forty elapsed days or any
malformed package state. No retry, single-leg fallback, target, trailing,
scale-in, grid, martingale, pyramid, optimization, or external runtime data.

## Framework alignment

| Contract | Implementation |
|---|---|
| no-trade and attempt | exact identity/input checks, synchronized monthly clock, persistent consumed-month key |
| entry | synchronized endpoint reconstruction, fixed trim, contrarian side, fixed aggregate risk, equal notionals, atomic two-leg open |
| management | pair integrity, expected side, notional tolerance, original hard stops |
| close | next-month, forty-day stale, malformed-pair, and framework kill-switch closure |

## Validation

`docs/test_xauxag_mtrim2_rv_reference.py` independently pins sorting, retained
indexes, sign/reflection, degeneracy, synchronized ratio returns, and the
side-disagreement fixture versus the nearest Hampel and bisquare EAs.

This build does not establish profitability or decorrelation. Q02 owns baseline
economics; Q09 alone owns realized book overlap. Portfolio gates, deploy/live
manifests, `T_Live`, and AutoTrading remain outside scope.
