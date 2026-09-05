# FTMO V4 correlation and tail certification — current eight-sleeve pool

Date: 2026-09-05  
Scope: read-only evaluation of the eight sealed Q08 trade streams  
Portfolio verdict: **ABSTAIN**

## Decision

No sleeve is certified and none fails. All eight receive `ABSTAIN`.

The zeros-kept daily-close Layer-A calculation is favorable: every one of the 28 pairwise stationary-bootstrap 95% intervals is wholly inside the existing OWNER-ratified V2 exclusive bound `(-0.50, +0.50)`. This is only the correlation layer. A portfolio certification is unavailable because the source data do not contain synchronized intraday mark-to-market minima, endpoint equity, or a pending-order census. Each legacy Q08 `8_3_tail_dependence.json` also says `no_portfolio_peers_trivial_pass`; those single-sleeve results are not treated as book-tail evidence.

Layer B is reported as advisory only. The OWNER adopted the two-layer V4 method, but its numeric occupancy flag thresholds remain an open OWNER item. No proposed alpha or lift cutoff is silently promoted into a gate.

## Authority and fixed gates

- V2 correlation: certify Layer A only when the full 95% interval is strictly within `|r| < 0.50`.
- V2 weight budget: `10.0`; this research census uses unit coefficients totaling `8.0`, not an allocation recommendation.
- V4: OWNER-ratified option C, zeros-kept daily close P&L plus occupancy/circular-shift evidence.
- SP-C3: $4,000 close-only daily reference at a $100,000 account (`80% × 5%`), family cap 3 and symbol cap 2.
- No threshold was changed by this work.

The exact authority files, source streams, Q08 artifacts, interval export, byte sizes, and SHA-256 bindings are embedded in the machine-readable result.

## Layer-A and Layer-B results

Layer A uses the common business-day support for each pair, keeps zero-P&L days, chooses a Politis–White-style block length from the two series and their cross-product, and runs 4,000 deterministic stationary-bootstrap replications (`seed=20260905`, `alpha=0.05`). `n` is business days and `co-exit` is the number of days on which both streams booked a close.

Layer B reconstructs inclusive entry-to-exit occupancy on the 3,004-calendar-day union ring (2017-10-10 through 2025-12-30). `p` is the exact upper-tail probability over every circular shift. It is diagnostic, not decisive.

| Pair | r | 95% bootstrap interval | n | co-exit | occupancy lift | exact p | Layer A |
|---|---:|---:|---:|---:|---:|---:|---|
| 10706–11421 | 0.0143 | [-0.0306, 0.0589] | 1980 | 13 | 1.4630 | 0.1894 | CERTIFIED |
| 10706–11422 | -0.0065 | [-0.0402, 0.0240] | 2041 | 27 | 1.3361 | 0.3036 | CERTIFIED |
| 10706–11910 | 0.0045 | [-0.0159, 0.0277] | 1880 | 11 | 1.1317 | 0.4118 | CERTIFIED |
| 10706–13054 | 0.0069 | [-0.0106, 0.0312] | 2043 | 7 | 1.1397 | 0.4657 | CERTIFIED |
| 10706–1537 | -0.0179 | [-0.0469, 0.0013] | 1591 | 10 | 1.3411 | 0.2786 | CERTIFIED |
| 10706–20048 | 0.0108 | [-0.0013, 0.0365] | 2020 | 3 | 0.3184 | 1.0000 | CERTIFIED |
| 10706–21505 | -0.0061 | [-0.0207, 0.0076] | 1871 | 10 | 1.5027 | 0.0183 | CERTIFIED |
| 11421–11422 | 0.0263 | [-0.0085, 0.0697] | 1980 | 25 | 1.5646 | 0.0593 | CERTIFIED |
| 11421–11910 | -0.0755 | [-0.1905, 0.0046] | 1845 | 12 | 1.3342 | 0.2037 | CERTIFIED |
| 11421–13054 | -0.0314 | [-0.1152, 0.0323] | 1980 | 11 | 1.6848 | 0.0320 | CERTIFIED |
| 11421–1537 | 0.0274 | [-0.0608, 0.1206] | 1591 | 10 | 1.3019 | 0.2260 | CERTIFIED |
| 11421–20048 | -0.0002 | [-0.0023, 0.0010] | 1980 | 0 | 0.9188 | 0.5919 | CERTIFIED |
| 11421–21505 | -0.0141 | [-0.0810, 0.0500] | 1871 | 17 | 1.9522 | 0.0043 | CERTIFIED |
| 11422–11910 | 0.0729 | [-0.0579, 0.2027] | 1880 | 19 | 1.8475 | 0.0023 | CERTIFIED |
| 11422–13054 | -0.0078 | [-0.0681, 0.0464] | 2041 | 22 | 1.7054 | 0.0053 | CERTIFIED |
| 11422–1537 | 0.0301 | [-0.0070, 0.0741] | 1591 | 21 | 1.3655 | 0.1411 | CERTIFIED |
| 11422–20048 | -0.0040 | [-0.0109, 0.0002] | 2020 | 2 | 0.7086 | 0.9151 | CERTIFIED |
| 11422–21505 | 0.0018 | [-0.0398, 0.0408] | 1871 | 38 | 1.4491 | 0.0566 | CERTIFIED |
| 11910–13054 | -0.0263 | [-0.0688, 0.0009] | 1880 | 10 | 1.6714 | 0.0469 | CERTIFIED |
| 11910–1537 | 0.0281 | [0.0031, 0.0692] | 1591 | 8 | 1.5155 | 0.1009 | CERTIFIED |
| 11910–20048 | -0.0003 | [-0.0024, 0.0011] | 1874 | 0 | 0.6366 | 0.8615 | CERTIFIED |
| 11910–21505 | 0.0056 | [-0.1059, 0.1374] | 1790 | 8 | 0.9253 | 0.5729 | CERTIFIED |
| 13054–1537 | -0.0273 | [-0.0677, 0.0029] | 1591 | 9 | 1.1163 | 0.3635 | CERTIFIED |
| 13054–20048 | -0.0018 | [-0.0301, 0.0257] | 2020 | 5 | 1.8088 | 0.0736 | CERTIFIED |
| 13054–21505 | 0.0043 | [-0.0544, 0.0705] | 1871 | 17 | 1.3451 | 0.1049 | CERTIFIED |
| 1537–20048 | -0.0035 | [-0.0119, 0.0006] | 1591 | 1 | 1.0437 | 0.4328 | CERTIFIED |
| 1537–21505 | 0.1470 | [-0.0130, 0.3092] | 1591 | 21 | 1.5153 | 0.0856 | CERTIFIED |
| 20048–21505 | -0.0009 | [-0.0035, 0.0008] | 1871 | 0 | 1.0014 | 0.4874 | CERTIFIED |

## Closing-tail diagnostic

This is explicitly `WEIGHTED_CLOSE_DAY_NET_ONLY_NOT_OPEN_EQUITY`:

- 811 observed close-P&L days; worst day 2024-11-20 at **-$2,441.94**.
- 414 observed calendar weeks; worst week beginning 2023-12-04 at **-$3,077.75**.
- No close-only breach of the $4,000 SP-C3 daily reference and no three-sleeve same-day 5%-worst cluster.
- Certification remains `ABSTAIN_MISSING_OPEN_EQUITY_AND_INTERVAL_MINIMA`; favorable close-only totals cannot prove FTMO daily-loss compliance.

## Candidate dispositions

| Sleeve | Verdict | Decisive reasons |
|---|---|---|
| 10706:GBPUSD | ABSTAIN | Missing interval minimum equity; missing pending/endpoint equity; Q08 tail pass has no peers |
| 11421:EURUSD | ABSTAIN | Same |
| 11422:USDCAD | ABSTAIN | Same |
| 11910:NZDUSD | ABSTAIN | Same |
| 13054:XTIUSD | ABSTAIN | Same |
| 1537:XAGUSD | ABSTAIN | Same |
| 20048:XTIUSD | ABSTAIN | Same |
| 21505:XAGUSD | ABSTAIN | Same |

## Reproduction and verification

```powershell
python tools/strategy_farm/portfolio/ftmo_v4_tail_certification.py `
  --spec docs/ops/evidence/2026-09-05_ftmo_v4_tail_certification_spec.json `
  --output docs/ops/evidence/2026-09-05_ftmo_v4_tail_certification.json
python -m pytest -q tools/strategy_farm/tests/test_ftmo_v4_tail_certification.py
```

The emitted JSON SHA-256 is `c8691a2a763974c05318060d5e302335996bb380087ba69d12b76b34ba047ad9`. The focused synthetic suite passes 3 tests and covers deterministic stationary bootstrap, both evidence layers, hash binding, abstention, and circular-shift diagnostics.

## What would remove the abstention

Capture synchronized interval minimum balance/equity and endpoint equity for all sleeves, plus open-position and pending-order state at every endpoint. Then rerun this exact hash-bound census. An OWNER decision is separately needed before Layer-B alpha/lift values can become a decisive gate.
