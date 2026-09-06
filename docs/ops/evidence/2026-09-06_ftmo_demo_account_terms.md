# FTMO Free-Trial demo — account terms as reported by the OWNER (2026-09-06, no secrets)

- Account: Free Trial, **2-Step, 100,000 USD, account type "FTMO" (standard, NOT Swing)** — Client Area screenshot 06.09. (private).
- Consequence for the M13 capture-only trial: the runbook assumed a Swing account. A standard FTMO account keeps the **weekend-flat rule** and the **news rule** (no Swing exemption). The trial sets must therefore bind `qm_friday_close_enabled=true` (QM Friday close before the weekend) in addition to the QM news blackout; strategies that hold over the weekend by design (D1/H4 sleeves) either close on Friday or are excluded from the trial subset.
- Leverage: not shown in the Client Area; FTMO standard accounts are documented at 1:100 (Swing 1:30). To be confirmed by the collector via `ACCOUNT_LEVERAGE` and recorded here.
- Symbols: all FTMO symbols (166 in the terminal); the 8 candidate symbols are to be matched by the install ticket.
- Trial window: **14 calendar days from the first trade**, then FTMO deactivates the account. **Duration cap (OWNER 06.09.): the trial window itself** (≈10 Prague trading days).
- Terminal: program `C:\Program Files\FTMO Global Markets MT5 Terminal`, data dir `…\Terminal\81A933A9AFC5DE3C23B15CAB19C63850` (not T_Live), login on FTMO-Demo since 15:55Z, AutoTrading OFF.
- Credentials: `.private/secrets/ftmo_demo_20260906.md` only.
