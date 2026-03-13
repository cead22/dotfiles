#!/bin/bash
# auth-status: Quick overview of auth cluster health
# Usage: auth_status.sh [host]

HOST="${1:-db2.rno}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Strip ANSI color codes from input
strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

# Gather all data in parallel
saltfab -H "$HOST" -- "echo -ne \"status\r\nconnection:close\r\n\r\n\" | nc -w 60 localhost 9999 | tail -1 | jq '(\"\(.host) \(.state) \(.priority) \(.version)\"), (.peerList[] | \"\(.host) \(.state) \(.priority) \(.version)\")'" 2>&1 \
    | strip_ansi | grep 4445 | sed "s/0.0.0.0/auth.${HOST}/" | cut -d' ' -f 3- \
    | sed 's/auth\.//' | sed 's/:4445//' | tr -d '"' > "$tmpdir/status" &

saltfab -P -z 10 -g bastion1.sjc -H 'db*' bedrock.compareCommitCounts 2>&1 \
    | strip_ansi > "$tmpdir/commits" &

saltfab -P -z 10 -g bastion1.sjc -H 'db*' -- 'nc -z -w 5 localhost 4444 2>/dev/null && echo CMDPORT_OPEN || echo CMDPORT_CLOSED' 2>&1 \
    | strip_ansi > "$tmpdir/ports" &

wait

# Build lookup files
mkdir -p "$tmpdir/lookup"

while IFS= read -r line; do
    node=${line%% *}
    case "$node" in db*) ;; *) continue ;; esac
    if echo "$line" | grep -q UNKNOWN; then
        echo "-" > "$tmpdir/lookup/commits_${node}"
    else
        echo "$line" | grep -oE '\(-?[0-9]+' | tr -d '(' > "$tmpdir/lookup/commits_${node}"
    fi
done < "$tmpdir/commits"

grep "] out:" "$tmpdir/ports" | while IFS= read -r line; do
    node=$(echo "$line" | grep -oE 'db[0-9]+\.[a-z]+' | head -1)
    [ -n "$node" ] || continue
    if echo "$line" | grep -q CMDPORT_OPEN; then
        echo "o" > "$tmpdir/lookup/ports_${node}"
    elif echo "$line" | grep -q CMDPORT_CLOSED; then
        echo "c" > "$tmpdir/lookup/ports_${node}"
    fi
done

lookup() {
    if [ -f "$tmpdir/lookup/${1}_${2}" ]; then
        cat "$tmpdir/lookup/${1}_${2}"
    else
        echo "${3:--}"
    fi
}

# Parse status, sort by priority desc, and format table
{
    echo "node state port priority version commits"
    {
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            node=$(echo "$line" | awk '{print $1}')
            if echo "$line" | grep -q DISCONNECTED; then
                state="SEARCHING"
                priority=$(echo "$line" | awk '{print $NF}')
                version="-"
            else
                state=$(echo "$line" | awk '{print $2}')
                priority=$(echo "$line" | awk '{print $3}')
                version=$(echo "$line" | awk '{print $4}')
            fi
            port=$(lookup ports "$node" "c")
            commit=$(lookup commits "$node")
            echo "${priority} ${node} ${state} ${port} ${priority} ${version:--} ${commit}"
        done < "$tmpdir/status"
    } | sort -rnk1 | cut -d' ' -f2-
} | column -t | sed $'s/ o / \033[32mo\033[0m /;s/ c / \033[31mc\033[0m /'
