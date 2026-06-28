# MEEK-HOELSCHER-WTI-DOW-2023

## Citation

Meek, H. and Hoelscher, S. A. (2023). "Day-of-the-week effect: Petroleum and petroleum products." Cogent Economics & Finance, 11(1). DOI: https://doi.org/10.1080/23322039.2023.2213876

Open repository pointer: https://www.econstor.eu/handle/10419/304091

## Use in QM

This source is used for one deterministic WTI day-of-week card: buy XTIUSD.DWX on the Friday D1 session only after a significant Thursday close-to-close decline, then flatten by Friday close or next D1 bar. No source performance number is imported into the portfolio; Q02 and later phases must validate the Darwinex CFD realization.

## R1-R4

- R1: PASS. Single peer-reviewed article/source family with DOI and open repository pointer.
- R2: PASS. The paper's WTI weekday effect can be mechanized as fixed Thursday/Friday calendar logic with a fixed decline threshold and time exit.
- R3: PASS. XTIUSD.DWX is in the Darwinex symbol matrix.
- R4: PASS. No ML, no adaptive PnL fitting, no grid, no martingale, one magic position.
