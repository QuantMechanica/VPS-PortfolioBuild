"""Antigravity agent-army: reverse-engineer a whole YouTube channel's strategy.

OWNER 2026-06-30: reverse-engineer the 'UnconventionalForexTrading' channel
(the 'T-WIN' / 'U.F.O.' BASKET forex strategy). Enumerate handled by yt-dlp
(VIDEO_MANIFEST.txt); this script fans an ARMY of headless agy (Antigravity)
instances over the videos in batches (each watches its batch + writes an
analysis), then runs one synthesis pass to reconstruct the full strategy.

agy is the only agent that can watch YouTube here (the VPS IP is bot-blocked;
agy uses Google infra). Each batch runs under the ConPTY runner (agy hangs on
non-TTY stdout). Auth = Windows Credential Manager (gemini:antigravity), so this
must run as Administrator (detached Start-Process, not the kill-prone harness).

  python antigravity_channel_harvest.py            # full run (all batches + synth)
  python antigravity_channel_harvest.py --batch 4 --concurrency 3
  python antigravity_channel_harvest.py --synth-only
"""
from __future__ import annotations
import argparse, datetime as dt, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(r"C:\QM\repo")
OUT = REPO / "docs" / "research" / "unconventional_forex"
LOGS = OUT / "logs"
PY = Path(r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe")
AGY = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\Administrator\AppData\Local")) / "agy" / "bin" / "agy.exe"
CONPTY = REPO / "tools" / "strategy_farm" / "agy_conpty_run.py"
PROGRESS = OUT / "HARVEST_PROGRESS.log"
CHANNEL = "UnconventionalForexTrading"
STRATEGY = "T-WIN / U.F.O. basket forex strategy (forex hedging + mathematical/Excel analysis, London session)"


def log(msg: str) -> None:
    line = f"[{dt.datetime.now().isoformat(timespec='seconds')}] {msg}"
    print(line, flush=True)
    with PROGRESS.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def agy_env() -> dict:
    env = os.environ.copy()
    env.update(USERPROFILE=r"C:\Users\Administrator", HOME=r"C:\Users\Administrator",
               HOMEDRIVE="C:", HOMEPATH=r"\Users\Administrator", QM_AGENT_ID="gemini",
               TERM="dumb", NO_COLOR="1", CI="1")
    return env


def read_manifest() -> list[tuple[str, str]]:
    raw = (OUT / "_raw_list.txt").read_text(encoding="utf-8", errors="replace").splitlines()
    vids = []
    for line in raw:
        line = line.strip()
        if not line or "|" not in line:
            continue
        vid, _, title = line.partition("|")
        vids.append((vid.strip(), title.strip()))
    vids.reverse()  # oldest-first: follow the strategy's evolution
    return vids


def run_agy(instruction: str, log_path: Path, timeout_min: int) -> int:
    cmd = [str(PY), str(CONPTY), str(AGY), "--dangerously-skip-permissions",
           "--print-timeout", f"{timeout_min}m", "--add-dir", str(REPO), "--add-dir", str(OUT),
           "-p", instruction]
    with log_path.open("wb") as lf:
        try:
            p = subprocess.Popen(cmd, cwd=str(REPO), stdin=open(os.devnull, "rb"),
                                 stdout=lf, stderr=subprocess.STDOUT, env=agy_env(),
                                 creationflags=subprocess.CREATE_NO_WINDOW)
            return p.wait(timeout=timeout_min * 60 + 120)
        except subprocess.TimeoutExpired:
            try:
                p.kill()
            except Exception:
                pass
            return 124
        except Exception as exc:
            lf.write(f"\nLAUNCH ERROR: {exc!r}\n".encode())
            return 1


def run_batch(idx: int, batch: list[tuple[str, str]], timeout_min: int) -> dict:
    outfile = OUT / f"batch_{idx:02d}.md"
    vids = "\n".join(f"- https://www.youtube.com/watch?v={v} ({t})" for v, t in batch)
    instr = (
        f"You are reverse-engineering the YouTube channel '{CHANNEL}' — its {STRATEGY}. "
        f"Watch/skim these {len(batch)} videos and extract EVERY concrete strategy detail:\n{vids}\n\n"
        "Extract precisely: (1) currency pairs / basket composition; (2) entry & exit rules; "
        "(3) the hedging / basket / recovery logic (how positions are opened, hedged, closed as a group); "
        "(4) position sizing + the 'mathematical analysis' / Excel formulas and any numbers shown; "
        "(5) timeframe & session (London?); (6) risk management & targets; (7) any on-screen ratios, "
        "formulas, settings, or EA parameters. Quote specifics and timestamps where possible. "
        f"Write a detailed markdown analysis to the file '{outfile.as_posix()}'. Then exit."
    )
    log(f"batch {idx:02d}: launching agy on {len(batch)} videos")
    rc = run_agy(instr, LOGS / f"batch_{idx:02d}.log", timeout_min)
    ok = outfile.exists() and outfile.stat().st_size > 200
    log(f"batch {idx:02d}: rc={rc} wrote={ok} ({outfile.stat().st_size if outfile.exists() else 0} bytes)")
    return {"idx": idx, "rc": rc, "ok": ok, "file": str(outfile)}


def synthesize(timeout_min: int) -> dict:
    final = OUT / "T-WIN_STRATEGY_RECONSTRUCTION_2026-06-30.md"
    instr = (
        f"Read ALL files matching '{(OUT / 'batch_*.md').as_posix()}' — they are per-video analyses of "
        f"the '{CHANNEL}' channel's {STRATEGY}, in chronological order (batch_01 = oldest videos). "
        "Synthesize the COMPLETE strategy as one coherent system: exact currency-pair basket; the full "
        "entry/exit/hedging/recovery logic; the mathematical/Excel position-sizing model with formulas; "
        "session & timeframe; risk rules & targets; and how the strategy evolved from the early 'U.F.O.' "
        "hedging EA to the later 'T-WIN' math-analysis version. THEN assess rebuilding it as a deterministic "
        "MT5 Expert Advisor: list exactly what we'd code, and CRITICALLY flag any grid / martingale / "
        "averaging-down / hedging-recovery elements — QuantMechanica V5 FORBIDS those — and state whether a "
        "compliant (bounded-risk, hard-SL, no-recovery) version of the edge is possible, and what it would be. "
        f"Write the full reconstruction to '{final.as_posix()}'. Then exit."
    )
    log("synthesis: launching agy over all batch analyses")
    rc = run_agy(instr, LOGS / "synthesis.log", timeout_min)
    ok = final.exists() and final.stat().st_size > 400
    log(f"synthesis: rc={rc} wrote={ok} -> {final}")
    return {"rc": rc, "ok": ok, "file": str(final)}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--batch", type=int, default=4)
    ap.add_argument("--concurrency", type=int, default=3)
    ap.add_argument("--batch-timeout-min", type=int, default=30)
    ap.add_argument("--synth-timeout-min", type=int, default=30)
    ap.add_argument("--synth-only", action="store_true")
    ap.add_argument("--limit", type=int, default=0, help="only first N videos (validation)")
    args = ap.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)

    if not AGY.exists():
        log(f"FATAL: agy not found at {AGY}")
        return 2

    if not args.synth_only:
        vids = read_manifest()
        if args.limit:
            vids = vids[: args.limit]
        batches = [vids[i:i + args.batch] for i in range(0, len(vids), args.batch)]
        log(f"START army: {len(vids)} videos, {len(batches)} batches, concurrency={args.concurrency}")
        results = []
        with ThreadPoolExecutor(max_workers=args.concurrency) as ex:
            futs = [ex.submit(run_batch, i + 1, b, args.batch_timeout_min) for i, b in enumerate(batches)]
            for f in futs:
                results.append(f.result())
        ok = sum(1 for r in results if r["ok"])
        log(f"batches done: {ok}/{len(batches)} ok")
        # one retry for failed batches
        failed = [r["idx"] for r in results if not r["ok"]]
        if failed:
            log(f"retrying {len(failed)} failed batches: {failed}")
            with ThreadPoolExecutor(max_workers=args.concurrency) as ex:
                futs = [ex.submit(run_batch, i, batches[i - 1], args.batch_timeout_min) for i in failed]
                for f in futs:
                    f.result()

    s = synthesize(args.synth_timeout_min)
    log(f"HARVEST COMPLETE. reconstruction ok={s['ok']} -> {s['file']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
