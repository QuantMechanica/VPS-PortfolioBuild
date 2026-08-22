# T_Live set-file provenance — lineage and value-preserving repair plan

Date: 2026-08-23  
Task: `740049db-4a8c-48cd-b84f-449152897de1`  
Scope: diagnosis and repair design only

## Verdict

The defect is confirmed and remains **provenance-only**. The ten deployed
presets still carry the functional values described by the LIVE manifest;
nothing in this investigation changed T_Live, an EA binary, a chart, a risk
value, or AutoTrading.

The deployed bytes are not lost: each of the ten T_Live files is SHA256-equal
to its preserved `C:\QM\deploy\DXZ_FINAL_2026-07-19\presets` source. Nine of
those sources are exactly one `RISK_PERCENT` line different from their
preserved `DXZ24_2026-07-17` parents; QM5_13128 is byte-identical to its parent.
The final staging script and the file-copy implementation are not preserved,
however, so their implementation provenance is not reconstructable beyond the
staged bytes, reports, and committed deployment record.

The exact files were copied on **2026-07-19**, not 2026-07-24. The later
`portfolio_manifest_live_24sleeve_20260724.json` describes the same deployed
roster and risk vector; it is not evidence of another set-file copy. The
committed deployment record is
`decisions/2026-07-19_t_live_dxz_sunday_final_book.md`, commits
`0f7f29a2961235ab20f185a1ad03fbb158f448ef` (file-side deploy record) and
`f030327488d7616621a25b3b5c236a91d24d8fd6` (final verification).

## 1. Per-preset source proof

Common lineage for all ten continuing sleeves:

1. `C:\QM\deploy\DXZ24_2026-07-17\evidence\stage_dxz24.py:45-57`
   reads the preserved DXZ23 preset, replaces only `RISK_PERCENT`, and writes
   the DXZ24 preset. It does not inspect or normalise provenance headers.
   Preserved script SHA256:
   `db22287c9c6825bc96296bdfa754a30c527e051512246d620672e4a5de072efb`.
2. `C:\QM\deploy\DXZ_FINAL_2026-07-19\staging_report.json:2-156`
   records each continuing source and its old/new risk. The final staging
   script is absent. The later committed explanation explicitly says it was a
   session-local script that was never committed
   (`tools/strategy_farm/portfolio/stage_tlive_presets_risk.py:3-7`, commit
   `46b645bad5e457717931ca52caf9712ee2168e9b`).
3. The preserved final preset is byte-identical to the numbered T_Live preset.

`DXZ24 parent` below is under
`C:\QM\deploy\DXZ24_2026-07-17\presets\`; `final source` is under
`C:\QM\deploy\DXZ_FINAL_2026-07-19\presets\`.

| T_Live preset | final-source SHA256 | final staging-report rows | DXZ24 parent SHA256 and exact delta | matching framework live set on 2026-08-23 |
|---|---|---:|---|---|
| `15_NDX_H1_QM5_10440_mql5-ohlc-mtf.set` | `cc7c9e3ba36c65a4721335be5abbc1c88780adb38a53586155baf18c75c53769` | 11-15 | `14025c512fb01dbca61d3911cd24e8d4b5dbbbfd08231cfebcddfd108cd8be52`; line 19 `0.0584 -> 0.0577` | yes, generated 2026-08-21; bytes differ |
| `19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set` | `7d15a3491465b916e7e5a0f2ef36212f76f43fde6fc186586cde542431080408` | 18-22 | `4e1f6d61fd9b3662777e908d4e2383f73108274de3a14b56ee0a8e17f53a69a7`; line 19 `0.3081 -> 0.3050` | yes, generated 2026-08-21; bytes differ |
| `11_GBPUSD_H1_QM5_10706_tv-mon-ls.set` | `e807c3706ff0bedbdbbe17d6bf64df833cf247e7a14b910802c1ae3a432f6377` | 137-141 | `49511b496b3c18b3b2c02307fe8af5814c12d397e3f0c83553d79878c7401735`; line 19 `0.0536 -> 0.0530` | **no** |
| `13_GDAXI_H1_QM5_10911_grimes-complex-pb.set` | `6a503e2b60328bda8fdc9ed2900f14270e8a20c28302060ba6c012cccdbce8ec` | 25-29 | `4eee0d73c6fa317cdc3f7bcbdcc722558baa17533f3eaf5ca365c2738b321ab1`; line 19 `0.1289 -> 0.1276` | yes, generated 2026-08-21; bytes differ |
| `04_XTIUSD_H4_QM5_10919_grimes-overshoot.set` | `10cbf478dcb6e4900325b2fc24ece2a0ce61878f8908384b0fe96e0ea11f9199` | 32-36 | `3c72ab7d3bc96aee01f95d9ed9177de80ba0c915631ab8219f86d0d25b005e60`; line 19 `0.9277 -> 0.9181` | **no** |
| `12_GBPUSD_H4_QM5_10939_grimes-context-pb.set` | `4869e29a3a6d217d45ebb23be2e406a41780ad0c71c6588502e3f7507390e90a` | 39-43 | `93c6fb3d394e334a3ab8bce1f46553a799f4b9fbf897e9a5c25f8bd964b14400`; line 19 `0.1907 -> 0.1887` | yes, generated 2026-08-22; bytes differ |
| `16_SP500_D1_QM5_11132_tm-cum-rsi2.set` | `76a984f06f69c750e1bae264bb4854a263eda7cddffbf8a2ec95065dd092f94d` | 46-50 | `6cedca3bf36ca944941968842b19911ad8e3ea43bee38d81a12e7385abdc147d`; line 19 `0.4610 -> 0.4562` | yes, generated 2026-08-22; bytes differ |
| `23_XNGUSD_D1_QM5_12567_cum-rsi2-commodity.set` | `c7a3d43ff6c8fc6e84f5495e627aa584a1f4cccc85fc8feb97e96e7c67711551` | 95-99 | `7e040ee9b8ab85a0d218a86a4629be322f9fe966676079d8482a5c07c497e899`; line 19 `0.9899 -> 0.9797` | yes, generated 2026-08-22; bytes differ |
| `21_XAUUSD_H4_QM5_12989_grimes-nested-pb-v2.set` | `a04013c587a5967fb28eb807d36e4b3d5897cdbe0a20e96310570825696bdeb8` | 116-120 | `8839c3b920f0d40cb138aa7fd1f4afe957a0ab447cd2a642e018e1033664bd22`; line 21 `0.2445 -> 0.2420` | **no** |
| `14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set` | `3aa27e4b869a4f1e0dac25457d3c5056664613e58e3b41556b78a5db18549ffb` | 123-127 | same SHA256; zero changed lines (`1.0000 -> 1.0000`) | **no** |

The current repository therefore has matching-symbol `*_live.set` files for
six of the ten, not eight. The files for 10706 and 13128 are also absent; the
task's narrower statement about only 10919 and 12989 is not borne out by the
2026-08-23 tree. The six present files were generated on 2026-08-21/22 and are
not the source of the July deployment, so none may be substituted without the
value-preservation proof in section 4.

### Why the headers survived

The nine `pending` values were already present in the parent set files. The
continuing-sleeve path in `stage_dxz24.py:45-57` intentionally changed only
the risk line and never ran a provenance-header normaliser. The preserved
final-stage bytes and report show that the next staging pass again changed
only that line (or no line for 13128). For 10919 the same inheritance preserved
the `environment: backtest` and `risk_mode: FIXED` comments as well as its old
64-hex hash. These are comments; its runtime keys are still `RISK_FIXED=0` and
`RISK_PERCENT=0.9181`.

## 2. How the 12989 marker reached T_Live

The marker's origin is fully reconstructable:

- `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\compute_d2d_composite.py:482-516`
  declares task `106ed489-5914-497b-9ca0-9986372ec8d0` and emits both
  `DRAFT_ONLY` and `DO_NOT_COPY_TO_T_LIVE_WITHOUT_SIGNED_OWNER_MANIFEST`.
  Script SHA256:
  `ea3f6477c76623d27c7fab3101713193eb814100c42fc90012ffa3a53cc92447`.
- The exact generated `staged_s3_live_presets` file has SHA256
  `cc71bbd52f9781681ab400513f816e61442dcd94c402998da7bef863df21e3f2`.
  The same bytes survive in the D2d S3 pre-Sunday backup. Later S4, DXZ23,
  DXZ24, and DXZ-final stages changed risk/header bytes but retained both
  guard lines.
- The specific propagation defect is
  `C:\QM\deploy\DXZ24_2026-07-17\evidence\stage_dxz24.py:45-57`: it copies
  every continuing preset and validates only that one risk replacement worked;
  no marker predicate exists.
- The final staging implementation is **not reconstructable**. Its surviving
  report and the 0/1-line byte comparisons prove its result, but not its code.
  `tools/strategy_farm/portfolio/stage_tlive_presets_risk.py:3-7` is the
  committed contemporaneous admission that the 2026-07-19 generator was
  session-local and never committed.
- The durable file-side deploy path is recorded at
  `decisions/2026-07-19_t_live_dxz_sunday_final_book.md:86-91`: all 24 files
  were copied from `DXZ_FINAL_2026-07-19` to T_Live and the post-copy checks
  covered SHA, count, `RISK_FIXED`, magic, and total risk. The corresponding
  `C:\QM\deploy\DXZ_FINAL_2026-07-19\evidence\deploy_report.json:1-25`
  contains no marker/header check. The actual copy script is absent, so it
  cannot truthfully be named; the committed record and report are the exact
  surviving file-and-line evidence of the deploy path that ignored the marker.

In short, the marker was not bypassed by a parser decision. No parser existed
at any of the three boundaries: continuing-sleeve staging, final staging, or
file-side copy.

## 3. Build-hash source to use in a repair

For live presets, the only useful provenance binding is the exact binary being
loaded. This is also the precedent in
`stage_dxz24.py:80-95`: it hashes the `.ex5` and writes that SHA to the live
preset header. The current T_Live binary must be re-hashed immediately before
staging and again immediately before any copy. The read-only 2026-08-23
snapshot is:

| EA | current T_Live `.ex5` SHA256 |
|---:|---|
| 10440 | `b71d302997ecdb661f1627e12b9e5e766e9679c780461b82fa018db7f2078a6a` |
| 10513 | `04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898` |
| 10706 | `01e34b2059de6ed505d445ce9fcbac7da0eb10d51e5cbcbbd18d38a968916078` |
| 10911 | `a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158` |
| 10919 | `57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691` |
| 10939 | `308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac` |
| 11132 | `25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152` |
| 12567 | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` |
| 12989 | `7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2` |
| 13128 | `364867a9fe8d58478ade5526aad19deb377a35b313cfdac29763bb2eb82d273b` |

Several binaries were updated on 2026-07-31, so a July staging hash must not be
assumed to describe the binary now present.

There is a generator prerequisite: the current
`framework/scripts/gen_setfile.ps1` has no `BuildHash` parameter
(`:1-15`), always emits `build_hash: pending` (`:481-505`), and rewrites the
whole file (`:507-550`). Running it unchanged would recreate the defect and can
also change runtime inputs. `build_check.ps1:384-420` stamps a hash of normalised
set-file text, not the deployed `.ex5`; that is not a binary provenance binding.

## 4. OWNER-gated, value-preserving regeneration plan

Do not execute this plan until OWNER explicitly confirms option (a), the live
risk freeze permits the operation, and a bounded deploy window is recorded.

1. Snapshot and hash the ten T_Live presets, all ten T_Live binaries, the LIVE
   manifest, and the unsigned pointer. Refuse if any preset hash differs from
   section 1 or if any roster/risk value differs from the LIVE manifest.
2. In a disposable checkout, first extend `gen_setfile.ps1` with a reviewed
   **provenance-only template mode** and a mandatory, 64-lowercase-hex
   `BuildHash` argument. Template mode must preserve the input file's raw bytes
   and may edit only an explicit header allowlist. It must never write T_Live.
   Ordinary generation retains its existing behaviour.
3. Generate each candidate into a new staging directory from the exact deployed
   preset as template, with the identity tuple from that preset and
   `Env=live`, `RiskFixed=0`, the exact existing `RiskPercent`, the exact
   existing `PortfolioWeight`, and the freshly measured T_Live `.ex5` SHA.
4. Header changes are limited to:
   `environment=live`, `risk_mode=PERCENT`, `build_hash=<deployed-ex5-sha>`,
   a new provenance-repair `set_version`, `author`, and `date`. For 12989 only,
   remove the two draft/do-not-copy lines; for no other file may a line be
   deleted. Identity headers (`ea_id`, slug, symbol, timeframe, magic slot,
   portfolio weight) remain byte-identical.
5. Perform a binary diff, not merely a parsed-value comparison. Record the
   byte offsets and old/new bytes for every changed span. Reject unless every
   span is one of the header changes in step 4. BOM, encoding, newline style,
   line order, every comment outside that allowlist, and the complete runtime
   assignment block must be byte-identical.
6. Independently parse both sides with a duplicate-aware parser. Require the
   ordered multimap of **every non-comment `key=value` assignment** to be equal,
   which is stricter than the requested subset. Emit explicit equality proofs
   for `RISK_PERCENT`, `RISK_FIXED`, `PORTFOLIO_WEIGHT`,
   `qm_magic_slot_offset`, and the full ordered set of every `qm_filter_*`
   key/value. Empty `qm_filter_*` sets (currently 13128) compare as empty to
   empty. Also require the 24-sleeve total to remain `9.7499` and all 24 risks
   to match the LIVE manifest to four decimals.
7. Run the live-preset guard from section 5 on the entire staged set as one
   transaction. Re-hash the ten live binaries and source presets; any race or
   mismatch aborts before the first copy.
8. After a separately authorised file-side deploy, re-read T_Live and require
   staged-to-live SHA equality for 10/10, unchanged hashes for the other 14,
   unchanged 24-sleeve runtime assignments/risk vector, and no forbidden
   marker. Archive the original ten bytes with their section-1 hashes. Do not
   touch AutoTrading.

If template mode or any byte-diff assertion fails, the outcome is **HOLD**, not
a best-effort rewrite. In particular, the six newer framework live files are
references only; they are not safe replacement bytes.

## 5. Fail-closed guard design

Add one reusable validator, for example
`tools/strategy_farm/portfolio/live_preset_guard.py`, and make the future
committed T_Live deploy command call it over the complete batch before any
archive/copy operation. Staging tools may call it too, but staging validation
does not replace the deploy-boundary check.

For every `.set`, refuse on unreadable/non-UTF-8 bytes, duplicate required
headers or runtime keys, identity/manifest mismatch, missing header, or any of:

- a case-insensitive `DRAFT_ONLY` or `DO_NOT_COPY_TO_T_LIVE` token anywhere;
- `build_hash` absent, `pending`, or not exactly `[0-9a-f]{64}`;
- `environment != live` or `risk_mode != PERCENT`;
- `RISK_FIXED != 0`, non-positive/mismatched `RISK_PERCENT`, absent
  `PORTFOLIO_WEIGHT`, or registry-inconsistent `qm_magic_slot_offset`;
- a build hash different from the SHA256 of the exact companion `.ex5` selected
  for the same deploy transaction.

The command validates all source bytes and all destinations first, writes a
plan containing source/destination hashes, then copies atomically. Any missing
state, unreadable file, changed source hash, extra preset, or partial batch
aborts with zero destination writes. A raw operator `Copy-Item` cannot be made
safe by a Python predicate; the runbook must prohibit it and filesystem policy
should restrict T_Live writes to the guarded deploy command.

Minimum negative tests:

1. The exact preserved 12989 file, even after replacing `pending` with a valid
   hash, is rejected for both marker tokens and the temp destination remains
   empty.
2. A marker-free fixture with `build_hash: pending` is rejected.
3. A valid-hash fixture with `environment: backtest` is rejected.
4. Missing/unreadable input, duplicate header, wrong binary hash, and a batch
   containing one bad file each produce zero writes.

Positive test: a temp-only batch with valid live headers, exact binary hashes,
manifest/registry-consistent identities, `RISK_FIXED=0`, and preserved runtime
assignments is accepted and copied byte-for-byte. No test points at T_Live.

## 6. Focused read-only verification performed

- SHA256 compared each of the ten numbered T_Live files with its unique
  DXZ-final staged source: **10/10 exact**.
- Line-by-line comparison of DXZ24 parent to DXZ-final source: **nine files
  have exactly one changed line (`RISK_PERCENT`); 13128 has zero**.
- Runtime audit of the ten: `RISK_FIXED=0` on 10/10, positive
  `RISK_PERCENT` on 10/10, `PORTFOLIO_WEIGHT` present on 10/10, and the
  recorded magic-slot offsets are `3,3,1,3,1,1,0,2,3,0` for EAs
  `10440,10513,10706,10911,10919,10939,11132,12567,12989,13128`.
- Framework target-live-set discovery: present for 10440, 10513, 10911,
  10939, 11132, and 12567; absent for 10706, 10919, 12989, and 13128.
- T_Live `.ex5` discovery found exactly one companion binary for each of the
  ten and recorded the SHA256 values in section 3.
- No terminal process was started or interrupted. T_Live and AutoTrading were
  not touched.

The pointer must remain unsigned until an OWNER-authorised repair is deployed
and independently verified.
