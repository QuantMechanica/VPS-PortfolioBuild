---
source_id: KATSANOS-INTERMARKET-2008
source_id_status: OWNER_APPROVED_NAMED_SOURCE
source_type: licensed_book
title: Intermarket Trading Strategies
authors: Markos Katsanos
publisher: Wiley
publication_year: 2008
print_isbn: "9780470758106"
online_isbn: "9781119207153"
status: EXTRACTION_COMPLETE_G0_DRAFTS_PENDING
created: 2026-07-23
created_by: Research
last_updated: 2026-07-23
approval_basis: "OWNER confirmed in this workspace that the supplied PDF came from an official shop and directed that the source block be removed."
source_sha256: B48AA0B83A783FDF6676199F399D5AFEEE48D259EF4A5F011C5131BC32E81D99
text_cache_sha256: C9DB82117A0AB4D9E6D015DF0BC370B2521FBF0C73C5657FA44D76E4A01A778D
provenance_ref: D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.provenance.json
research_artifact: docs/research/KATSANOS_CH13_CH17_EXTRACTION_2026-06.md
---

# KATSANOS-INTERMARKET-2008 — Intermarket Trading Strategies

## Source approval and scope

The OWNER supplied the local PDF and explicitly confirmed its provenance on
2026-07-23:

> "das ist aus einem offiziellen shop, somit blockierung aufheben"

That instruction authorizes research extraction from the identified copy. It
does not authorize a build, a pipeline PASS claim, T6 deployment, or live use.

- Local source:
  `C:/Users/Administrator/Downloads/intermarket-trading-strategies-markos-katsanos.pdf`
- PDF SHA-256:
  `B48AA0B83A783FDF6676199F399D5AFEEE48D259EF4A5F011C5131BC32E81D99`
- PDF size: 5,888,264 bytes; 430 pages.
- Evidence cache:
  `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.txt`
- Evidence-cache SHA-256:
  `C9DB82117A0AB4D9E6D015DF0BC370B2521FBF0C73C5657FA44D76E4A01A778D`
- Cache extraction: `pypdf 6.12.1`, UTF-8, 430 `PDFPAGE` markers.
- Page map for Chapters 13, 17, and Appendix A:
  `PDFPAGE = printed book page + 18`.
- Runtime provenance record:
  `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.provenance.json`.

Approved and reviewed mechanical-system evidence:

- Chapter 13, "Trading DAX Futures": book pp. 201–213 /
  PDFPAGE 219–231.
- Chapter 17, "Forex Trading Using Intermarket Analysis": book pp. 261–292 /
  PDFPAGE 279–310.
- Appendix A.4: book pp. 327–332 / PDFPAGE 345–350.
- Appendix A.8: book pp. 348–355 / PDFPAGE 366–373.

The complete bounded evidence above was read against both the text cache and
the Appendix code. Material prose/code conflicts were retained rather than
silently normalized. The source audit is:

- `docs/research/KATSANOS_CH13_CH17_EXTRACTION_2026-06.md`

## Extraction result

Nine mechanical configurations or variants were identified. Most require
unavailable CAC/FCE, Euro Stoxx/FESX, TNX, CRB, 6J, or individual DAX stocks.
Two source configurations use only a currently available base series:

| Slot | Candidate | Source carrier | Current research carrier | State |
|---|---|---|---|---|
| S01 | CI-regime MA/stochastic system | FDAX D1 | `GDAXI.DWX` D1 | [`kats-dax-maci_card.md`](../../cards/kats-dax-maci_card.md), Draft pending G0 |
| S02 | Volatility-filtered MA/CI/SAR system | EUR/USD D1 | `EURUSD.DWX` D1 | [`kats-eu-macisar_card.md`](../../cards/kats-eu-macisar_card.md), Draft pending G0 |

The Chapter 11 gold card `QM5_12542_katsanos-gold-multidiv-d1` predates this
canonical source record. It shares the same book but has separate historical
lineage metadata and is not modified by this extraction.

## Frozen extraction interpretations

The draft Cards use the executable Appendix implementation as their source-rule
baseline and disclose every deviation:

- S01 uses Appendix A.4's exact DAX MA/CI/stochastic Boolean rules and the
  printed next-open, one-bar-delay convention.
- S02 uses Appendix A.8's `ABS(CI) > 40` implementation. Equations 17.2 and
  17.5 print `< 40`; that alternate publication form remains a falsification
  diagnostic and cannot replace the baseline after seeing results without a
  new Card/version and review.
- S02 converts the source's idealized same-day-close fill into a causal
  closed-D1-signal/next-bar-open implementation. It is an explicit
  QuantMechanica execution interpretation, not a claim that the historical
  source result is reproduced.
- Any ATR catastrophe stop, framework news pause, or Friday flatten is a
  QuantMechanica safety/execution overlay and must be identified as such.

## Authorization boundary

The two Cards remain `DRAFT` with `ea_id: TBD`. EA IDs and magic rows are left
to the deterministic registry procedure after an explicit OWNER G0 decision.
No code, compile, tester run, terminal operation, pipeline phase, or live
artifact is authorized by this source record.
