#!/system/bin/sh
set -eu

config=$1
bootstrap_line=$(awk '/^bootstrap_ips = / { print; exit }' "$config")
normalized_bootstrap_line=$(printf '%s' "$bootstrap_line" | tr -d '[:space:]')
case "$normalized_bootstrap_line" in
	bootstrap_ips=\[\]) ;;
	*) exit 0 ;;
esac
url=$(awk '/^url = / { gsub(/^url = "|"$/, ""); print; exit }' "$config")
[ -n "$url" ] || exit 0
case "$url" in
	https://*) ;;
	*) exit 0 ;;
esac
host=${url#https://}
host=${host%%/*}
host=${host%%:*}
bootstrap=
attempts=${DOHD_BOOTSTRAP_ATTEMPTS:-60}
delay=${DOHD_BOOTSTRAP_DELAY:-2}
case "$attempts" in ''|*[!0-9]*) attempts=60 ;; esac
case "$delay" in ''|*[!0-9]*) delay=2 ;; esac

i=1
while [ "$i" -le "$attempts" ]; do
	bootstrap=$(ping -c 1 -W 1 "$host" 2>/dev/null | sed -n 's/^PING [^(]*(\([^)]*\)).*/\1/p' | head -n 1)
	case "$bootstrap" in
		''|*[!0-9.]*) sleep "$delay" ;;
		*) break ;;
	esac
	i=$((i + 1))
done
case "$bootstrap" in
	''|*[!0-9.]*) exit 1 ;;
esac
tmp="$config.bootstrap.tmp"
awk -v target="$url" -v ip="$bootstrap" '
	/^url = / {
		line = $0
		sub(/^url = "/, "", line)
		sub(/"$/, "", line)
		replace = line == target
	}
	/^bootstrap_ips = / && replace {
		print "bootstrap_ips = [\"" ip "\"]"
		replace = 0
		next
	}
	{ print }
' "$config" > "$tmp"
chmod 0600 "$tmp"
mv "$tmp" "$config"
