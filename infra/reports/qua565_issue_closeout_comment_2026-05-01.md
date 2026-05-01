QUA-565 closeout complete.

Commits:
- `0d3e3ead` - Operating model schema/json + export wiring + stale data documentation
- `730666bf` - Public payload validator (required sections + safety checks)
- `d682c972` - Infra README documentation for validator
- `99492341` - Closeout evidence report in `infra/reports/`

Acceptance check:
1. Menu/dashboard discovery from JSON: PASS
2. Stale-data behavior documented: PASS
3. Schema validation passes: PASS
4. Public-safe language boundary: PASS
