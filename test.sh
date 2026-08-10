#!/usr/bin/env bash
#
# test.sh -- end-to-end smoke test for the hd-api-server REST API.
#
# Walks every endpoint in a logical order: reads first, then create, read-back,
# update, read-back, delete, and confirms the delete actually removed the row.
# Negative cases (404s) are asserted too, not just happy paths.
#
# Every record it creates uses a throwaway model/serial and is deleted again,
# including on failure or Ctrl-C (see the EXIT trap).
#
# HOW TO RUN
#
#   ./test.sh                                  # against localhost:8080
#   BASE_URL=http://localhost:9000 ./test.sh   # somewhere else
#
#   # the real-data probe defaults to a model/date that exists in the
#   # Backblaze load; override if you loaded a different range
#   REAL_MODEL=ST16000NM001G REAL_DATE=2025-10-06 ./test.sh
#
# Requires: curl, jq. Exits non-zero if any assertion fails.

set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
REAL_MODEL="${REAL_MODEL:-CT250MX500SSD1}"
REAL_DATE="${REAL_DATE:-2025-10-06}"

# Throwaway record. $$ keeps parallel runs from colliding with each other.
TEST_MODEL="ZZZ-TEST-MODEL-$$"
TEST_SERIAL="ZZZ-TEST-SERIAL-$$"
TEST_DATE="2025-10-01"          # path form, for GET/DELETE
TEST_TS="2025-10-01T00:00:00Z"  # RFC 3339 form, for JSON bodies

command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed"; exit 1; }

PASSED=0
FAILED=0
TMP_BODY="$(mktemp)"

# Always try to remove the test row, even if we bailed out early.
cleanup() {
    curl -s -o /dev/null -X DELETE \
        "$BASE_URL/drive_stats/$TEST_SERIAL/$TEST_DATE" || true
    rm -f "$TMP_BODY"
}
trap cleanup EXIT

# request METHOD PATH [JSON_BODY] -> sets HTTP_CODE, TIME_TOTAL, BODY
request() {
    local method="$1" path="$2" body="${3:-}" out
    if [ -n "$body" ]; then
        out=$(curl -s -X "$method" "$BASE_URL$path" \
            -H "Content-Type: application/json" -d "$body" \
            -o "$TMP_BODY" -w '%{http_code} %{time_total}')
    else
        out=$(curl -s -X "$method" "$BASE_URL$path" \
            -o "$TMP_BODY" -w '%{http_code} %{time_total}')
    fi
    HTTP_CODE="${out%% *}"
    TIME_TOTAL="${out##* }"
    BODY="$(cat "$TMP_BODY")"
}

# expect_status EXPECTED LABEL
expect_status() {
    local expected="$1" label="$2"
    if [ "$HTTP_CODE" = "$expected" ]; then
        PASSED=$((PASSED + 1))
        printf '  PASS  %-52s %s in %ss\n' "$label" "$HTTP_CODE" "$TIME_TOTAL"
    else
        FAILED=$((FAILED + 1))
        printf '  FAIL  %-52s expected %s, got %s\n' "$label" "$expected" "$HTTP_CODE"
        printf '        body: %s\n' "$BODY"
    fi
}

# expect_json JQ_FILTER EXPECTED LABEL  -- asserts on the last response body
expect_json() {
    local filter="$1" expected="$2" label="$3" actual
    actual="$(printf '%s' "$BODY" | jq -r "$filter" 2>/dev/null)"
    if [ "$actual" = "$expected" ]; then
        PASSED=$((PASSED + 1))
        printf '  PASS  %-52s %s = %s\n' "$label" "$filter" "$actual"
    else
        FAILED=$((FAILED + 1))
        printf '  FAIL  %-52s %s: expected %s, got %s\n' \
            "$label" "$filter" "$expected" "$actual"
    fi
}

create_body() {  # create_body FAILURE DATACENTER
    cat <<EOF
{
  "date": "$TEST_TS",
  "serial_number": "$TEST_SERIAL",
  "model": "$TEST_MODEL",
  "capacity_bytes": -1,
  "failure": $1,
  "datacenter": "$2",
  "cluster_id": "CL1",
  "vault_id": "VA1",
  "pod_id": "POD1",
  "pod_slot_num": "SLOT1",
  "is_legacy_format": false
}
EOF
}

echo "Testing $BASE_URL"
echo "Test record: model=$TEST_MODEL serial=$TEST_SERIAL date=$TEST_DATE"
echo

# --- 1. health -------------------------------------------------------------
echo "1. Health"
request GET /helloworld
expect_status 200 "GET /helloworld"
expect_json '.message' 'Hello World' "GET /helloworld body"
echo

# --- 2. rollup (the aggregate endpoint) ------------------------------------
echo "2. Rollup"
request GET /rollup_stats
expect_status 200 "GET /rollup_stats"
if [ "$HTTP_CODE" = "200" ]; then
    printf '  INFO  %-52s %s models\n' "rollup row count" \
        "$(printf '%s' "$BODY" | jq -r 'length')"
fi
echo

# --- 3. read against the real loaded data ----------------------------------
# Not a hard assertion: whether this hits depends on which quarters you loaded.
echo "3. Real-data read ($REAL_MODEL / $REAL_DATE)"
request GET "/drive_stats/$REAL_MODEL/$REAL_DATE"
case "$HTTP_CODE" in
    200) printf '  PASS  %-52s 200 in %ss\n' "GET real drive_stats" "$TIME_TOTAL"
         PASSED=$((PASSED + 1)) ;;
    404) printf '  SKIP  %-52s 404 (model/date not in your load)\n' "GET real drive_stats" ;;
    *)   printf '  FAIL  %-52s got %s\n' "GET real drive_stats" "$HTTP_CODE"
         FAILED=$((FAILED + 1)) ;;
esac
echo

# --- 4. read before create: must 404 ---------------------------------------
echo "4. Read before create"
request GET "/drive_stats/$TEST_MODEL/$TEST_DATE"
expect_status 404 "GET /drive_stats/{model}/{date} (absent)"
echo

# --- 5. create -------------------------------------------------------------
echo "5. Create"
request POST /drive_stats "$(create_body 0 DC1)"
expect_status 201 "POST /drive_stats"
expect_json '.serial_number' "$TEST_SERIAL" "POST echoes serial_number"
expect_json '.failure' '0' "POST echoes failure"
echo

# --- 6. read it back -------------------------------------------------------
echo "6. Read after create"
request GET "/drive_stats/$TEST_MODEL/$TEST_DATE"
expect_status 200 "GET /drive_stats/{model}/{date} (present)"
expect_json '.serial_number' "$TEST_SERIAL" "GET returns our row"
expect_json '.datacenter' 'DC1' "GET datacenter before update"
echo

# --- 7. update -------------------------------------------------------------
# Model and date are the lookup key, so change the mutable fields instead:
# failure 0 -> 1, datacenter DC1 -> DC2.
echo "7. Update"
request PUT /drive_stats "$(create_body 1 DC2)"
expect_status 200 "PUT /drive_stats"
expect_json '.failure' '1' "PUT applied failure"
expect_json '.datacenter' 'DC2' "PUT applied datacenter"
echo

# --- 8. confirm the update stuck -------------------------------------------
echo "8. Read after update"
request GET "/drive_stats/$TEST_MODEL/$TEST_DATE"
expect_status 200 "GET after update"
expect_json '.failure' '1' "update persisted"
echo

# --- 9. update something that doesn't exist: must 404 ----------------------
echo "9. Update absent row"
request PUT /drive_stats "$(printf '%s' "$(create_body 0 DC1)" \
    | jq -c --arg s "NOPE-$$" '.serial_number = $s')"
expect_status 404 "PUT /drive_stats (absent)"
echo

# --- 10. delete ------------------------------------------------------------
echo "10. Delete"
request DELETE "/drive_stats/$TEST_SERIAL/$TEST_DATE"
expect_status 200 "DELETE /drive_stats/{serial}/{date}"
expect_json '.message' 'drive-day deleted' "DELETE message"
echo

# --- 11. delete again + read again: both must 404 --------------------------
echo "11. Confirm cleanup"
request DELETE "/drive_stats/$TEST_SERIAL/$TEST_DATE"
expect_status 404 "DELETE again (already gone)"
request GET "/drive_stats/$TEST_MODEL/$TEST_DATE"
expect_status 404 "GET after delete"
echo

# --- summary ---------------------------------------------------------------
echo "-----------------------------------------------"
echo "passed: $PASSED   failed: $FAILED"
if [ "$FAILED" -gt 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
