#!/bin/sh

ABI_LIST='arm64-v8a armeabi-v7a x86_64 x86'

cargo_target_for_abi() {
	case "$1" in
		arm64-v8a) printf '%s\n' aarch64-linux-android ;;
		armeabi-v7a) printf '%s\n' armv7-linux-androideabi ;;
		x86_64) printf '%s\n' x86_64-linux-android ;;
		x86) printf '%s\n' i686-linux-android ;;
		*) printf 'unsupported ABI: %s\n' "$1" >&2; return 1 ;;
	esac
}

cargo_binary_path() {
	printf '%s/daemon/target/%s/release/%s\n' "$1" "$(cargo_target_for_abi "$2")" "$3"
}

copy_module_binaries() {
	binary_root=$1
	binary_abi=$2
	binary_destination=$3
	binary_sing_box_source=${4:-$(cargo_binary_path "$binary_root" "$binary_abi" sing-box)}
	binary_dohd_source=$(cargo_binary_path "$binary_root" "$binary_abi" dohd)
	[ -x "$binary_dohd_source" ] || { printf 'missing binary: %s\n' "$binary_dohd_source" >&2; return 1; }
	[ -x "$binary_sing_box_source" ] || { printf 'missing binary: %s\n' "$binary_sing_box_source" >&2; return 1; }
	cp "$binary_dohd_source" "$binary_destination/dohd"
	cp "$binary_sing_box_source" "$binary_destination/sing-box"
}

stage_module() {
	stage_root=$1
	stage_abi=$2
	stage_destination=$3
	stage_sing_box_source=${4:-}
	mkdir -p "$stage_destination/config" "$stage_destination/system/bin/$stage_abi"
	cp "$stage_root/module/module.prop" "$stage_root/module/service.sh" "$stage_root/module/boot-completed.sh" "$stage_root/module/uninstall.sh" "$stage_root/module/action.sh" "$stage_root/module/customize.sh" "$stage_destination/"
	cp "$stage_root/module/config/config.toml.example" "$stage_root/module/config/tun.json" "$stage_destination/config/"
	cp -R "$stage_root/module/scripts" "$stage_destination/scripts"
	cp -R "$stage_root/module/webroot" "$stage_destination/webroot"
	sh "$stage_root/scripts/build-info.sh" "$stage_destination/webroot"
	copy_module_binaries "$stage_root" "$stage_abi" "$stage_destination/system/bin/$stage_abi" "$stage_sing_box_source"
	chmod 0755 "$stage_destination"/*.sh "$stage_destination/system/bin/$stage_abi/"* "$stage_destination/scripts/"*.sh
}
