# Intake receipt - QuantMechanica Implementation Package v1.0 (OWNER hand-over 2026-09-07 ~10:55Z)

- Source: `C:\Users\Administrator\Downloads\QuantMechanica_Implementation_Package_v1.0\QuantMechanica_Implementation_Package_v1.0` (OWNER + external design session).
- Manifest: `MANIFEST_SHA256.txt` verified against all 27 files at intake (sha256sum -c: 27 OK). Repo copy re-verified after copy.
- Repo copy: everything except `docs/*.docx` and `docs/*.pdf` (same content as the `.md`; binaries parked under `D:\QM\design\qm_implementation_package_v1.0\`).
- Status of the MQL5 sources in `mql5/`: **reference implementation from a foreign EA project** (`QuantRangePRO` -> `OHLC Daily Squeeze Reversal`, IFilter/IStrategy/TimeRangeBreakout architecture). They are NOT V5 framework code and are not installed anywhere. The reusable design contract lives in `QMDesignTokens.mqh`, `QMDashboardModel.mqh`, `QMStrategyConsole.mqh` and is ported into the V5 framework (`framework/include/QM/`) by the Astra ticket; the package's own pattern-filter cache correction is out of scope for QuantMechanica V5.
- Website: `website/quantmechanica-design-tokens.{css,json}` + `quantmechanica-components.css` are the cross-platform token source of truth (design guideline section 23).
- Binding OWNER instruction (2026-09-07): "Gib das alles an Astra zur Implementierung und Umsetzung (wieder am Test EA auf FTMO)" -> Strategy Console v4 on the QM5_11421 FTMO demo canary (artifact-only), website tokens on the local 8772 work copy (no deploy).
