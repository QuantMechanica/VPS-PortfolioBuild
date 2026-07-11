# QM5_13134 Energy Variance-Ratio Momentum

This build implements `MEHLITZ-AUER-MEM-2024_XTI_S01`, the approved WTI-only
carrier in `strategy-seeds/cards/energy-vr-mom_card.md`.

Each broker month it derives 32 monthly XTI log returns from completed D1 bars,
computes the q=2 heteroskedasticity-robust Lo-MacKinlay statistic, and applies
the source matrix:

- persistent winner: long;
- persistent loser: short;
- anti-persistent winner: short;
- anti-persistent loser: long;
- insignificant variance ratio: flat.

The two-sided 10% gate, 32-month window, monthly lifecycle, and at-most-one
entry per month are locked. Q02 uses `RISK_FIXED=1000` and a frozen
`ATR(20) * 3.0` stop. No live setfile or portfolio admission is authorized.
