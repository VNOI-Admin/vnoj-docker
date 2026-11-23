#!/bin/bash
# Unit tests for scripts/lib/setup_lib.sh. Run: bash scripts/tests/test_setup_lib.sh
HERE=$(cd "$(dirname "$0")" && pwd)
DMOJ=$(dirname "$(dirname "$HERE")")
source "$DMOJ/scripts/lib/setup_lib.sh" || { echo "FAIL: cannot source lib"; exit 1; }

FAILS=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; FAILS=$((FAILS+1)); fi; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp "$DMOJ"/environment/*.example "$TMP"/

# env_files_exist
check "env_files_exist false when missing" '! env_files_exist "$TMP"'

# write_env_files with special characters
MYSQL_ROOT_PASSWORD='r00t/&#$x'
MYSQL_PASSWORD='p@ss/&#$x'
SECRET_KEY='k3y=&/\#$!'
HOST='oj.test'
write_env_files "$TMP"
check "env_files_exist true after write" 'env_files_exist "$TMP"'
check "root password round-trips" '[ "$(read_env_value "$TMP/mysql-admin.env" MYSQL_ROOT_PASSWORD)" = "$MYSQL_ROOT_PASSWORD" ]'
check "user password round-trips" '[ "$(read_env_value "$TMP/mysql.env" MYSQL_PASSWORD)" = "$MYSQL_PASSWORD" ]'
check "mysql host kept" 'grep -Fxq "MYSQL_HOST=db" "$TMP/mysql.env"'
check "secret key round-trips" '[ "$(read_env_value "$TMP/site.env" SECRET_KEY)" = "$SECRET_KEY" ]'
check "HOST set" 'grep -Fxq "HOST=oj.test" "$TMP/site.env"'
check "SITE_FULL_URL set" 'grep -Fxq "SITE_FULL_URL=http://oj.test/" "$TMP/site.env"'
check "MEDIA_URL set" 'grep -Fxq "MEDIA_URL=http://oj.test/" "$TMP/site.env"'
check "other site lines kept" 'grep -Fxq "BRIDGED_HOST=bridged" "$TMP/site.env"'
check "no placeholders left" '! grep -q "<" "$TMP"/*.env'

# ask_value: preset value is kept, no prompt
FOO=preset
ask_value FOO "Foo" </dev/null 2>/dev/null
check "ask_value keeps preset" '[ "$FOO" = preset ]'

# ask_value: blank line re-prompts, then accepts
BAR=""
ask_value BAR "Bar" < <(printf '\nbar val\n') 2>/dev/null
check "ask_value re-prompts on blank" '[ "$BAR" = "bar val" ]'

# ask_value: secret mode reads too
BAZ=""
ask_value BAZ "Baz" secret < <(printf 's3cr/t\n') 2>/dev/null
check "ask_value secret" '[ "$BAZ" = "s3cr/t" ]'

# ask_value: EOF with nothing -> fails
QUX=""
check "ask_value fails on EOF" '! ask_value QUX "Qux" </dev/null 2>/dev/null'

# set_server_name
cp "$DMOJ/nginx/conf.d/nginx.conf" "$TMP/nginx.conf"
set_server_name "$TMP/nginx.conf" "oj.test"
check "server_name replaced" 'grep -q "^    server_name oj.test;$" "$TMP/nginx.conf"'
check "old server_name gone" '! grep -q "oj.vnoi.info" "$TMP/nginx.conf"'

# set_server_name rejects bad host and leaves file untouched
cp "$TMP/nginx.conf" "$TMP/nginx.before"
check "set_server_name rejects bad host" '! set_server_name "$TMP/nginx.conf" "a b/c" 2>/dev/null'
check "file untouched on bad host" 'cmp -s "$TMP/nginx.conf" "$TMP/nginx.before"'

# read_env_value
check "read_env_value reads value with =" '[ "$(read_env_value "$TMP/site.env" SECRET_KEY)" = "k3y=&/\\#\$!" ]'
check "read_env_value missing key fails" '! read_env_value "$TMP/site.env" NOPE'

# --- review fixes ---
# compose must deliver values verbatim to containers
if docker compose version >/dev/null 2>&1; then
    C="$TMP/compose"; mkdir -p "$C/environment"; cp "$DMOJ"/environment/*.example "$C/environment/"
    printf 'services:\n  t:\n    image: busybox\n    env_file: [environment/mysql-admin.env, environment/mysql.env, environment/site.env]\n' > "$C/docker-compose.yml"
    MYSQL_ROOT_PASSWORD='a${b'; MYSQL_PASSWORD='p@ss/&#$x'; SECRET_KEY="\"q abc #def \$z it's\\"; HOST=oj.test
    write_env_files "$C/environment"
    CFG=$(cd "$C" && docker compose config --format json 2>&1)
    getv() { printf '%s' "$CFG" | python3 -c "import json,sys;print(json.load(sys.stdin)['services']['t']['environment']['$1'].replace('\$\$','\$'),end='')" 2>/dev/null; }
    check "compose: \${ survives" '[ "$(getv MYSQL_ROOT_PASSWORD)" = "a\${b" ]'
    check "compose: \$ and # survive" '[ "$(getv MYSQL_PASSWORD)" = "p@ss/&#\$x" ]'
    check "compose: quotes/space-hash/backslash survive" '[ "$(getv SECRET_KEY)" = "$SECRET_KEY" ]'
    check "read_env_value decodes what compose reads" '[ "$(read_env_value "$C/environment/site.env" SECRET_KEY)" = "$SECRET_KEY" ]'
else
    echo "skip - docker compose not installed"
fi
MYSQL_PASSWORD="two
lines"
check "write_env_files rejects newline" '! write_env_files "$TMP/x" 2>/dev/null'

# valid_host
check "valid_host ok" 'valid_host oj.example.com && valid_host localhost'
check "valid_host rejects port" '! valid_host localhost:8080'
check "valid_host rejects space/scheme/empty" '! valid_host "my host" && ! valid_host http://x && ! valid_host ""'

# ask_host: re-prompts on invalid typed value, fails on invalid preset
HOST=""
ask_host < <(printf 'bad host\noj.test\n') 2>/dev/null
check "ask_host re-prompts invalid" '[ "$HOST" = oj.test ]'
HOST="bad host"
check "ask_host fails on invalid preset" '! ask_host </dev/null 2>/dev/null'

# db_has_data / reset_marker_if_fresh
D="$TMP/db"; M="$TMP/marker"
check "db_has_data false when missing" '! db_has_data "$D"'
mkdir -p "$D"; check "db_has_data false when empty" '! db_has_data "$D"'
touch "$M"; reset_marker_if_fresh "$D" "$M"
check "marker removed on fresh db" '[ ! -f "$M" ]'
touch "$D/ibdata1" "$M"; reset_marker_if_fresh "$D" "$M"
check "db_has_data true" 'db_has_data "$D"'
check "marker kept when db has data" '[ -f "$M" ]'

[ $FAILS -eq 0 ] && { echo OK; exit 0; } || { echo "$FAILS failed"; exit 1; }
