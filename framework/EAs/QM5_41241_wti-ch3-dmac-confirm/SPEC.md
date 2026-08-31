# QM5_41241_wti-ch3-dmac-confirm - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 PASS; Q02 ENQUEUED_PENDING`

## Identity

**EA ID:** QM5_41241

- EA ID: `QM5_41241`
- slug: `wti-ch3-dmac-confirm`
- strategy ID: `SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026_S01`
- source ID: `SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026`
- source packet:
  `strategy-seeds/sources/SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026/source.md`
- source approval:
  `decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41241_wti-ch3-dmac-confirm_card.md`
- G0 decision:
  `decisions/2026-08-31_qm5_41241_wti_ch3_dmac_confirmation_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412410000`

## 1. Strategy Logic

At the first genuine normalized broker-month transition into `(Y,M)`, close
the preceding package and consume the new `yyyymm` attempt before any
fallible entry-only gate. Reconstruct exactly six consecutive completed WTI
broker-month closing prices, newest first, as `C0..C5`. The current month is
never an input.

```text
CH3  = BUY  if C0 > max(C1,C2,C3)
       SELL if C0 < min(C1,C2,C3)
       FLAT otherwise

mean6 = (C0+C1+C2+C3+C4+C5)/6
DMAC  = BUY  if C0 > mean6*1.025
        SELL if C0 < mean6*0.975
        FLAT otherwise

signal = CH3 only when CH3 == DMAC and CH3 != FLAT; otherwise FLAT
```

Every comparison is strict. Missing or nonconsecutive endpoints, invalid
arithmetic, equality, a flat parent, or parent disagreement consumes the
month without entry. An accepted position holds to the next broker month
behind one frozen hard stop, subject only to malformed-state and 40-day
survivor repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_channel_months` | 3 | strict prior-close channel |
| `strategy_mean_months` | 6 | arithmetic closing-price mean |
| `strategy_band_pct` | 2.5 | symmetric DMAC neutral band |
| `strategy_history_bars_d1` | 300 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_stop_multiple` | 4.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Slot 0, deterministic magic `412410000`.
- Direct WTI is outside the certified XAU/SP500/NDX/XNG carrier set; only an
  unchanged downstream portfolio gate may establish realized decorrelation.
- No proxy, basket, external feed, or second traded symbol.

## 4. Timeframe

Execution, endpoint reconstruction, risk range, and structural clock are D1.
The EA attempts entry at most once per normalized broker month and renews at
the next genuine month boundary.

## 5. Expected Behaviour

After six completed months of warm-up, the cadence prior is approximately
five to eight completed positions per full year because the strategy trades
only the intersection of two source rule states. Q02 retires on zero trades,
fewer than five completed positions in any full scored year, invalid risk,
nondeterminism, or nonpositive governed economics. It does not tune any rule.

The fixtures make the distinct decision surface explicit:

- `[103,100,99,98,120,120]`: CH3 buy, DMAC sell, candidate flat;
- `[110,111,109,108,80,80]`: CH3 flat, DMAC buy, candidate flat;
- `[120,110,105,100,95,90]`: both buy, candidate buy; and
- `[80,90,95,100,105,110]`: both sell, candidate sell.

## 6. Source Citation

Szakmary, Shen, and Sharma (2010), *Trend-following trading strategies in
commodity futures: A re-examination*, *Journal of Banking & Finance* 34(2),
DOI `10.1016/j.jbankfin.2009.08.004`, provide the monthly channel and dual
moving-average rule families and explicit crude-oil membership. The complete
review evidence is preserved by the approved source packet.

The paper does not test the exact AND intersection, a single WTI CFD, the
operational attempt ledger, fixed-dollar risk, the ATR stop, or book
correlation. Those are disclosed pre-result QM choices; no source performance
or correlation result transfers.

## 7. Risk Model

The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each entry receives one frozen `4.0*ATR(20,D1)` broker
hard stop and no target. Both news axes and legacy news are OFF; Friday close
is OFF so the structural monthly hold may span weekends.

The EA owns at most one exact-symbol, exact-magic position. It has no scale-in,
grid, martingale, pyramid, trail, break-even, partial close, target,
stop-and-reverse, or signal-magnitude sizing.

## 8. Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact identity, host, risk, modes, and inputs | `Strategy_NoTradeFilter` |
| normalized month and completed endpoints | calendar and endpoint helpers |
| exact CH3, mean6, band, and AND state | `Strategy_ComputeConfirmedState` |
| durable attempt before fallible gates | `Strategy_PrepareDecisionSignal` |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_CloseExpiredPositions` |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, consecutive completed
endpoints, strict channel and band boundaries, AND disagreement fixtures,
durable attempts, spread boundaries, lifecycle, registry resolution, card
identity, sole setfile, static guardrails, and strict zero-error/zero-warning
compilation.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-31 | G0-approved WTI CH3/DMAC confirmation build | Q01 PASS; Q02 enqueued pending |

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue only after Q01 and capacity checks.
It creates no live, demo, shadow, stress, or optimization preset; does not
change `T_Live`, a deploy manifest, the portfolio gate, admission, or a
correlation decision; and never toggles AutoTrading.
