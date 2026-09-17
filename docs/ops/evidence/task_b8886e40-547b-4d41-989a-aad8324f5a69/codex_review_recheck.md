# Codex re-review: QM5_35006

- Review task: `b8886e40-547b-4d41-989a-aad8324f5a69`
- Gemini source task: `348092fa-14ad-4bd0-974f-c1a360144519`
- Disposition: `CHANGES_REQUIRED`
- Router handoff: remain in `REVIEW`; no pipeline handoff

The 2026-08-21 card amendment replaced the undefined ribbon-expansion phrase
with exact Trader alignment and rising-spread predicates, and fixed the stop
strictly at EMA(60). The EA source and binary are unchanged from the earlier
failed review and do not implement those corrected mechanics. The router-listed
review skills are unavailable; Codex performed the mandatory review directly.

## Bound inputs

- Approved card SHA-256: `b19edd0ef51a93247fdc69bd72013f6be6ab915eae4636ebc4f254ae0e7ab75c`
- MQ5 SHA-256: `28e00b4b1a5b8efc45bc78ccdcbeba0f20369b1548facabec7fb91dc451d882b`
- EX5 SHA-256: `7bd722291c2612aafe8a810e6f4337e5b5d6fae62b0e645f307e40ed2c0f5ffd`
- SPEC SHA-256: `a30f876a155c499dd08e925b70591ea36cdda70eee32f4a7a6bc4c3856560153`
- Active magic rows: `350060000`, `350060001`

## Blocking findings

1. Card lines 78-98 require `Trader_Spread[1] > Trader_Spread[2]`. The source
   reads every fast EMA only at shift 1 and never computes the prior-bar
   spread (source lines 115-152 and 175-183), so the mandatory expansion
   predicate is absent. It instead adds full Investor-ribbon ordering, which
   the exact entry equation does not require.
2. Card line 101 requires the stop strictly at EMA(60), with no arbitrary
   minimum override. Source lines 138-165 and 188-196 replace EMA(60) whenever
   its distance is below `strategy_min_sl_pips`.
3. The required EMA(30) exit is evaluated only after the entry no-trade filter;
   source lines 261-270 can return before the exit check. An entry filter may
   therefore suppress position management.

No amended-card rebuild or new RESULT packet was supplied. The bound MQ5/EX5
hashes remain those of the earlier failed review.

## Focused verification

- Build guardrails: PASS over three package files with
  `qm_news_stale_max_hours <= 336`.
- SPEC validation: PASS.
- Set risk: both setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Registry: EA row is active and both magic rows are active.
- Target EA directory: clean in Git.
- Compilation was not rerun because no source repair exists. The next build
  must use `COMPILE_EA`, test shift-1 versus shift-2 spread behavior and exact
  EMA(60) stops, and provide a new bound RESULT packet.

Structural validation does not establish card fidelity. Pipeline verdicts
remain solely with the pipeline.
