# CODEX INDEPENDENT SAMPLE CLASSIFICATION — Source Harvest 2026-07-24

You are Codex, independently classifying a random 20% sample (26 PDFs) of the
Web-Sources harvest. Claude classifies the full set in parallel; your entries are
the control group — work from the PDFs alone, do NOT read any Claude ledger files
under `docs/ops/source_harvest/` (only this brief).

**This run develops NOTHING.** No strategy design, no MQL5, no EA work, no code
beyond throwaway text-extraction helpers. Classification only.

## Input

`D:\QM\reports\source_harvest_codex_sample\` — 26 PDFs + `_sample_manifest.json`
(file, pages, original G: path). Extract text with python (`pypdf` is installed:
`from pypdf import PdfReader`); PDFs are text-based (no OCR needed; if one turns
out image-only/unreadable, record it as UNREADABLE in your notes column and move on).

## Output — one row PER CANDIDATE STRATEGY (a PDF can yield several rows, or zero)

Write `D:\QM\reports\source_harvest_codex_sample\CODEX_SAMPLE_LEDGER.csv` with
EXACTLY these columns (and a human-readable `.md` twin):

`source_file, source_pages, source_ref, strategy_name, concept, market, timeframe, session, rules_completeness, eligibility, eligibility_reason, priority_hint, notes`

- `source_ref`: author/title/year + URL as running text (forum threads: thread
  title, author handle, forum, year, URL). Forum sources are NOT auto-rejected —
  precedent: the live Balke EA came from a ForexFactory thread. Reputability
  concerns go into `eligibility_reason`/`priority_hint`, not auto-REJECT.
- `market`: FX / Indices / Metals / Futures / Crypto (our universe: DXZ symbols,
  .DWX feeds). `timeframe`: M1/M5/M15/H1/H4/D1 (MN1 untestable; monthly = D1-native).
- `session`: Asia / London / NY / none.
- `rules_completeness`: FULL (entry+exit+params all stated) | PARTIAL | VAGUE.
- `eligibility` (hard rules, congruent with Q00 R1–R4):
  - **ELIGIBLE** = ALL of: (a) implementable in pure MQL5 on the V5 framework, no
    external runtime, no ML; (b) deterministic rule-based entry/exit; (c) data for
    market+timeframe available via .DWX/DXZ; (d) compatible in principle with
    FTMO (daily loss, max DD) + DXZ constraints (5%/20% DD, ≥20% p.a., no ML);
    Friday-close exists in the framework.
  - **PARKED** = interesting but violates (a)–(d) (ML, Python/external data,
    options data, order-flow feeds, fundamentals). Give the revisit trigger.
  - **REJECTED** = no usable edge, pure marketing, or rules too vague to implement.
- `priority_hint`: HIGH | MED | LOW (edge plausibility × rules completeness ×
  fit to the current portfolio need for uncorrelated return drivers).

## Constraints

Read-only everywhere except `D:\QM\reports\source_harvest_codex_sample\`. No git
operations, no repo writes, no T_Live/factory/task/flag/config touches, no DB
writes (`file:...?mode=ro` only if you need the EA inventory for context — not
required for your task). When done:
`python C:\QM\repo\tools\strategy_farm\agent_router.py update-task <task_id> --state REVIEW --artifact-path "D:\QM\reports\source_harvest_codex_sample\CODEX_SAMPLE_LEDGER.csv" --verdict "sample classification complete: <n_rows> rows from 26 PDFs, <eligible>/<parked>/<rejected>"`
(task id via `list-tasks --agent codex --state IN_PROGRESS`). Then exit.
