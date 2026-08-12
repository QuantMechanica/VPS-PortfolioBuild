# MEEK-HOELSCHER-XNG-DOW-2023

## Citation

Meek, H. and Hoelscher, S. A. (2023). "Day-of-the-week effect: Petroleum and petroleum products." Cogent Economics and Finance, 11(1). DOI: https://doi.org/10.1080/23322039.2023.2213876

Open repository pointer: https://www.econstor.eu/handle/10419/304091

## Use in QM

This source is used for deterministic natural-gas weekday cards. `QM5_12818_xng-tue-prem` buys `XNGUSD.DWX` only on the broker-calendar Tuesday D1 session, then flattens on the next non-Tuesday D1 bar or by a stale-position guard. `QM5_12819_xng-thu-fade` isolates the separate negative Thursday effect by selling `XNGUSD.DWX` only on the broker-calendar Thursday D1 session, then flattening on the next non-Thursday D1 bar or by a stale-position guard. The source reports Natural Gas day-of-week structure, including positive Monday and Tuesday effects and a negative Thursday effect. The Thursday card avoids duplicating `QM5_12806_xng-rev-weekend`, which already trades Monday long and Friday short, and `QM5_12818`, which trades Tuesday long only.

`QM5_20011_xng-thu-tue` extracts the source's separate, explicit composite
implementation from Section 4: one long package from Thursday close through
Tuesday close. On Darwinex D1 bars those boundaries map to Friday open and
Wednesday open. This is the paper's source-explicit integrated hold rather
than an inferred merge of the one-day cards: the weekend and persistent
multi-day lifecycle are load-bearing, Friday close is disabled, and one
restart-safe package is allowed per broker week. The package nevertheless
contains the Monday return window sampled by pending `QM5_12806` and the
Tuesday return window sampled by pending `QM5_12818`; this known overlap must
be measured and must not be described as proven decorrelation.

No source performance statistic is imported into QM. Q02 and later phases must validate the Darwinex CFD realization.

## R1-R4

- R1: PASS. Single peer-reviewed article/source family with DOI and open repository pointer.
- R2: PASS. The Natural Gas weekday effects can be mechanized as fixed Tuesday long, Thursday short, and the author's explicit Thursday-close-to-Tuesday-close weekly long package, with fixed ATR and time exits.
- R3: PASS. `XNGUSD.DWX` is in the Darwinex symbol matrix.
- R4: PASS. No ML, no adaptive PnL fitting, no grid, no martingale, one magic position.
