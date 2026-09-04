# FTMO Rulepack V2 evidence-chain coherence — 2026-09-04

Router task: `a4fb4108-4da7-46c3-830f-97c0dd45d4b6`
OWNER decision: `OWNER-DEC-FTMO-RULEPACK-COHERENCE-20260904`
Receipt: `decisions/2026-09-04_owner_receipts_briefing_2_4.md`

## Correction notice (supersedes the first version of this page)

The first version of this page, and the `retrieval_method` field of
`docs/ops/evidence/2026-09-02_ftmo_official_rules_snapshot.json`, stated that the
normalized rule claims "were cross-checked against the same official FTMO origins on
2026-09-04". **That statement was not backed by any retrieval evidence and is withdrawn.**
An adversarial verification also found that five of the seven source records in that
snapshot carried `retrieved_at_utc=2026-09-02T09:27:22Z`, `http_status 200` and a
`content_type` although they were 2026-07-29 observations re-stamped with the 2026-09-02
instant, which would have satisfied the evaluator's fail-closed seven-day freshness gate
without a corresponding retrieval.

This page now describes a real retrieval and the snapshot minted from it.

## The 2026-09-04 retrieval

Nine official FTMO URLs were requested from the VPS on **2026-09-04 between 02:10:47Z and
02:10:49Z** with Python `urllib` and `User-Agent: Mozilla/5.0`. For every request the
status line, `Content-Type`, byte count, `Last-Modified` header, final URL after redirects
and the SHA-256 of the raw response body were recorded, and the body itself was written to
disk.

- Eight requests returned **HTTP 200**: the seven expected evaluator source ids plus the
  declared economic component source `https://ftmo.com/en/scaling-plan/` (which redirects
  to `https://ftmo.com/en/reward-growth-and-scaling-plan/`).
- One request failed: **`https://ftmo.com/en/trading-symbols/` returned HTTP 404** — a dead
  URL. It is the source the 2026-09-02 snapshot cites for the two Swing leverage facts. No
  replacement source was located and **none was invented**.

The eight retained bodies (2,335,383 bytes in total) are committed verbatim under
`docs/ops/evidence/ftmo_fetch_20260904/` and pinned `-text` in `.gitattributes`. Every
body's SHA-256 equals the `response_sha256_observation` recorded for that source in the new
snapshot.

Two observations that must not be over-read:

- The `Last-Modified` header returned by ftmo.com equals the request time for every page,
  so it is a dynamic-response artefact, not a content vintage. The snapshot records it with
  `"last_modified_is_content_vintage": false`.
- `ftmo_economic_terms_official` and `ftmo_2_step_challenge_official` resolve to the same
  URL. The two independent GETs returned bodies of identical length (306,302 bytes) but
  **different SHA-256**, i.e. the page emits per-response varying bytes.

## The new snapshot

`docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`, SHA-256
`c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905`, in the evaluator's
required `qm.ftmo-official-rules-snapshot/v1` schema.

- All 30 `normalized_claims` values and the whole `claim_provenance` map are **byte-identical**
  to the 2026-09-02 snapshot. No rule value changed.
- Every source record now carries a measured 2026-09-04 observation: `http_status`,
  `content_type`, `retrieved_at_utc`, `response_bytes`, `response_sha256_observation`,
  `last_modified_header_observation`, `final_url` and the in-repository `raw_body_path`.
  Nothing is re-stamped and nothing is null-by-omission.
- A new `claim_reconfirmation_2026_09_04` block records, per claim, whether the value was
  found in a 2026-09-04 body, with the verbatim quote, the body path, and whether the
  snapshot value is the literal page value or this repository's normalization of the quoted
  wording. Each `RE_CONFIRMED` row additionally carries
  `declared_provenance_source_ids`, `confirmed_on_declared_provenance_page`, `quote_form`
  and `quote_is_literal_substring_of_body`, so "which page actually re-confirmed this" and
  "is the printed quote literally in that page" are machine-readable per claim instead of
  being asserted once in prose.

### Re-confirmed vs carried over

**28 of 30 claims RE_CONFIRMED, 2 CARRIED_OVER — but the 28 are not homogeneous.**
Stated precisely: **25 claims were re-confirmed on the page named by their own
hash-pinned `claim_provenance`, 3 were re-confirmed on a different official FTMO page,
and 2 were carried over without re-confirmation.** The three-way split is recorded in the
snapshot's `claim_reconfirmation_summary` and per row; the sub-section
"Three claims re-confirmed on a different page" below names them.

| Cited source | Claims | Re-confirmed | Carried over |
| --- | ---: | ---: | ---: |
| `ftmo_trading_objectives_official` | 14 | 14 | 0 |
| `ftmo_news_official` | 1 | 1 | 0 |
| `ftmo_weekend_official` | 1 | 1 | 0 |
| `ftmo_ea_official` (+ `ftmo_forbidden_practices_official`) | 5 | 5 | 0 |
| `ftmo_economic_terms_official` | 9 | 7 | 2 |

The two carried-over claims are `swing_fx_leverage` (`1:30`) and
`swing_metals_and_oil_leverage` (`1:15`). Their cited component URL is the dead
`https://ftmo.com/en/trading-symbols/`, and the literal tokens `1:30` and `1:15` are absent
from all eight retained bodies. **These two values are reproduced unchanged from the earlier
snapshots and are not re-confirmed as of 2026-09-04.** They must be re-sourced before any
decision that depends on Swing leverage.

Qualifications recorded per claim inside the snapshot rather than smoothed away:

- `maximum_daily_loss_reset_timezone` — the page states `00:00 CE(S)T`; the IANA identifier
  `Europe/Prague` is this repository's normalization and does not appear literally.
- `trading_day_qualifier` — likewise a normalization of the page's `00:00:00 to 23:59:59
  CE(S)T` day window.
- `maximum_trading_period_days` — the quote `No time limit` comes from the Trading
  Objectives page's marketing block, not from its rule list; the 2-Step product page
  corroborates it with `Trading Period / Unlimited`.
- `usd_100000_2_step_list_price_usd` — `540` is the second entry of the page's embedded
  `prices.step_2` array. Its evidence quote is the **only abridged quote in the snapshot**:
  the `...` markers inside it are our own elisions, so that quote is not a literal substring
  of the retained body (see "Quote-check" below). Each elided fragment was machine-checked
  individually. The `540` entry carries `discounted_price` `439` and a
  `discounted_price_tooltip_text` that reads, once the page's own JSON `\uXXXX` escapes are
  decoded, `Special Deal! $100,000 FTMO Challenge for EUR 439 - only if you don't already
  have one active.` The exact byte form as it appears in the retained body — escapes and all
  — is stored verbatim in that snapshot row's `quote_fragments_verified_literal`. The page
  therefore **does literally name the `$100,000` account size on that same array entry**,
  which supports the `100000 -> 540` mapping more strongly than positional alignment alone.
  The entry additionally aligns positionally with the first currency block's balances
  `[200000, 100000, 50000, 25000, 10000]`. What remains genuinely un-stated is the
  **currency of the `540` list price itself**: the only currency symbol on that entry is the
  EUR escape on the discounted `439`, so **the USD denomination of `540` is still inferred,
  not literally stated**. The earlier version of this bullet cited only the EUR figure and
  called the whole attribution positional; that understated the page evidence.
- `hyperactive_server_request_threshold_per_day` — the number `2,000 server requests per
  day` is on the forbidden-practices page; the co-cited EA FAQ restates the rule
  qualitatively without a number.
- `ftmo_2_step_challenge_official` is required by the evaluator's source-id set but has no
  claim attributed to it in `claim_provenance` and duplicates the economic-terms URL. That
  is recorded in the snapshot instead of being papered over. Four re-confirmation rows
  (`usd_100000_2_step_list_price_usd`, `evaluation_fee_refund_percent_with_first_reward`,
  `base_reward_split_percent`, `maximum_reward_split_percent`) name
  `ftmo_2_step_challenge_official` as the body they were found in while their
  `claim_provenance` names `ftmo_economic_terms_official`. Because both source records carry
  the identical URL `https://ftmo.com/en/2-step-challenge/`, this is a source-id label
  difference, not a different page, and those four count as re-confirmed on their declared
  provenance page. Three of the four quotes were additionally machine-checked as present in
  the separately retained `ftmo_economic_terms_official` body; the fourth is the abridged
  `usd_100000_2_step_list_price_usd` row, whose fragments are present in both bodies.

### Three claims re-confirmed on a different page

`account_balance_increase_percent` (`25`), `minimum_months_between_scaleups` (`4`) and
`scaled_reward_split_percent` (`90`) declare `claim_provenance =
['ftmo_economic_terms_official']`, which the evaluator pins and hash-validates. Their
quotes were machine-checked as **ABSENT** from that retained body and **PRESENT** in the
retained `ftmo_scaling_plan_official` body (`https://ftmo.com/en/scaling-plan/`):

| Claim | Quote found in `ftmo_scaling_plan_official` |
| --- | --- |
| `account_balance_increase_percent` | `Enjoy account size growth of 25% every 4 months, up to the maximum limit of $2,000,000 …` |
| `minimum_months_between_scaleups` | `Get a 25% boost to your FTMO Account balance every 4 months.` |
| `scaled_reward_split_percent` | `Get a 90% share of your simulated profits (valid for 2-Step only)` |

`ftmo_scaling_plan_official` is a genuine official FTMO page retrieved HTTP 200 in the same
2026-09-04 fetch and retained under `docs/ops/evidence/ftmo_fetch_20260904/`, **but it is
not one of the seven `EXPECTED_OFFICIAL_SOURCE_IDS` and is not a declared source record in
the snapshot**. The rows themselves always named the body they were actually found in; what
was missing — and is now supplied in the snapshot and in the headline above — is the
disclosure that for these three the pinned provenance page did *not* re-confirm the claim
on 2026-09-04. No value changed; the scaling-plan wording matches the carried values
exactly. Re-pointing `claim_provenance` for these three would change a hash the evaluator
pins and is deliberately **not** done here.

## Pin repoint

- Rulepack `FTMO_2S_100K_SWING_V2`: all seven `official_sources` rows now bind
  `snapshot_path=docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`,
  `snapshot_sha256=c199b8f5…`, `retrieved_on=2026-09-04`,
  `retrieved_at_utc=2026-09-04T02:10:47Z`. No value in `official_rules` changed;
  `profile_version` stays 2.
- Rulepack raw SHA-256 `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`;
  canonical SHA-256 `7e0b21d3768c78c69e28c390814948286736ecec4fd28490a86c647f3485dbd8`.
  Both were advanced in `tools/strategy_farm/config/pipeline_books_program_status.v1.json`
  and in the dossier test's `RULEPACK_HASHES`. That program-status file states the
  canonical hash in **three** coupled places, not two: `bindings.rulepacks[1].file_sha256`,
  `bindings.rulepacks[1].canonical_sha256` and `target_lanes[1].rulepack_canonical_sha256`.
  `pipeline_books_dashboard_status._validate_target_lanes` enforces equality between the
  lane field and the binding, fail-closed. The first version of this repoint advanced only
  the two `bindings` fields and left the lane field on the previous canonical hash, which
  made `load_program_status()` raise `lane hash does not match rulepack binding` and turned
  `program_status_snapshot()` into `state=INVALID, valid=False, target_lanes=[]` — the
  cockpit/strategies Pipeline-Books surface lost its lane data. All three fields are now
  advanced together.
- The standalone evaluator repoints `OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH`,
  `OFFICIAL_RULE_SNAPSHOT_SHA256`, `DEFAULT_RULEPACK_SHA256`, the `retrieved_on` vintage
  check (`2026-09-04`) and the header `as_of` contract.
- FTMO Q02/standalone preparers and the isolated-work-item source scope point at the new
  snapshot.

### `as_of` had to move to 2026-09-04

`target_rulepacks.py` enforces `0 <= as_of - retrieved_on <= 7` days and rejects a
`retrieved_on` later than `as_of`. A 2026-09-04 retrieval therefore cannot be carried by a
rulepack whose `as_of` is 2026-09-02: the header date moved from `2026-09-02` to
`2026-09-04`, and the evaluator's header contract moved with it. This is a vintage stamp;
no rule value and no gate threshold changed.

### Evaluator rulepack path made checkout-relative

`DEFAULT_RULEPACK_PATH` was an absolute `C:\QM\repo\…` literal while the official-rules
snapshot was already resolved relative to the module's own `REPO_ROOT`. The evaluator
cross-validates those two operands against each other, so reading them from two different
checkouts is the same class of evidence-chain incoherence this repair is about. The
constant now resolves against `REPO_ROOT`; in the canonical repository it yields the
identical absolute path, so production behaviour is unchanged. `DEFAULT_COST_SNAPSHOT_PATH`
was deliberately left as-is.

### The 2026-09-02 snapshot is left byte-unchanged

No `_superseded_by` marker was written into
`docs/ops/evidence/2026-09-02_ftmo_official_rules_snapshot.json`. Nothing in code pins it
any more after this repoint, but its SHA-256 `d055f71c…` is still cited as a durable record
in `docs/ops/OPEN_ITEMS_STATUS.md` and in this page; mutating the file would falsify those
records. The supersession is declared in the new snapshot's `supersedes` block instead.
The withdrawn cross-check sentence inside that file's `retrieval_method` therefore still
stands in the historical artefact and is corrected here, on this page, and in the new
snapshot.

## Verification

- `python -X utf8 tools/strategy_farm/target_rulepacks.py` — `DXZ_BETTER_BOOK_V1 PASS`,
  `FTMO_2S_100K_SWING_V2 PASS 7e0b21d3768c78c69e28c390814948286736ecec4fd28490a86c647f3485dbd8`
  (exit 0).
- `python -X utf8 -m pytest -q -p no:cacheprovider tools/strategy_farm/tests/test_ftmo_book3_standalone_evaluator.py tools/strategy_farm/tests/test_prepare_ftmo_book3_q02.py tools/strategy_farm/tests/test_prepare_ftmo_book3_standalone_diagnostic.py tools/strategy_farm/tests/test_isolated_work_item_runner.py tools/strategy_farm/tests/test_target_outcome_dossier.py`
  — **238 passed** in 136.34s.
- `tools/strategy_farm/tests/test_target_rulepacks.py` — **14 passed**.
- `tools/strategy_farm/tests/test_pipeline_books_dashboard_status.py` — **40 passed**. This
  file is not in the required five, but it is the one that catches the lane/binding hash
  coupling described under "Pin repoint"; with the lane field left stale it fails 22 of 40.

### Quote-check (corrected)

The earlier version of this page claimed that *every* `RE_CONFIRMED` quote was
machine-checked as a substring of the named retained body. That is true for **27 of the 28**
rows, not all of them. Each of those 27 quotes was matched against the raw response bytes,
the HTML-unescaped bytes, or the tag-stripped whitespace-collapsed page text of the body its
own row names. The single exception is `usd_100000_2_step_list_price_usd`, whose
`evidence_quote` is abridged with explicit `...` elisions and is therefore **not** a literal
substring; its six constituent fragments were machine-checked individually instead and are
listed in that snapshot row under `quote_fragments_verified_literal`. The underlying facts
are unaffected — the `1080 / 540 / 345 / 250 / 89` step_2 price sequence is present in the
body — and the snapshot now carries `quote_form` and
`quote_is_literal_substring_of_body` on every `RE_CONFIRMED` row so the distinction is
machine-readable rather than prose-only.

The two `CARRIED_OVER` tokens were machine-checked as absent from all eight bodies.

No FTMO rule value and no evaluation threshold changed. No purchase, deployment, `T_Live`,
terminal, or AutoTrading action was performed.

Verdict: **REVIEW — evidence chain now rests on a measured retrieval; two Swing leverage
claims remain unverified and are flagged as such. Claude/OWNER close-out remains required.**
