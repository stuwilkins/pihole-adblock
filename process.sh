#!/bin/bash -
#===============================================================================
#
#          FILE: process.sh
#
#         USAGE: ./process.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Stuart B. Wilkins (sbw), stuart@stuwilkins.org
#  ORGANIZATION: 
#       CREATED: 07/20/2020 06:59:21 AM
#      REVISION:  ---
#===============================================================================

set -x -e -o nounset
#set -e -o nounset

JQ=/usr/bin/jq
AWK=/usr/bin/gawk
CURL=/usr/bin/curl

SOURCES=https://raw.githubusercontent.com/openwrt/packages/master/net/adblock/files/adblock.sources
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")
V=""


process_list () {
	local list="$1"	
	local output="$2"
	local url=$(cat ${WORKDIR}/sources.json | jq -r ".$list.url")
	local cat=$(cat ${WORKDIR}/sources.json | jq -r ".$list.categories | @sh")

	cat ${WORKDIR}/sources.json | jq -r ".$list.rule" >$WORKDIR/rule # \
        #		| sed 's/\\\\\./\\\./g' > $WORKDIR/rule

	if [[ "$cat" == "null" ]]; then
		$CURL $url > $WORKDIR/$list 2> /dev/null
	else
		$CURL $url > $WORKDIR/$list.download 2> /dev/null
		local c
		local tar_entries=""
		local tar_list=$(tar -tzf "$WORKDIR/$list.download" 2> /dev/null)
		for c in $cat; do
			# Remove single quotes
			local _c=$(echo $c | sed "s/'//g")
			tar_entries="${tar_entries} $(printf "%s" "${tar_list}" | grep -E "${_c}/domains")"
		done
		tar -xvOzf "$WORKDIR/$list.download" ${tar_entries} 2> /dev/null > $WORKDIR/$list
	fi

	$AWK -f $WORKDIR/rule $WORKDIR/$list >> ${output}
	if [ -n "$V" ]; then
		echo "RULE = $(cat $WORKDIR/rule)"
		echo "Origional output ...."
		tail "$WORKDIR/$list"
		echo "Processed output ...."
		tail "$output"
		echo "Done processing $list"
	fi
}

echo "Working directory : ${WORKDIR}"
echo "Downloading list from ${SOURCES}"
$CURL -o "${WORKDIR}/sources.json" "${SOURCES}" 2> /dev/null

LISTS="adaway adguard malwarelist malwaredomains notracking anti_ad utcapitole_porn shallalist_porn stevenblack_porn yoyo youtube"

URL=""
for LIST in $LISTS; do
	process_list ${LIST} "${LIST}.blacklist"
	URL="${URL} file://$(pwd)/${LIST}.blacklist"
done

# process_list "adaway" "adaway.list"
# process_list "adguard" "adguard.list"
# process_list "malwarelist" "malwarelist.list"
# process_list "malwaredomains" "malware
# process_list "notracking"
# process_list "anti_ad"
# process_list "utcapitole_porn"
# process_list "shallalist_porn"
# process_list "stevenblack_porn"
# process_list "yoyo"

rm -rf $WORKDIR

pihole -g

echo $URL
