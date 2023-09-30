#!/bin/sh

run_latehook() {
	local conf="default"

	[ "x$ovlroot" = "x" ] && return 0
	[ "$ovlroot" != "y" ] && conf="$ovlroot"

	/bin/ovlroot.sh "$conf"

	return 0
}