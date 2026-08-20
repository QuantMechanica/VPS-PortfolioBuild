# QM5_1642 XTI Q03 infrastructure recovery handoff

## Outcome

`QM5_1642_aa-xasset-xmom-third` was blocked on the diverse `XTIUSD.DWX` lane by
pre-EA tester/history failures. The current binary cannot reuse the historical
Q02 execution identity, so the canonical gate correctly requires a current-binary
Q02 requalification before Q03. One exact, append-only `RISK_FIXED` Q02 rerun was
enqueued as work item `6191a99d-96c5-4e90-a63a-49df3d651a25`.

- Coordination claim: `d22ca78a-4437-42b7-8088-711a78493783`
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1642_aa-xasset-xmom-third.md`
- Instrument/timeframe: `XTIUSD.DWX`, D1
- Structural edge: low-frequency, monthly cross-sectional 12-2 momentum rank
- Risk contract: `risk_fixed=1000.0`, `risk_percent=0.0`
- Strategy mechanics and parameters changed: **no**

## Bound execution identity

| Artifact / evidence | SHA256 |
|---|---|
| Current MQ5 | `7aecf540726e4647a7e91ff68933eca35c1478a769c32b5209a53533319d0893` |
| Historical EX5 bound to Q02/Q03 | `8e9d5a3904da0f8db251ca082cbc493b0a1b64b784fa63af11623c2bea673ffa` |
| Current strict-compiled EX5 | `ada03e8548298af271b67759523674951338d73a7d119ae1a2a2339427774882` |
| XTI backtest setfile | `0912bf85f8e85cf91ba5d4569c80aec26635e7027d1ce36b7b96246dfbd7b4b8` |
| Failed Q03 summary | `18b7e97a4ff0f2ec04b27b1ec1dd83423fe1dd9cc0d3787130be46a0ab62bcd3` |
| Historical Q02 PASS summary | `3e3acee9cee586643da4f319359ed91a35400a1a25b466ff530055ce8943b152` |

The current EX5 was produced by the strict zero-error/zero-warning compile in
commit `b8bfb9927fc586914bcb649dcc4302007b727031`; the MQ5 and XTI setfile have not
changed since the failed Q03 execution.

## First-failed-layer diagnosis

Source Q03 work item: `b8f2f3dd-20ad-4cec-9ee6-a3e983d4cac1`.

| Layer | Evidence | Classification |
|---|---|---|
| Harness / tester | Four attempted reports had empty Expert and Symbol fields, `M0 (1970.01.01 - 1970.01.01)`, and zero bars. All four tester INIs requested the correct expert, XTI symbol, D1, Model 4, and 2024 dates. | **First failed layer: INFRA** (`BARS_ZERO;INCOMPLETE_RUNS`) |
| Setup / history | The failure ran on 2026-07-24, before fleet custom-history isolation activation. Current enqueue admission reports `status=ACTIVE`, `selected_symbols=[XTIUSD.DWX]`, and 108 selected archive rows under activation `61c8c72c...`. | Historical shared-history setup failure; current isolated archive admitted |
| EA initialization | Summary explicitly recorded no `OnInit` failure. Report identity never reached a valid EA run. | Not reached / not causal |
| Entry logic | No valid bars or initialized EA execution existed. | Not evaluated |
| Order submission | No valid EA execution existed. | Not evaluated |
| Economics | Zero trades came from zero tester bars, not a valid no-signal backtest. | No strategy verdict |

Current isolation state is enabled for T1-T10, the ramp limit is 10, containment
mode is correctly `enabled:false`, and the enqueue path authenticated the active
XTI archive manifest (`fe0dd0fd...`).

## Governed repair and enqueue

A direct append-only Q03 request was refused with
`q03_predecessor_not_bound_to_current_execution`: the only exact XTI Q02 PASS,
`ae53401c-0675-4b76-9614-819b1dd5e208`, is bound to the historical EX5. No row
was created by that refused request.

The governed prerequisite was then created through `farmctl enqueue-backtest`:

- New work item: `6191a99d-96c5-4e90-a63a-49df3d651a25`
- Phase/status at handoff: `Q02` / `pending`
- Exact append-only source: `ae53401c-0675-4b76-9614-819b1dd5e208`
- Current EX5 binding: `ada03e8548298af271b67759523674951338d73a7d119ae1a2a2339427774882`
- Preserved source verdict/evidence: `PASS`, immutable
- Changed execution binding: EX5 only
- Next governed step: a valid current-binary Q02 PASS may promote this exact
  XTI identity to Q03 through the normal cascade

At the final pre-enqueue capacity check, 9 of the 10 factory tester terminals
were active; T10 was neither running nor reserved. The CPU ceiling was therefore
not reached. No manual tester was launched.

## Safety boundary

No T_Live path, AutoTrading state, portfolio gate, deploy manifest, framework
include, EA source, setfile, or strategy parameter was modified. Historical DB
rows and reports remain append-only and unchanged.
