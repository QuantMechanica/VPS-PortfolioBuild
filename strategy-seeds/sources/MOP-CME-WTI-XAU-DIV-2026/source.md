---
source_id: MOP-CME-WTI-XAU-DIV-2026
parent_source_ids:
  - MOP-TSMOM-2012
  - CME-OIL-GOLD-RATIO-2024
title: WTI Twelve-Month Trend In A Gold-Divergence State
publisher: QuantMechanica governed composite of peer-reviewed and exchange sources
source_type: governed_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-14_wti_xau_div_trend_source_approval.md
g0_decision: decisions/2026-08-14_qm5_21523_wti_xau_div_trend_g0.md
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  CME-OIL-GOLD-RATIO-2024: 71BDFA8A8D291655AC44EC2B3F12CB1ED21D08763C540C32687238579A279CDE
created: 2026-08-14
created_by: Research+Development
cards_extracted:
  - QM5_21523_wti-xau-div-tr
---

# WTI Trend In A Gold-Divergence State — Source Packet

## Approved Sources Of Record

The governed parent packets were read before this extraction:

- Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
  "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250.
  The complete published-paper review and retrieval receipt are preserved at
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
- CME Group (2024), "Through the Lens of Gold." The bounded exchange-source
  notes are preserved at
  `strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/source.md`.

The durable OWNER source approval is
`decisions/2026-08-14_wti_xau_div_trend_source_approval.md`. Parent hashes in
the frontmatter bind this extraction to the repository material actually
reviewed.

The mandatory generic-source router classified a fresh read of the CME URL as
`PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY`. The exact receipt is
`strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/retrieval_route_20260814.json`.
No live-page text, cached mirror, proxy, quotation, or inferred page content
is used by this packet.

## Findings Used

Moskowitz, Ooi, and Pedersen define time-series momentum from the sign of an
instrument's own past return, with monthly decisions and holding periods. The
selected twelve-month rule is positive across the broad futures sample, and
WTI crude oil is an explicit source contract. The paper does not report a
WTI-only return, a gold-divergence gate, or a Darwinex CFD result.

The governed CME packet frames crude oil through gold as relative value and
separates oil's energy supply/growth exposure from gold's monetary and
safe-haven role. It establishes the economic pairing only. It does not test
opposite twelve-month signs, WTI-only execution, or a monthly strategy.

## Bounded Composite Mechanization

The card tests whether the established WTI trend can isolate an energy-
specific state when gold, the certified metal carrier, trends in the opposite
direction over the same completed-month endpoints.

At the first processed WTI D1 bar after a genuine broker-month transition:

1. Intersect bounded completed WTI and gold D1 histories by exact timestamp.
2. Derive exactly thirteen consecutive common broker-month endpoints ending
   in the immediately completed month.
3. Calculate the two exact endpoint log returns:

```text
wti_trend_12m = ln(WTI_latest / WTI_12_months_older)
xau_trend_12m = ln(XAU_latest / XAU_12_months_older)
```

4. For each series, verify that its endpoint return equals the sum of the
   twelve component monthly log returns within `1e-10`.
5. Buy WTI when its return is strictly above `1e-12` and gold's is strictly
   below `-1e-12`. Sell WTI under the exact inverse condition.
6. Consume same-sign, tied, deadband, stale, misaligned, or invalid states
   flat.

The strict opposite-sign conjunction is not tested by either parent source.
It is a predeclared falsifiable QM hypothesis intended to reject common
commodity direction, not a source replication or a proven correlation hedge.

## Exact Runtime Contract

- Host and trade only `XTIUSD.DWX` on D1, slot 0, magic `215230000`.
- `XAUUSD.DWX` is read-only. It has no magic, order, position, package-PnL,
  or risk-budget authority.
- Load bounded completed D1 histories, intersect exact timestamps, require
  strict chronology, and derive exactly thirteen consecutive common broker-
  month endpoints. The newest endpoint must be no more than ten calendar days
  stale.
- Use log returns, strict `1e-12` sign deadbands, a `1e-10` endpoint-chain
  equality tolerance, and no magnitude-weighted sizing.
- Consume the broker month before history, signal, news, spread, quote, ATR,
  sizing, or order gates. No stopped, blocked, failed, or flat decision may
  retry in the same month.
- Use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` broker hard stop, no take-profit, and a 1,500-point entry
  spread cap.
- Close before monthly replacement or after forty calendar days. Friday close
  and both news axes are OFF for the source-aligned monthly hold.

No same-sign confirmation, ratio, z-score, channel, short-window return
spread, two-leg order, gold risk allocation, external series, trained output,
signal indicator, or fallback estimator is equivalent.

## Evidence And Claim Boundary

- The momentum paper pools 58 futures and does not establish WTI-only alpha.
- The CME packet establishes a relative-value lens, not a trading return or
  opposite-sign anomaly.
- Fixed-maturity collateralized futures and continuous Darwinex CFDs have
  different roll, financing, gap, and execution effects.
- Opposite endpoint signs do not prove low daily, tail, nonlinear, or
  portfolio correlation. Q09 alone may evaluate realized book overlap.
- The gold filter can suppress too many months; Q02 retires below the binding
  density floor rather than weakening the rule.
- No source or sibling performance, significance, cost, density, drawdown,
  neutrality, or correlation statistic transfers.

## Non-Duplicate Boundary

The canonical pre-allocation check was `CLEAN` across 4,395 registry rows and
491 root cards. Manual review separates the closest families:

- `QM5_12604_cme-oilgold-ratio` fades a daily absolute log-ratio z-score and
  orders both WTI and gold.
- `QM5_12605_cme-oilgold-brk` follows a daily ratio channel and orders both
  legs.
- `QM5_12863_oilgold-rspread` fades a short-window relative-return shock and
  orders both legs.
- Unconditional WTI TSMOM has no gold state. Recent WTI decoupling, Brent
  confirmation, and downside-beta filters use XNG, Brent, or SP500 state
  rather than gold's opposite twelve-month sign.
- `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon XNG pullback.

This card forms no ratio, z-score, channel, shock, basket, or gold position.
Verdict:
`CLEAN_WTI_TWELVE_MONTH_TREND_IN_STRICT_GOLD_DIVERGENCE_STATE`.

## Reputable-Source Criteria

- R1 `PASS_WITH_POLICY_DEFER`: one composite source ID, complete peer-reviewed
  momentum-paper evidence, governed CME exchange evidence, and an honest
  deferred fresh-route receipt.
- R2 `PASS`: synchronized month endpoints, exact return checks, strict signs,
  direction, attempt, risk, stop, rollover, and stale guard are fixed.
- R3 `PASS`: registered WTI and gold D1 closes supply all runtime data; only
  WTI is traded.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Q02 retires below five completed positions per full post-warm-up year or on
nonpositive governed economics. Do not rescue failure by changing the return
horizon, endpoint synchronization, sign deadbands, opposite-sign direction,
cadence, traded/read-only roles, fixed risk, stop, hold, spread, or retry
policy.

This packet authorizes one branch-only non-live build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress/optimization
setfile, AutoTrading action, `T_Live` or deploy manifest, portfolio-gate edit,
portfolio admission, or correlation waiver.
