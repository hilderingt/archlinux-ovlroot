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
OVLROOT_OVL_OPTS_ROOT=""
OVLROOT_OVERLAY=""
OVLROOT_RDONLY=""
OVLROOT_SWAP=""

opts_add_replace() {
	local opts="$1" opt1="$2" opt2="$3"
	local avail=n ret=

	for opt in $(echo "$opts" | tr "," " "); do
		if [ "$opt" = "$opt1" ]; then
			ret="$opts"; avail=y
			break
		elif [ "$opt" = "$opt2" ]; then
			ret="${ret:+${ret},}${opt1}"
			avail=y
			break
		fi
	done

	[ "$avail" = "n" ] && ret="${opts:+${opts},},$opt1"

	printf "$ret"
}

run_latehook() {
	local ovl_lower_dir= ovl_upper_dir= ovl_work_dir=
	local fs= dir= type= opts= dump= pass= err=
	local skip= line= _line= _dir=

	if [ "x$ovlroot" != "xy" ]; then
		if [ -s "$OVLROOT_CFGDIR/$ovlroot.conf" ]; then
			. "$OVLROOT_CFGDIR/$ovlroot.conf"
		else
			return 1
		fi
	fi

	[ "x$OVLROOT_BASEDIR" = "x" ] && return 1
	[ "x$OVLROOT_LOWER_DIR" = "x" -o "x$OVLROOT_UPPER_DIR" = "x" -o\
	  "x$OVLROOT_WORK_DIR" = "x" ] && return 1

	ovl_lower_dir="$OVLROOT_BASE_DIR/$OVLROOT_LOWER_DIR"
	ovl_upper_dir="$OVLROOT_BASE_DIR/$OVLROOT_UPPER_DIR"
	ovl_work_dir="$OVLROOT_BASE_DIR/$OVLROOT_WORK_DIR"


	[ "x$OVLROOT_BASE_TYPE" = "x" -a "x$OVLROOT_BASE_DEV" = "x" ] && return 1

	if mount "${OVLROOT_BASE_OPTS:+"-o $OVLROOT_BASE_OPTS "}"\
	   "${OVLROOT_BASE_TYPE:+"-t $OVLROOT_BASE_TYPE "}"\
	   "${OVLROOT_BASE_DEV:-"$OVLROOT_BASE_TYPE"}" "$OVLROOT_BASE_DIR"; then
		rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	fi

	if ! mkdir -p "$ovl_lower_dir"; then
		umount "$OVLROOT_BASE_DIR"
		rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	fi

	if ! mkdir -p "$ovl_upper_dir/rootfs"; then
		rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
		umount "$OVLROOT_BASE_DIR"
		rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	fi

	if ! mkdir -p "$ovl_work_dir/rootfs"; then
		rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
		rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
		rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
		umount "$OVLROOT_BASE_DIR"
		rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
	fi

	if ! mount -o "move" "$OVLROOT_INIT_ROOTMNT" "$ovl_lower_dir"; then
		rmdir --ignore-fail-on-non-empty "$ovl_upper_dir/rootfs"
		rmdir --ignore-fail-on-non-empty "$ovl_upper_dir"
		rmdir --ignore-fail-on-non-empty "$ovl_work_dir/rootfs"
		rmdir --ignore-fail-on-non-empty "$ovl_work_dir"
		rmdir --ignore-fail-on-non-empty "$ovl_lower_dir"
		umount "$OVLROOT_BASE_DIR"
		rmdir --ignore-fail-on-non-empty "$OVLROOT_BASE_DIR"
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
	fi		
  
	while IFS= read -r line; do
		[ "x$line" = "x" ] && { echo ""; continue; }

		_line="${line%%#*}"

		read -r fs dir type opts dump pass err <<-END
		$_line
		END

		[ "x$fs"    = "x" ] && { echo "$line"; continue; }
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
			opts="$(opts_add_replace "$opts" "ro" "rw")"
			opts="$(opts_add_replace "$opts" "remount")"
			dir="$ovl_lower_dir"
			modified=y
		fi

		if [ "$modified" = "n" -a "x$OVLROOT_OVERLAY" != "x" ]; then
			for _dir in $(echo "$OVLROOT_OVERLAY" | tr "," " "); do
				if [ "$_dir" = "$dir" ]; then
					opts="$(opts_add_replace "$opts" "ro" "rw")"
					opts="ovlroot_realfs=$type,$opts"
					type="ovlroot"
					modified=y
					break
				fi
			done
		fi

		if [ "$modified" = "n" -a "x$OVLROOT_RDONLY" != "x" ]; then
			for _dir in $(echo "$OVLROOT_RDONLY" | tr "," " "); do
				if [ "$_dir" = "$dir" ]; then
					opts="$(opt_add_replace "$opts" "ro" "rw")"
					modified=y
					break
				fi
			done
		fi

		if [ "$modified" = "y" ]; then
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
				   "$fs" "$dir" "$type" "$opts" "${dump:=0}" "${pass:=0}"
		else
			echo $line
		fi
	done <"$ovl_lower_dir/$OVLROOT_FSTAB" >"$OVLROOT_NEW_FSTAB"

	if ! mv "$OVLROOT_NEW_FSTAB" "$OVLROOT_INIT_ROOTMNT/$OVLROOT_FSTAB"; then
		 mount -o "move" "$OVLROOT_INIT_ROOTMNT/$OVLROOT_BASE_DIR" \
		"$OVLROOT_BASE_DIR"
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
	fi

	rmdir "$OVLROOT_BASE_DIR"

	return 0
}
