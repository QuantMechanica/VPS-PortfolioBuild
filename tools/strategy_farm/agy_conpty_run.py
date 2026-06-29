"""Run a command (the Antigravity CLI 'agy') under a Windows ConPTY via pywinpty.

agy HANGS when its stdout is not a TTY (redirected file/pipe in headless/CI/cron).
A real pseudo-console is required. winpty.exe itself refuses a non-TTY stdout, but
pywinpty's ConPTY gives the CHILD a real pty regardless of THIS process's stdout —
so the caller can safely capture our stdout to a normal file/pipe.

We forward the child's pty output to our own stdout and exit with the child's code.

Usage: python agy_conpty_run.py <command> [args...]
Proven 2026-06-29: agy wrote its self-test marker headless in ~20s via this path.
"""
import sys


def main() -> int:
    argv = sys.argv[1:]
    if not argv:
        sys.stderr.write("agy_conpty_run: no command given\n")
        return 2
    try:
        import winpty  # pywinpty
    except Exception as e:  # pragma: no cover
        sys.stderr.write(f"agy_conpty_run: pywinpty unavailable: {e!r}\n")
        return 3
    try:
        proc = winpty.PtyProcess.spawn(argv)
    except Exception as e:
        sys.stderr.write(f"agy_conpty_run: spawn failed: {e!r}\n")
        return 4
    out = sys.stdout
    while True:
        if not proc.isalive():
            break
        try:
            data = proc.read(4096)
        except EOFError:
            break
        except Exception:
            break
        if data:
            try:
                out.write(data)
                out.flush()
            except Exception:
                pass
    try:
        code = proc.exitstatus
    except Exception:
        code = None
    return int(code) if isinstance(code, int) else 0


if __name__ == "__main__":
    raise SystemExit(main())
