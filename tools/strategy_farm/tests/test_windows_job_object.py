from __future__ import annotations

import ctypes

import pytest

from tools.strategy_farm.windows_job_object import (
    CtypesWindowsJobApi,
    JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS,
    JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    WINDOWS_CREATE_NO_WINDOW,
    WINDOWS_CREATE_SUSPENDED,
    JobObjectError,
    JobObjectRegistry,
    bind_spawned_process_to_kill_job,
    reap_finished_job_objects,
    suspended_runner_creation_flags,
)


class FakeProcess:
    def __init__(self, events: list, *, pid: int = 1234, handle: int | None = 4321) -> None:
        self.events = events
        self.pid = pid
        if handle is not None:
            self._handle = handle
        self.returncode = None
        self.kill_calls = 0
        self.wait_calls = []

    def kill(self) -> None:
        self.events.append("kill")
        self.kill_calls += 1
        self.returncode = -9

    def wait(self, timeout=None):
        self.events.append(("wait", timeout))
        self.wait_calls.append(timeout)
        return self.returncode

    def poll(self):
        self.events.append("poll")
        return self.returncode


class FakeApi:
    def __init__(
        self,
        events: list,
        *,
        fail_create=False,
        fail_assign=False,
        fail_resume=False,
        fail_query=False,
        fail_close=False,
        active_processes=0,
    ):
        self.events = events
        self.fail_create = fail_create
        self.fail_assign = fail_assign
        self.fail_resume = fail_resume
        self.fail_query = fail_query
        self.fail_close = fail_close
        self.active_processes = active_processes

    def create_kill_on_close_job(self) -> int:
        self.events.append("create_kill_on_close")
        if self.fail_create:
            raise JobObjectError("create failed")
        return 9001

    def assign_process(self, job_handle: int, process_handle: int) -> None:
        self.events.append(("assign", job_handle, process_handle))
        if self.fail_assign:
            raise JobObjectError("assign failed")

    def resume_primary_thread(self, process_handle: int, process_id: int) -> None:
        self.events.append(("resume", process_handle, process_id))
        if self.fail_resume:
            raise JobObjectError("resume failed")

    def active_process_count(self, job_handle: int) -> int:
        self.events.append(("active_process_count", job_handle, self.active_processes))
        if self.fail_query:
            raise JobObjectError("query failed")
        return self.active_processes

    def close_handle(self, handle: int) -> None:
        self.events.append(("close", handle))
        if self.fail_close:
            raise JobObjectError("close failed")


def _capture(events: list, *, creation_key: str = "creation:1234"):
    def inner(process: FakeProcess):
        events.append("capture_identity")
        return {
            "process_creation_key": creation_key,
            "process_image_path": "C:/runner.exe",
            "process_started_at_epoch": 100.0,
        }

    return inner


def test_non_windows_is_explicit_noop_but_still_captures_identity() -> None:
    events: list = []
    process = FakeProcess(events)
    result = bind_spawned_process_to_kill_job(
        process,
        _capture(events),
        platform="linux",
        api=FakeApi(events),
    )

    assert events == ["capture_identity"]
    assert result["process_creation_key"] == "creation:1234"
    assert result["job_object_assigned"] is False
    assert result["job_object_mode"] == "NON_WINDOWS_NOOP"
    assert result["job_object_registry_key"] is None
    assert result["process_started_suspended"] is False
    assert result["primary_thread_resumed"] is False


def test_runner_creation_flags_are_suspended_only_on_windows() -> None:
    assert suspended_runner_creation_flags(platform="linux") == 0
    flags = suspended_runner_creation_flags(platform="win32")
    assert flags & WINDOWS_CREATE_SUSPENDED
    assert flags & WINDOWS_CREATE_NO_WINDOW


def test_windows_assignment_precedes_identity_and_registry_retains_handle() -> None:
    events: list = []
    process = FakeProcess(events)
    api = FakeApi(events)
    registry = JobObjectRegistry()

    result = bind_spawned_process_to_kill_job(
        process,
        _capture(events),
        platform="win32",
        api=api,
        registry=registry,
        start_observer=False,
        process_created_suspended=True,
    )

    assert events == [
        "create_kill_on_close",
        ("assign", 9001, 4321),
        "capture_identity",
        ("resume", 4321, 1234),
    ]
    assert result["job_object_assigned"] is True
    assert result["job_object_mode"] == "KILL_ON_JOB_CLOSE"
    assert result["job_object_registry_key"] == "1234|creation:1234"
    assert result["process_started_suspended"] is True
    assert result["primary_thread_resumed"] is True
    assert registry.active_keys() == ("1234|creation:1234",)
    assert not any(isinstance(event, tuple) and event[0] == "close" for event in events)

    assert reap_finished_job_objects(registry=registry, platform="win32") == 0
    assert registry.active_keys() == ("1234|creation:1234",)
    process.returncode = 0
    assert reap_finished_job_objects(registry=registry, platform="win32") == 1
    assert registry.active_keys() == ()
    assert events[-1] == ("close", 9001)


def test_root_end_with_active_children_retains_job_until_tree_is_empty() -> None:
    events: list = []
    process = FakeProcess(events)
    api = FakeApi(events, active_processes=2)
    registry = JobObjectRegistry()
    bind_spawned_process_to_kill_job(
        process,
        _capture(events),
        platform="win32",
        api=api,
        registry=registry,
        start_observer=False,
        process_created_suspended=True,
    )
    process.returncode = 0

    assert registry.reap_finished() == 0
    assert registry.active_keys() == ("1234|creation:1234",)
    assert ("active_process_count", 9001, 2) in events
    assert ("close", 9001) not in events

    api.active_processes = 0
    assert registry.reap_finished() == 1
    assert registry.active_keys() == ()
    assert events[-1] == ("close", 9001)


def test_job_accounting_query_failure_is_fail_closed_and_retains_handle() -> None:
    events: list = []
    process = FakeProcess(events)
    api = FakeApi(events, fail_query=True)
    registry = JobObjectRegistry()
    bind_spawned_process_to_kill_job(
        process,
        _capture(events),
        platform="win32",
        api=api,
        registry=registry,
        start_observer=False,
        process_created_suspended=True,
    )
    process.returncode = 0

    with pytest.raises(JobObjectError, match="failed to query active processes"):
        registry.reap_finished()
    assert registry.active_keys() == ("1234|creation:1234",)
    assert ("close", 9001) not in events


def test_assignment_failure_closes_job_and_kills_through_retained_popen() -> None:
    events: list = []
    process = FakeProcess(events)
    api = FakeApi(events, fail_assign=True)

    with pytest.raises(JobObjectError, match="assign failed"):
        bind_spawned_process_to_kill_job(
            process,
            lambda _process: pytest.fail("identity must follow assignment"),
            platform="win32",
            api=api,
            registry=JobObjectRegistry(),
            start_observer=False,
            process_created_suspended=True,
        )

    assert events == [
        "create_kill_on_close",
        ("assign", 9001, 4321),
        ("close", 9001),
        "kill",
        ("wait", 10),
    ]
    assert process.kill_calls == 1


def test_windows_binding_rejects_a_runner_not_created_suspended() -> None:
    events: list = []
    process = FakeProcess(events)

    with pytest.raises(JobObjectError, match="requires CREATE_SUSPENDED"):
        bind_spawned_process_to_kill_job(
            process,
            lambda _process: pytest.fail("identity must not be captured"),
            platform="win32",
            api=FakeApi(events),
            registry=JobObjectRegistry(),
            start_observer=False,
        )

    assert events == ["kill", ("wait", 10)]


def test_resume_failure_aborts_retained_job_then_kills_and_waits() -> None:
    events: list = []
    process = FakeProcess(events)
    registry = JobObjectRegistry()

    with pytest.raises(JobObjectError, match="resume failed"):
        bind_spawned_process_to_kill_job(
            process,
            _capture(events),
            platform="win32",
            api=FakeApi(events, fail_resume=True),
            registry=registry,
            start_observer=False,
            process_created_suspended=True,
        )

    assert events == [
        "create_kill_on_close",
        ("assign", 9001, 4321),
        "capture_identity",
        ("resume", 4321, 1234),
        ("close", 9001),
        "kill",
        ("wait", 10),
    ]
    assert registry.active_keys() == ()


def test_identity_failure_closes_assigned_job_and_kills_retained_process() -> None:
    events: list = []
    process = FakeProcess(events)

    def bad_capture(_process):
        events.append("capture_identity")
        raise RuntimeError("identity unavailable")

    with pytest.raises(JobObjectError, match="identity unavailable"):
        bind_spawned_process_to_kill_job(
            process,
            bad_capture,
            platform="win32",
            api=FakeApi(events),
            registry=JobObjectRegistry(),
            start_observer=False,
            process_created_suspended=True,
        )

    assert events == [
        "create_kill_on_close",
        ("assign", 9001, 4321),
        "capture_identity",
        ("close", 9001),
        "kill",
        ("wait", 10),
    ]


def test_missing_retained_windows_handle_fails_before_job_creation_and_kills() -> None:
    events: list = []
    process = FakeProcess(events, handle=None)

    with pytest.raises(JobObjectError, match="retained process handle"):
        bind_spawned_process_to_kill_job(
            process,
            _capture(events),
            platform="win32",
            api=FakeApi(events),
            registry=JobObjectRegistry(),
            start_observer=False,
            process_created_suspended=True,
        )

    assert events == ["kill", ("wait", 10)]


def test_missing_creation_identity_is_fail_closed() -> None:
    events: list = []
    process = FakeProcess(events)

    with pytest.raises(JobObjectError, match="process_creation_key"):
        bind_spawned_process_to_kill_job(
            process,
            _capture(events, creation_key=""),
            platform="win32",
            api=FakeApi(events),
            registry=JobObjectRegistry(),
            start_observer=False,
            process_created_suspended=True,
        )

    assert ("close", 9001) in events
    assert "kill" in events


def test_close_failure_restores_observed_registry_record_for_retry() -> None:
    events: list = []
    process = FakeProcess(events)
    api = FakeApi(events, fail_close=True)
    registry = JobObjectRegistry()
    bind_spawned_process_to_kill_job(
        process,
        _capture(events),
        platform="win32",
        api=api,
        registry=registry,
        start_observer=False,
        process_created_suspended=True,
    )
    process.returncode = 0

    with pytest.raises(JobObjectError, match="failed to close observed"):
        registry.reap_finished()
    assert registry.active_keys() == ("1234|creation:1234",)


class _KernelFunction:
    def __init__(self, callback):
        self.callback = callback
        self.argtypes = None
        self.restype = None

    def __call__(self, *args):
        return self.callback(*args)


class FakeKernel32:
    def __init__(self, *, thread_ids=(55,), process_pid=1234, resume_count=1) -> None:
        self.calls: list = []
        self.thread_ids = list(thread_ids)
        self.process_pid = process_pid
        self.resume_count = resume_count
        self._thread_index = -1
        self.CreateJobObjectW = _KernelFunction(self._create)
        self.SetInformationJobObject = _KernelFunction(self._set)
        self.AssignProcessToJobObject = _KernelFunction(self._assign)
        self.QueryInformationJobObject = _KernelFunction(self._query)
        self.CreateToolhelp32Snapshot = _KernelFunction(self._snapshot)
        self.Thread32First = _KernelFunction(self._thread_first)
        self.Thread32Next = _KernelFunction(self._thread_next)
        self.OpenThread = _KernelFunction(self._open_thread)
        self.ResumeThread = _KernelFunction(self._resume_thread)
        self.GetProcessId = _KernelFunction(self._get_process_id)
        self.CloseHandle = _KernelFunction(self._close)

    def _create(self, security, name):
        self.calls.append(("create", security, name))
        return 77

    def _set(self, handle, info_class, info_pointer, size):
        info_type = __import__(
            "tools.strategy_farm.windows_job_object", fromlist=["_JOBOBJECT_EXTENDED_LIMIT_INFORMATION"]
        )._JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        info = ctypes.cast(info_pointer, ctypes.POINTER(info_type)).contents
        self.calls.append(("set", handle, info_class, info.BasicLimitInformation.LimitFlags, size))
        return 1

    def _assign(self, job, process):
        self.calls.append(("assign", job, process))
        return 1

    def _query(self, job, info_class, info_pointer, size, returned_length):
        module = __import__(
            "tools.strategy_farm.windows_job_object",
            fromlist=["_JOBOBJECT_BASIC_ACCOUNTING_INFORMATION"],
        )
        info_type = module._JOBOBJECT_BASIC_ACCOUNTING_INFORMATION
        info = ctypes.cast(info_pointer, ctypes.POINTER(info_type)).contents
        info.ActiveProcesses = 3
        self.calls.append(("query", job, info_class, size))
        return 1

    def _get_process_id(self, process_handle):
        self.calls.append(("get_process_id", process_handle))
        return self.process_pid

    def _snapshot(self, flags, process_id):
        self.calls.append(("snapshot", flags, process_id))
        return 66

    @staticmethod
    def _entry(info_pointer):
        module = __import__(
            "tools.strategy_farm.windows_job_object", fromlist=["_THREADENTRY32"]
        )
        return ctypes.cast(
            info_pointer, ctypes.POINTER(module._THREADENTRY32)
        ).contents

    def _write_thread(self, info_pointer, index):
        entry = self._entry(info_pointer)
        entry.th32ThreadID = self.thread_ids[index]
        entry.th32OwnerProcessID = self.process_pid

    def _thread_first(self, snapshot, info_pointer):
        self.calls.append(("thread_first", snapshot))
        if not self.thread_ids:
            return 0
        self._thread_index = 0
        self._write_thread(info_pointer, 0)
        return 1

    def _thread_next(self, snapshot, info_pointer):
        self.calls.append(("thread_next", snapshot))
        self._thread_index += 1
        if self._thread_index >= len(self.thread_ids):
            return 0
        self._write_thread(info_pointer, self._thread_index)
        return 1

    def _open_thread(self, access, inherit, thread_id):
        self.calls.append(("open_thread", access, inherit, thread_id))
        return 99

    def _resume_thread(self, thread_handle):
        self.calls.append(("resume_thread", thread_handle))
        return self.resume_count

    def _close(self, handle):
        self.calls.append(("close", handle))
        return 1


def test_ctypes_adapter_sets_kill_on_job_close_and_uses_exact_handles() -> None:
    kernel = FakeKernel32()
    api = CtypesWindowsJobApi(kernel32=kernel)

    handle = api.create_kill_on_close_job()
    api.assign_process(handle, 88)
    api.resume_primary_thread(88, 1234)
    assert api.active_process_count(handle) == 3
    api.close_handle(handle)

    assert kernel.calls[0] == ("create", None, None)
    assert kernel.calls[1][0:4] == (
        "set",
        77,
        JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
    )
    assert kernel.calls[2:] == [
        ("assign", 77, 88),
        ("get_process_id", 88),
        ("snapshot", 4, 0),
        ("thread_first", 66),
        ("thread_next", 66),
        ("close", 66),
        ("open_thread", 2050, False, 55),
        ("resume_thread", 99),
        ("close", 99),
        ("query", 77, JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS, ctypes.sizeof(
            __import__(
                "tools.strategy_farm.windows_job_object",
                fromlist=["_JOBOBJECT_BASIC_ACCOUNTING_INFORMATION"],
            )._JOBOBJECT_BASIC_ACCOUNTING_INFORMATION
        )),
        ("close", 77),
    ]


def test_ctypes_adapter_rejects_non_unique_primary_thread_without_resuming() -> None:
    kernel = FakeKernel32(thread_ids=(55, 56))
    api = CtypesWindowsJobApi(kernel32=kernel)

    with pytest.raises(JobObjectError, match="exactly one primary thread"):
        api.resume_primary_thread(88, 1234)

    assert not any(call[0] == "resume_thread" for call in kernel.calls)
    assert ("close", 66) in kernel.calls


def test_ctypes_adapter_rejects_process_handle_pid_mismatch() -> None:
    kernel = FakeKernel32(process_pid=9876)
    api = CtypesWindowsJobApi(kernel32=kernel)

    with pytest.raises(JobObjectError, match="PID mismatch"):
        api.resume_primary_thread(88, 1234)

    assert not any(call[0] == "snapshot" for call in kernel.calls)
