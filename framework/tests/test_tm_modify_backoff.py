import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MQH_PATH = REPO_ROOT / "framework" / "include" / "QM" / "QM_TradeManagement.mqh"


def _load_source():
    return MQH_PATH.read_text(encoding="utf-8")


def _load_constants():
    source = _load_source()
    constants = {}
    for name in (
        "QM_TM_MODIFY_RETRY_SECONDS",
        "QM_TM_MODIFY_BACKOFF_MAX_SECONDS",
        "QM_TM_MODIFY_GIVEUP_ATTEMPTS",
    ):
        match = re.search(rf"#define {name} (\d+)", source)
        assert match, f"{name} not found in {MQH_PATH}"
        constants[name] = int(match.group(1))
    return constants


def _backoff_seconds(attempt_count, retry_seconds, backoff_max_seconds):
    # Mirrors QM_TM_ModifyBackoffSeconds in QM_TradeManagement.mqh exactly:
    # shift = clamp(attempt_count - 1, 0, 10); backoff = base * 2^shift, capped.
    shift = min(max(attempt_count - 1, 0), 10)
    backoff = retry_seconds * (2.0 ** shift)
    return min(backoff, backoff_max_seconds)


class RejectSimulation:
    """Reimplements QM_TM_ModifySuppressed / QM_TM_RememberFailedModify /
    QM_TM_ClearFailedModify against a synthetic clock, so the retry-cadence
    contract can be exercised without a live MT5 terminal (build_check.ps1
    strict-compile is the separate check that the .mqh itself still compiles).
    """

    def __init__(self, retry_seconds, backoff_max_seconds, giveup_attempts):
        self.retry_seconds = retry_seconds
        self.backoff_max_seconds = backoff_max_seconds
        self.giveup_attempts = giveup_attempts
        self.attempt_count = 0
        self.last_attempt = None
        self.giveup_alerts = 0

    def suppressed(self, now):
        if self.last_attempt is None:
            return False
        backoff = _backoff_seconds(self.attempt_count, self.retry_seconds, self.backoff_max_seconds)
        return (now - self.last_attempt) < backoff

    def remember_failed(self, now):
        self.last_attempt = now
        self.attempt_count += 1
        if self.attempt_count == self.giveup_attempts:
            self.giveup_alerts += 1

    def clear(self):
        self.attempt_count = 0
        self.last_attempt = None

    def tick(self, now, broker_will_reject):
        """One EA tick: attempt a modify unless suppressed. Returns True if a
        request was actually sent to the broker (WARN-line-producing path)."""
        if self.suppressed(now):
            return False
        if broker_will_reject:
            self.remember_failed(now)
        else:
            self.clear()
        return True


def test_constants_match_incident_remediation_intent():
    c = _load_constants()
    assert c["QM_TM_MODIFY_RETRY_SECONDS"] == 30
    assert c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"] >= 300, (
        "backoff cap must settle into a genuinely low-frequency retry, not stay near the base window"
    )
    assert c["QM_TM_MODIFY_GIVEUP_ATTEMPTS"] >= 5, (
        "hard cap must not fire on the first few transient rejections"
    )


def test_backoff_grows_exponentially_then_caps():
    c = _load_constants()
    seconds = [
        _backoff_seconds(n, c["QM_TM_MODIFY_RETRY_SECONDS"], c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"])
        for n in range(1, 12)
    ]
    for earlier, later in zip(seconds, seconds[1:]):
        assert later >= earlier, "backoff must never shrink as attempts accumulate"
    assert seconds[0] == c["QM_TM_MODIFY_RETRY_SECONDS"]
    assert seconds[-1] == c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"]
    assert seconds[-2] == c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"], "must have reached the cap before the array end"


def test_giveup_alert_fires_exactly_once_per_streak():
    c = _load_constants()
    sim = RejectSimulation(
        c["QM_TM_MODIFY_RETRY_SECONDS"],
        c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"],
        c["QM_TM_MODIFY_GIVEUP_ATTEMPTS"],
    )
    now = 0
    # Drive the ticket through far more than giveup_attempts consecutive
    # rejections by always waiting out the current backoff before retrying.
    for _ in range(c["QM_TM_MODIFY_GIVEUP_ATTEMPTS"] * 3):
        backoff = _backoff_seconds(sim.attempt_count, sim.retry_seconds, sim.backoff_max_seconds)
        now += int(backoff) + 1
        sim.tick(now, broker_will_reject=True)
    assert sim.giveup_alerts == 1, "the alert line must fire exactly once, not once per subsequent failure"
    assert sim.attempt_count > c["QM_TM_MODIFY_GIVEUP_ATTEMPTS"], "retries must continue past the cap at low frequency"


def test_success_clears_state_and_resets_backoff():
    c = _load_constants()
    sim = RejectSimulation(
        c["QM_TM_MODIFY_RETRY_SECONDS"],
        c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"],
        c["QM_TM_MODIFY_GIVEUP_ATTEMPTS"],
    )
    now = 0
    for _ in range(5):
        now += c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"]
        sim.tick(now, broker_will_reject=True)
    assert sim.attempt_count == 5
    now += c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"]
    sim.tick(now, broker_will_reject=False)
    assert sim.attempt_count == 0
    assert sim.suppressed(now + 1) is False


def test_qm5_10706_incident_replay_no_longer_storms():
    """Replay of docs/ops/evidence/2026-08-22_tlive_ea_warn_classification.md
    Finding 1: one ticket, rejected on effectively every tick for 4.5h
    (2026-07-29T12:59:58Z -> 17:30:18Z), which produced 36098 TM_MODIFY WARN
    lines under the pre-fix behavior (no backoff at all once the target
    drifted off the exact-match suppression). Under the new per-ticket
    backoff this must collapse to a handful of broker round-trips."""
    c = _load_constants()
    sim = RejectSimulation(
        c["QM_TM_MODIFY_RETRY_SECONDS"],
        c["QM_TM_MODIFY_BACKOFF_MAX_SECONDS"],
        c["QM_TM_MODIFY_GIVEUP_ATTEMPTS"],
    )
    incident_seconds = int((17 * 3600 + 30 * 60 + 18) - (12 * 3600 + 59 * 60 + 58))
    sent_to_broker = 0
    for second in range(0, incident_seconds, 1):
        # a target that drifts every tick defeated the old exact-match
        # suppression outright; the new suppression does not look at the
        # target at all, so drift cannot matter here.
        if sim.tick(second, broker_will_reject=True):
            sent_to_broker += 1
    assert sent_to_broker < 40, (
        f"expected the 4.5h incident window to collapse to a handful of attempts, got {sent_to_broker}"
    )
    assert sim.giveup_alerts == 1
