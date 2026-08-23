# QM5_41136 XNG interquartile-mean build and CPU-ceiling handoff

Date: 2026-08-24

Branch: `agents/board-advisor`

Verdict: `SOURCE_READY_COMPILE_HELD_Q02_NOT_ENQUEUED_CPU_CEILING`

## Delivered energy sleeve

`QM5_41136_xng-mdaily-iqrmean-mom` is a new direct-XNG D1 sleeve under
strategy ID `MOP-MEEK-XNG-MDAILY-IQRMEAN-2026_S01`. It is mechanically
different from certified `QM5_12567_cum-rsi2-commodity`: that incumbent is a
long-only two-day cumulative-RSI(2) pullback above SMA(200) with a five-bar
maximum hold, while this candidate has no oscillator or moving-average gate,
is symmetric long/short, and owns one completed broker month.

At the first executable D1 bar of a normalized broker month, the EA rebuilds
the immediately completed month from 17-23 session closes plus one older
boundary close. It forms every chronological close-to-close log return ending
in the month, verifies endpoint identity, sorts the full sample, removes
`floor(n/4)` returns from each tail, and follows the arithmetic mean of the
exact 9-13 retained observations. The raw endpoint is diagnostic only.

The implementation is low-frequency and fixed-risk:

- exact `XNGUSD.DWX` / D1 carrier, slot zero, magic `411360000`;
- one consumed attempt and at most one position per normalized broker month;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`;
- frozen `3.5*ATR(20,D1)` hard stop, no target, next-month exit, and forty-day
  stale repair;
- 3,000-point XNG entry spread ceiling, both news axes OFF, and Friday close
  OFF; and
- no optimization, ML, banned signal indicator, external feed, live, demo,
  shadow, or stress preset.

The bounded source packet cites Moskowitz, Ooi, and Pedersen (2012) for
peer-reviewed natural-gas own-return monthly-continuation lineage and Meek
and Hoelscher (2023) for daily natural-gas close-to-close log-return lineage.
The within-month interquartile-mean translation is explicitly a QM hypothesis;
no paper result is transferred to the continuous-CFD carrier or the QM book.

## Identity and commits

- source approval: `c24a87615`;
- bounded source packet: `c3ad3a01b`;
- G0-approved card: `94e47219a`;
- deterministic identity reservation: `6af250fbc`;
- governed magic allocation: `033501c22`;
- exact-card allocation postcheck: `b94afb143`; and
- EA, SPEC, reference suite, card copy, and fixed-risk setfile: `ac8257f05`.

The normal governed magic apply aborted atomically because strict resolver
regeneration would have dropped three unchanged legacy identities. The
reviewed non-dropping fallback added only the exact `41136 / slot 0 /
XNGUSD.DWX / 411360000` row, retained all 17,988 resolver rows, and passed an
exact-card postcheck with zero findings. No `--allow-dropped` bypass was used.

The MQ5 SHA-256 is
`45DDE0AB39D8E9C1B7D6EE1F69BCBB96FA0EED7A2816DDC38844E38EE0792DB5`.
The pending, unbound backtest setfile SHA-256 is
`7CE254B403B43FD446745EECD8767193711D8A478A471900AC15F003A8F24834`.

## Verification completed

- canonical pre-allocation dedup: no exact collision after manual
  carrier-family review; post-allocation exact hits are the new self identity;
- approved-card schema lint: PASS, no missing sections and no ML hits;
- deterministic Python reference suite: PASS, 16/16;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS for the MQ5 and sole backtest setfile;
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations;
- package whitespace audit: PASS; and
- approved card and EA-local card copy are byte-identical at SHA-256
  `811DCE404E98ADBACEFF17F20427EC6F6B498E4B3A5C8C3D30FD28E33898A2A7`.

The source was also compared in memory against the reviewed WTI
interquartile-mean sibling after the card-required identity, carrier, natural-
gas wording, and 3,000-point spread substitutions; the transformed source was
exactly equal. This preserves the reviewed calendar, arithmetic, attempt,
risk, and lifecycle implementation while creating a separate XNG exposure.

## Compile and Q02 boundary

Direct strict compilation stopped safely at
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory terminals were alive.
No retry, bypass, include mutation, terminal action, or tester was attempted.

The governed command then created compile work item
`77d52009-3434-4c70-a93b-29471832c3cd`. It is pending, unclaimed,
verdict-free, and held under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Releasing
that fleet-worker rollout requires separate authorization and was not
bypassed. There is no EX5, sealed setfile, strict Q01 PASS, or build evidence.

A target-only, no-apply Q02 preview selected zero rows. Q02 cannot legally be
enqueued without the current EX5 and Q01 PASS, and `farmctl work-items --ea
QM5_41136` confirms the compile utility is the only work item.

## CPU ceiling

The first five-sample observation remained just below the hard ceiling, with
93.1% average and 96.5% maximum CPU. A fresh five-sample observation at
four-second spacing then returned `98.12, 98.00, 98.19, 98.46, 96.46` percent
CPU, averaging 97.85% and peaking at 98.46%. This breaches
`CPU_MAX_LOAD_PERCENT=97.0`; the configured resume threshold is 90.0%.

Machine-readable evidence is
`artifacts/qm5_41136_cpu_ceiling_20260824.json`.

The mission explicitly requires stopping at the backtest CPU ceiling, so no
compile-hold release, compile retry, Q02 enqueue, dispatcher tick, or tester
run followed the observation.

## Governed continuation

After sustained recovery below 90% and separately authorized fleet-worker
rollout, let the governed compile worker consume the existing exact item.
Only strict `COMPILE_OK` with zero errors/warnings, a bound current EX5,
finalized fixed-risk setfile, and Q01 PASS permits one target-only
`XNGUSD.DWX` D1 Q02 enqueue.

No portfolio gate, `T_Live` manifest, `T_Live` file, AutoTrading state, live
preset, terminal process, existing EA, gate threshold, portfolio verdict, or
correlation waiver was changed.
