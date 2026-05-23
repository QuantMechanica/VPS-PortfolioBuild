# Codex G0 Review

You are doing focused QM G0 reviews on Codex. Claude does the SAME job
in parallel — both workers split the draft-card queue using filesystem
claim locks. Cards you are assigned have a `.g0_claim` file naming
`codex` next to them in `D:/QM/strategy_farm/artifacts/cards_draft/`.

OWNER 2026-05-17: "wir wollen weiterhin beides in parallel" — Claude
and Codex run G0 concurrently; this prompt is Codex-side.

## Workflow

For each card in your batch (paths listed below):

1. Read `C:/QM/repo/processes/qb_reputable_source_criteria.md` to refresh
   R1–R4 criteria (one-time per session is fine).
2. For each `{{batch_paths}}` card:
   a. Read the card frontmatter + body.
   b. Apply R1 (reputable source link/attribution), R2 (mechanical Entry +
      Exit rules), R3 (testable on ≥1 DWX symbol after porting), R4 (no
      ML / binding HR14).
      R2 must include a plausible trade-frequency estimate. Reject if the
      card cannot support at least 2 expected trades/year/symbol, unless the
      strategy is explicitly portfolio-basket based and the card gives a
      defensible basket-level cadence. Purely annual/one-shot seasonal ideas
      are too sparse for this factory unless OWNER explicitly marked them
      approved.
      Also sanity-check the declared `expected_trades_per_year_per_symbol`
      against the written entry conditions. If the entry pattern is monthly,
      quarterly, event-only, or otherwise rare, do not accept an inflated
      cadence number just because it appears in frontmatter.
   c. If ALL four PASS:
      ```
      python C:/QM/repo/tools/strategy_farm/farmctl.py approve-card \
        --card "<path>" --reasoning "<R1-R4 one-line rationale>"
      ```
   d. If ANY FAIL:
      ```
      python C:/QM/repo/tools/strategy_farm/farmctl.py reject-card \
        --card "<path>" --reason "<which R + why>"
      ```
3. After the last card, exit cleanly. No prose outside farmctl invocations.

## SP500.DWX note (R3 caveat)

SP500.DWX is now backtest-only available (Custom Symbol since 2026-05-16
19:15Z). R3 PASS-with-T6-caveat is acceptable for SPY-intraday cards.
DWX broker feed still doesn't support live SP500 — those cards need
NDX/WS30 fallback parameters for any future live promotion.

## Quality bar

You and Claude both apply the same R1–R4 — your verdicts should converge
on the same approve/reject decision most of the time. If you're unsure:
**lean reject**. We have plenty of pending sources; better to send a
marginal card back than to flood the build pipeline with rejectable
strategies that waste Codex build cycles + MT5 backtest time.

After your invocations, the card .md file moves to either
`cards_approved/` or `cards_rejected/`. The `.g0_claim` lock file in
`cards_draft/` becomes orphan — repair pass cleans those up. Just exit.

## Cards assigned to this batch

{{batch_paths}}
