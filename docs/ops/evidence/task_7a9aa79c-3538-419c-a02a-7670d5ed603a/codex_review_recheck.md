# Codex re-review: QM5_35007

- Review task: `7a9aa79c-3538-419c-a02a-7670d5ed603a`
- Gemini source task: `c0f9d1e3-582f-4842-86d4-9b37950b32c0`
- Disposition: `CHANGES_REQUIRED`
- Router handoff: remain in `REVIEW`; no pipeline handoff

The 2026-08-21 card amendment resolved the reward/risk contradiction and
specified a two-leg OCO bracket with completed-bar expiry. The source and
binary are unchanged from the earlier failed review and still implement the
pre-amendment mechanics. The router-listed review skills are unavailable;
Codex performed the mandatory review directly.

## Bound inputs

- Approved card SHA-256: `ca3eff004558980b668ecc1f295555897db2e676ef4c3f0c2ace63f8ee0df5d2`
- MQ5 SHA-256: `a390d193fb248ade83c67848cb9932a28d145dd54410d7c0a794f9da102011ef`
- EX5 SHA-256: `7df381a8fccf9bb2bab008d24dc0cae3352effb41779cae2bf3eb7f6ca8f02ae`
- SPEC SHA-256: `a23927e1bc4b6480679952df34e27bf623ff7dd961ce5775489840c5b10dab9e`
- Active magic rows: `350070000`, `350070001`, `350070002`

## Blocking findings

1. Card lines 97-104 require simultaneous BUY_STOP and SELL_STOP legs with
   OCO cancellation and expiry after three completed H4 bars. The single
   `QM_EntryRequest` path returns only a BUY_STOP in the normal case (source
   lines 191-200), does not establish an opposing leg, and does not implement
   OCO ownership.
2. The corrected TP is `2 * SL_Distance = 0.40 * Mother_Range` (card lines
   95-96). Source lines 161-162 still compute a minimum-clamped SL but set TP
   to `strategy_tp_rr_mult * mother_range`; with the default 2.0 this remains
   a 2.0-mother-range target, or 10R before the minimum clamp.
3. Card line 105 expressly forbids market fallbacks and extra breakeven moves.
   Source lines 172-189 convert already-broken setups to market entries, while
   lines 205-267 add a +1R breakeven rule. Elapsed seconds at line 128 also do
   not prove three completed active H4 bars.

No amended-card rebuild or new RESULT packet was supplied. The bound MQ5/EX5
hashes remain those of the earlier failed review.

## Focused verification

- Build guardrails: PASS over four package files with
  `qm_news_stale_max_hours <= 336`.
- SPEC validation: PASS.
- Set risk: all three setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Registry: EA row is active and all three magic rows are active.
- Target EA directory: clean in Git.
- Compilation was not rerun because no source repair exists. The next build
  must use `COMPILE_EA`, test atomic two-leg/OCO state, completed-bar expiry,
  and exact 1:2 payoff, then provide a new bound RESULT packet.

Structural validation does not establish card fidelity. Pipeline verdicts
remain solely with the pipeline.
