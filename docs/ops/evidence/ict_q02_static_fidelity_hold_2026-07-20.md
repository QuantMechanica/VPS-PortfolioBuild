# ICT Q02 Static-Fidelity Hold — 2026-07-20

Status: `HOLD_BEFORE_TEST`

No Q02 outcome was opened. The pending work items below are held because a
source-level audit found implementation/provenance defects that would prevent a
result from being interpreted as a source-faithful strategy test.

## QM5_13210 — Asian Sweep London

- Build task: `3bba09a5-e8e6-4e56-99c0-dad71c678a4e`
- MQ5 SHA-256: `d8f350f2e6d8470341fb6509b6244bb8ba2711d4fb98f06e27c8c8e437d9627c`
- EX5 SHA-256: `c2a4790a0e32575c5ea0120f9f7ce4a8ce34f67cee4080b7cf81326180c6b91a`
- Held work items:
  - `62d24e59-a2ec-4037-950f-8caec28190b0` (`EURUSD.DWX`, M5)
  - `088c2466-a50f-4cec-9b73-816a4d223a47` (`XAUUSD.DWX`, M5)

Blocking findings:

1. The news return precedes closed-bar state observation, so news blackouts
   remove bars from the Asian range, extension, sweep, MSS and FVG state.
2. A server-side pending order is not bounded or cancelled at a later news
   blackout and can fill during the prohibited interval.
3. Sweep detection can fall through into MSS/FVG confirmation on the same bar;
   the required event ordering is therefore not frozen.
4. The build receipt does not hermetically bind source, includes, setfiles and
   EX5. No smoke was run.

## QM5_10834 — NQ ICT Order-Block Sweep

- Build task: `b4d0f7eb-e969-4f89-9c13-44b6e8fada09`
- Build commit: `b3a6b958ce5b9533ce5e5b1bede4b71589286860`
- MQ5 SHA-256: `f3f3dd8a4dd681482d11f06f32dc7b0fb1b324f327092a70fdba14fa103a7253`
- EX5 SHA-256: `2ebd05a5825d27ed7e2e83f5eb08a2e2d2b065d823fb6b9f3204cd2e9ff64354`
- Held work items:
  - `c5683fb0-259b-4733-9da2-825eb5007dbf` (`EURUSD.DWX`, M5)
  - `46c8b741-c1c9-4ec3-a47a-82fb49c9bff1` (`NDX.DWX`, M5)
  - `240f163d-2e50-4b94-a59c-d0d7bf21e80e` (`XAUUSD.DWX`, M5)

Blocking findings:

1. The MSS bar can activate an order block and immediately satisfy mitigation
   from the same bar's OHLC. The within-bar event order is unknowable and the
   primary description says the OB remains active until subsequently mitigated.
2. News authorization runs before session-end exit management, so a blackout
   can delay the card's forced morning-session flatten.
3. The baseline uses broker D1 PDH/PDL while the execution session is explicitly
   New-York-time based; the intended day boundary must be frozen before the
   result is admissible.

Primary source checked for QM5_10834:
<https://www.tradingview.com/script/8NHRB35j-NQ-9-45-10-15-ICT-Strategy-Complete/>

## Release condition

Repair must be outcome-blind. Each EA requires a strict 0-error/0-warning clean
compile, build check, source-to-EX5/set hash binding, and fresh work-item IDs.
The held binaries and any accidental results remain diagnostic-only and must not
be promoted or compared as strategy evidence.
