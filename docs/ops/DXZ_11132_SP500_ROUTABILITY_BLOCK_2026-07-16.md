# DXZ EA11132 / SP500 routing correction

Date: 2026-07-16  
Scope: Darwinex Zero 23-sleeve book only

## Corrected decision

The earlier same-day conclusion that `SP500` was not broker-routable was
incorrect. Read-only Darwinex-Live evidence proves that the broker accepted and
executed both entry and close orders on exact symbol `SP500`.

The governed mapping is explicit:

`SP500.DWX` (backtest/requalification data) -> `SP500` (live broker order)

Canonical evidence, including exact log lines and SHA-256 bindings, is in
`docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md`.

## 11132 remains blocked

`QM5_11132_tm-cum-rsi2` remains `BLOCKED` for independent qualification work:

1. reconcile Card/default `35/65/SMA200/ATR14x2.5` with effective as-live
   `38/66/SMA165/ATR12x2.0` parameters;
2. requalify the exact test-to-live symbol mapping;
3. qualify or remove the unapproved Friday-close override and active news axes;
4. resolve the source/Card-v2 exit-semantics gap and stale Card routing text;
5. requalify the remediated binary.

The block is no longer based on non-routability. An NDX/WS30 substitution is
not required remediation. NDX/WS30 proxy variants remain optional research
derivatives and cannot inherit 11132's evidence or identity.

## Safety boundary

This correction changes governance metadata and validation only. It does not
approve a Card, edit an EA or live preset/binary, deploy anything, or change
AutoTrading.
