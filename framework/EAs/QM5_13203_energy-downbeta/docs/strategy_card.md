---
ea_id: QM5_13203
slug: energy-downbeta
strategy_id: HOLLSTEIN-DOWNBETA-2021_XTI_XNG_S01
source_id: HOLLSTEIN-DOWNBETA-2021
status: APPROVED
g0_status: APPROVED
logical_symbol: QM5_13203_XTI_XNG_DOWNBETA_D1
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [SP500.DWX]
period: D1
risk_mode: RISK_FIXED
copy_of: strategy-seeds/cards/energy-downbeta_card.md
---

# Approved Build Reference - QM5_13203 Energy Downside Beta

Canonical card: `strategy-seeds/cards/energy-downbeta_card.md`.

On the first tradable XTI D1 bar of each broker month, estimate XTI and XNG
downside betas from 252 synchronized completed daily returns using only the
days when read-only `SP500.DWX` returned strictly below its full-window mean.
Require at least 100 downside observations, apply the locked `1e-8` beta-tie
guard, buy the lower-beta energy leg, and short the higher-beta leg.

Split `RISK_FIXED=1000` equally under frozen `ATR(20) * 3.5` hard stops. Close
at the next month transition, after 40 days, or on orphan/invalid composition;
deal history suppresses same-month re-entry.

The source spread is negative but insignificant and the broad futures result
is narrowed to two continuous energy CFDs plus a read-only custom-symbol
factor. Q02 is a strict carrier falsification. No source performance, live
action, portfolio admission, gate change, or decorrelation claim is authorized.
