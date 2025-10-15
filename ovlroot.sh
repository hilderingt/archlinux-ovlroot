#!/bin/sh

# Copyright 2025 Tim Hildering

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

OVLROOT_INIT_ROOTMNT="/new_root"
OVLROOT_CFGDIR="/etc/ovlroot.d"
OVLROOT_BASE_TYPE="tmpfs"
OVLROOT_BASE_OPTS=""
OVLROOT_BASE_DEV=""
OVLROOT_BASE_DIR="/.ovlroot"
OVLROOT_BASE_CLEAN="n"
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
OVLROOT_SWAP="on"

opts_add_replace() {
	local opts="$1" opt1="$2" opt2="$3"
	local avail=n ret=

	for opt in $(echo "$opts" | sed "s/,/ /g"); do
		if [ "x$opt" = "x$opt2" -o  "x$opt" = "x$opt1"  ]; then
			if [ "$avail" = "n" ]; then
				ret="${ret:+${ret},}${opt1}"
			fi

			avail=y
		else
			ret="${ret:+${ret},}${opt}"
		fi
	done

	[ "$avail" = "n" ] && ret="${opts:+${opts},}$opt1"

	printf "%s" "$ret"
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
root_init_mode=""
root_init_opts=""
root_fstab_opts=""
modified="n"
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

while read -r fs dir type opts dump pass; do
	if [ "$dir" = "$OVLROOT_INIT_ROOTMNT" ]; then
		root_init_opts="$opts";
	fi
done <"/proc/mounts"

if [ "x$root_init_opts" != "x" ]; then
	for opt in $(echo "$root_init_opts" | sed 's/,/ /g'); do
		case "$opt" in
			ro | rw)
				root_init_mode="$opt" ;;
		esac
	done
fi

if [ "x$root_init_mode" = "x" ]; then
	root_init_mode="ro"

	for opt in $(cat "/proc/cmdline"); do
		if [ "$opt" = "rw" ]; then
			root_init_mode="rw"
		fi
	done

	root_init_opts="$(opts_add_replace "$root_init_opts" "$root_init_mode")"
fi

ovl_lower_dir="$OVLROOT_BASE_DIR/$OVLROOT_LOWER_DIR"
ovl_upper_dir="$OVLROOT_BASE_DIR/$OVLROOT_UPPER_DIR"
ovl_work_dir="$OVLROOT_BASE_DIR/$OVLROOT_WORK_DIR"

mkdir -p "$OVLROOT_BASE_DIR" || exit 1

if ! mount ${OVLROOT_BASE_OPTS:+-o $OVLROOT_BASE_OPTS} \
${OVLROOT_BASE_TYPE:+-t $OVLROOT_BASE_TYPE} \
${OVLROOT_BASE_DEV:-$OVLROOT_BASE_TYPE} "$OVLROOT_BASE_DIR"; then
	rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null
	exit 1
fi

if [ "x$OVLROOT_BASE_CLEAN" = "xy" ]; then
	(cd "$OVLROOT_BASE_DIR"; rm -rf * .*)
fi

if ! mkdir -p "$ovl_lower_dir"; then
	umount "$OVLROOT_BASE_DIR" && \
	rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null

	exit 1
fi

if ! mkdir -p "$ovl_upper_dir/rootfs"; then
	rmdir "$ovl_lower_dir" 2>>/dev/null
	umount "$OVLROOT_BASE_DIR" && \
	rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null

	exit 1
fi

if ! mkdir -p "$ovl_work_dir/rootfs"; then
	rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
	rmdir "$ovl_upper_dir" 2>>/dev/null
	rmdir "$ovl_lower_dir" 2>>/dev/null
	umount "$OVLROOT_BASE_DIR" && \
	rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null

	exit 1
fi

if ! mount -o "move" "$OVLROOT_INIT_ROOTMNT" "$ovl_lower_dir"; then
	rmdir "$ovl_lower_dir" 2>>/dev/null
	rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
	rmdir "$ovl_upper_dir" 2>>/dev/null
	rmdir "$ovl_work_dir/rootfs" 2>>/dev/null && \
	rmdir "$ovl_work_dir" 2>>/dev/null
	umount "$OVLROOT_BASE_DIR" && \
	rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null

	exit 1
fi

if [ "x$OVLROOT_OVL_OPTS_ROOT" != "x" ]; then
	ovlopts="${OVLROOT_OVL_OPTS_ROOT},"
fi

if ! mount -t "overlay" -o "${ovlopts}lowerdir=$ovl_lower_dir,\
upperdir=$ovl_upper_dir/rootfs,workdir=$ovl_work_dir/rootfs" \
"ovlroot" "$OVLROOT_INIT_ROOTMNT"; then
	mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT" && \
	rmdir "$ovl_lower_dir" 2>>/dev/null
	rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
	rmdir "$ovl_upper_dir" 2>>/dev/null
	rmdir "$ovl_work_dir/rootfs" 2>>/dev/null && \
	rmdir "$ovl_work_dir" 2>>/dev/null
	umount "$OVLROOT_BASE_DIR" && \
	rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null

	exit 1
fi

if ! mkdir -p "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"; then
	if umount "$OVLROOT_INIT_ROOTMNT"; then
		mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT" && \
		rmdir "$ovl_lower_dir" 2>>/dev/null
		rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
		rmdir "$ovl_upper_dir" 2>>/dev/null
		rmdir "$ovl_work_dir/rootfs" 2>>/dev/null && \
		rmdir "$ovl_work_dir" 2>>/dev/null
		umount "$OVLROOT_BASE_DIR" && \
		rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null
	else
		mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	fi

	exit 1
fi

if ! mount -o "move" "$OVLROOT_BASE_DIR" \
"$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR"; then
	rmdir "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" 2>>/dev/null

	if umount "$OVLROOT_INIT_ROOTMNT"; then
		mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT" && \
		rmdir "$ovl_lower_dir" 2>>/dev/null
		rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
		rmdir "$ovl_upper_dir" 2>>/dev/null
		rmdir "$ovl_work_dir/rootfs" 2>>/dev/null && \
		rmdir "$ovl_work_dir" 2>>/dev/null
		umount "$OVLROOT_BASE_DIR" && \
		rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null
	else
		mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	fi

	exit 1
fi

while IFS= read -r line; do
	[ "x$line" = "x" ] && { echo ""; continue; }

	_line="${line%%#*}"

	read -r fs dir type opts dump pass err <<-END
	$_line
	END

	[ "x$err"  != "x" -o "x$opts" = "x" ] && { echo "$line"; continue; }

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
			root_fstab_opts="$opts"
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
				opts="$(opts_add_replace "$opts" "ro" "rw")"
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

if [ "$root_init_mode" != "$OVLROOT_LOWER_MODE" ]; then
	if [ "$OVLROOT_LOWER_MODE" = "ro" ]; then
		root_fstab_opts="$(opts_add_replace "$root_fstab_opts" "ro" "rw")"
	else
		root_fstab_opts="$(opts_add_replace "$root_fstab_opts" "rw" "ro")"
	fi
fi

if [ "x$root_fstab_opts" != "x" ]; then
	if ! mount -o "remount,$root_fstab_opts" "$OVLROOT_INIT_ROOTMNT/$ovl_lower_dir"; then
		if mount -o move "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" \
	       "$OVLROOT_BASE_DIR"; then
			rmdir "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" 2>>/dev/null

			if umount "$OVLROOT_INIT_ROOTMNT"; then
				mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT" && \
				rmdir "$ovl_lower_dir" 2>>/dev/null
				rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
				rmdir "$ovl_upper_dir" 2>>/dev/null
				rmdir "$ovl_work_dir/rootfs" 2>>/dev/null && \
				rmdir "$ovl_work_dir" 2>>/dev/null
				umount "$OVLROOT_BASE_DIR" && \
				rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null
			fi
		else
			mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
		fi

		exit 1
	fi
fi

if ! mv "$OVLROOT_NEW_FSTAB" "$OVLROOT_INIT_ROOTMNT/$OVLROOT_FSTAB"; then
	if   [ "x$OVLROOT_ROOT_FSTAB_OPTS" = "xy" -a "x$root_fstab_opts" != "x" ]; then
		mount -o "remount,$root_init_opts" "$ovl_lower_dir"
	elif [ "$root_init_mode" != "$OVLROOT_LOWER_MODE" ]; then
		mount -o "remount,$root_init_mode" "$ovl_lower_dir"
	fi

	if mount -o move "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" \
	   "$OVLROOT_BASE_DIR"; then
		rmdir "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" 2>>/dev/null

		if umount "$OVLROOT_INIT_ROOTMNT"; then
			mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT" && \
			rmdir "$ovl_lower_dir" 2>>/dev/null
			rmdir "$ovl_upper_dir/rootfs" 2>>/dev/null && \
			rmdir "$ovl_upper_dir" 2>>/dev/null
			rmdir "$ovl_work_dir/rootfs" 2>>/dev/null && \
			rmdir "$ovl_work_dir" 2>>/dev/null
			umount "$OVLROOT_BASE_DIR" && \
			rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null
		fi
	else
		mount -o move "$ovl_lower_dir" "$OVLROOT_INIT_ROOTMNT"
	fi

	exit 1
fi

rmdir "$OVLROOT_BASE_DIR" 2>>/dev/null

exit 0 
