# Cross-vendor critique of H-V1 / H-V2 / H-V3 (QM-RESEARCH-2026-0009 / 0010 / 0011)

- Router task: `1614737c-d2d8-45be-a27a-489f30c3b76d` (research_strategy, critic seat Codex, creator Claude
  task `31012467`), returned 2026-09-21T06:40Z. Closed by Fable 2026-09-21T07:3xZ (APPROVED = critique accepted).
- Verbatim critic verdict (copied from `agent_tasks.verdict`; the critic performed no repo writes):

> H-V1 REVISE — not buildable from spec alone: target is an unresolved 1.5x-2.0x choice, the thin-range floor is
> unnamed, and no explicit new-bar/shift-1 contract exists (0009/source.md:45-58). Its 0.6-0.7/bd and +0.10-0.15R are
> labelled priors, not measurements; +0.10-0.15R is an unsupported uplift over measured 13213 +0.064R
> (0009/source.md:62-79; velocity README:14-26). The alleged pilot is only prior*1175 arithmetic. Cost_R is not
> computable: source points to tester_defaults, which has no commission, while live_commission.json:6-17 requires actual
> notional/volume and the draft supplies no minimum stop/unit value (0009/source.md:88-98). Require frozen 1.5/2.0
> arm(s), exact false-break precedence, shift-1/new-bar reads, a measured fire-count prescreen per symbol/arm, and tail
> tests vs 10706/13213/H-V3.
>
> H-V2 REVISE — fixed 13:30 UTC conflates a DST-varying US cash open with 08:30 ET macro time (0010/source.md:27-39;
> CLAUDE.md:240-264); choose one America/New_York economic anchor and map it deterministically. Target 1.5x-2.0x, min
> range, and explicit shift-1 contract are unresolved (0010/source.md:41-51). Density 0.5-0.7 and +0.10-0.15R are
> unsupported extrapolations above measured 10423 +0.086R / 11690 +0.028R, with the news blackout overlapping the
> claimed driver (0010/source.md:55-73). Cost_R cannot be computed despite governed XAU commission being 0.005% notional
> RT (live_commission.json:14-16; venue_cost_model.json:71-76); no min stop exists. Quantify the DD kill bar and run fast
> fire-count/cost floors before Q02; keep the 10700 tail test.
>
> H-V3 REJECT current draft — entry price, gap vs spike definition, ATR multiple, reference side, and closed-bar/shift-1
> semantics are unspecified; using a spike extreme before the signal bar closes would look ahead (0011/source.md:51-63).
> The 0.4-0.6/bd rate is a bare assumption, and combined R/bd is arithmetically wrong: two symbols imply 0.064-0.144,
> not 0.032-0.072 (0011/source.md:67-84). Negative breakout evidence does not establish a fade edge
> (0011/source.md:30-49); thin-session spread is explicitly unmeasured (0011/source.md:86-95). A materially
> re-authored, DST-aware, closed-bar hypothesis with measured fire count and per-leg kill rules may be reconsidered; add
> tail tests vs H-V1/10706 as well as 13213.
>
> GLOBAL FAIL-CLOSED PROVENANCE — research_source.py verify returns NUMERIC_UNBACKED plus LEDGER_STATUS_BAD:draft for all
> three. source.md manifest/research.json bind baseline hashes c987e2d3/7426c6e9/cfcdde83 (0009:153, 0010:126,
> 0011:137), but actual SHA-256 is 5b291bdf/c43a6cee/1258bc60. Therefore the index claim that verification has only
> LEDGER_STATUS_BAD:draft (index:30-36) is false. No card/build until the artifacts verify cleanly. No source/repo
> writes performed.

## Fable verification (2026-09-21T07:3xZ)

- Provenance finding independently confirmed: `sha256sum` of the three stored `baseline_extract.json` files gives
  5b291bdf… / c43a6cee… / 1258bc60…, while the sealed manifests bind c987e2d3… / 7426c6e9… / cfcdde83…. The
  artifacts therefore do not verify and are not card-admissible in their current state.
- Every substantive point (unresolved target arm, missing thin-range floor, missing shift-1 contract, unmeasured
  density, DST-conflated 13:30 UTC anchor, non-computable cost_R, H-V3 arithmetic error and look-ahead risk) is
  correct against the drafts.

## Disposition

| id | verdict | follow-up |
|---|---|---|
| 0009 H-V1 | REVISE | re-author with frozen arms (1.5x / 2.0x as separate arms), explicit shift-1/new-bar contract, false-break precedence, named thin-range floor, measured fire-count + cost_R prescreen per symbol/arm from bar data; reseal |
| 0010 H-V2 | REVISE | same, plus one America/New_York economic anchor (08:30 ET) mapped deterministically to server time, DD kill bar quantified, 10700 tail test retained; reseal |
| 0011 H-V3 | REJECT (current draft) | ledger status → retired; a closed-bar, DST-aware re-authoring with measured fire count is a new artifact, not an edit |

Re-authoring is Fable's own work (hypothesis authoring = Claude lane), then a second cross-vendor critic round (Codex).
No card, no build, no factory rows until `research_source.py verify` is clean except `LEDGER_STATUS_BAD:draft`.
