#!/bin/bash
# bedrock-status: Quick overview of bedrock cluster health
# Usage: bedrock_status.sh [-b] [host]
#   -b    Query webrock cluster (virt servers) instead of auth cluster (db servers)

CLUSTER="auth"
while getopts "b" opt; do
    case "$opt" in
        b) CLUSTER="webrock" ;;
        *) echo "Usage: bedrock_status.sh [-b] [host]"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ "$CLUSTER" = "webrock" ]; then
    HOST="${1:-virt2.rno}"
    HOST_PATTERN="virt*"
    NODE_PATTERN='virt[0-9]+\.[a-z]+'
    NODE_PREFIX="virt"
    CMD_PORT=8888
    PEER_PORT=8889
    WEBROCK_HOST=$(echo "$HOST" | sed 's/virt/webrock/')
    STATUS_NC="nc -w 60 ${WEBROCK_HOST} ${CMD_PORT}"
    SELF_SED="s/[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}/${WEBROCK_HOST}/"
    HOST_CLEANUP="s/webrock/virt/g"
    PORT_CHECK="nc -z -w 5 \$(hostname | sed s/virt/webrock/) ${CMD_PORT} 2>/dev/null && echo CMDPORT_OPEN || echo CMDPORT_CLOSED"
else
    HOST="${1:-db2.rno}"
    HOST_PATTERN="db*"
    NODE_PATTERN='db[0-9]+\.[a-z]+'
    NODE_PREFIX="db"
    CMD_PORT=4444
    PEER_PORT=4445
    STATUS_NC="nc -w 60 localhost 9999"
    SELF_SED="s/0.0.0.0/auth.${HOST}/"
    HOST_CLEANUP="s/auth\.//"
    PORT_CHECK="nc -z -w 5 localhost ${CMD_PORT} 2>/dev/null && echo CMDPORT_OPEN || echo CMDPORT_CLOSED"
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

# Gather all data in parallel
saltfab -H "$HOST" -- "echo -ne \"status\r\nconnection:close\r\n\r\n\" | ${STATUS_NC} | tail -1 | jq '(\"\(.host) \(.state) \(.priority) \(.version)\"), (.peerList[] | \"\(.host) \(.state) \(.priority) \(.version)\")'" 2>&1 \
    | strip_ansi | grep "$PEER_PORT" \
    | sed "$SELF_SED" | cut -d' ' -f 3- \
    | sed "$HOST_CLEANUP" | sed "s/:${PEER_PORT}//" | tr -d '"' > "$tmpdir/status" &

saltfab -P -z 10 -g bastion1.sjc -H "$HOST_PATTERN" bedrock.compareCommitCounts 2>&1 \
    | strip_ansi > "$tmpdir/commits" &

saltfab -P -z 10 -g bastion1.sjc -H "$HOST_PATTERN" -- "$PORT_CHECK" 2>&1 \
    | strip_ansi > "$tmpdir/ports" &

wait

# Build lookup files
mkdir -p "$tmpdir/lookup"

while IFS= read -r line; do
    node=${line%% *}
    case "$node" in ${NODE_PREFIX}*) ;; *) continue ;; esac
    if echo "$line" | grep -q UNKNOWN; then
        echo "-" > "$tmpdir/lookup/commits_${node}"
    else
        echo "$line" | grep -oE '\(-?[0-9]+' | tr -d '(' > "$tmpdir/lookup/commits_${node}"
    fi
done < "$tmpdir/commits"

grep "] out:" "$tmpdir/ports" | while IFS= read -r line; do
    node=$(echo "$line" | grep -oE "$NODE_PATTERN" | head -1)
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
