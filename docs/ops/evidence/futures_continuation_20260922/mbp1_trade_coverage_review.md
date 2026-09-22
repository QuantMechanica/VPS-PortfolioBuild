# GLBX.MDP3 MBP-1 action-T coverage — bounded independent review

Reviewed 2026-09-22. **The schema choice is officially supported; exact equality of our June-2019 MES files to separately requested trades files is NOT established.** Documentation is sufficient to justify deriving trade signals from MBP-1 action `T`. It does not, by itself, certify a particular download, all original exchange traffic, or our filtered usable signal stream. No credentials, account API calls, metadata queries, market-data downloads, or purchases were made. Existing plan/code/data files were unchanged.

## What the official specification establishes

Databento describes MBP-1 as containing every trade in addition to top-of-book updates: “This includes every trade”. Its schema guide expressly says that Trades can be derived from MBP-1 and describes such client derivation as lossless. The separate Trades schema contains trade events with action `T`. Thus MBP-1 is not merely sampled BBO; filtering its `T` events is a documented trade-data route. [MBP-1](https://databento.com/docs/schemas-and-data-formats/mbp-1), [schema derivation](https://databento.com/docs/schemas-and-data-formats/whats-a-schema#deriving-one-schema-from-another), [Trades](https://databento.com/docs/schemas-and-data-formats/trades).

The GLBX supplement says MBP-n and Trades share Trade records normalized from CME Trade Summary messages; passive Fill details belong to MBO. Each trade summary produces one Trade record. Its MBOFD transition is dated 2017-05-21, so June 2019 is in that regime. No 2019-specific contrary coverage rule was found in the bounded review. This is current documentation read in 2026, not a contemporaneous 2019 service guarantee. The general schema guide mentions venue-specific exceptions; none was found here for GLBX trade coverage. [GLBX.MDP3](https://databento.com/docs/venues-and-datasets/glbx-mdp3).

The official issue board does document additional erroneous `F` records in historical MBP-1/10, with a January-2019 example; they follow a Trade and are not additional trades. That evidence supports selecting `T`, not adding `F` to repair a hypothetical omission. A separate channel-flush issue states that `T` actions remain correct even when adjacent trades are byte-identical. Do not silently deduplicate equal records. These issue descriptions do not prove that our MES files contain the reported defects. [Official issue board entry](https://issues.databento.com/b/6vrl98vl/feature-ideas/glbxmdp3-mbp-110-schemas-with-wrong-action-fill).

## Pinned decoder and local evidence

Installed Nautilus 1.221.0 `adapters/databento/loaders.py` defaults `include_trades=False`; the MBP-1 route must enable it when separate native TradeTicks are needed. The matching tagged Rust decoder emits an optional TradeTick precisely for `include_trades && action == 'T'`. This supports interpretation, not original market completeness. It also maps native `ts_event` to raw `ts_recv`; preserve the original exchange timestamp separately for exchange-minute bars. It does not apply our quality gate. [Pinned decoder](https://raw.githubusercontent.com/nautechsystems/nautilus_trader/v1.221.0/crates/adapters/databento/src/decode.rs).

The existing hash-bound full-scan receipt reports:

| Local file | All MBP-1 rows | Action-T rows | Flag 168 rows | Separate same-contract Trades file |
|---|---:|---:|---:|---|
| MESM9 | 13,111,990 | 710,439 | 10 | Absent in inspected directory |
| MESU9 | 9,545,391 | 548,292 | 9 | Absent in inspected directory |

These are report-derived counts, not a new scan or cross-schema comparison. No action-F rows appear in those recorded action histograms. The action and flag histograms are marginal counts; their totals alone do not establish a joint T/flag mapping. ESM9/ESU9 Trades files are different instruments and cannot validate MES completeness. Source: `june2019_data_validation.json`, SHA256 `1186b54f4cd4c10d5126deb428d8f5c7940ab937083d0fddf8f467aa4c847129`.

## Flags, snapshots and recovery are separate questions

Pinned DBN 0.43.0 and current documentation agree: bit 8 means inaccurate receive time; bit 32 identifies replay/snapshot provenance; bit 4 identifies a channel with an unrecoverable gap. Flag 168 combines LAST, SNAPSHOT and BAD_TS_RECV. None alone means “this row is an additional new trade”. Snapshot provenance also does not automatically make a price false. [Pinned flags](https://raw.githubusercontent.com/databento/dbn/v0.43.0/rust/dbn/src/flags.rs), [current flag definitions](https://databento.com/docs/standards-and-conventions/common-fields-enums-types#flags), [dependency pin](https://raw.githubusercontent.com/nautechsystems/nautilus_trader/v1.221.0/Cargo.lock).

Our exclusion of those flags for fresh execution/signal use is a conservative QM policy. A book snapshot can restore book state without proving recovery of each missing intermediate trade; matching two derived schemas would not reveal traffic absent from their common source. BAD_TS_RECV challenges chronology rather than establishing a missing-trade count. These are validation implications, not additional vendor guarantees. `F_LAST` is not a trade-selection condition: GLBX documentation says its event-boundary handling is already incorporated outside MBO. [GLBX normalization](https://databento.com/docs/venues-and-datasets/glbx-mdp3).

The current runner additionally rejects affected sessions for quality failures, and checks BBO quality on MES MBP-1 signal rows. Therefore its usable input is stricter than raw action-T coverage. A clean backtest subset must not be described as all trades from the whole downloaded period. This review does not relax those rules or change the frozen plan.

## What an exact comparison would establish

No redundant data purchase is required merely to justify this documented schema choice. If we instead want the stronger claim “these exact files reproduce the same Trades stream”, a same-contract comparison is required. Counts alone cannot prove it.

Proposed validation, not executed here:

1. Bind dataset, raw contract and instrument ID, publisher, DBN version, identical UTC `[start,end)` receive-time window, request settings and both file hashes. Compare before quality filtering; report filtered populations separately.
2. Stream every MBP-1 action-T row and every Trades row in original order. Preserve multiplicity and equal timestamps; do not sort or deduplicate. Compare publisher/instrument, raw exchange and receive timestamps, action, side, integer price, size, sequence and `ts_in_delta`. Count all differences and retain bounded examples. Inspect flags/depth separately; any normalization exception needs evidence before it is excluded from equivalence.
3. Record count plus an ordered canonical-record digest provides practical evidence of trade-content equality. Whole DBN file hashes cannot match: MBP-1 includes BBO fields, a different rtype and a different record length. A successful comparison only establishes equality for those exact files/windows, not zero omissions in the upstream exchange capture.

Disposition: **SCHEMA_SEMANTICS_SUPPORTED; EXACT_LOCAL_TRADE_EQUIVALENCE_NOT_TESTED; UPSTREAM_ZERO_LOSS_NOT_PROVEN.** Continue using documented action-T extraction within the existing diagnostic/quality bounds. Do not manufacture an additional mandatory purchase gate or a completeness PASS from documentation alone.
