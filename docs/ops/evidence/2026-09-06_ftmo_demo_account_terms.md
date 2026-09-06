# FTMO Free-Trial demo — account terms as reported by the OWNER (2026-09-06, no secrets)

- Account: Free Trial, **2-Step, 100,000 USD, account type "FTMO" (standard, NOT Swing)** — Client Area screenshot 06.09. (private).
- Consequence for the M13 capture-only trial: the runbook assumed a Swing account. A standard FTMO account keeps the **weekend-flat rule** and the **news rule** (no Swing exemption). The trial sets must therefore bind `qm_friday_close_enabled=true` (QM Friday close before the weekend) in addition to the QM news blackout; strategies that hold over the weekend by design (D1/H4 sleeves) either close on Friday or are excluded from the trial subset.
- Leverage: terminal read-only IPC confirmed **1:100** on login `1514536732` at 2026-09-06T17:28:43Z. The collector now records `ACCOUNT_LEVERAGE` in every sample.
- Symbols: all FTMO symbols (166 in the terminal); the 8 candidate symbols are to be matched by the install ticket.
- Trial window: **14 calendar days from the first trade**, then FTMO deactivates the account. **Duration cap (OWNER 06.09.): the trial window itself** (≈10 Prague trading days).
- Terminal: program `C:\Program Files\FTMO Global Markets MT5 Terminal`, data dir `…\Terminal\81A933A9AFC5DE3C23B15CAB19C63850` (not T_Live), login on FTMO-Demo since 15:55Z, AutoTrading OFF.
- Credentials: `.private/secrets/ftmo_demo_20260906.md` only.

## Terminal contract snapshot

The terminal reported build 6182, balance/equity USD 100,000/100,000, zero positions and zero orders. Requested native symbols were all offered. Swap metadata (long/short points, triple day) was: XAUUSD -93/-10.4 (3), GER40.cash -441.62/-28.19 (5), GBPUSD -6.7/-5.2 (3), EURUSD -13.29/0.17 (3), USDCAD 0.71/-12 (3), NZDUSD -4.82/-1.36 (3), USOIL.cash 5.83/-35.11 (5), and XAGUSD -23.05/0.32 (3). MT5 `symbol_info` does not expose the account's realized commission schedule; the telemetry contract therefore records broker-returned `DEAL_COMMISSION` and `DEAL_FEE` from each fill rather than assuming a rate.
