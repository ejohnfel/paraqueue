#!/bin/bash

#
# Script to execute other scripts in parallel, based on how many available CPU cores there are.
# The script will only run one queue when one or two CPU's are available, otherwise, n - 2
# threads are executed. This is to leave enough CPU cores to do other things. You always
# override this and declare how many "slots" are available. A CPU core is a "slot", but
# you can execute as many slots as you like, but beware, performance will suffer.
#

#
# Variables and Constants
#

# Debug mode flag
DEBUGMODE=0

# Verbose Mode
VERBOSE=0

# Slot Count
SLOTS=1
# Queue that is operational for this invocation (can be changed by "-l" flag)
OPQUEUE="default"
# Default Queue folder
QUEUEFOLDER="${HOME}/.pq"
# Output Items
PREFIX="output"

# Flag semaphor file
FLAG="busyflag"

# Input File
INPUT="/dev/stdin"

#
# Functions
#

# Usage Menu
function Usage()
{
	echo -e "pq - ParaQueue"
	echo -e "=============="
	echo -e "Queue your scripts and execute them in parallel"
	echo -e "=============="
	echo -e "-s [slots]\tNumber of slots in queue"
	echo -e "-n\t\tNew run, issues a force reset before executing"
	echo -e "-l [label]\tCreate or set Label of queue for current operation"
	echo -e "-t [label]\tStatus of default queue or labelled queue"
	echo -e "-o [label]\tShow output of default queue or labelled queue"
	echo -e "-q\t\tShow queues"
	echo -e "-r [label]\tRemove completed queue"
	echo -e "-c [label]\tClean output from queue"
	echo -e "-x [label]\tForce remove queue"
	echo -e "-f [label]\tForce clean queue"
	echo -e "-v\t\tEnter verbose mode"
	echo -e "-d\t\tEnter debug mode"
}

# Debug Message Function
function DebugMsg()
{
	[ ${DEBUGMODE} -gt 0 ] && printf "$(date) : %s\n" "${*}"
}

# Show items in a column format
function ShowItems()
{
	TTMP="/tmp/output.${RANDOM}"

	echo "${1} :" > "${TTMP}"

	while read line; do
		bn=$(basename "${line}")
		extension="${bn##*.}"

		ol="Started on ${extension} : $(cat ${line})"
		echo "${ol}" >> "${TTMP}"
	done < $(ls -1 ${2}.*.*)

	column "${TTMP}"

	[ -e "${TTMP}" ] && rm "${TTMP}"
}

# Determine Slot Count Based on Prevailing resources
function GetSlots()
{
	DebugMsg "Checking for processors"

	cpus=$(egrep "^processor\s+\:\s+[0-9]+" /proc/cpuinfo | wc -l)

	[ ${VERBOSE} -gt 0 ] && echo -n "Found ${cpus} CPU(s)..."

	if [ ${cpus} -gt 3 ]; then
		SLOTS=$(( ${cpus} - 2 ))
	else
		SLOTS=1
	fi

	[ ${VERBOSE} -gt 0 ] && echo " ${SLOTS} slot(s)"

	DebugMsg "Found ${cpus}, so ${SLOTS} slots"
}

# Make A Queue
function MkQueue()
{
	DebugMsg "MkQueue Called : ${QUEUEFOLDER}/${OPQUEUE}"

	[ ! -d "${QUEUEFOLDER}/${OPQUEUE}" ] && mkdir -p "${QUEUEFOLDER}/${OPQUEUE}" && DebugMsg "Created queue folder"
}

# Check Status of Queue
function CheckStatus()
{
	DebugMsg "CheckStatus Called"

	OP="${QUEUEFOLDER}/${OPQUEUE}"

	TTMP="/tmp/listing.${RANDOM}"

	# Check Started Files

	sc=$(ls -1 "${OP}"/started.* | wc -l)

	if [ ${sc} -gt 0 ]; then
		ShowItems "Start Time(s)" "${OP}/started"
	else
		echo -e "Running\t: Nothing running"
	fi

	# Check for Busy Semaphor
	if [ -f "${OP}/${FLAG}" ]; then
		echo -e "Busy\t: Semaphor present"
	else
		echo -e "Busy\t: No"
	fi

	[ -f ${TTMP} ] && rm "${TTMP}"
}

# Show Output of Queue
function ShowOutput()
{
	DebugMsg "ShowOutput Called"
	echo "Not Yet Implemented - ${OPQUEUE}"
}

# Remove Queue
function RemoveQueue()
{
	DebugMsg "RemoveQueue Called"

	if [ ! ${OPQUEUE} = "default" ]; then
		if [ -d "${QUEUEFOLDER}/${OPQUEUE}" ]; then
			if [ ! -z ${QUEUEFOLDER}/${OPQUEUE}/cmds ]; then
				DebugMsg "Removing ${QUEUEFOLDER}/${OPQUEUE}"

				rm -R "${QUEUEFOLDER}/${OPQUEUE}"
			else
				echo "${OPQUEUE} - not complete"
			fi
		else
			echo "${OPQUEUE} - does not currently exist"
		fi
	else
		echo "Can't delete default queue"
	fi
}

# Clean Queue's Output
function CleanQueue()
{
	DebugMsg "CleanQueue Called - Not Yet Implemented/Tested"

	OP="${QUEUEFOLDER}/${OPQUEUE}"

	if [ -d "${OP}" ]; then
		if [ ! -s "${OP}/cmds" ]; then
			DebugMsg "Cleaning ${OP}/${PREFIX}..."

			rm ${OP}/${PREFIX}.* 2> /dev/null
			rm ${OP}/started.* 2> /dev/null
			rm ${OP}/finished.* 2> /dev/null
			rm ${OP}/runtime.* 2> /dev/null
			rm ${OP}/running.* 2> /dev/null
			rm ${OP}/count.* 2> /dev/null

			[ -f "${OP}/${FLAG}" ] && rm "${OP}/${FLAG}"
		else
			echo "${OPQUEUE} - not complete"
		fi
	else
		echo "${OPQUEUE} - does not currently exist"
	fi
}

# Force Remove Queue
function ForceRemove()
{
	DebugMsg "ForceRemove Called"

	OP="${QUEUEFOLDER}/${OPQUEUE}"

	if [ -d "${OP}" ]; then
		DebugMsg "Clearing cmds out"

		[ -e "${OP}/cmds" ] && rm -f "${OP}/cmds"

		if [ ! "${OPQUEUE}" = "default" ]; then
			DebugMsg "Force Removing Queue"

			RemoveQueue
		else
			echo "default queue cannot be deleted"
		fi
	else
		echo "${OPQUEUE} - does not currently exist"
	fi
}

# Force Clean Queue's Output
function ForceClean()
{
	DebugMsg "ForceClean Called"

	OP="${QUEUEFOLDER}/${OPQUEUE}"

	if [ -d "${OP}" ]; then
		DebugMsg "Clearing cmds out"

		[ -e "${OP}/cmds" ] && rm -f "${OP}/cmds"

		CleanQueue
	else
		echo "${OPQUEUE} - does not currently exist"
	fi
}

# List Queues
function ListQueues()
{
	DebugMsg "ListQueue Called"

	tmp=/tmp/queues.list

	ls -d -1 ${QUEUEFOLDER}/* > ${tmp}

	while read item; do
		bname=$(basename "${item}")

		if [ -f ${item}/cmds ]; then
			cmds=$(wc -l ${item}/cmds)
		else
			cmds="0"
		fi

		if [ -f ${item}/running ]; then
			running=$(cat ${item}/running)
		else
			running=0
		fi

		if [ -f ${item}/started ]; then
			started=$(cat ${item}/started)
		else
			started="-"
		fi

		if [ -f ${item}/finished ]; then
			finished=$(cat ${item}/finished)
		else
			finished="-"
		fi

		if [ -f ${item}/runtime ]; then
			runtime=$(cat ${item}/runtime)
		else
			runtime="-"
		fi

		if [ -f ${item}/count ]; then
			count=$(( $(cat ${item}/count}) - ${running} ))
		else
			count=0
		fi

		echo "${bname} - ${cmds} queued, ${running} running, started ${started}, finished ${finished}, run time ${runtime}, ${count} finished"
	done < ${tmp}

	[ -e ${tmp} ] && rm ${tmp}
}

# WaitFor File To Be Removed
function WaitFor()
{
	DebugMsg "WaitFor Called"

	[ -e "${1}" ] && inotifywait -q -q -e delete_self "${1}"

	touch "${1}"
}

# Execute A Script with Completed command string
# Parameters : [input file|/dev/stdin] [all other cmd line options]
function Execute()
{
	# format all commands save in queue/cmds
	# set a start time, keep track of execution time and endtime
	# a file contains the "running" process count

	DebugMsg "Execute Called with : ${*}"

	# Extract input file name, shift it out of the parameter list
	SRC="${1}"
	shift 1

	OP="${QUEUEFOLDER}/${OPQUEUE}"
	STARTED="${OP}/started.${HOSTNAME}"
	FINISHED="${OP}/finished.${HOSTNAME}"
	RUNTIME="${OP}/runtime.${HOSTNAME}"
	RUNNING="${OP}/running.${HOSTNAME}"
	COUNT="${OP}/count.${HOSTNAME}"

	if [ -f ${OP}/finished ]; then
		DebugMsg "Clearing out old runs"

		rm "${STARTED}"
		rm "${FINIHSED}"
		rm "${RUNTIME}"
		echo 0 > "${RUNNING}"
		rm ${OP}/cmds
		touch ${OP}/cmds
	fi

	if [ ! -f "${STARTED}" ]; then
		date > "${STARTED}"
	fi

	# Look for, and set flags, to prevent multiple running instances fromn clobbering one another
	WaitFor "${OP}/${FLAG}"

	# Fill in command file (if there is input)
	DebugMsg "Reading in parameter lines, outputing to cmds file"

	while read line; do
		echo "${*} ${line}" >> "${OP}/cmds"
	done < "${SRC}"

	# Current Cmd build complete, remove flag to allow other processes to proceed (if any)
	[ -f "${OP}/${FLAG}" ] && rm "${OP}/${FLAG}"

	running=0

	if [ ! -z "${OP}/cmds" ]; then
		count=0
		terminate=0

		DebugMsg "Beginning command execution"

		while [ ${terminate} -lt 1 ]; do
			# Check for filled slots, if filled, wait for *any* background job to complete before starting a new thread
			[ ${running} -ge ${SLOTS} ] && wait -n && running=$(( ${running} - 1 ))

			# Check for concurrent operations and wait if needed
			WaitFor "${OP}/${FLAG}"

			cmd=$(head -n 1 "${OP}/cmds")

			# If cmd is empty, terminate task, queue emptied
			if [ "${cmd}" = "" ]; then
				terminate=1
				continue
			fi

			# Create Tmp file name
			TMP="${OP}/tmp.${RANDOM}"

			# Essentially, remove top cmd, save the rest to tmp file, remove cmds file, replace with tmp file, minus the top line
			if [ -f "${OP}/cmds" ]; then
				tail -n +2 "${OP}/cmds" > "${TMP}"
				rm "${OP}/cmds"
				mv "${TMP}" "${OP}/cmds"
			fi

			# We have a new thread running, increment the running thread count (used to see if slots are filled)
			running=$(( ${running} + 1 ))
			echo "${running}" > "${RUNNING}"

			# Increment total number of threads executed thus far
			count=$(( ${count} + 1 ))
			echo "${count}" > "${COUNT}"

			# Execute command
			DebugMsg "Launching ${cmd}..."

			echo "Cmd : ${cmd} - $(date)" > ${OP}/${PREFIX}.${HOSTNAME}.stdout
			${cmd} > ${OP}/${PREFIX}.${HOSTNAME}.stdout.${count} 2> ${OP}/${PREFIX}.${HOSTNAME}.stderr.${count} &

			[ -f "${OP}/${FLAG}" ] && rm "${OP}/${FLAG}"
		done

		date > ${FINISHED}

		# TODO : Review if we want the stderr/stdout in the user's current folder... is this what I intended or an oversight???
		cat ${OP}/${PREFIX}.${HOSTNAME}.stdout.* >> ${OP}/${PREFIX}.${HOSTNAME}.stdout 2> /dev/null
		cat ${OP}/${PREFIX}.${HOSTNAME}.stderr.* >> ${OP}/${PREFIX}.${HOSTNAME}.stderr 2> /dev/null

		rm ${OP}/${PREFIX}.${HOSTNAME}.stdout.* > /dev/null
		rm ${OP}/${PREFIX}.${HOSTNAME}.stderr.* > /dev/null
	fi

	# Remove cmds file
	[ -f "${OP}/cmds" ] && rm "${OP}/cmds"
}

# Check for Queue Folder
function CheckQueueFolder()
{
	DebugMsg "Checking for ${QUEUEFOLDER}"

	# If paraqueue folder does not exist, create with default queue
	[ ! -d "${QUEUEFOLDER}" ] && echo "Making Queue Management Folder" && mkdir -p "${QUEUEFOLDER}/default" && DebugMsg "${QUEUEFOLDER} created..."
}

# Check Supplied Option for "-"
function OptCheck()
{
	DebugMsg "OptCheck Called"

	if [[ ${1} =~ ^- ]]; then
		return 0
	fi

	return 1
}

#
# Main Loop
#

DebugMsg "Executions started"

CheckQueueFolder
GetSlots

DebugMsg "Processing cmd line args..."

while getopts ":hni:ds:l:t:oqr:c:x:vf" opt; do
	if [ "${opt}" = ":" ]; then
		DebugMsg "Silent opt error : ${OPTARG}"
		opt="${OPTARG}"
		OPTARG="default"
	fi

	case "${opt}" in
	"h")	Usage; exit 0 ;;
	"i")	INPUT="${OPTARG}" ;;
	"d")	DEBUGMODE=1; DebugMsg "Entering debugmode" ;;
	"s")	SLOTS=${OPTARG} ;;
	"l")	OPQUEUE="${OPTARG}"; MkQueue ;;
	"t")	OPQUEUE="${OPTARG}"; CheckStatus; exit ;;
	"o")	ShowOutput; exit ;;
	"q")	ListQueues; exit ;;
	"r")	OPQUEUE="${OPTARG}";
		RemoveQueue; exit ;;
	"c")	OPQUEUE="${OPTARG}"; CleanQueue; exit ;;
	"x")	OPQUEUE="${OPTARG}"; ForceRemove; exit ;;
	"n")	CleanQueue ;;
	"f")	ForceClean; exit ;;
	"v")	VERBOSE=1 ;;
	esac
done

DebugMsg "Cmdline args processed"

shift $(( ${OPTIND} - 1 ))

# TODO : How do we enter into a parallel execution from a different host with a existing queue???

DebugMsg "Calling Execute"

Execute "${INPUT}" ${*}

DebugMsg "Call to execute completed"
