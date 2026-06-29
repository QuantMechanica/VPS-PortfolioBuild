---
source_id: TGIF-WTI-WEEKEND-2017
title: TGIF? The weekend effect in energy commodities
publisher: Journal of Finance Issues
source_type: academic_paper
status: cards_ready
created: 2026-06-28
created_by: Codex
uri: https://jfi-aof.org/index.php/jfi/article/view/2264
cards_extracted:
  - wti-weekend-gap-fade
  - wti-weekend-gap-bounce
---

# TGIF WTI Weekend Source

## Source Identity

- Publisher: Journal of Finance Issues
- Primary source: "TGIF? The weekend effect in energy commodities", URL
  https://jfi-aof.org/index.php/jfi/article/view/2264
- PDF URL: https://jfi-aof.org/index.php/jfi/article/download/2264/1847

## Research Use

This source is used for structural lineage around weekday/weekend return
structure in energy commodities. The QM extraction mechanizes two one-sided WTI
CFD rules: a D1 Monday positive-weekend-gap fade on `XTIUSD.DWX`, and a
separate D1 Monday negative-weekend-gap bounce that targets a fill back to the
prior Friday close.

The implementation does not import the paper's performance claims into QM. It
uses the source only to justify a deterministic weekend-effect hypothesis, then
requires Q02+ validation on Darwinex `XTIUSD.DWX` bars.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, EIA inventory data, analyst
  forecast, discretionary override, or news scraping.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per XTIUSD.DWX magic slot.

## R-Rules

- R1 reputable source: PASS. Single academic-paper source with public URL.
- R2 mechanical: PASS. Fixed D1 Monday gap condition, ATR hard stop, gap-fill
  target, and deterministic time exit.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar/gap
  sleeve.
