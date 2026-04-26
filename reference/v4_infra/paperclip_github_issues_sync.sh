#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${PAPERCLIP_API_URL:?PAPERCLIP_API_URL is required}"
: "${PAPERCLIP_API_KEY:?PAPERCLIP_API_KEY is required}"
: "${PAPERCLIP_COMPANY_ID:?PAPERCLIP_COMPANY_ID is required}"

GITHUB_REPO="${GITHUB_REPO:-QuantMechanica/quantmechanica-ops}"
PAPERCLIP_ISSUE_STATUSES="${PAPERCLIP_ISSUE_STATUSES:-todo,in_progress,in_review,blocked,done,cancelled,backlog}"
PAPERCLIP_UI_BASE_URL="${PAPERCLIP_UI_BASE_URL:-${PAPERCLIP_API_URL}}"
SYNC_STATE_PATH="${SYNC_STATE_PATH:-${XDG_STATE_HOME:-$HOME/.local/state}/quantmechanica/paperclip_github_issues_sync_state.json}"
DRY_RUN="${DRY_RUN:-0}"
PAPERCLIP_IDENTIFIER_FILTER="${PAPERCLIP_IDENTIFIER_FILTER:-}"
LOCK_DIR="${SYNC_STATE_PATH}.lock"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log "missing required command: ${command_name}"
    exit 1
  fi
}

ensure_state_file() {
  local state_dir
  state_dir="$(dirname "$SYNC_STATE_PATH")"
  mkdir -p "$state_dir"
  if [[ ! -f "$SYNC_STATE_PATH" ]]; then
    cat >"$SYNC_STATE_PATH" <<'EOF'
{
  "schema_version": 1,
  "updated_at": null,
  "issues": {}
}
EOF
  fi
  jq -e '.schema_version == 1 and (.issues | type == "object")' "$SYNC_STATE_PATH" >/dev/null
}

acquire_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "lock exists at ${LOCK_DIR}. another sync may be active."
    exit 1
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
}

fetch_paperclip_issues() {
  curl -fsS \
    -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" \
    "${PAPERCLIP_API_URL%/}/api/companies/${PAPERCLIP_COMPANY_ID}/issues?status=${PAPERCLIP_ISSUE_STATUSES}"
}

search_github_issue_number() {
  local paperclip_issue_id="$1"
  gh api -X GET search/issues \
    -f "q=repo:${GITHUB_REPO} is:issue in:body paperclip-issue-id:${paperclip_issue_id}" \
    --jq '.items[0].number // empty'
}

create_github_issue() {
  local issue_json="$1"
  local temp_file
  local paperclip_issue_id
  local identifier
  local title
  local status
  local priority
  local updated_at
  local description
  local prefix
  local source_url
  local gh_title
  local issue_url
  local number

  paperclip_issue_id="$(jq -r '.id' <<<"$issue_json")"
  identifier="$(jq -r '.identifier // .id' <<<"$issue_json")"
  title="$(jq -r '.title // "(no title)"' <<<"$issue_json")"
  status="$(jq -r '.status // "unknown"' <<<"$issue_json")"
  priority="$(jq -r '.priority // "unknown"' <<<"$issue_json")"
  updated_at="$(jq -r '.updatedAt // ""' <<<"$issue_json")"
  description="$(jq -r '.description // ""' <<<"$issue_json")"
  description="$(printf '%s\n' "$description" | awk 'NR<=40 { print }')"

  prefix="${identifier%%-*}"
  source_url="${PAPERCLIP_UI_BASE_URL%/}/${prefix}/issues/${identifier}"
  gh_title="[${identifier}] ${title}"
  if ((${#gh_title} > 240)); then
    gh_title="${gh_title:0:237}..."
  fi

  temp_file="$(mktemp)"
  cat >"$temp_file" <<EOF
Paperclip issue mirror (interim one-way sync). Source of truth remains Paperclip.

- Paperclip identifier: \`${identifier}\`
- Paperclip issue id: \`${paperclip_issue_id}\`
- Paperclip status: \`${status}\`
- Paperclip priority: \`${priority}\`
- Paperclip updated at: \`${updated_at}\`
- Paperclip URL: ${source_url}

### Paperclip Description Snapshot
${description}

<!-- paperclip-issue-id:${paperclip_issue_id} -->
EOF

  issue_url="$(gh issue create --repo "$GITHUB_REPO" --title "$gh_title" --body-file "$temp_file")"
  rm -f "$temp_file"
  number="${issue_url##*/}"
  printf '%s\n' "$number"
}

status_comment_exists() {
  local github_issue_number="$1"
  local marker="$2"
  local count
  count="$(gh api "repos/${GITHUB_REPO}/issues/${github_issue_number}/comments" --paginate --jq --arg marker "$marker" '[.[] | select(.body | contains($marker))] | length')"
  [[ "$count" -gt 0 ]]
}

post_status_comment() {
  local github_issue_number="$1"
  local identifier="$2"
  local old_status="$3"
  local new_status="$4"
  local updated_at="$5"
  local source_url="$6"
  local paperclip_issue_id="$7"
  local marker
  local body

  marker="paperclip-sync-status:${paperclip_issue_id}:${new_status}:${updated_at}"
  if status_comment_exists "$github_issue_number" "$marker"; then
    log "skip duplicate status comment for ${identifier} (${new_status})"
    return 0
  fi

  body=$(
    cat <<EOF
Paperclip status update for \`${identifier}\`

- Previous status: \`${old_status}\`
- Current status: \`${new_status}\`
- Paperclip updated at: \`${updated_at}\`
- Source: ${source_url}

<!-- ${marker} -->
EOF
  )
  gh issue comment "$github_issue_number" --repo "$GITHUB_REPO" --body "$body" >/dev/null
}

update_state_entry() {
  local paperclip_issue_id="$1"
  local identifier="$2"
  local title="$3"
  local github_issue_number="$4"
  local status="$5"
  local updated_at="$6"
  local temp_state

  temp_state="$(mktemp)"
  jq \
    --arg issue_id "$paperclip_issue_id" \
    --arg identifier "$identifier" \
    --arg title "$title" \
    --arg github_issue_number "$github_issue_number" \
    --arg status "$status" \
    --arg updated_at "$updated_at" \
    '.issues[$issue_id] = {
      paperclip_identifier: $identifier,
      paperclip_title: $title,
      github_issue_number: ($github_issue_number | tonumber),
      last_synced_status: $status,
      last_synced_updated_at: $updated_at
    }' \
    "$SYNC_STATE_PATH" >"$temp_state"
  mv "$temp_state" "$SYNC_STATE_PATH"
}

update_state_timestamp() {
  local temp_state
  temp_state="$(mktemp)"
  jq --arg ts "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" '.updated_at = $ts' "$SYNC_STATE_PATH" >"$temp_state"
  mv "$temp_state" "$SYNC_STATE_PATH"
}

main() {
  local issues_json
  local issue_count
  local created_count
  local commented_count
  local recovered_count
  local issue_json
  local paperclip_issue_id
  local identifier
  local title
  local status
  local updated_at
  local previous_status
  local mapped_number
  local source_url
  local prefix

  require_command curl
  require_command jq
  if [[ "$DRY_RUN" != "1" ]]; then
    require_command gh
  fi

  ensure_state_file
  acquire_lock

  log "sync start: repo=${GITHUB_REPO} state=${SYNC_STATE_PATH} dry_run=${DRY_RUN}"
  issues_json="$(fetch_paperclip_issues)"
  issue_count="$(jq 'length' <<<"$issues_json")"
  created_count=0
  commented_count=0
  recovered_count=0

  while IFS= read -r issue_json; do
    paperclip_issue_id="$(jq -r '.id' <<<"$issue_json")"
    identifier="$(jq -r '.identifier // .id' <<<"$issue_json")"
    title="$(jq -r '.title // "(no title)"' <<<"$issue_json")"
    status="$(jq -r '.status // "unknown"' <<<"$issue_json")"
    updated_at="$(jq -r '.updatedAt // ""' <<<"$issue_json")"

    if [[ -n "$PAPERCLIP_IDENTIFIER_FILTER" && "$identifier" != "$PAPERCLIP_IDENTIFIER_FILTER" ]]; then
      continue
    fi

    prefix="${identifier%%-*}"
    source_url="${PAPERCLIP_UI_BASE_URL%/}/${prefix}/issues/${identifier}"

    mapped_number="$(jq -r --arg issue_id "$paperclip_issue_id" '.issues[$issue_id].github_issue_number // empty' "$SYNC_STATE_PATH")"
    previous_status="$(jq -r --arg issue_id "$paperclip_issue_id" '.issues[$issue_id].last_synced_status // empty' "$SYNC_STATE_PATH")"

    if [[ -z "$mapped_number" ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        mapped_number="0"
        log "dry-run create: ${identifier} -> [new GitHub issue]"
      else
        mapped_number="$(search_github_issue_number "$paperclip_issue_id")"
        if [[ -n "$mapped_number" ]]; then
          recovered_count=$((recovered_count + 1))
          log "recovered mapping: ${identifier} -> #${mapped_number}"
        else
          mapped_number="$(create_github_issue "$issue_json")"
          created_count=$((created_count + 1))
          log "created GitHub issue: ${identifier} -> #${mapped_number}"
        fi
      fi
    fi

    if [[ -n "$previous_status" && "$previous_status" != "$status" ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        log "dry-run comment: ${identifier} status ${previous_status} -> ${status}"
      else
        post_status_comment "$mapped_number" "$identifier" "$previous_status" "$status" "$updated_at" "$source_url" "$paperclip_issue_id"
        commented_count=$((commented_count + 1))
        log "commented status change: ${identifier} ${previous_status} -> ${status}"
      fi
    fi

    if [[ "$DRY_RUN" != "1" ]]; then
      update_state_entry "$paperclip_issue_id" "$identifier" "$title" "$mapped_number" "$status" "$updated_at"
    fi
  done < <(jq -c '.[] | select(.hiddenAt == null)' <<<"$issues_json")

  if [[ "$DRY_RUN" != "1" ]]; then
    update_state_timestamp
  fi

  log "sync done: paperclip_issues=${issue_count} created=${created_count} recovered=${recovered_count} status_comments=${commented_count}"
}

main "$@"
