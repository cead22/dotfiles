#!/bin/bash
# Opens Victoria Logs VMUI tabs to identify users making the most requests.
# Each tab shows a different query sorted by request count per email.

BASE_URL="https://vl.expensify.com/select/vmui/#/?"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S")

url_encode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote_plus('''$1'''))"
}

open_query() {
    local label="$1"
    local query="$2"
    local encoded
    encoded=$(url_encode "$query")
    local url="${BASE_URL}step=2m&query=${encoded}&g0.range_input=30m&g0.end_input=${NOW}&g0.relative_time=none&limit=10000"
    echo "Opening: $label"
    open "$url"
}

# 1. "Processing" requests by email
open_query "Processing requests" \
    '{type=web, process=php-fpm} "Processing" _time:30m | stats by (email) count() as count | sort by (count desc)'

# 2. blockingCommit requests by email
open_query "blockingCommit requests" \
    '{type=auth, process=bedrock} thread:blockingCommit _time:30m | stats by (email) count() as count | sort by (count desc)'

# 3. Long exclusiveTransactionLockTime (4+ digits = 1000ms+)
open_query "Long exclusiveTransactionLockTime" \
    '{type=auth, process=bedrock} _time:30m ~"exclusiveTransactionLockTime:[0-9]{4,}" | stats by (email) count() as count | sort by (count desc)'
