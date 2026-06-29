# FTMO March 2026 XTIUSD Portfolio Package

Source ID: `FTMO-MAR2026-XTI-PORTFOLIO`

This local code-first source is the prior QM inventory of OWNER's FTMO March
2026 portfolio package, specifically the `FTMO_XTIUSD_Portfolio_v1` row in
[existing_ea_inventory.md](../../../docs/research/dropbox/existing_ea_inventory.md).

The inventory records the XTIUSD package as a rule-based, non-ML portfolio EA
using `TrendPullback + ParSAR` on D1/H4/H1 timeframes, with the third strategy
disabled. The source is treated as a single local package lineage. No vendor or
inventory performance claim is imported into the card; the QM pipeline must
judge the mechanical port on Darwinex `XTIUSD.DWX`.

For this card, only the trend-pullback component is mechanized:

- D1 trend filter using EMA regime.
- H4 pullback/reclaim trigger in the D1 trend direction.
- ATR hard stop and deterministic time/trend invalidation exits.
- Darwinex MT5 OHLC only at runtime.

R1 note: the current Dropbox package is not hydrated in this session, so this
card is grounded in the previously committed local inventory rather than fresh
file reads. The lineage is intentionally narrow and auditable.
