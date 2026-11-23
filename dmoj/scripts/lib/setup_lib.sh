#!/bin/bash

ENV_NAMES="mysql-admin.env mysql.env site.env"

ask_value() {
    local name=$1 prompt=$2 secret=${3:-} value=${!1:-}
    while [ -z "$value" ]; do
        printf '%s: ' "$prompt" >&2
        if [ "$secret" = secret ]; then
            IFS= read -r -s value || { echo >&2; return 1; }
            echo >&2
        else
            IFS= read -r value || return 1
        fi
    done
    printf -v "$name" '%s' "$value"
}

# env_files_exist ENV_DIR -> 0 if all three .env files exist
env_files_exist() {
    local f
    for f in $ENV_NAMES; do [ -f "$1/$f" ] || return 1; done
}

# _quote VALUE -> prints VALUE as a docker compose env_file double-quoted string:
_quote() {
    local v=$1
    v=${v//\\/\\\\}
    v=${v//\"/\\\"}
    v=${v//\$/\$\$}
    printf '"%s"' "$v"
}

# _unquote VALUE -> reverses _quote (unquoted values are returned as-is)
_unquote() {
    local v=$1 out="" c i
    case "$v" in \"*\") v=${v#\"}; v=${v%\"} ;; *) printf '%s' "$v"; return ;; esac
    i=0
    while [ $i -lt ${#v} ]; do
        c=${v:$i:1}
        if [ "$c" = "\\" ] || [ "$c" = "\$" ]; then i=$((i+1)); c=${v:$i:1}; fi
        out="$out$c"; i=$((i+1))
    done
    printf '%s' "$out"
}

# _render EXAMPLE OUT -> copy EXAMPLE to OUT, replacing values of known keys.
_render() {
    local line key
    : > "$2"
    while IFS= read -r line || [ -n "$line" ]; do
        key=${line%%=*}
        case "$key" in
            MYSQL_ROOT_PASSWORD) line="$key=$(_quote "$MYSQL_ROOT_PASSWORD")" ;;
            MYSQL_PASSWORD)      line="$key=$(_quote "$MYSQL_PASSWORD")" ;;
            SECRET_KEY)          line="$key=$(_quote "$SECRET_KEY")" ;;
            HOST)                line="$key=$HOST" ;;
            SITE_FULL_URL|MEDIA_URL) line="$key=http://$HOST/" ;;
        esac
        printf '%s\n' "$line" >> "$2"
    done < "$1"
}

# write_env_files ENV_DIR -> writes the three .env files from their .example files
write_env_files() {
    local f v
    for v in "$MYSQL_ROOT_PASSWORD" "$MYSQL_PASSWORD" "$SECRET_KEY"; do
        case "$v" in *"
"*) echo "Passwords and SECRET_KEY cannot contain a newline." >&2; return 1 ;; esac
    done
    valid_host "$HOST" || { echo "Invalid host: '$HOST'" >&2; return 1; }
    for f in $ENV_NAMES; do
        _render "$1/$f.example" "$1/$f" || return 1
        chmod 600 "$1/$f"
    done
}

# read_env_value FILE KEY -> prints the decoded value of KEY from an env file
read_env_value() {
    local line v
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "${line%%=*}" = "$2" ]; then
            _unquote "${line#*=}"; return 0
        fi
    done < "$1"
    return 1
}

# set_server_name NGINX_CONF HOST -> sets the server_name directive (portable)
set_server_name() {
    local tmp
    tmp=$(mktemp) || return 1
    valid_host "$2" || { echo "Invalid host: $2" >&2; rm -f "$tmp"; return 1; }
    sed -E "s/^([[:space:]]*)server_name[[:space:]].*;/\1server_name $2;/" "$1" > "$tmp" && cat "$tmp" > "$1"
    rm -f "$tmp"
}

# valid_host HOST -> 0 if HOST is a bare hostname (no scheme, port, path or spaces)
valid_host() {
    case "$1" in ''|*[!A-Za-z0-9.-]*) return 1 ;; esac
}

# ask_host -> like ask_value for HOST, but re-prompts until it is a valid hostname.
ask_host() {
    if [ -n "${HOST:-}" ]; then
        valid_host "$HOST" || { echo "HOST='$HOST' is not a valid host name (use e.g. localhost or oj.example.com, no http:// or port)." >&2; return 1; }
        return 0
    fi
    while :; do
        ask_value HOST "Host name (e.g. localhost or oj.example.com)" || return 1
        valid_host "$HOST" && return 0
        echo "Not a valid host name (no http://, port, path or spaces)." >&2
        HOST=""
    done
}

# db_has_data DIR -> 0 if the MariaDB data directory exists and is non-empty
db_has_data() {
    [ -d "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]
}

# reset_marker_if_fresh DB_DIR MARKER -> remove the first-install marker when the DB is fresh,
reset_marker_if_fresh() {
    db_has_data "$1" || rm -f "$2"
}
