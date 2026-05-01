#!/usr/bin/env bash
# check_phase_state_staleness.sh
#
# Reads the `Updated (UTC)` row from paperclip/governance/PHASE_STATE.md
# and reports staleness vs the DL-053 R-053-1 threshold (6 hours).
#
# Usage:   scripts/check_phase_state_staleness.sh [--threshold-hours N] [--file PATH]
# Exit:    0 = fresh, 1 = stale (escalation due), 2 = unreadable / schema break
# Output:  one JSON line on stdout (always); human messages on stderr
#
# JSON shape:
#   {"status": "fresh|stale|error",
#    "file": "<path>",
#    "updated_utc": "<ISO8601 or null>",
#    "now_utc": "<ISO8601>",
#    "age_hours": <float or null>,
#    "threshold_hours": <int>,
#    "escalation_class": "Class-2 (DL-053 R-053-1)" | null,
#    "error": "<string or null>"}
#
# Authority: DL-053 R-053-1 (CEO operating contract — PHASE_STATE.md > 6 h
#            stale = Class-2 escalation per processes/12-board-escalation.md).
# Owner:     Documentation-KM. Schema contract: processes/20-phase-state-maintenance.md.
#
# Wiring:    initial wiring is CEO-heartbeat preflight (CEO runs at top of
#            every heartbeat). A Paperclip routine is a follow-up — see
#            processes/20-phase-state-maintenance.md § Wiring options.

set -u

THRESHOLD_HOURS=6
FILE_PATH="C:/QM/paperclip/governance/PHASE_STATE.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold-hours)
      THRESHOLD_HOURS="$2"
      shift 2
      ;;
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,30p' "$0" >&2
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

emit_error() {
  local msg="$1"
  local now_iso
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"status":"error","file":"%s","updated_utc":null,"now_utc":"%s","age_hours":null,"threshold_hours":%d,"escalation_class":null,"error":"%s"}\n' \
    "$FILE_PATH" "$now_iso" "$THRESHOLD_HOURS" "$msg"
  echo "PHASE_STATE staleness check ERROR: $msg" >&2
  exit 2
}

[[ -r "$FILE_PATH" ]] || emit_error "file not readable: $FILE_PATH"

# Extract `Updated (UTC)` row from the Live Entry table.
# Expected line shape:
#   | **Updated (UTC)** | 2026-05-01T09:35Z |
# We tolerate optional `**` markdown bold around the field name and trim
# surrounding whitespace from the value.
UPDATED_LINE="$(grep -E '^\| \*?\*?Updated \(UTC\)\*?\*? \|' "$FILE_PATH" | head -n 1 || true)"
[[ -n "$UPDATED_LINE" ]] || emit_error "no Updated (UTC) row found in $FILE_PATH"

UPDATED_RAW="$(printf '%s' "$UPDATED_LINE" \
  | awk -F'|' '{print $3}' \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[[ -n "$UPDATED_RAW" ]] || emit_error "Updated (UTC) value is empty"

# Accept both `YYYY-MM-DDTHH:MMZ` and `YYYY-MM-DDTHH:MM:SSZ`.
# Normalize to `YYYY-MM-DDTHH:MM:SSZ` for parsing.
if [[ "$UPDATED_RAW" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2})(:[0-9]{2})?Z$ ]]; then
  if [[ -z "${BASH_REMATCH[2]:-}" ]]; then
    UPDATED_NORM="${BASH_REMATCH[1]}:00Z"
  else
    UPDATED_NORM="${BASH_REMATCH[1]}${BASH_REMATCH[2]}Z"
  fi
else
  emit_error "Updated (UTC) value '$UPDATED_RAW' is not ISO-8601 YYYY-MM-DDTHH:MM[:SS]Z"
fi

UPDATED_EPOCH="$(date -u -d "$UPDATED_NORM" +%s 2>/dev/null || true)"
[[ -n "$UPDATED_EPOCH" ]] || emit_error "could not parse Updated (UTC) '$UPDATED_NORM' to epoch"

NOW_EPOCH="$(date -u +%s)"
NOW_ISO="$(date -u -d "@$NOW_EPOCH" +%Y-%m-%dT%H:%M:%SZ)"

AGE_SEC=$((NOW_EPOCH - UPDATED_EPOCH))
# Bash float via awk
AGE_HOURS="$(awk -v s="$AGE_SEC" 'BEGIN{printf "%.2f", s/3600.0}')"
THRESHOLD_SEC=$((THRESHOLD_HOURS * 3600))

# Tolerate up to 15 min of clock skew (file written on a slightly fast clock,
# or rounded-to-nearest-minute by editor). Larger future deltas are real errors.
FUTURE_TOLERANCE_SEC=900
if (( AGE_SEC < -FUTURE_TOLERANCE_SEC )); then
  emit_error "Updated (UTC) is more than 15 min in the future ($UPDATED_NORM > $NOW_ISO)"
fi
if (( AGE_SEC < 0 )); then
  AGE_SEC=0
  AGE_HOURS="0.00"
fi

if (( AGE_SEC <= THRESHOLD_SEC )); then
  printf '{"status":"fresh","file":"%s","updated_utc":"%s","now_utc":"%s","age_hours":%s,"threshold_hours":%d,"escalation_class":null,"error":null}\n' \
    "$FILE_PATH" "$UPDATED_NORM" "$NOW_ISO" "$AGE_HOURS" "$THRESHOLD_HOURS"
  echo "PHASE_STATE fresh: age=${AGE_HOURS}h threshold=${THRESHOLD_HOURS}h" >&2
  exit 0
else
  printf '{"status":"stale","file":"%s","updated_utc":"%s","now_utc":"%s","age_hours":%s,"threshold_hours":%d,"escalation_class":"Class-2 (DL-053 R-053-1)","error":null}\n' \
    "$FILE_PATH" "$UPDATED_NORM" "$NOW_ISO" "$AGE_HOURS" "$THRESHOLD_HOURS"
  echo "PHASE_STATE STALE: age=${AGE_HOURS}h threshold=${THRESHOLD_HOURS}h — Class-2 escalation due (DL-053 R-053-1)" >&2
  exit 1
fi
