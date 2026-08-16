"""The payload timeout_min override must budget the smoke layer, not only the
worker watchdog (2026-08-16: XAU/XAG 2-member baskets burned every attempt on
the flat 2h floor while carrying timeout_min=450)."""

import farmctl


def test_payload_floor_unset_or_invalid_is_zero():
    assert farmctl._payload_timeout_floor_seconds({}) == 0
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": None}) == 0
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": "abc"}) == 0
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": -5}) == 0


def test_payload_floor_scales_and_caps():
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": 450}) == 25200
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": 10}) == 600
    # 7h cap like the member-count formula
    assert farmctl._payload_timeout_floor_seconds({"timeout_min": 10000}) == 25200


def test_q02_full_two_member_basket_with_override_beats_2h_floor():
    payload = {"basket_symbol_count": 2, "timeout_min": 450}
    got = farmctl._p2_full_timeout_seconds(payload, "2018.07.02", "2022.12.31")
    assert got == 25200  # 450min capped at 7h, well above the 7200 floor


def test_q02_full_without_override_keeps_prior_behavior():
    payload = {"basket_symbol_count": 2}
    got = farmctl._p2_full_timeout_seconds(payload, "2018.07.02", "2022.12.31")
    assert got == farmctl.P2_FULL_TIMEOUT_MIN_SECONDS


def test_override_never_shrinks_many_member_budget():
    # 28-member T-WIN formula budget (18600s) must survive a small override.
    payload = {"basket_symbol_count": 28, "timeout_min": 10}
    got = farmctl._p2_full_timeout_seconds(payload, "2018.07.02", "2022.12.31")
    assert got == max(farmctl.P2_FULL_TIMEOUT_MIN_SECONDS, min(25200, 1800 + 28 * 600))
