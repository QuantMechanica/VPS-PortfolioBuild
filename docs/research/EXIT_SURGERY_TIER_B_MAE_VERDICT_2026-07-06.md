# Exit-Surgery Tier B — MAE Verdict (2026-07-06, Fable program #4)

**Question:** Tier B of the exit-surgery scan (2026-07-04) — "SL too tight" on
the live sleeves 10715/USDJPY, 10440/NDX, 10476/USDCAD — was PARKED because
hold-gradient evidence is tautological for stop-based systems. The 06-30
intraday-MAE capture now allows the real test: do winners routinely survive
deep adverse excursions (stop clips edge) or do winners and losers separate
early (stop is not binding)?

**Method:** one fresh full-history (2017-2025) canonical backtest per sleeve on
free terminals (T8/T9/T10), binaries recompiled 2026-07-06 (includes MAE capture
+ audit fixes; compile 0/0 each). RISK_FIXED sizing makes the stop distance in
money a known constant, verified per-sleeve by the losers' MAE/stop median =
1.00 (sanity anchor). Sweeney MAE analysis on winners.

**Streams:** Common\Files QM\q08_trades — 10715_USDJPY (1,466 trades),
10440_NDX (618), 10476_USDCAD (255), all 100% MAE-covered.

## Results (winner MAE as fraction of stop distance)

| sleeve | n | med | p75 | p90 | ≥0.5 | ≥0.7 | ≥0.8 | ≥0.9 | loser med |
|---|---|---|---|---|---|---|---|---|---|
| 10476/USDCAD | 255 | 0.00 | 0.00 | 0.30 | 3.6% | 2.7% | 1.8% | 0.9% | 1.00 |
| 10440/NDX | 618 | 0.00 | 0.00 | 0.00 | 1.7% | 0.4% | 0.4% | 0.4% | 1.00 |
| 10715/USDJPY | 1,466 | 0.29 | 0.51 | 0.73 | 26.0% | 11.7% | 6.0% | 1.9% | 1.00 |

## Verdict: Tier B CLOSED — REJECTED for all three. No live-parameter changes.

- **10440 / 10476:** winners essentially never go adverse (median MAE 0.0×
  stop). Winners and losers separate immediately; a trade that draws near the
  stop is not a winner-in-waiting. Widening the SL only enlarges losses and
  (via equal-risk sizing) shrinks size — strictly worse.
- **10715:** genuine adverse tolerance exists (26% of winners ≥0.5× stop), but
  the boundary density decays steeply (only 1.9% in the last decile). Widening
  to 1.3× recovers an estimated ~20 of 766 losers (~51k benefit at avg-win +
  stop values) while costing ~30% extra on ~750 remaining losers (~224k) —
  roughly 4:1 against. The stop sits where it should.
- Secondary observation (10715 only, recorded, NO action): the same table
  hints a slightly TIGHTER stop could be marginally positive (~+28k/9y,
  borderline). Not worth touching a live sleeve's risk geometry on in-sample
  MAE; the Q03 sweep explores `strategy_atr_sl_mult` at the next natural
  rebuild anyway — the sweep, not a hand edit, is the sanctioned instrument.

This closes the loop opened by the T-WIN hold-gradient work: the hold-gradient
signal on stop-exit systems ("short-hold losers") was indeed tautology for
these three, now shown with capture data instead of reasoning alone. Tier A
(time-exit amputation) remains the only validated exit-surgery lever — its 6
v2 builds (13012-13017) are in the funnel.

**Caveats:** 10440's fresh run trades 618 vs 274 in its old stream over the
same window — consistent with the 07-05 news-index-defect fix unblocking
entries (short symbols were blocked by every event pre-fix); MAE geometry
per-trade is unaffected, but cross-run comparisons of trade counts are not
apples-to-apples. MAE is measured in account currency on tick basis
(mae_acct); exact-0.00 medians mean floating PnL never went negative — the
capture is validated by the losers' 1.00 anchor in every stream.

**Artifacts:** streams above; runs under `D:\QM\reports\mae_capture\QM5_107*`,
`QM5_10440`, `QM5_10476` (run_smoke ADHOC/mae_tierb).
