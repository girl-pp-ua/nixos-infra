#!/usr/bin/env bash
# Configure Garage: cluster layout, buckets, and keys (no install/system setup).
# - Skips install/upgrade, firewall/nginx/keepalived, and other system config.
# - Assumes: garage is already installed and running locally; /etc/garage.toml already present.
# - Requires: curl and jq
#
# How to use (single-node):
#   1) Set at least GARAGE_ADMIN_TOKEN and run the script.
#
# How to use (multi-node):
#   On every node:
#     - Run this script once to print NODE_ID (it appears in logs), or retrieve with: garage node id -q
#   On the PRIMARY node only:
#     - Set PEER_NODE_IDS to a space-separated list of the other nodes' node IDs
#     - Run the script with CONNECT_PEERS=true to connect nodes and apply layout
#
# Buckets and keys:
#   - Define BUCKETS_JSON and KEYS_JSON below (or point to files via BUCKETS_FILE / KEYS_FILE).
#   - Buckets are created/updated via the Admin API.
#   - Keys are imported via the Admin API. Bucket grants for keys can optionally be done via the garage CLI
#     if available (set GRANT_ACCESS=true); adjust the grant command if your Garage version differs.

set -euo pipefail

# -------- Configuration (edit as needed) --------

GARAGE_BIN="${GARAGE_BIN:-/usr/local/bin/garage}"
GARAGE_ADMIN_API_PORT="${GARAGE_ADMIN_API_PORT:-3903}"

# Cluster layout
GARAGE_ZONE_NAME="${GARAGE_ZONE_NAME:-garage}"
GARAGE_NODE_CAPACITY="${GARAGE_NODE_CAPACITY:-15G}"

# Admin API auth
GARAGE_ADMIN_TOKEN="${GARAGE_ADMIN_TOKEN:-CHANGE_ME}"   # MUST NOT be 'SECRET' or empty

# Optional: domains (leading dots will be stripped)
GARAGE_S3_ROOT_DOMAIN="${GARAGE_S3_ROOT_DOMAIN:-s3.garage.internal}"
GARAGE_WEB_ROOT_DOMAIN="${GARAGE_WEB_ROOT_DOMAIN:-web.garage.internal}"

# Multi-node connectivity
CONNECT_PEERS="${CONNECT_PEERS:-false}"                # true on the primary node to connect peers
PEER_NODE_IDS="${PEER_NODE_IDS:-}"                     # space-separated list of peer node IDs (not including this node)

# Optional: attempt to grant bucket access to keys via CLI
GRANT_ACCESS="${GRANT_ACCESS:-false}"                  # true to attempt grants with garage CLI

# Buckets definition
# Structure example:
# [
#   {
#     "name": "garage",
#     "quotas": { "max_size": "100GiB", "max_objects": 1000000 },
#     "web_access": { "enabled": false, "index_document": "index.html", "error_document": "error.html" }
#   }
# ]
BUCKETS_JSON="${BUCKETS_JSON:-[
  {\"name\":\"garage\",\"web_access\":{\"enabled\":false}}
]}"

# Keys definition
# Structure example:
# [
#   {
#     "name": "garage",
#     "id":   "GK1234567890abcdef12345678",
#     "secret":"1234567890abcdef123456781234567890abcdef123456781234567890abcdef",
#     "buckets":[
#       {"name":"garage","access":["read","write","owner"]}
#     ]
#   }
# ]
KEYS_JSON="${KEYS_JSON:-[
  {\"name\":\"garage\",\"id\":\"GK1234567890abcdef12345678\",\"secret\":\"1234567890abcdef123456781234567890abcdef123456781234567890abcdef\",\"buckets\":[{\"name\":\"garage\",\"access\":[\"read\",\"write\",\"owner\"]}]}
]}"

# Or load from files (if set). If both provided, files take precedence.
BUCKETS_FILE="${BUCKETS_FILE:-}"
KEYS_FILE="${KEYS_FILE:-}"

# -------- End configuration --------

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required binary '$1' not found in PATH." >&2
    exit 1
  fi
}

jq_field() {
  # jq wrapper that fails if path missing
  local json="$1" path="$2"
  echo "$json" | jq -er "$path"
}

http_get() {
  local url="$1"
  curl -fsSL -H "Authorization: Bearer ${GARAGE_ADMIN_TOKEN}" "$url"
}

http_get_allow_404() {
  local url="$1"
  set +e
  local out
  out=$(curl -sS -H "Authorization: Bearer ${GARAGE_ADMIN_TOKEN}" -w '\n%{http_code}' "$url")
  local code="${out##*$'\n'}"
  local body="${out%$'\n'*}"
  echo "$code" "$body"
  set -e
}

http_post_json() {
  local url="$1" body="$2"
  curl -fsSL -H "Authorization: Bearer ${GARAGE_ADMIN_TOKEN}" -H "Content-Type: application/json" -X POST -d "$body" "$url"
}

http_put_json() {
  local url="$1" body="$2"
  curl -fsSL -H "Authorization: Bearer ${GARAGE_ADMIN_TOKEN}" -H "Content-Type: application/json" -X PUT -d "$body" "$url"
}

strip_leading_dot() {
  # strips leading dots if any
  echo "${1#.}"
}

validate_secrets() {
  if [[ -z "${GARAGE_ADMIN_TOKEN}" || "${GARAGE_ADMIN_TOKEN}" == "SECRET" || "${GARAGE_ADMIN_TOKEN}" == "CHANGE_ME" ]]; then
    echo "ERROR: GARAGE_ADMIN_TOKEN must be set to a non-default value." >&2
    exit 1
  fi
}

load_json_inputs() {
  if [[ -n "$BUCKETS_FILE" ]]; then
    BUCKETS_JSON="$(cat "$BUCKETS_FILE")"
  fi
  if [[ -n "$KEYS_FILE" ]]; then
    KEYS_JSON="$(cat "$KEYS_FILE")"
  fi
  # Validate that they are JSON arrays
  echo "$BUCKETS_JSON" | jq -e 'assert(type=="array")' >/dev/null
  echo "$KEYS_JSON"    | jq -e 'assert(type=="array")' >/dev/null
}

main() {
  require_bin "$GARAGE_BIN"
  require_bin curl
  require_bin jq

  validate_secrets
  GARAGE_S3_ROOT_DOMAIN="$(strip_leading_dot "$GARAGE_S3_ROOT_DOMAIN")"
  GARAGE_WEB_ROOT_DOMAIN="$(strip_leading_dot "$GARAGE_WEB_ROOT_DOMAIN")"

  load_json_inputs

  echo "== Garage configuration start =="
  echo "Admin API port: ${GARAGE_ADMIN_API_PORT}"
  echo "Zone name: ${GARAGE_ZONE_NAME}"
  echo "Node capacity: ${GARAGE_NODE_CAPACITY}"
  echo "S3 root domain: ${GARAGE_S3_ROOT_DOMAIN}"
  echo "Web root domain: ${GARAGE_WEB_ROOT_DOMAIN}"
  echo

  # Get local node ID
  local NODE_ID
  NODE_ID="$("$GARAGE_BIN" node id -q)"
  echo "Local NODE_ID: ${NODE_ID}"

  # Optionally connect peers (primary node)
  if [[ "${CONNECT_PEERS}" == "true" ]]; then
    if [[ -z "${PEER_NODE_IDS}" ]]; then
      echo "CONNECT_PEERS=true but no PEER_NODE_IDS provided; skipping connect." >&2
    else
      echo "Connecting peers from primary node..."
      for peer in ${PEER_NODE_IDS}; do
        echo "  garage node connect ${peer}"
        "$GARAGE_BIN" node connect "${peer}"
      done
    fi
  fi

  # Assign layout for this node (use node ID prefix before '@')
  local NODE_SHORT="${NODE_ID%%@*}"
  echo "Assigning layout for node ${NODE_SHORT} (zone=${GARAGE_ZONE_NAME}, capacity=${GARAGE_NODE_CAPACITY})"
  "$GARAGE_BIN" layout assign "${NODE_SHORT}" -z "${GARAGE_ZONE_NAME}" -c "${GARAGE_NODE_CAPACITY}"

  # Read current layout version and apply new version (+1)
  echo "Fetching current layout version via Admin API..."
  local layout_resp layout_version new_version
  layout_resp="$(http_get "http://127.0.0.1:${GARAGE_ADMIN_API_PORT}/v1/layout")"
  layout_version="$(jq_field "$layout_resp" '.version | tonumber')"
  new_version="$((layout_version + 1))"
  echo "Applying layout with version=${new_version}"
  "$GARAGE_BIN" layout apply --version "${new_version}"

  # Buckets: create/update
  echo
  echo "== Buckets =="
  local buckets_count
  buckets_count="$(echo "$BUCKETS_JSON" | jq 'length')"
  echo "Configured buckets: ${buckets_count}"

  for i in $(seq 0 $((buckets_count - 1))); do
    local b name
    b="$(echo "$BUCKETS_JSON" | jq ".[$i]")"
    name="$(jq_field "$b" '.name | strings')"
    echo "-- Bucket: ${name}"

    # GET current details (allow 404)
    read -r code body < <(http_get_allow_404 "http://127.0.0.1:${GARAGE_ADMIN_API_PORT}/v1/bucket?globalAlias=$(printf %s "$name" | jq -sRr @uri)")
    local bucket_id
    if [[ "$code" == "404" ]]; then
      echo "  Not found; creating..."
      body="$(http_post_json "http://127.0.0.1:${GARAGE_ADMIN_API_PORT}/v1/bucket" "$(jq -nc --arg n "$name" '{globalAlias:$n}')")"
      bucket_id="$(jq_field "$body" '.id')"
    elif [[ "$code" == "200" ]]; then
      bucket_id="$(echo "$body" | jq -er '.id')"
      echo "  Exists with id=${bucket_id}"
    else
      echo "ERROR: Unexpected status ${code} for GET bucket ${name}" >&2
      exit 1
    fi

    # Build update payload
    # quotas
    local quotas max_size max_objects
    max_size="$(echo "$b" | jq -er '.quotas.max_size // empty' || true)"
    max_objects="$(echo "$b" | jq -er '.quotas.max_objects // empty' || true)"
    quotas="$(jq -nc \
      --arg ms "${max_size:-}" --argjson have_ms "$( [[ -n "${max_size:-}" ]] && echo true || echo false )" \
      --arg mo "${max_objects:-}" --argjson have_mo "$( [[ -n "${max_objects:-}" ]] && echo true || echo false )" \
      '{
        quotas: ( ( ( $have_ms | if . then {maxSize:$ms} else {} end )
                  + ( $have_mo | if . then {maxObjects:($mo|tonumber? // $mo)} else {} end ) ) )
       }' \
    )"

    # web_access (if provided)
    local web_enabled index_document error_document web_access
    web_enabled="$(echo "$b" | jq -er '.web_access.enabled // empty' || true)"
    index_document="$(echo "$b" | jq -er '.web_access.index_document // empty' || true)"
    error_document="$(echo "$b" | jq -er '.web_access.error_document // empty' || true)"

    if echo "$b" | jq -e 'has("web_access")' >/dev/null; then
      web_access="$(jq -nc \
        --argjson enabled "$( [[ -n "${web_enabled:-}" ]] && echo "$web_enabled" || echo false )" \
        --arg idx "${index_document:-index.html}" \
        --arg err "${error_document:-error.html}" \
        '{ web: { enabled:$enabled, index_document:$idx, error_document:$err } }' \
      )"
    else
      web_access='{}'
    fi

    local update_payload
    update_payload="$(jq -n --arg id "$bucket_id" \
      --argjson q "$quotas" \
      --argjson w "$web_access" \
      '$q * $w' \
    )"

    echo "  Updating settings for bucket id=${bucket_id}"
    http_put_json "http://127.0.0.1:${GARAGE_ADMIN_API_PORT}/v1/bucket?id=$(printf %s "$bucket_id" | jq -sRr @uri)" "$update_payload" >/dev/null
    echo "  Done."
  done

  # Keys: import, then optionally grant access via CLI
  echo
  echo "== Keys =="
  local keys_count
  keys_count="$(echo "$KEYS_JSON" | jq 'length')"
  echo "Configured keys: ${keys_count}"

  for i in $(seq 0 $((keys_count - 1))); do
    local k name kid secret
    k="$(echo "$KEYS_JSON" | jq ".[$i]")"
    name="$(jq_field "$k" '.name | strings')"
    kid="$(jq_field "$k" '.id | strings')"
    secret="$(jq_field "$k" '.secret | strings')"

    # Validate formats
    if ! [[ "$kid" =~ ^GK[a-f0-9]{24}$ ]]; then
      echo "ERROR: Key ID '${kid}' must match ^GK[a-f0-9]{24}$" >&2
      exit 1
    fi
    if ! [[ "$secret" =~ ^[a-f0-9]{64}$ ]]; then
      echo "ERROR: Key secret for '${kid}' must match ^[a-f0-9]{64}$" >&2
      exit 1
    fi

    echo "-- Key: ${name} (${kid})"

    # GET key (allow 404)
    read -r code body < <(http_get_allow_404 "http://127.0.0.1:${GARAGE_ADMIN_API_PORT}/v1/key?id=$(printf %s "$kid" | jq -sRr @uri)")
    if [[ "$code" == "404" ]]; then
      echo "  Not found; importing..."
      local import_payload
      import_payload="$(jq -nc --arg n "$name" --arg id "$kid" --arg sec "$secret" \
        '{name:$n, accessKeyId:$id, secretAccessKey:$sec}')"
      http_post_json "http://127.0.0.1:${GARAGE_ADMIN_API_PORT}/v1/key/import" "$import_payload" >/dev/null
      echo "  Imported."
    elif [[ "$code" == "200" ]]; then
      echo "  Exists."
    else
      echo "ERROR: Unexpected status ${code} for GET key ${kid}" >&2
      exit 1
    fi

    # Optional: grant access to buckets via CLI
    if [[ "${GRANT_ACCESS}" == "true" ]]; then
      if echo "$k" | jq -e 'has("buckets") and (.buckets | type=="array") and (.buckets|length>0)' >/dev/null; then
        local bcount
        bcount="$(echo "$k" | jq '.buckets | length')"
        for j in $(seq 0 $((bcount - 1))); do
          local bk bname
          bk="$(echo "$k" | jq ".buckets[$j]")"
          bname="$(jq_field "$bk" '.name | strings')"

          # Build access flags
          local access_flags=""
          if echo "$bk" | jq -e '.access | index("read")' >/dev/null; then
            access_flags+=" --read"
          fi
          if echo "$bk" | jq -e '.access | index("write")' >/dev/null; then
            access_flags+=" --write"
          fi
          if echo "$bk" | jq -e '.access | index("owner")' >/dev/null; then
            access_flags+=" --owner"
          fi

          if [[ -z "$access_flags" ]]; then
            echo "  Skipping grant for bucket '${bname}' (no access specified)."
            continue
          fi

          # NOTE: Adjust this command to your garage CLI version if needed.
          # Common pattern: "garage bucket allow --key <KEY_ID> [--read] [--write] [--owner] <BUCKET>"
          echo "  Granting${access_flags} on bucket '${bname}' to key '${kid}'"
          set +e
          $GARAGE_BIN bucket allow --key "$kid" $access_flags "$bname"
          rc=$?
          set -e
          if [[ $rc -ne 0 ]]; then
            echo "  WARNING: Grant command failed for key='${kid}' bucket='${bname}'. Please verify CLI syntax for your Garage version." >&2
          fi
        done
      fi
    fi
  done

  echo
  echo "== Done =="
}

main "$@"
