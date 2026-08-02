# MNT-043 vintage-bill apply preparation

- Date: 2026-08-02
- Branch: agents/board-advisor
- Bill: docs/ops/evidence/2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json
- Verified bill SHA-256: 1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1
- Source pin: 386151841013afbaf01fe10b23e6cf7538480b71
- Preparation outcome: PASS; no terminal was started, T_Live was not contacted, the farm DB was opened read-only only, and the real overlay was not written.

## Staged-binary adoption

Each staged EX5 was verified against the bill before copying, each repo-tree destination matched the bill's historical hash before copying, and each destination was re-hashed after copying. No MQ5 was touched.

| EA | Repo-tree EX5 | Historical SHA-256 | Adopted SHA-256 |
|---|---|---|---|
| QM5_10911 | framework/EAs/QM5_10911_grimes-complex-pb/QM5_10911_grimes-complex-pb.ex5 | 2a1760492156fba9557ee3844131bf01dbe3c446b9c420fd0be7e2fbb4a34cd8 | a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158 |
| QM5_10919 | framework/EAs/QM5_10919_grimes-overshoot/QM5_10919_grimes-overshoot.ex5 | 9258fe631ec29d8af9b63d9aceb5306b3164608481ad67a3f00e52aa2d7c7e31 | 57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691 |
| QM5_10939 | framework/EAs/QM5_10939_grimes-context-pb/QM5_10939_grimes-context-pb.ex5 | 0c1278f5d44d0c88db90f632d0cefacda79b6c8853bde9540676c4c95296edd0 | 308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac |
| QM5_11132 | framework/EAs/QM5_11132_tm-cum-rsi2/QM5_11132_tm-cum-rsi2.ex5 | 7fe65d4c86d8cf0fc6ff17f9dc9d3b7dc794802d8457dab96e40d4df34383555 | 25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152 |
| QM5_11421 | framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.ex5 | 03455d533ffbf1cc35482dc8de487b04d997bea328ee8505d0f5bb0d591a7415 | 0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7 |
| QM5_12567 | framework/EAs/QM5_12567_cum-rsi2-commodity/QM5_12567_cum-rsi2-commodity.ex5 | 353dddbb93c393dc4135d03f84ba203b6f8ab657ce5ebb5b14cb9f6d44893c85 | 5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9 |
| QM5_12989 | framework/EAs/QM5_12989_grimes-nested-pb-v2/QM5_12989_grimes-nested-pb-v2.ex5 | 27b9dc294fd6b0d25825bcf91e4ef08f832cc79fe7414ce84e215570c5d26e1e | 7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2 |

- Adoption commit: 310a0bb126eba416714b67446ad3f10744164c33
- Commit subject: mnt043: adopt staged 386151841 binaries for admission requalification

## Bill-bound tool contract

- Tool: tools/strategy_farm/apply_ks_vintage_bill.py
- Tool commit: a6e89abf60969f78b2e2423e3fe5f61db0c80e01
- Tool file SHA-256: 7420d4f966ec82fe25853e551b8af999facc4d9c0df51dcb9c78854bd0a1f842

The tool:

- hard-binds the only accepted expected bill hash to 1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1;
- requires schema qm.mnt043_044.recompile_vintage_bill.proposed.v1, the exact status PREPARED_NOT_APPENDED_PENDING_CLAUDE_REVIEW_AND_STAGED_BINARY_ADOPTION, source pin 386151841013afbaf01fe10b23e6cf7538480b71, exactly 26 events and seven replacements, and all four bill trailer flags exactly false;
- opens SQLite through mnt_closure_drift.open_db_read_only and recomputes every row hash as canonical_sha256(mnt_closure_drift.work_item_snapshot(row)); all 26 rows must still exist as done/PASS with matching phase, EA, symbol, and raw-row hash;
- resolves one repo-tree EX5 for each replacement and requires its current hash to equal the bill's new_ex5_sha256;
- imports and runs mnt_closure_drift.validate_overlay_chain, hard-requires the 13-event pre-apply population, and binds the caller-supplied full overlay file SHA-256 and tail event SHA-256;
- creates exactly 26 deterministic candidate event IDs and standard overlay events carrying the bill hash, row hash, original verdict, adopted EX5 hash, reviewer, EVIDENCE_VINTAGE_STALE status, and BINARY_VINTAGE_MISMATCH reason;
- defaults to dry-run and creates no lock, receipt, DB mutation, or overlay write;
- in apply mode, requires the create-only receipt path and all expected hashes, re-verifies under the create-only overlay .lock sidecar, appends sorted chained records with flush/fsync after every line, validates the resulting chain and bytes, re-verifies DB rows and adopted binaries, and creates the receipt with O_EXCL semantics.

## Test and compile evidence

Command:

~~~text
python -m py_compile tools/strategy_farm/apply_ks_vintage_bill.py tools/strategy_farm/tests/test_apply_ks_vintage_bill.py
~~~

Exit code 0; no stdout or stderr.

Command and verbatim output:

~~~text
python -m pytest tools/strategy_farm/tests/test_apply_ks_vintage_bill.py -q
.......                                                                  [100%]
7 passed in 0.78s
~~~

Coverage includes dry-run success/zero-write, wrong bill hash, tampered raw row, missing adopted binary, 26-event chained apply with post-validation, second-apply tail refusal, and create-only receipt refusal.

## Real dry-run

Command:

~~~text
python tools/strategy_farm/apply_ks_vintage_bill.py --dry-run --bill docs/ops/evidence/2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json --expected-bill-sha256 1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1 --db D:/QM/strategy_farm/state/farm_state.sqlite --repo-root C:/QM/repo --overlay D:/QM/reports/maintenance/mnt_adjudication_overlay.jsonl --expected-overlay-sha256 f3b3a11877689a4a81848f764f26623c1f778dc615a8e8f1e817a835fde9621c --expected-tail-event-sha256 0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6 --reviewer claude:MNT-043 --observed-at-utc 2026-08-02T09:05:00+00:00
~~~

Verbatim output:

~~~json
{
  "adopted_binaries_verified": [
    {
      "ea_id": "QM5_10911",
      "new_ex5_sha256": "a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_10911_grimes-complex-pb\\QM5_10911_grimes-complex-pb.ex5"
    },
    {
      "ea_id": "QM5_10919",
      "new_ex5_sha256": "57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_10919_grimes-overshoot\\QM5_10919_grimes-overshoot.ex5"
    },
    {
      "ea_id": "QM5_10939",
      "new_ex5_sha256": "308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_10939_grimes-context-pb\\QM5_10939_grimes-context-pb.ex5"
    },
    {
      "ea_id": "QM5_11132",
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_11132_tm-cum-rsi2\\QM5_11132_tm-cum-rsi2.ex5"
    },
    {
      "ea_id": "QM5_11421",
      "new_ex5_sha256": "0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_11421_ohlc-daily-squeeze-reversal-d1\\QM5_11421_ohlc-daily-squeeze-reversal-d1.ex5"
    },
    {
      "ea_id": "QM5_12567",
      "new_ex5_sha256": "5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_12567_cum-rsi2-commodity\\QM5_12567_cum-rsi2-commodity.ex5"
    },
    {
      "ea_id": "QM5_12989",
      "new_ex5_sha256": "7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2",
      "repo_ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_12989_grimes-nested-pb-v2\\QM5_12989_grimes-nested-pb-v2.ex5"
    }
  ],
  "apply_tool_path": "C:\\QM\\repo\\tools\\strategy_farm\\apply_ks_vintage_bill.py",
  "apply_tool_sha256": "7420d4f966ec82fe25853e551b8af999facc4d9c0df51dcb9c78854bd0a1f842",
  "bill_path": "docs\\ops\\evidence\\2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json",
  "bill_sha256": "1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1",
  "bill_status": "PREPARED_NOT_APPENDED_PENDING_CLAUDE_REVIEW_AND_STAGED_BINARY_ADOPTION",
  "candidate_event_ids": [
    "03635c480ac10e3b6c63a9e34a238ad6f6dd5ef8639e04925db2ff4a5ae1986f",
    "088daadfc007b37a1ae5f230913e485b8f05c9434517808c8a5745ad899bac0d",
    "0cc58e97ee0cbb568ccf12472fb6fdd075d6ffea49e54387adf5b8264a4ee735",
    "1d85d1817c5e7387b6f8ac13be0d4bf20e0d1e10975daefdde7263b8a59b0b13",
    "28cd19c14ac964159c6b35a6e2919813bd3fb0cc6cc1594b96ddac16a1c4dbea",
    "2b467e9a8539a475196711df9df2fab77474554e2f7676fb9e017bf2742a0849",
    "32e91afdb1fd9569af4016954c673db9dd0e2cfbee58e79a9d0867cb7449b0cc",
    "3bce5f12a54f283e593a8e2eda3b0c2e33dbbe4430b6e32fb95b0302ffbed1ed",
    "62a19efcb288e569d7bcc2805f37118e2746ee2c3dba24241da4b24d53b40417",
    "635accfe3346288be45438eeb4208364e50f96b512857d5a488e25bf8e00e19d",
    "72255a81d62da401418af7e7676b18028b21374f60581d0906350bd3ab496046",
    "73b9e009d0d6d463f49b8ae08a3c41c2cce5cdfacccdb4c0a9b86e758bc6bf82",
    "79312ad46b31fa0b59755d6e041396580bec58d3bc219ac1eec4f9e4f202aa5a",
    "b5e8253f7be6f1aea8d340e560e1f75fb78f8464640e15c4d8ea4bc0a768d03b",
    "b6852a23684cfc404ffced4cd4f447418336c3f10bfe13e9fa382b7a46cc8b05",
    "bb9becac2db57011f22b62a488772f2cd70cf811a5a779e9cce5657b13456960",
    "be5696d6c49d772b946f28eaf98b8361c009642648357d7b18df2b2ad2dd5cd4",
    "ca521b0d4d38737fefdc563d53517803a98bea6d87c6c3ab90b5c6c852ac0ce6",
    "d2242dad7e962bd21845b8c4beafcbd089312dff51df51897fc04859afdfc95b",
    "d348139e64d1d889b04561b4a42267d0631eaed688e35584222b2e50cfb7dbf4",
    "d6a01ef3ea111a2372aebe0174f1f36e447f27cac07d572b498d51effd40dfc4",
    "db534a0faa7cb3f57ac04627314b1494c2b2ed9dc17f5b88976bbf209e718558",
    "e0fa15f40811a74505b5c46117dac838dcf75bce847c8851ff787ac4f4924861",
    "e1859d1e2e04d803db0385f052d8e5031fd2faffc34f7962a7f74b08631cbff1",
    "e95ff9d8cef9cf39926a339ce900ba76f6bcf3a82eebca8560dc9f1fee6cf039",
    "f5c57bff5843d5e285199c12e01531e7d0c9f3f80b61f56f5031b976fb7c370b"
  ],
  "database": "D:\\QM\\strategy_farm\\state\\farm_state.sqlite",
  "database_open_mode": "ro/query_only",
  "database_rows_verified": 26,
  "observed_at_utc": "2026-08-02T09:05:00+00:00",
  "overlay": {
    "before_bytes": 26676,
    "before_bytes_sha256": "f3b3a11877689a4a81848f764f26623c1f778dc615a8e8f1e817a835fde9621c",
    "before_event_count": 13,
    "before_tail_event_sha256": "0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6",
    "chain_validation": "PASS",
    "path": "D:\\QM\\reports\\maintenance\\mnt_adjudication_overlay.jsonl",
    "planned_after_bytes": 70237,
    "planned_after_bytes_sha256": "49d56972c2a765a3b57e961eaa65e02c40b08099c60b1bcf21dbfad20b780cae",
    "planned_after_event_count": 39,
    "planned_after_tail_event_sha256": "713ac5c0e618532c0841ad1a8cb94522a9166f6e5f37674310679181b4159678",
    "planned_append_count": 26
  },
  "overlay_writes": 0,
  "raw_work_item_mutations": 0,
  "receipt_writes": 0,
  "repo_root": "C:\\QM\\repo",
  "reviewer": "claude:MNT-043",
  "rows": [
    {
      "ea_id": "QM5_11421",
      "event_id": "03635c480ac10e3b6c63a9e34a238ad6f6dd5ef8639e04925db2ff4a5ae1986f",
      "event_sha256": "fe2242295dd7845b683a40405f5a992c62fa959ce8cba3e11d293e906ab0c95c",
      "line_number": 14,
      "new_ex5_sha256": "0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7",
      "phase": "Q07",
      "previous_event_sha256": "0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6",
      "raw_row_sha256": "0bdf0a3f4ab95e0bc471cd48526674183a29733a1e5c93c8073423b0002b9e66",
      "symbol": "AUDUSD.DWX",
      "work_item_id": "b77d915a-d9be-4a51-bdf4-c6c186caded9"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "088daadfc007b37a1ae5f230913e485b8f05c9434517808c8a5745ad899bac0d",
      "event_sha256": "b2f8f398b39b8745104686f6ce8482ebe8ef1110efd06f0711911466a81cdce5",
      "line_number": 15,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q07",
      "previous_event_sha256": "fe2242295dd7845b683a40405f5a992c62fa959ce8cba3e11d293e906ab0c95c",
      "raw_row_sha256": "ec0b8c395929bdf361656b2c53718934992a8286330970812df15b46b5d8684f",
      "symbol": "NDX.DWX",
      "work_item_id": "9275f769-2c6d-4cfd-a598-40cf68921c0d"
    },
    {
      "ea_id": "QM5_12567",
      "event_id": "0cc58e97ee0cbb568ccf12472fb6fdd075d6ffea49e54387adf5b8264a4ee735",
      "event_sha256": "e87d1a79a8098ab62e157ee4edb7267cd195dfb44c8ef2d0c0bc492a7bb9d645",
      "line_number": 16,
      "new_ex5_sha256": "5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9",
      "phase": "Q06",
      "previous_event_sha256": "b2f8f398b39b8745104686f6ce8482ebe8ef1110efd06f0711911466a81cdce5",
      "raw_row_sha256": "03a1d0ade55307680d9635e2d3dec230f494f7ea6550b2d313f2f4d01ba7cf7c",
      "symbol": "XAUUSD.DWX",
      "work_item_id": "5cdcd811-723f-4a98-a0f1-2a02bea2bff5"
    },
    {
      "ea_id": "QM5_10919",
      "event_id": "1d85d1817c5e7387b6f8ac13be0d4bf20e0d1e10975daefdde7263b8a59b0b13",
      "event_sha256": "b9ba2d56a2cf397aa0e35d72e92ce6c405bd17c75bfd6636ef62a7173c765be2",
      "line_number": 17,
      "new_ex5_sha256": "57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691",
      "phase": "Q07",
      "previous_event_sha256": "e87d1a79a8098ab62e157ee4edb7267cd195dfb44c8ef2d0c0bc492a7bb9d645",
      "raw_row_sha256": "1ac18a9d49496d51e072e239ab0ba65f4dd28d189efa60b6e64b9cf0dfba2bf9",
      "symbol": "XTIUSD.DWX",
      "work_item_id": "b0a43323-8520-4afd-b4b3-c59503645dee"
    },
    {
      "ea_id": "QM5_11421",
      "event_id": "28cd19c14ac964159c6b35a6e2919813bd3fb0cc6cc1594b96ddac16a1c4dbea",
      "event_sha256": "6a0fb78447f02a5e10c5399ad9b672c62e4d366e2027abd3465f4349aa3c7d4a",
      "line_number": 18,
      "new_ex5_sha256": "0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7",
      "phase": "Q07",
      "previous_event_sha256": "b9ba2d56a2cf397aa0e35d72e92ce6c405bd17c75bfd6636ef62a7173c765be2",
      "raw_row_sha256": "7a6de592d1bfbbec7d1a4e1337ee1daaea83b1cdda402e6d0b46c37ea719c20d",
      "symbol": "EURUSD.DWX",
      "work_item_id": "0d1cb1a3-7a0f-497a-bfb2-4640d37a7962"
    },
    {
      "ea_id": "QM5_10911",
      "event_id": "2b467e9a8539a475196711df9df2fab77474554e2f7676fb9e017bf2742a0849",
      "event_sha256": "3e25a141faa8836887819e9e40f53481e9e65eb77fa466d0516439cd0409cdd6",
      "line_number": 19,
      "new_ex5_sha256": "a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158",
      "phase": "Q07",
      "previous_event_sha256": "6a0fb78447f02a5e10c5399ad9b672c62e4d366e2027abd3465f4349aa3c7d4a",
      "raw_row_sha256": "2c38e2b3fc868d148f0d8055e395453ac3d34d16d10b810111f99098856cea11",
      "symbol": "GDAXI.DWX",
      "work_item_id": "ba34fb1f-2b3b-4ab4-b511-096000fbb8a8"
    },
    {
      "ea_id": "QM5_10939",
      "event_id": "32e91afdb1fd9569af4016954c673db9dd0e2cfbee58e79a9d0867cb7449b0cc",
      "event_sha256": "12172aa2366d51cd80f07452c09c754524764d7c7b963de7cbf56a16d8fe69c3",
      "line_number": 20,
      "new_ex5_sha256": "308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac",
      "phase": "Q07",
      "previous_event_sha256": "3e25a141faa8836887819e9e40f53481e9e65eb77fa466d0516439cd0409cdd6",
      "raw_row_sha256": "fd0c3db4762ef19b252dfc15f8ba3fa5dc43cb8805c0ffcae7b9c23e7ad61409",
      "symbol": "GBPUSD.DWX",
      "work_item_id": "2a77e549-58c7-4b18-b502-40f64f73e1fb"
    },
    {
      "ea_id": "QM5_12989",
      "event_id": "3bce5f12a54f283e593a8e2eda3b0c2e33dbbe4430b6e32fb95b0302ffbed1ed",
      "event_sha256": "e0ae20fbd8f7fec461f57644eaad30daf82008c760c956a549b8608b9ec25944",
      "line_number": 21,
      "new_ex5_sha256": "7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2",
      "phase": "Q06",
      "previous_event_sha256": "12172aa2366d51cd80f07452c09c754524764d7c7b963de7cbf56a16d8fe69c3",
      "raw_row_sha256": "acfc2cf41707b4f405f76c8ecb3fca488107df428aa46768294f719fcfa34bd7",
      "symbol": "XAUUSD.DWX",
      "work_item_id": "209795ab-859f-4aaf-a426-97627e317f6e"
    },
    {
      "ea_id": "QM5_12567",
      "event_id": "62a19efcb288e569d7bcc2805f37118e2746ee2c3dba24241da4b24d53b40417",
      "event_sha256": "b36b20ff126b652204e42dccb43d89d4de1a8432bb71fb32fdd323e43cae157b",
      "line_number": 22,
      "new_ex5_sha256": "5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9",
      "phase": "Q06",
      "previous_event_sha256": "e0ae20fbd8f7fec461f57644eaad30daf82008c760c956a549b8608b9ec25944",
      "raw_row_sha256": "672c068a97e071d175630340642006213714996e524169efef986b8c94e3c456",
      "symbol": "XNGUSD.DWX",
      "work_item_id": "5c3b1d27-3d69-4863-843d-5182b3e8983d"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "635accfe3346288be45438eeb4208364e50f96b512857d5a488e25bf8e00e19d",
      "event_sha256": "078e1f88bc36e77e8fd9cf60dbeedbafa16c8dbb6e99594728169692b7732c60",
      "line_number": 23,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q06",
      "previous_event_sha256": "b36b20ff126b652204e42dccb43d89d4de1a8432bb71fb32fdd323e43cae157b",
      "raw_row_sha256": "a8dadefe51e20c0fa4cf4928f1df70561633cc3c03cd822de5d732e28478fe39",
      "symbol": "SP500.DWX",
      "work_item_id": "eb23ab22-d01b-441b-addf-ffdf6d12293b"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "72255a81d62da401418af7e7676b18028b21374f60581d0906350bd3ab496046",
      "event_sha256": "711d5544d8a82f882081fd4646b0c82b89e085a4e14ffa3f2b841bdcea063e4d",
      "line_number": 24,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q07",
      "previous_event_sha256": "078e1f88bc36e77e8fd9cf60dbeedbafa16c8dbb6e99594728169692b7732c60",
      "raw_row_sha256": "1b42c0b82787743f26f190233acdb484059cf3b2e5429fa227f383cbdc482b92",
      "symbol": "SP500.DWX",
      "work_item_id": "cbb145d8-4341-4f00-b0f8-13d9ca162109"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "73b9e009d0d6d463f49b8ae08a3c41c2cce5cdfacccdb4c0a9b86e758bc6bf82",
      "event_sha256": "ca89df3d7c7706829a43100bdefa4ff418648977d07586a5c15ba04de062a74d",
      "line_number": 25,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q06",
      "previous_event_sha256": "711d5544d8a82f882081fd4646b0c82b89e085a4e14ffa3f2b841bdcea063e4d",
      "raw_row_sha256": "2db3c9dee6876a48ae0e73c0d9202d9babfacfbee4064f6dd8523b69facc8ce6",
      "symbol": "SP500.DWX",
      "work_item_id": "8e3aa6c8-32de-4ede-9dd2-ee535e6f97a6"
    },
    {
      "ea_id": "QM5_12567",
      "event_id": "79312ad46b31fa0b59755d6e041396580bec58d3bc219ac1eec4f9e4f202aa5a",
      "event_sha256": "33c1d7d527e6137d08791d4ebb8a3ee89f6d11ba776fc4b056c58adf3679d842",
      "line_number": 26,
      "new_ex5_sha256": "5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9",
      "phase": "Q07",
      "previous_event_sha256": "ca89df3d7c7706829a43100bdefa4ff418648977d07586a5c15ba04de062a74d",
      "raw_row_sha256": "65d4a9ad94c80373ecdc944a7970aee3d2dad1dcdbe0e3a1c13ef085e2570445",
      "symbol": "XNGUSD.DWX",
      "work_item_id": "f9452af6-d356-4856-afdb-d45cf863c625"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "b5e8253f7be6f1aea8d340e560e1f75fb78f8464640e15c4d8ea4bc0a768d03b",
      "event_sha256": "6f2098bc7d8aac1118851a7bdbdd2bfea3b13aa23e3e5002c0de909276d5dc06",
      "line_number": 27,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q06",
      "previous_event_sha256": "33c1d7d527e6137d08791d4ebb8a3ee89f6d11ba776fc4b056c58adf3679d842",
      "raw_row_sha256": "31cc43f47056ab2b8fb8e358b5d0fde7cd51c2723d2c66ff0100e84ce8ea041f",
      "symbol": "NDX.DWX",
      "work_item_id": "fedb56a2-1a79-457d-b3ac-2c474b86fb64"
    },
    {
      "ea_id": "QM5_10919",
      "event_id": "b6852a23684cfc404ffced4cd4f447418336c3f10bfe13e9fa382b7a46cc8b05",
      "event_sha256": "d3f4ecbfae0e79d249ed1fbb79cf1d185ddd49d57e5d2bbbcafbcc8cf6539d49",
      "line_number": 28,
      "new_ex5_sha256": "57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691",
      "phase": "Q06",
      "previous_event_sha256": "6f2098bc7d8aac1118851a7bdbdd2bfea3b13aa23e3e5002c0de909276d5dc06",
      "raw_row_sha256": "7361e19244ce51f56a40385a25204d48851bd348607fc29c0727cfb7cb29f9fb",
      "symbol": "XTIUSD.DWX",
      "work_item_id": "96bdad0e-ebec-4d4d-9375-14597ec509ec"
    },
    {
      "ea_id": "QM5_11421",
      "event_id": "bb9becac2db57011f22b62a488772f2cd70cf811a5a779e9cce5657b13456960",
      "event_sha256": "96913c2c0da71b275dc767d80676c042d9aa6b9b08ac2bc8e201a056d314b28d",
      "line_number": 29,
      "new_ex5_sha256": "0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7",
      "phase": "Q06",
      "previous_event_sha256": "d3f4ecbfae0e79d249ed1fbb79cf1d185ddd49d57e5d2bbbcafbcc8cf6539d49",
      "raw_row_sha256": "3fdd3fc1bff4dc0f942af2d08fed8465c5b46cf60ac295be43b9f8b5f5cbe8f4",
      "symbol": "EURUSD.DWX",
      "work_item_id": "84caa901-4c50-4553-b427-d6ee48a0ca18"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "be5696d6c49d772b946f28eaf98b8361c009642648357d7b18df2b2ad2dd5cd4",
      "event_sha256": "4bf4aabda11bd93d9d7b9003f1103776097626068dd15022b093e2f225982e11",
      "line_number": 30,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q07",
      "previous_event_sha256": "96913c2c0da71b275dc767d80676c042d9aa6b9b08ac2bc8e201a056d314b28d",
      "raw_row_sha256": "23e5f47cb473310376edf9fc6a2835e24203de3454fd145e7772868fdabf49fa",
      "symbol": "SP500.DWX",
      "work_item_id": "c481ff0c-195e-4ef1-af41-221ce09dc8cf"
    },
    {
      "ea_id": "QM5_10939",
      "event_id": "ca521b0d4d38737fefdc563d53517803a98bea6d87c6c3ab90b5c6c852ac0ce6",
      "event_sha256": "79c4a1347ad6e95e09d03705cf851ef54a62e1a928e3e686681845fb53648cdd",
      "line_number": 31,
      "new_ex5_sha256": "308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac",
      "phase": "Q07",
      "previous_event_sha256": "4bf4aabda11bd93d9d7b9003f1103776097626068dd15022b093e2f225982e11",
      "raw_row_sha256": "0f6be1a6728ee46ad21d3cb457992334303df160d00d82a3560d959fd8d727de",
      "symbol": "XAUUSD.DWX",
      "work_item_id": "3a4a9c20-7378-4822-a1f6-089f9ef9c2cd"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "d2242dad7e962bd21845b8c4beafcbd089312dff51df51897fc04859afdfc95b",
      "event_sha256": "6ad134a3d0fc60dfde7a0b1a0da67f6160cc50b9d72316c644a979c81b4cd30a",
      "line_number": 32,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q06",
      "previous_event_sha256": "79c4a1347ad6e95e09d03705cf851ef54a62e1a928e3e686681845fb53648cdd",
      "raw_row_sha256": "37ab54d69068c2f1a75b18ffe494b0c112b607b7038a2804614eef9c19addb34",
      "symbol": "SP500.DWX",
      "work_item_id": "b3615375-d509-409b-82b3-0ec6e5799673"
    },
    {
      "ea_id": "QM5_11421",
      "event_id": "d348139e64d1d889b04561b4a42267d0631eaed688e35584222b2e50cfb7dbf4",
      "event_sha256": "b9d0e3dd86e69f2dcc060a3d8803db2837299d08397850be6e4b6ba1e13549dd",
      "line_number": 33,
      "new_ex5_sha256": "0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7",
      "phase": "Q06",
      "previous_event_sha256": "6ad134a3d0fc60dfde7a0b1a0da67f6160cc50b9d72316c644a979c81b4cd30a",
      "raw_row_sha256": "f703213ba1dcf07d3866e6968143b9a86e206333d162b41167f1de4c92e4b19a",
      "symbol": "AUDUSD.DWX",
      "work_item_id": "50854095-d2b7-44e3-ab6a-80ddd996283e"
    },
    {
      "ea_id": "QM5_11132",
      "event_id": "d6a01ef3ea111a2372aebe0174f1f36e447f27cac07d572b498d51effd40dfc4",
      "event_sha256": "a856e698568619191801ac6cb9cbfb81665970b531353cabd3821adbb9273eb9",
      "line_number": 34,
      "new_ex5_sha256": "25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152",
      "phase": "Q07",
      "previous_event_sha256": "b9d0e3dd86e69f2dcc060a3d8803db2837299d08397850be6e4b6ba1e13549dd",
      "raw_row_sha256": "7a80905a02ab72831f1d308a9792731c3add2cc7f5544fba742f58dacb080477",
      "symbol": "SP500.DWX",
      "work_item_id": "6aadeed9-d64b-4ee3-aabe-0c0e74232218"
    },
    {
      "ea_id": "QM5_10911",
      "event_id": "db534a0faa7cb3f57ac04627314b1494c2b2ed9dc17f5b88976bbf209e718558",
      "event_sha256": "a6e74db3c5385f440716e4ee17e90b55a61b9d409dac4453f0fa8bb50f65f1fb",
      "line_number": 35,
      "new_ex5_sha256": "a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158",
      "phase": "Q06",
      "previous_event_sha256": "a856e698568619191801ac6cb9cbfb81665970b531353cabd3821adbb9273eb9",
      "raw_row_sha256": "a7d6b57aa8fec1dc8a3a9423d1611767eebec45ef1f2f208666222b5d588dbf7",
      "symbol": "GDAXI.DWX",
      "work_item_id": "88966987-8485-468b-bd17-9e358e42eb95"
    },
    {
      "ea_id": "QM5_10939",
      "event_id": "e0fa15f40811a74505b5c46117dac838dcf75bce847c8851ff787ac4f4924861",
      "event_sha256": "8018ed4c16e6e0f500b8b2007466335fad63467d1ccba3c71565ad238eb39712",
      "line_number": 36,
      "new_ex5_sha256": "308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac",
      "phase": "Q06",
      "previous_event_sha256": "a6e74db3c5385f440716e4ee17e90b55a61b9d409dac4453f0fa8bb50f65f1fb",
      "raw_row_sha256": "50ccb8387561caac9860bab5f775e65887bd7455cc4ebb3881faf27baa0b1288",
      "symbol": "XAUUSD.DWX",
      "work_item_id": "8924596d-e3d6-4801-bc6d-6bf73599f315"
    },
    {
      "ea_id": "QM5_10939",
      "event_id": "e1859d1e2e04d803db0385f052d8e5031fd2faffc34f7962a7f74b08631cbff1",
      "event_sha256": "0536c23160c56c20925cbb16a1daf5df9b0e5044a92d31acee9ada615cf52074",
      "line_number": 37,
      "new_ex5_sha256": "308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac",
      "phase": "Q06",
      "previous_event_sha256": "8018ed4c16e6e0f500b8b2007466335fad63467d1ccba3c71565ad238eb39712",
      "raw_row_sha256": "7e5d910e959a33a1a9a5cd4e4320c1c0a82c0741ba42969f282a33009972d91a",
      "symbol": "GBPUSD.DWX",
      "work_item_id": "8ebd89ef-566b-45f8-8bc3-61cc6c7e6a9c"
    },
    {
      "ea_id": "QM5_12989",
      "event_id": "e95ff9d8cef9cf39926a339ce900ba76f6bcf3a82eebca8560dc9f1fee6cf039",
      "event_sha256": "f49093fd0c07a4647ab23f0b4bb7a868b5747a94c4ad0666f2fc615aeb3d5e7f",
      "line_number": 38,
      "new_ex5_sha256": "7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2",
      "phase": "Q07",
      "previous_event_sha256": "0536c23160c56c20925cbb16a1daf5df9b0e5044a92d31acee9ada615cf52074",
      "raw_row_sha256": "c3164713c1d34c1eacb407461dd1c464add23aeb87c9b08e8fec1de57266a5f7",
      "symbol": "XAUUSD.DWX",
      "work_item_id": "377350fb-2b57-4f72-9372-fef9c94c6f62"
    },
    {
      "ea_id": "QM5_12567",
      "event_id": "f5c57bff5843d5e285199c12e01531e7d0c9f3f80b61f56f5031b976fb7c370b",
      "event_sha256": "713ac5c0e618532c0841ad1a8cb94522a9166f6e5f37674310679181b4159678",
      "line_number": 39,
      "new_ex5_sha256": "5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9",
      "phase": "Q07",
      "previous_event_sha256": "f49093fd0c07a4647ab23f0b4bb7a868b5747a94c4ad0666f2fc615aeb3d5e7f",
      "raw_row_sha256": "977a1c0a6416678a0b5e9803ae126152f96035fe95d67ae1e8f8ce49025423d4",
      "symbol": "XAUUSD.DWX",
      "work_item_id": "3cc839c7-ec92-4050-8193-8a5b8f457f69"
    }
  ],
  "schema": "qm/mnt043-ks-vintage-bill-apply-receipt/v1",
  "status": "DRY_RUN_VERIFIED_NO_MUTATION"
}
~~~

Post-run read-only confirmation: overlay SHA-256 remained f3b3a11877689a4a81848f764f26623c1f778dc615a8e8f1e817a835fde9621c, the event count remained 13, the tail remained 0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6, and no .lock sidecar existed.

## Read-only enqueue-pair verification

All 17 supplied pairs were queried by exact UUID against D:\QM\strategy_farm\state\farm_state.sqlite opened mode=ro/query_only. For each pair the predecessor exists in the required preceding phase as done/PASS, the target exists in the requested phase and is terminal/PASS, EA/symbol/setfile match, the setfile exists, no append-only rerun of the target exists, and no pending/active row occupies the identity.

| Phase | Identity | Exact predecessor | Append-only target | Result |
|---|---|---|---|---|
| Q06 | QM5_10919/XTIUSD.DWX | 7775c12a-cc8c-4d16-af11-288a68fe9a79 | 96bdad0e-ebec-4d4d-9375-14597ec509ec | PASS |
| Q06 | QM5_10939/GBPUSD.DWX | d0e2db9e-ad81-4199-9245-bb37514cf40d | 8ebd89ef-566b-45f8-8bc3-61cc6c7e6a9c | PASS |
| Q06 | QM5_11132/SP500.DWX base | 4d0aedce-1b2b-40dc-b3f1-36e78bc9023c | 8e3aa6c8-32de-4ede-9dd2-ee535e6f97a6 | PASS |
| Q06 | QM5_11421/AUDUSD.DWX | fbb9f805-96e3-4959-8273-76fb3659d5cf | 50854095-d2b7-44e3-ab6a-80ddd996283e | PASS |
| Q06 | QM5_11421/EURUSD.DWX | 4c62aa2b-d5d5-456e-8987-e5db0d54a0a4 | 84caa901-4c50-4553-b427-d6ee48a0ca18 | PASS |
| Q06 | QM5_12567/XAUUSD.DWX | 232b6803-b145-4fcb-a815-ba11a931ab60 | 5cdcd811-723f-4a98-a0f1-2a02bea2bff5 | PASS |
| Q06 | QM5_12567/XNGUSD.DWX | 6188e6fe-4738-4d44-8dd4-5d5ffe2c4a9e | 5c3b1d27-3d69-4863-843d-5182b3e8983d | PASS |
| Q06 | QM5_12989/XAUUSD.DWX | ecb3c2f3-e167-4082-8597-ba18d231c4d6 | 209795ab-859f-4aaf-a426-97627e317f6e | PASS |
| Q07 | QM5_10911/GDAXI.DWX | 88966987-8485-468b-bd17-9e358e42eb95 | ba34fb1f-2b3b-4ab4-b511-096000fbb8a8 | PASS |
| Q07 | QM5_10919/XTIUSD.DWX | 96bdad0e-ebec-4d4d-9375-14597ec509ec | b0a43323-8520-4afd-b4b3-c59503645dee | PASS |
| Q07 | QM5_10939/GBPUSD.DWX | 8ebd89ef-566b-45f8-8bc3-61cc6c7e6a9c | 2a77e549-58c7-4b18-b502-40f64f73e1fb | PASS |
| Q07 | QM5_11132/SP500.DWX base | 8e3aa6c8-32de-4ede-9dd2-ee535e6f97a6 | cbb145d8-4341-4f00-b0f8-13d9ca162109 | PASS |
| Q07 | QM5_11421/AUDUSD.DWX | 50854095-d2b7-44e3-ab6a-80ddd996283e | b77d915a-d9be-4a51-bdf4-c6c186caded9 | PASS |
| Q07 | QM5_11421/EURUSD.DWX | 84caa901-4c50-4553-b427-d6ee48a0ca18 | 0d1cb1a3-7a0f-497a-bfb2-4640d37a7962 | PASS |
| Q07 | QM5_12567/XAUUSD.DWX | 5cdcd811-723f-4a98-a0f1-2a02bea2bff5 | 3cc839c7-ec92-4050-8193-8a5b8f457f69 | PASS |
| Q07 | QM5_12567/XNGUSD.DWX | 5c3b1d27-3d69-4863-843d-5182b3e8983d | f9452af6-d356-4856-afdb-d45cf863c625 | PASS |
| Q07 | QM5_12989/XAUUSD.DWX | 209795ab-859f-4aaf-a426-97627e317f6e | 377350fb-2b57-4f72-9372-fef9c94c6f62 | PASS |

QM5_10939 has two current Q05 done/PASS rows for the same GBPUSD base set. The requested d0e2db9e-ad81-4199-9245-bb37514cf40d row is the most recently updated (2026-07-03T10:08:23Z versus 2026-06-26T21:27:33Z) and passes the exact farmctl binding checks.

QM5_11132/SP500 has three Q06 and three Q07 bill rows. The listed targets 8e3aa6c8-32de-4ede-9dd2-ee535e6f97a6 and cbb145d8-4341-4f00-b0f8-13d9ca162109 use QM5_11132_tm-cum-rsi2_SP500.DWX_D1_backtest.set; the other four bill rows use ablation_01 or ablation_02 setfiles. Accordingly, all six receive the overlay-stale events but only the base-set pair is enqueued.

## QM5_10911/GDAXI Q06 predecessor investigation and proposed binding

There is no current Q05 done/PASS row for QM5_10911/GDAXI.DWX. The only base-set Q05 row is 17622470-7435-4031-b995-4af1bc44eee1:

- it was created at 2026-06-15T13:50:04Z from Q04 row 538405f6-3e5e-4072-9c04-336fa3164fae;
- it uses the same GDAXI.DWX H1 base setfile as Q04, Q06, and Q07;
- Q06 row 88966987-8485-468b-bd17-9e358e42eb95 was created ten minutes later with promoted_from_work_item=17622470-7435-4031-b995-4af1bc44eee1 and promotion_source=pump_cascade, proving the exact lineage that historically admitted Q06;
- on 2026-07-03, event 208527 recorded a legacy cascade requeue of that same Q05 UUID; its payload now carries requeued_at=2026-07-03T05:47:14Z, an archived_report_root_on_requeue marker, and preflight_failure=ea_dir_missing for C:\QM\worktrees\codex-orchestration-1\framework\EAs\QM5_10911_*;
- the re-used row finished at 2026-07-03T09:52:05Z as INFRA_FAIL with BARS_ZERO, EMPTY_EXPERT, EMPTY_SYMBOL, HISTORY_CONTEXT_INVALID, INCOMPLETE_RUNS, M0_1970_PERIOD, NO_HISTORY, and RUN_STATUS_INVALID. The archived report directory is no longer present.

This is a non-PASS-verdict problem caused by a legacy in-place requeue, not a different-setfile problem. The row must not be rewritten back to PASS and farmctl must not be bypassed.

Proposed OWNER binding: first create an append-only Q05 prerequisite rerun from the still-current Q04 done/PASS row 538405f6-3e5e-4072-9c04-336fa3164fae, preserving Q05 target 17622470-7435-4031-b995-4af1bc44eee1. Read-only checks confirm same EA/symbol/setfile, an existing setfile, a terminal target, no prior append-only rerun, and no open duplicate. Only if that new Q05 row finishes PASS should its newly allocated UUID be bound as the Q06 predecessor for append-only target 88966987-8485-468b-bd17-9e358e42eb95.

The proposed prerequisite command, not authorized by this preparation and deliberately excluded from the 17-command operator list below, is:

~~~text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10911 --phase Q05 --from-work-item-id 538405f6-3e5e-4072-9c04-336fa3164fae --append-only-rerun-of 17622470-7435-4031-b995-4af1bc44eee1 --rerun-reason 'MNT-043 QM5_10911/GDAXI Q06 prerequisite; adopted_ex5_sha256=a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
~~~

After that new Q05 row passes, the proposed Q06 command is:

~~~text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10911 --phase Q06 --from-work-item-id <NEW_Q05_PASS_WORK_ITEM_ID> --append-only-rerun-of 88966987-8485-468b-bd17-9e358e42eb95 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
~~~

Runtime execution will resolve the already-adopted repo-tree binary; no payload injection or farmctl change is proposed.

## Exact Claude operator commands

Run from C:\QM\repo, in the listed order, while the OWNER-approved OFF window remains in force. The first command mutates only the overlay and create-only receipt. The following 17 commands enqueue append-only farm rows and therefore write the farm DB; Codex did not run any of them.

### 1. Apply the reviewed 26-event bill

~~~text
python tools/strategy_farm/apply_ks_vintage_bill.py --apply --bill docs/ops/evidence/2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json --expected-bill-sha256 1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1 --db D:/QM/strategy_farm/state/farm_state.sqlite --repo-root C:/QM/repo --overlay D:/QM/reports/maintenance/mnt_adjudication_overlay.jsonl --expected-overlay-sha256 f3b3a11877689a4a81848f764f26623c1f778dc615a8e8f1e817a835fde9621c --expected-tail-event-sha256 0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6 --reviewer claude:MNT-043 --receipt-out docs/ops/evidence/2026-08-02_mnt043_ks_vintage_bill_apply_receipt.json
~~~

### 2. Enqueue Q06 first

~~~text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10919 --phase Q06 --from-work-item-id 7775c12a-cc8c-4d16-af11-288a68fe9a79 --append-only-rerun-of 96bdad0e-ebec-4d4d-9375-14597ec509ec --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10939 --phase Q06 --from-work-item-id d0e2db9e-ad81-4199-9245-bb37514cf40d --append-only-rerun-of 8ebd89ef-566b-45f8-8bc3-61cc6c7e6a9c --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11132 --phase Q06 --from-work-item-id 4d0aedce-1b2b-40dc-b3f1-36e78bc9023c --append-only-rerun-of 8e3aa6c8-32de-4ede-9dd2-ee535e6f97a6 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11421 --phase Q06 --from-work-item-id fbb9f805-96e3-4959-8273-76fb3659d5cf --append-only-rerun-of 50854095-d2b7-44e3-ab6a-80ddd996283e --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11421 --phase Q06 --from-work-item-id 4c62aa2b-d5d5-456e-8987-e5db0d54a0a4 --append-only-rerun-of 84caa901-4c50-4553-b427-d6ee48a0ca18 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12567 --phase Q06 --from-work-item-id 232b6803-b145-4fcb-a815-ba11a931ab60 --append-only-rerun-of 5cdcd811-723f-4a98-a0f1-2a02bea2bff5 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12567 --phase Q06 --from-work-item-id 6188e6fe-4738-4d44-8dd4-5d5ffe2c4a9e --append-only-rerun-of 5c3b1d27-3d69-4863-843d-5182b3e8983d --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12989 --phase Q06 --from-work-item-id ecb3c2f3-e167-4082-8597-ba18d231c4d6 --append-only-rerun-of 209795ab-859f-4aaf-a426-97627e317f6e --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
~~~

### 3. Then enqueue Q07

~~~text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10911 --phase Q07 --from-work-item-id 88966987-8485-468b-bd17-9e358e42eb95 --append-only-rerun-of ba34fb1f-2b3b-4ab4-b511-096000fbb8a8 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10919 --phase Q07 --from-work-item-id 96bdad0e-ebec-4d4d-9375-14597ec509ec --append-only-rerun-of b0a43323-8520-4afd-b4b3-c59503645dee --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10939 --phase Q07 --from-work-item-id 8ebd89ef-566b-45f8-8bc3-61cc6c7e6a9c --append-only-rerun-of 2a77e549-58c7-4b18-b502-40f64f73e1fb --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11132 --phase Q07 --from-work-item-id 8e3aa6c8-32de-4ede-9dd2-ee535e6f97a6 --append-only-rerun-of cbb145d8-4341-4f00-b0f8-13d9ca162109 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11421 --phase Q07 --from-work-item-id 50854095-d2b7-44e3-ab6a-80ddd996283e --append-only-rerun-of b77d915a-d9be-4a51-bdf4-c6c186caded9 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11421 --phase Q07 --from-work-item-id 84caa901-4c50-4553-b427-d6ee48a0ca18 --append-only-rerun-of 0d1cb1a3-7a0f-497a-bfb2-4640d37a7962 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12567 --phase Q07 --from-work-item-id 5cdcd811-723f-4a98-a0f1-2a02bea2bff5 --append-only-rerun-of 3cc839c7-ec92-4050-8193-8a5b8f457f69 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12567 --phase Q07 --from-work-item-id 5c3b1d27-3d69-4863-843d-5182b3e8983d --append-only-rerun-of f9452af6-d356-4856-afdb-d45cf863c625 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12989 --phase Q07 --from-work-item-id 209795ab-859f-4aaf-a426-97627e317f6e --append-only-rerun-of 377350fb-2b57-4f72-9372-fef9c94c6f62 --rerun-reason 'MNT-043 vintage requalification; adopted_ex5_sha256=7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2; bill_sha256=1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1'
~~~
