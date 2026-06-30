# MEEK-HOELSCHER-XNG-DOW-2023

## Citation

Meek, H. and Hoelscher, S. A. (2023). "Day-of-the-week effect: Petroleum and petroleum products." Cogent Economics and Finance, 11(1). DOI: https://doi.org/10.1080/23322039.2023.2213876

Open repository pointer: https://www.econstor.eu/handle/10419/304091

## Use in QM

This source is used for one deterministic natural-gas weekday card: buy `XNGUSD.DWX` only on the broker-calendar Tuesday D1 session, then flatten on the next non-Tuesday D1 bar or by a stale-position guard. The source reports Natural Gas day-of-week structure, including positive Monday and Tuesday effects and a negative Thursday effect. This card uses only the Tuesday long leg to avoid duplicating `QM5_12806_xng-rev-weekend`, which already trades Monday long and Friday short.

No source performance statistic is imported into QM. Q02 and later phases must validate the Darwinex CFD realization.

## R1-R4

- R1: PASS. Single peer-reviewed article/source family with DOI and open repository pointer.
- R2: PASS. The Natural Gas weekday effect can be mechanized as fixed Tuesday calendar logic with fixed ATR and time exits.
- R3: PASS. `XNGUSD.DWX` is in the Darwinex symbol matrix.
- R4: PASS. No ML, no adaptive PnL fitting, no grid, no martingale, one magic position.
