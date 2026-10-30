#!/system/bin/sh
set -eu

config=$1
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
for _ in 1 2 3 4 5 6 7 8 9 10; do
	bootstrap=$(ping -c 1 -W 1 "$host" 2>/dev/null | sed -n 's/^PING [^(]*(\([^)]*\)).*/\1/p' | head -n 1)
	case "$bootstrap" in
		''|*[!0-9.]*) sleep 1 ;;
		*) break ;;
	esac
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
