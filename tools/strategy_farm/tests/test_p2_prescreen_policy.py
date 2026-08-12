import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class P2PrescreenPolicyTests(unittest.TestCase):
    def test_ftmo_book3_exact_q02_window_is_taken_from_payload(self) -> None:
        payload = {
            "measurement_contract": farmctl.FTMO_BOOK3_FIDELITY_MEASUREMENT_CONTRACT,
            "from_date": "2018.07.02",
            "to_date": "2025.12.31",
        }
        self.assertEqual(
            farmctl._ftmo_book3_q02_exact_window("Q02", payload),
            ("2018.07.02", "2025.12.31"),
        )

    def test_ftmo_book3_override_requires_exact_contract_and_q02(self) -> None:
        base = {
            "from_date": "2018.07.02",
            "to_date": "2025.12.31",
        }
        for phase, contract in (
            ("Q02", None),
            ("Q02", "FTMO_BOOK3_FIDELITY_LADDER_V1"),
            ("Q02", "FTMO_BOOK3_FIDELITY_LADDER_V1_NEAR_MATCH"),
            ("Q02", "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET_NEAR_MATCH"),
            ("P2", farmctl.FTMO_BOOK3_FIDELITY_MEASUREMENT_CONTRACT),
        ):
            with self.subTest(phase=phase, contract=contract):
                payload = dict(base)
                if contract is not None:
                    payload["measurement_contract"] = contract
                self.assertIsNone(
                    farmctl._ftmo_book3_q02_exact_window(phase, payload)
                )

    def test_ftmo_book3_exact_q02_window_rejects_invalid_payload_dates(self) -> None:
        invalid_windows = (
            (None, "2025.12.31"),
            ("2018.07.02", None),
            (" 2018.07.02", "2025.12.31"),
            ("2018.02.30", "2025.12.31"),
            ("2025.12.31", "2018.07.02"),
        )
        for from_date, to_date in invalid_windows:
            with self.subTest(from_date=from_date, to_date=to_date):
                payload = {
                    "measurement_contract": (
                        farmctl.FTMO_BOOK3_FIDELITY_MEASUREMENT_CONTRACT
                    ),
                    "from_date": from_date,
                    "to_date": to_date,
                }
                with self.assertRaises(ValueError):
                    farmctl._ftmo_book3_q02_exact_window("Q02", payload)

    def test_prescreen_window_is_recent_six_months_inside_p2_window(self) -> None:
        self.assertEqual(
            farmctl._p2_prescreen_dates(2022),
            ("2022.07.01", "2022.12.31"),
        )

    def test_full_timeout_uses_prescreen_runtime_with_bounds(self) -> None:
        payload = {
            "p2_prescreen_runtime_sec": 60,
            "p2_prescreen_from_date": "2022.07.01",
            "p2_prescreen_to_date": "2022.12.31",
        }
        self.assertEqual(
            farmctl._p2_full_timeout_seconds(payload, "2017.01.01", "2022.12.31"),
            farmctl.P2_FULL_TIMEOUT_MIN_SECONDS,
        )

        payload["p2_prescreen_runtime_sec"] = 1800
        self.assertEqual(
            farmctl._p2_full_timeout_seconds(payload, "2017.01.01", "2022.12.31"),
            farmctl.P2_FULL_TIMEOUT_MAX_SECONDS,
        )

    def test_full_timeout_falls_back_to_min_without_measurement(self) -> None:
        self.assertEqual(
            farmctl._p2_full_timeout_seconds({}, "2017.01.01", "2022.12.31"),
            farmctl.P2_FULL_TIMEOUT_MIN_SECONDS,
        )


if __name__ == "__main__":
    unittest.main()
