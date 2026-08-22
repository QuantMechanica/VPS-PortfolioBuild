# Codex router build preflight — QM5_1457 data contract block

Date: 2026-08-22  
Role: Development / Codex  
Router task: `7ac78155-3ba3-4948-8bf9-ab5b451a0a3a` (`build_ea`, priority 50)  
EA: `QM5_1457_as-predict-bonds`  
Verdict: `PREBUILD_BLOCK_CARD_DATA_UNAVAILABLE`

## Outcome

The identity preflight passes: the exact G0-approved card, active EA-ID row, exact directory slug, and 13 active magic rows all exist. Implementation is nevertheless blocked by the approved card's own data contract.

The card frontmatter declares `r3_data_available: FAIL` and explains that IEF, BIL, DBC, the 10-year Treasury yield, and the 13-week Treasury yield have no listed or approved custom-symbol series in `framework/registry/dwx_symbol_matrix.csv`. Its body labels R3 `UNKNOWN` pending approved proxies. Its G0 reasoning likewise says R3 is pending. Those lifecycle statements are internally inconsistent with a build-ready card and do not authorize Development to substitute different mechanics.

The approved strategy trades intermediate-term US Treasuries against cash from a four-component monthly ensemble. Replacing its traded IEF leg and required yield/bond/cash/commodity inputs with the currently registered equity, FX, index, or gold symbols would change the approved strategy rather than implement it mechanically.

## Focused verification

| Check | Result |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1457_as-predict-bonds.md` |
| Card SHA-256 | `c07d5d9e8de3abeb5a910e298b3279d273490ad85f2e429c3a79bb1b18baaa21` |
| Card identity / G0 | exact `QM5_1457` / `as-predict-bonds`; `APPROVED` |
| Card R3 frontmatter | `FAIL` |
| Card R3 body / G0 reasoning | `UNKNOWN` / pending approved proxies |
| Canonical EA-ID row | 1 active exact-slug row |
| Canonical magic rows | 13 active exact-slug rows |
| Registered symbols | `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`, `XAUUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` |
| Required IEF/BIL/DBC/Treasury series in symbol matrix | none |
| Existing source | tracked auto-generated TODO skeleton; SHA-256 `4444789e25475af4040b8cfef1832763b19a8e110ad3a891314ff3e7e972a7ce` |
| EX5 / SPEC / setfiles | 0 / 0 / 0 |

Every registered row is itself present in the symbol matrix; the defect is not malformed registration. The registered universe simply cannot supply the card's required data or traded Treasury instrument.

The existing source also defaults both `RISK_PERCENT = 0.5` and `RISK_FIXED = 1000.0`; it remains an unimplemented historical skeleton and was not treated as a valid build. No source edit was attempted because the card/data gate precedes implementation.

## Deterministic boundary

V5 EAs may use only approved MT5-native/custom-symbol data, and the build skill permits only card-authorized mechanics. A proxy substitution here would be an unauthorized strategy redesign. Therefore build check, compile, setfile generation, and smoke were not run. This is not a compile or pipeline verdict.

No source, registry, resolver, news seed, terminal, pipeline row, `T_Live`, or AutoTrading state was changed.

## Required upstream remediation

OWNER/Research must choose one governed disposition before fresh routing:

1. approve and validate custom-symbol/proxy series for the traded Treasury leg plus every required component input, then normalize R3 and reapprove the exact card; or
2. approve a mechanically different DWX-native card with explicit substitution rules and a matching registered symbol universe; or
3. reject/retire this card as unavailable under the current data contract.

Registry allocation alone does not cure the card's R3 failure.
