# DXZ 11132 Card / Source / Preset Drift — 2026-07-16

## Decision

`QM5_11132` remains **BLOCKED / REQUAL_REQUIRED**. The DarwinexZero symbol route is
now proven (`SP500.DWX` test alias -> `SP500` broker order symbol), but the strategy
that was exercised as-live is not the parameterization written in the APPROVED
Strategy Card. This is a governance and lineage defect, not evidence that either
variant is unprofitable.

No Strategy Card, EA, live preset, deployment, risk allocation, or AutoTrading
state was changed by this adjudication.

## Bound artifacts

| Artifact | Path | SHA-256 |
|---|---|---|
| APPROVED Card | `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11132_tm-cum-rsi2.md` | `b2c5a52cdc5455fc6cbdca68da1cf673436f3c168b1790c92d736553737bf9c2` |
| Repo EA source | `framework/EAs/QM5_11132_tm-cum-rsi2/QM5_11132_tm-cum-rsi2.mq5` | `79f86dbe6ad1f7b866213b0679063573f990e2610a0e227176afe84627a577b3` |
| DXZ23 live preset (read-only evidence) | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\slot0_SP500_D1_QM5_11132_ohlc-daily-squeeze-reversal-d1_magic111320000_dxz23_live.set` | `e5731c4e9ca682282b04d992581714a10851675949bd3fa6efc04381ba3ae750` |
| As-live MT5 report | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_hardened\20260716T051551Z\runs\10_11132_SP500_DWX\report.htm` | `f0a2c600fcc35c6de22f0b93fcd0f0318a45c7a98e0cf5aff6b884e2b4d87a55` |
| Tester configuration | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_hardened\20260716T051551Z\runs\10_11132_SP500_DWX\tester.ini` | `4344912bda61418a53a20e557ed6c478dd4bf18e27eb19e1c912637cab68d693` |
| Run receipt | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_hardened\20260716T051551Z\runs\10_11132_SP500_DWX\receipt.json` | `e2c45bd8060781b44cfff89c04274da9e23744ab36090a851622d8a517fc29cd` |

The report itself records the effective inputs below; this avoids inferring
execution merely from fields present in a `.set` file.

## Material strategy differences

| Rule | APPROVED Card / EA default | Effective as-live report | Status |
|---|---:|---:|---|
| cumulative RSI entry | 35 | 38 | unqualified variant |
| RSI exit | 65 | 66 | unqualified variant |
| trend SMA | 200 | 165 | unqualified variant |
| ATR period | 14 | 12 | unqualified variant |
| ATR stop multiple | 2.5 | 2.0 | unqualified variant |
| maximum hold | 5 D1 bars | 5 D1 bars | aligned |
| RSI period / cumulative window | 2 / 2 | 2 / 2 | aligned |

The Card explicitly says that the source article does not disclose a complete
exit and that its RSI/time/ATR exits are constructed baselines. Therefore an
optimized-looking live parameter set cannot be treated as the approved source
strategy without an amendment and independent requalification.

## Framework-policy differences

- The Card does not qualify forced Friday liquidation. The source/MT5 report has
  `qm_friday_close_enabled=true` at broker hour 21.
- The Card does not qualify the active two-axis news policy. The MT5 report has
  `qm_news_temporal=3` and `qm_news_compliance=1`.
- The live preset still contains `qm_filter_news_*` and regime/volatility fields
  that are not EA inputs and do not appear in the report's effective input list.
  They must not be cited as proof of active filtering.
- The Card's statement that `SP500.DWX` is not broker-routable is stale. Direct
  route evidence is recorded separately in
  `docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md`.

## Required next qualification

1. Preserve two predeclared variants: **Card default** and **legacy-live exact**.
2. Exercise both against the same literal `.DWX` data segments, with identical
   account, spread, commission, swap, Friday, and news assumptions.
3. Bind Card, source, EX5, preset, data, report, and trade-stream hashes.
4. Treat the comparison as research until the Card owner explicitly approves
   the winning rule set and the complete qualification cascade passes.
5. Keep deployment and resizing blocked meanwhile.

## Current interpretation

The SP500 sleeve still has a plausible gross edge (the as-live MT5 report has 75
closed trades and reported PF 1.44), but that number is not a promotion verdict:
its old reference stream, cost model, data-gap treatment, and Card lineage still
require adjudication.
