# Codex re-review: QM5_34006

- Review task: `cf62861c-2bb3-40ec-8239-c12627e0a0a0`
- Gemini source task: `70238994-3b68-455c-b170-034bffb81530`
- Disposition: `CHANGES_REQUIRED`
- Router handoff: remain in `REVIEW`; no pipeline handoff

The 2026-08-21 card amendment fixed the impossible channel window by defining
bars 2 through 25 and made the Parabolic SAR stop contract explicit. The
current EA source is byte-for-byte the source reviewed before that amendment,
so this re-review tests the amended card against the unchanged implementation.
The router-listed review skills are unavailable; Codex performed the mandatory
review directly.

## Bound inputs

- Approved card SHA-256: `ab8bf971f305a9973b6c2a2ee3fce4d985fd38bccafcd3815748068991877c1e`
- MQ5 SHA-256: `47ee42750126a191b6ef687b42ee7f2f925f02ab30163204e1b42803b028b1e3`
- EX5 SHA-256: `d2a1ff418fd82b186c5772a00ba63572b72155a8613c676aec88c1b2530e010c`
- SPEC SHA-256: `49f09d2497183b17b2fe7d260d8ee027cd8948d0d154516c04a179856057f8ba`
- Active magic rows: `340060000`, `340060001`, `340060002`

## Blocking finding

The corrected card requires the stop strictly at `Parabolic_SAR[1]`, forbids
ATR corridor clamping, and requires a fail-closed rejection when the broker
stop level is not met (card lines 99-101). The source still calculates 0.5 ATR
and 3.5 ATR limits and moves the SAR stop into that corridor for both long and
short entries (source lines 131-151 and 169-180). This changes stop distance,
position sizing, and TP. The channel loop at lines 102-116 now agrees with the
amended bars-2-through-25 definition, but that resolved item does not cure the
stop-rule drift.

No amended-card rebuild or new RESULT packet was supplied. The MQ5 and EX5
hashes are the same as the earlier failed review, so a structural compile PASS
cannot establish card fidelity.

## Focused verification

- Build guardrails: PASS over four package files with
  `qm_news_stale_max_hours <= 336`.
- SPEC validation: PASS.
- Set risk: all three setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Registry: EA row is active and all three magic rows are active.
- Target EA directory: clean in Git.
- Compilation was not rerun: there is no source delta to compile, and the
  semantic failure precedes compilation. Any repair must use `COMPILE_EA` and
  return a new bound RESULT packet for Codex review.

Required rework is to remove both ATR clamps, reject broker-invalid exact SAR
stops, compile through the authorized path, test the fail-closed behavior, and
resubmit hashes and compiler evidence. Pipeline verdicts remain solely with
the pipeline.
