# QM5_41308_wti-mordinal-entropy-tr - Strategy Spec

**EA ID:** QM5_41308

**Slug:** `wti-mordinal-entropy-tr`

**Strategy ID:** `AI-CODEX-WTI-MORDENTROPY-20260902_S01`

**Source:** `AI-CODEX-WTI-MORDENTROPY-20260902`

**Author:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct twenty-five consecutive completed broker-month-end closes. Convert
them to twenty-four chronological adjacent log returns and partition those
returns into exactly eight disjoint chronological triples.

Each triple receives one of the six strict order-three ordinal labels. Reject
the decision if any pair within a triple is equal under the locked relative
`1e-12` tolerance. Compute natural-log Shannon entropy over the six label
counts and normalize by `ln(6)`. When normalized entropy is at most `0.80`,
follow the sign of the newest twelve-return sum; otherwise consume the month
flat. Entropy and momentum magnitude never scale risk.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 24 | completed adjacent monthly log returns |
| `strategy_pattern_order` | 3 | values in each ordinal block |
| `strategy_pattern_blocks` | 8 | disjoint chronological triples |
| `strategy_pattern_states` | 6 | strict order-three permutations |
| `strategy_entropy_ceiling` | `0.80` | inclusive normalized-entropy gate |
| `strategy_relative_tie_epsilon` | `1e-12` | fail-closed within-triple tie rule |
| `strategy_momentum_months` | 12 | newest return count used for side |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral-direction band |
| `strategy_history_bars` | 1200 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol, Clock, and Formula

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `413080000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the D1 boundary.
- Every current-month price is excluded.

For completed endpoints `c[0..24]` in oldest-to-newest order:

```text
r[i] = ln(c[i+1] / c[i]), i=0..23
T[k] = (r[3k], r[3k+1], r[3k+2]), k=0..7
```

For `(a,b,c)`, after the relative tie check, use the exact map:

```text
0: 012 iff a < b < c
1: 021 iff a < c < b
2: 102 iff b < a < c
3: 120 iff c < a < b
4: 201 iff b < c < a
5: 210 iff c < b < a
```

Require the six counts to sum to eight. For `p[j]=count[j]/8`:

```text
H_norm = -sum(p[j] * ln(p[j]), p[j] > 0) / ln(6)
mom12  = sum(r[12..23])

BUY  iff H_norm <= 0.80 and mom12 > +1e-12
SELL iff H_norm <= 0.80 and mom12 < -1e-12
FLAT otherwise
```

All inputs and intermediate values must be finite. Missing, duplicate,
nonconsecutive, stale, nonchronological, nonpositive, tied, or malformed data
fail closed. Pattern strings are diagnostic only.

## 4. Entry and Risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualified month can open one market position with a
frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Existing
owned exposure or foreign `XTIUSD.DWX` exposure blocks entry. Framework quote,
contract, tick, volume, sizing, and margin guards remain authoritative.

Both news axes and legacy news are OFF. Friday close and stress rejection are
disabled. A nonnegative spread no greater than 1,500 points is allowed.

The normalized broker-month attempt is persisted before history, arithmetic,
news, spread, quote, ATR, sizing, margin, or order gates. A failed gate cannot
cause a same-month retry. The entry month is persisted only after a confirmed
fill and can be recovered from matching position-deal history after restart.

## 5. Management and Exit

An owned position closes on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Missing or inconsistent
position, stop, side, entry-time, or entry-month state triggers a defensive
strategy close. There is no target, trail, break-even, partial close, entropy
exit, opposite-signal exit, intramonth flip, Friday flatten, retry, scale-in,
grid, martingale, or pyramid.

The framework kill switch and broker hard stop remain authoritative. Runtime
uses MT5-native price, calendar, ATR, quote, position, deal, and terminal-global
state only; no futures chain, API, file, inventory, optimizer, portfolio state,
randomized tie breaker, or trained artifact is allowed.

## 6. Expected Activity and Kill Criteria

Exact pre-data enumeration of all `6^8=1,679,616` label strings admits
`782,496` (`46.5877914952%`) at `H_norm<=0.80`, or 5.5905 states per twelve
attempts. The highest admitted discrete entropy is `0.773705614469`; the next
possible value is `0.833915022608`. These are combinatorial facts, not WTI
performance evidence.

Retire on zero positions, fewer than five completed positions in any full
scored post-warm-up year, nonpositive governed economics, nondeterminism, or
any formula, fixed-risk, hard-stop, lifecycle, or downstream gate failure.
Q09 alone may establish or reject portfolio diversification.

## 7. Source and Non-Duplicate Boundary

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MORDENTROPY-20260902/source.md`. Bandt and
Pompe support ordinal-pattern entropy; Moskowitz, Ooi, and Pedersen support
monthly own-return continuation and explicit WTI membership. Neither tests
this exact conjunction, threshold, CFD implementation, or risk contract.

The canonical dedup receipt is
`artifacts/qm5_wti_mordinal_entropy_tr_preallocation_dedup_20260902.json`.
This differs from `QM5_9520` (M15 ternary Shannon-entropy crossings) and
`QM5_12603` (ungated twelve-month WTI momentum). Certified `QM5_12567` is a
long-only two-day XNG oscillator pullback.

## Framework Alignment

- `Strategy_NoTradeFilter`: exact identity, registered magic, fixed risk,
  news/Friday/stress contract, and every strategy lock.
- bounded helpers: month clock, attempt state, endpoint reconstruction,
  return orientation, tie rejection, pattern map, count checksum, normalized
  entropy, momentum side, and restart recovery.
- `Strategy_EntrySignal`: foreign/owned exposure, spread, quote, ATR, frozen
  stop, and one fixed-risk market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side verification,
  next-month exit, and forty-day stale exit.
- `Strategy_ExitSignal`: no additional discretionary exit; framework close
  helpers carry the authorized reasons.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved source build | G0-approved card; magic `413080000`; Q01 pending |
