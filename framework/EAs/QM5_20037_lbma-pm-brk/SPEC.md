# QM5_20037_lbma-pm-brk — Strategy Spec

**EA ID:** QM5_20037
**Slug:** `lbma-pm-brk`
**Source:** CAMINSCHI-HEANEY-2014
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA first loads and hash-verifies the governed ICE IBA LBMA Gold PM schedule
package. Only a provenance-matched `SCHEDULED_PM_AUCTION` row may reach the
price-bar logic. The verified schedule currently covers 2020-01-01 through
2025-12-31; 2018 and 2019, missing rows, non-auction rows, malformed data, hash
drift, and dates outside coverage fail closed. Price bars never substitute for
official auction-calendar membership.

On an eligible date, the EA freezes the completed 14:55–15:00 London M5 range
and arms in the direction of that bar's body. It enters at 15:05 or 15:10
London only when the first eligible completed M5 close breaks the frozen range
in the armed direction; an opposite close cancels the date. The opposite range
edge is the immutable hard stop, there is no profit target or trade-management
overlay, and any remaining position closes at the first tradable quote at or
after 15:15 London. Tester Groups applies venue commission to fills.

The annual calendars establish planned auction status. No official historical
date-level cancellation/`No Publication` ledger was located. That limitation is
logged as a Q02/promotion evidence gap; it does not blanket-block an otherwise
provenance-locked scheduled row. A positively known cancellation or
`No Publication` condition would fail closed.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `LBMA_PM_BRK_BASELINE` | locked | Approved card variant identity. |
| `strategy_signal_tf` | `PERIOD_M5` | locked | Signal and execution-bar timeframe. |
| `strategy_pre_bar_*_london` | `14:55` | locked | Frozen pre-auction M5 bar start in London time. |
| `strategy_confirmation1_*_london` | `15:00` | locked | First confirmation-bar start in London time. |
| `strategy_confirmation2_*_london` | `15:05` | locked | Second confirmation/first-entry bar start in London time. |
| `strategy_exit_*_london` | `15:15` | locked | Mandatory flat time in London time. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

The calendar filenames and SHA-256 values are compile-locked in
`framework/include/QM/QM_LbmaGoldPmCalendar.mqh`; they are not user inputs and
cannot be disabled by a setfile.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — the card's sole gold-auction price, signal, and order route.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card forbids sibling order routes and
  depends specifically on the LBMA PM gold auction.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Governed Runtime Data

The common loader binds six `Common\Files` artifacts before new entries:

- dense PM schedule: 2,192 daily rows, including 1,503
  `SCHEDULED_PM_AUCTION` rows for 2020-2025;
- row-level schedule provenance;
- nine-row official/card-authorized source registry;
- sixteen pinned IANA `Europe/London` transitions for 2018-2025;
- explicit coverage/evidence gaps; and
- the package manifest.

Every artifact must match its compile-time SHA-256. Runtime and provenance are
parsed together and must agree row-for-row on date, status, qualification,
annual source ID, and IANA clock source. The auction's 15:00 London timestamp is
also reconciled against the pinned UTC transition table. Package failure blocks
new entries but does not suppress management or the deterministic exit of an
already-open position.

## 6. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 200 is an untested card prior before holidays, dojis, unconfirmed breaks, news and costs; it is not a validated result |
| Typical hold time | 5–15 minutes, always flat at or after 15:15 London |
| Expected drawdown profile | approximately 12% card prior, with losses clustered around failed auction breakouts |
| Regime preference | benchmark-auction information concentration and short-horizon breakout |
| Win rate target (qualitative) | not specified by the approved card |

## 7. Source Citation

This card was mechanised from:

**Source ID:** CAMINSCHI-HEANEY-2014
**Source type:** academic paper
**Pointer:** Caminschi and Heaney (2014), *Journal of Futures Markets* 34(11),
DOI 10.1002/fut.21636; implementation card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20037_lbma-pm-brk_card.md`.
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20037_lbma-pm-brk.md`.

## 8. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The approved baseline itself authorizes fixed-risk testing only; any live risk
mode remains a later governed promotion decision.

## 9. Current Qualification Status

The Strategy Card and execution contract remain `DRAFT`. The calendar package
is `PARTIAL_BLOCKED`: its 2020-2025 planned schedule is technically usable, but
2018/2019 official source bytes are unavailable and historical actual-occurrence
reconciliation is still a promotion evidence gap. Therefore the EA is neither
full-window Q02-ready nor a validated successful strategy.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | e7bbe65a-a948-4127-a13a-5422895208fa |
| v2 | 2026-07-22 | FTMO density fix | Replaced the unprovisioned auction ledger and commission/cost gate with broker-clock weekday/bar eligibility and the optional native spread guard. |
| v3 | 2026-07-22 | Restore card calendar contract | Supersedes v2's invalid weekday/bar shortcut with the strict hash-bound LBMA PM schedule and pinned Europe/London clock loader; verified technical eligibility is limited to 2020-2025. |
