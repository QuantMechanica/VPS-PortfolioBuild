# Decision: Q10 recency axis — enforcement + rolling live-sleeve re-qualification

- Date: 2026-07-26
- Status: accepted (OWNER: „6: folge Deiner Empfehlung", 2026-07-26 midday)
- Basis: WS-C decay audit (`D:/QM/reports/ultracode_20260726/wsc/`), DL draft therein;
  Codex challenge WS-C revisions (honest coverage, UNKNOWN propagation, endpoint labeling).

## The problem

Q10 certifies 8-year-average edge, not current edge: 12567/XNGUSD held a full-history Q10
PASS while its sealed Q08 showed 41.5 % edge decay (last-half PF 1.032). The WS-C audit of
the live book (endpoint 2025-12-31): CURRENT 20, WATCH 1 (13128), DECAYED 1 (10939),
UNKNOWN 2 (10919 low-N, 12567/XNG no row) — with the three cap-1.0 sleeves exactly the
three not confirmed CURRENT.

## The rule

1. **Shadow first (tonight):** `recency_shadow_v1` fields (trailing-12m/24m PF, trades,
   net, half-vs-half decline, window endpoint + age) persist in every Q10 aggregate;
   verdict untouched (WS-C patch, merged in the 2026-07-26 Factory-OFF window).
2. **Enforcement from the next Q10 cohort:** Q10 PASS additionally requires
   trailing-24m PF >= 1.0 at >= 10 trailing trades, and half-vs-half decline < 40 %
   (aligned with the Q08 convention). Insufficient trailing trades => verdict stays but
   the aggregate carries `recency: UNKNOWN` — a live-deployment blocker flag, not a FAIL
   (low-frequency swing sleeves per DL-070 must not be killed by N alone).
   Windows are labeled by their actual data endpoint; an endpoint older than 9 months
   itself sets `recency: STALE_WINDOW`.
3. **Rolling re-qualification of LIVE sleeves:** every live sleeve gets a sealed re-Q08
   quarterly (next wave due 2026-10-01); a FAIL_HARD or DECAYED outcome goes to OWNER as
   a composition decision — never auto-removal (survivor-port purity preserved).

## Guard rails

- Anchors (24m window, PF 1.0 floor, 40 % decline, 10-trade floor, 9-month staleness) come
  from the measured WS-C distribution (21/22 assessable sleeves below +20 % trailing
  decline); changes require a new dated decision.
- The constant flip (RECENCY_AXIS_ENFORCED) lands only with the merged, Codex-reviewed
  WS-C patch; until then shadow-only.
