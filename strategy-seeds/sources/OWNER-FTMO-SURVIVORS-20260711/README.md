# OWNER FTMO Survivors 2026-07-11

Source ID: `OWNER-FTMO-SURVIVORS-20260711`

This source captures the OWNER-provided request on 2026-07-11 to take five
Secret Lab research survivors through the formal FTMO pipeline. The immutable
research inputs are under `.private/secret_strategy_lab/` and use only
`T_Export` `.DWX` data.

G0 dedup review rejected `SECRET_01_pre_fomc_event_flat` as a new build because
the same frozen event-flat mechanics already exist in `QM5_12971` and the
current NDX port `QM5_13128`. Code-level review then mapped `SECRET_02` and
`SECRET_03` to parameter-locked D1 variants of the existing
`QM5_10377_et-ma50-cross`; the briefly reserved IDs 13135/13136 were retired
without builds. Two mechanics remain approved as new EAs:

- `QM5_13137_breadth-tue`
- `QM5_13138_xau-m5-ema20`

Approval means only that R1-R4 are satisfied and the rules are buildable. It
does not import the Secret Lab PF values into Q02, authorize deployment, or
permit any live-account action.
