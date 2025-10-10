#!/bin/sh

OVLROOT_INIT_ROOTMNT="/new_root"
OVLROOT_CFGDIR="/etc/ovlroot.d"
OVLROOT_BASE_TYPE="tmpfs"
OVLROOT_BASE_OPTS=""
OVLROOT_BASE_DEV=""
OVLROOT_BASE_DIR="/.ovlroot"
OVLROOT_LOWER_DIR="lowerdir"
OVLROOT_UPPER_DIR="upperdir"
OVLROOT_WORK_DIR="workdir"
OVLROOT_FSTAB="/etc/fstab"
OVLROOT_NEW_FSTAB="/tmp/new_fstab"
OVLROOT_LOWER_MODE="ro"
OVLROOT_OVL_OPTS_ROOT=""
OVLROOT_ROOT_FSTAB_OPTS="n"
OVLROOT_OVERLAY=""
OVLROOT_DISABLE=""
OVLROOT_RDONLY=""
OVLROOT_SWAP=""

opts_add_replace() {
	local opts="$1" opt1="$2" opt2="$3"
	local avail=n ret=

	for opt in $(echo "$opts" | sed "s/,/ /g"); do
		if [ "$opt" = "$opt2" -o  "$opt" = "$opt1"  ]; then
			if [ "$avail" = "n" ]; then
				ret="${ret:+${ret},}${opt1}"
			fi

			avail=y
		else
			ret="${ret:+${ret},}${opt}"
		fi
	done

	[ "$avail" = "n" ] && ret="${opts:+${opts},}$opt1"

	printf "$ret"
}

if [ "x$1" != "x" ]; then
	if [ -s "$OVLROOT_CFGDIR/$1.conf" ]; then
		. "$OVLROOT_CFGDIR/$1.conf"
	else
		exit 1
	fi
fi

ovl_lower_dir=""
ovl_upper_dir=""
ovl_work_dir=""
root_mode="ro"
root_opts=""
ovlopts=""
fs=""
dir="" 
type=""
opts=""
dump=""
pass=""
err="" 
line=""
_line=""
_dir=""

for opt in $(cat /proc/cmdline); do
	case "$opt" in
		rw)
			root_mode="rw" ;;
	esac
done

[ "x$OVLROOT_INIT_ROOTMNT" = "x" ] && exit 1
[ "x$OVLROOT_CFGDIR" = "x" ]       && exit 1
[ "x$OVLROOT_FSTAB" = "x" ]        && exit 1
[ "x$OVLROOT_NEW_FSTAB" = "x" ]    && exit 1
[ "x$OVLROOT_BASE_DIR" = "x" ]     && exit 1
[ "x$OVLROOT_LOWER_DIR" = "x" -o \
  "x$OVLROOT_UPPER_DIR" = "x" -o \
  "x$OVLROOT_WORK_DIR" = "x" ]     && exit 1
[ "x$OVLROOT_BASE_TYPE" = "x" -a \
  "x$OVLROOT_BASE_DEV" = "x" ]     && exit 1

if [ "x$OVLROOT_LOWER_MODE" != "xrw" -a "x$OVLROOT_LOWER_MODE" != "xro" ]; then
	OVLROOT_LOWER_MODE="ro"
fi

ovl_lower_dir="$OVLROOT_BASE_DIR/$OVLROOT_LOWER_DIR"
ovl_upper_dir="$OVLROOT_BASE_DIR/$OVLROOT_UPPER_DIR"
ovl_work_dir="$OVLROOT_BASE_DIR/$OVLROOT_WORK_DIR"

mkdir -p "$OVLROOT_BASE_DIR" || exit 1

if ! mount ${OVLROOT_BASE_OPTS:+-o $OVLROOT_BASE_OPTS} \
${OVLROOT_BASE_TYPE:+-t $OVLROOT_BASE_TYPE} \
${OVLROOT_BASE_DEV:-$OVLROOT_BASE_TYPE} "$OVLROOT_BASE_DIR"; then
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if ! mkdir -p "$ovl_lower_dir"; then
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if ! mkdir -p "$ovl_upper_dir/rootfs"; then
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if ! mkdir -p "$ovl_work_dir/rootfs"; then
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if ! mount -o "move" "$OVLROOT_INIT_ROOTMNT" "$ovl_lower_dir"; then
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if [ "x$OVLROOT_OVL_OPTS_ROOT" != "x" ]; then
	ovlopts="${OVLROOT_OVL_OPTS_ROOT},"
fi

if ! mount -t "overlay" -o "${ovlopts}lowerdir=$ovl_lower_dir,\
upperdir=$ovl_upper_dir/rootfs,workdir=$ovl_work_dir/rootfs" \
"ovlroot" "$OVLROOT_INIT_ROOTMNT"; then
	mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if ! mkdir -p "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"; then
	umount "$OVLROOT_INIT_ROOTMNT"
	mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

if ! mount -o "move" "$OVLROOT_BASE_DIR" \
"$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"; then
	rmdir --ignore-fail-on-non-empty \
	"$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"
	umount "$OVLROOT_INIT_ROOTMNT"
	mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

while IFS= read -r line; do
	[ "x$line" = "x" ] && { echo ""; continue; }

	_line="${line%%#*}"

	read -r fs dir type opts dump pass err <<-END
	$_line
	END

	[ "x$opts"  = "x" ] && { echo "$line"; continue; }
	[ "x$err"  != "x" -o "x$opts"  = "x" ] && return 1

	if [ "$type" = "swap" ]; then
		if [ "x$OVLROOT_SWAP" = "xoff" ]; then			
			printf "# "
		fi

		echo "$line"
		continue
	fi

	modified=n

	if [ "$dir" = "/" ]; then
		if [ "x$OVLROOT_ROOT_FSTAB_OPTS" = "xy" ]; then
			root_opts="$opts"
		fi

		continue
	fi

	if [ "$modified" = "n" -a "x$OVLROOT_OVERLAY" != "x" ]; then
		for _dir in $(echo "$OVLROOT_OVERLAY" | sed "s/,/ /g"); do
			if [ "$_dir" = "$dir" ]; then
				if [ "$OVLROOT_LOWER_MODE" = "ro" ]; then
					opts="$(opts_add_replace "$opts" "ro" "rw")"
				else
					opts="$(opts_add_replace "$opts" "rw" "ro")"
				fi

				opts="ovlroot_realfs=$type,$opts"
				type="ovlroot"
				modified=y
				break
			fi
		done
	fi

	if [ "$modified" = "n" -a "x$OVLROOT_RDONLY" != "x" ]; then
		for _dir in $(echo "$OVLROOT_RDONLY" | sed "s/,/ /g"); do
			if [ "$_dir" = "$dir" ]; then
				opts="$(opt_add_replace "$opts" "ro" "rw")"
				modified=y
				break
			fi
		done
	fi

	if [ "$modified" = "n" -a "x$OVLROOT_DISABLE" != "x" ]; then
		for _dir in $(echo "$OVLROOT_DISABLE" | sed "s/,/ /g"); do
			if [ "$_dir" = "$dir" ]; then
				line="# $line"
				break
			fi
		done
	fi

	if [ "$modified" = "y" ]; then
		printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
			   "$fs" "$dir" "$type" "$opts" "${dump:=0}" "${pass:=0}"
	else
		echo "$line"
	fi
done <"$OVLROOT_INIT_ROOTMNT/$OVLROOT_FSTAB" >"$OVLROOT_NEW_FSTAB"

if [ "$root_mode" != "$OVLROOT_LOWER_MODE" ]; then
	if [ "$OVLROOT_LOWER_MODE" = "ro" ]; then
		root_opts="$(opts_add_replace "$root_opts" "ro" "rw")"
	else
		root_opts="$(opts_add_replace "$root_opts" "rw" "ro")"
	fi
fi

if [ "x$root_opts" != "x" ]; then
	if ! mount -o "remount,$root_opts" "$ovl_lower_dir"; then
		mount -o move "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" "$OVLROOT_BASE_DIR"
		rmdir --ignore-fail-on-non-empty "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"
		umount "$OVLROOT_INIT_ROOTMNT"
		mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
		rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
		rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
		rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
		rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
		rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
		umount "$OVLROOT_BASE_DIR"
		rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
		exit 1
	fi
fi

if ! mv "$OVLROOT_NEW_FSTAB" "$OVLROOT_INIT_ROOTMNT/$OVLROOT_FSTAB"; then
	if [ "$root_mode" != "$OVLROOT_LOWER_MODE" ]; then
		mount -o "remount,$root_mode" "$ovl_lower_dir"
	fi

	mount -o move "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"
	umount "$OVLROOT_INIT_ROOTMNT"
	mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
	rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
	rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
	umount "$OVLROOT_BASE_DIR"
	rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	exit 1
fi

rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"

exit 0 

