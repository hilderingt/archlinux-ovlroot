#!/bin/sh

OVLROOT_INIT_ROOTMNT="/new_root"
OVLROOT_CFGDIR="/etc/ovlroot.d"
OVLROOT_BASE="tmpfs"
OVLROOT_BASE_DIR="/.ovlroot"
OVLROOT_LOWER_DIR="lowerdir"
OVLROOT_UPPER_DIR="upperdir"
OVLROOT_WORK_DIR="workdir"
OVLROOT_FSTAB="/etc/fstab"
OVLROOT_NEW_FSTAB="/tmp/new_fstab"

opts_add_replace() {
	local opts="$1" opt1="$2" opt2="$3"
	local avail=n ret=

	for opt in $(echo "$opts" | tr "," " "); do
		case $opt in
			$opt1)
				avail=y
				break
				;;
			$opt2)
				ret="${ret:+${ret},}${opt1}"
				avail=y
				break
				;;
		esac
	done

	[ "$avail" = "n" ] && ret="$opts,$opt1"

	printf "$ret"
}

run_latehook() {
	local ovl_lower_dir= ovl_upper_dir= ovl_work_dir=
	local fs= dir= type= opts= dump= pass= err=
	local line= _line= _dir=

	[ "x$ovlroot" = "x" ] && return 0

	if [ "$ovlroot" != "y" ]; then
		if [ -s "$OVLROOT_CFGDIR/$ovlroot.conf" ]; then
			. "$OVLROOT_CFGDIR/$ovlroot.conf"
		else
			return 1
		fi
	fi

	[ "$OVLROOT_BASE" = "tmpfs" ] && OVLROOT_BASE_TYPE="tmpfs"

	ovl_lower_dir="$OVLROOT_BASE_DIR/$OVLROOT_LOWER_DIR"
	ovl_upper_dir="$OVLROOT_BASE_DIR/$OVLROOT_UPPER_DIR"
	ovl_work_dir="$OVLROOT_BASE_DIR/$OVLROOT_WORK_DIR"

	mkdir -p "$OVLROOT_BASE_DIR"

	mount "${OVLROOT_BASE_OPTS:+"-o $OVLROOT_BASE_OPTS"}" \
	      "${OVLROOT_BASE_TYPE:+"-t $OVLROOT_BASE_TYPE"}" \
	      "$OVLROOT_BASE" "$OVLROOT_BASE_DIR"

	mkdir -p "$ovl_lower_dir"
	mkdir -p "$ovl_upper_dir/rootfs"
	mkdir -p "$ovl_work_dir/rootfs"

	mount -o "move" "$OVLROOT_INIT_ROOTMNT" "$ovl_lower_dir"
	mount -t "overlay" \
	      -o "lowerdir=$ovl_lower_dir,upperdir=$ovl_upper_dir/rootfs \
	          workdir=$ovl_work_dir/rootfs" "ovlroot" "$OVLROOT_INIT_ROOTMNT"

	mkdir -p "$OVLROOT_INIT_ROOTMNT$OVLROOT_BASE_DIR"

	mount -o "move" "$OVLROOT_MNT_BASE_DIR" \
	                "$OVLROOT_BASE_DIR/$OVLROOT_INIT_ROOTMNT"
	      
	while IFS= read -r line; do
		[ "x$line" = "x" ] && continue

		_line="${line%%#*}"

		read -r fs dir type opts dump pass err <<-END
		$_line
		END

		[ "x$err"  != "x" ] && return 1
		[ "x$opts"  = "x" ] && return 1

		if [ "$type" = "swap" ]; then
			if [ "x$OVLROOT_SWAP" = "xoff" ]; then			
				printf "# "
			fi

			echo "$line"
			continue
		fi

		if [ "$dir" = "/" ]; then
			opts="$(opts_add_replace "$opts" "ro" "rw")"
			opts="$(opts_add_replace "$opts" "remount")"

			printf "%s\t%s\t%s\t%s\t%s\t%s\t%s" \
			       "$fs" "$OVLROOT_BASE/$OVLROOT_LOWER_DIR" \
			       "$type" "$opts" "${dump:=0}" "${pass:=0}"

			continue
		fi

		found=n

		for _dir in $(echo "$OVLROOT_OVERLAY" | tr "," " "); do
			if [ "$_dir" = "$dir" ]; then
				type="ovlroot"
				found=y
				break
			fi
		done

		if [ "$found" = "n" ]; then
			for _dir in $(echo "$OVLROOT_RDONLY" | tr "," " "); do
				if [ "$_dir" = "$dir" ]; then
					opts="$(opt_add_replace "$opts" "ro" "rw")"
					found=y
					break
				fi
			done
		fi

		if [ "$found" = "y" ]; then
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
		    	   "$fs" "$dir" "$type" "$opts" "${dump:=0}" "${pass:=0}"
		else
			echo $line
		fi
	done <"$ovl_lower_dir/$OVLROOT_FSTAB" >"$OVLROOT_NEW_FSTAB"

	mv "$OVLROOT_NEW_FSTAB" "$ovl_lower_dir/$OVLROOT_FSTAB"
	rmdir "$OVLROOT_BASE_DIR"

	return 0
}