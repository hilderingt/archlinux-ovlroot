#!/bin/sh

run_latehook() {
	local conf=""

	if [ "x$ovlroot" != "x" -a "$ovlroot" != "y" ]; then
		conf="$ovlroot"
	fi

	/bin/ovlroot.sh "$conf"

	return 0
}

