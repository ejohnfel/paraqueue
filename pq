#!/bin/bash

#
# Variables and Constants
#

# Slot Count
SLOTS=1
# Queue that is operational for this invocation (can be changed by "-l" flag)
OPQUEUE="default"
# Default Queue folder
QUEUEFOLDER="${HOME}/.pq"
# Output Items
PREFIX="output"

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
	echo -e "-l [label]\tCreate or set Label of queue for current operation"
	echo -e "-t [label]\tStatus of default queue or labelled queue"
	echo -e "-o [label]\tShow output of default queue or labelled queue"
	echo -e "-q\t\tShow queues"
	echo -e "-r [label]\tRemove completed queue"
	echo -e "-c [label]\tClean output from queue"
	echo -e "-x [label]\tForce remove queue"
	echo -e "-f [label]\tForce clean queue"
}

# Determine Slot Count Based on Prevailing resources
function GetSlots()
{
	cpus=$(egrep "^processor\s+\:\s+[0-9]+" /proc/cpuinfo | wc -l)

	echo "Found ${cpus} CPU(s)..."
	if [ ${cpus} -gt 3 ]; then
		SLOTS=$(( ${cpus} - 2 ))
	else
		SLOTS=1
	fi
}

# Make A Queue
function MkQueue()
{
	[ ! -d "${QUEUEFOLDER}/${OPQUEUE}" ] && mkdir -p "${QUEUEFOLDER}/${OPQUEUE}";
}

# Check Status of Queue
function CheckStatus()
{
	echo "Not yet implemented - ${OPQUEUE}"
}

# Show Output of Queue
function ShowOutput()
{
	echo "Not Yet Implemented - ${OPQUEUE}"
}

# Remove Queue
function RemoveQueue()
{
	if [ ! ${OPQUEUE} = "default" ]; then
		if [ -d "${QUEUEFOLDER}/${OPQUEUE}" ]; then
			if [ ! -z ${QUEUEFOLDER}/${OPQUEUE}/cmds ]; then
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
	echo "Not yet implemented"

	if [ -d "${QUEUEFOLDER}/${OPQUEUE}" ]; then
		if [ ! -z ${QUEUEFOLDER}/${OPQUEUE}/cmds ]; then
			rm "${QUEUEFOLDER}/${OPQUEUE}/${PREFIX}*"
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
	if [ -d "${QUEUEFOLDER}/${OPQUEUE}" ]; then
		[ -e "${QUEUEFOLDER}/${OPQUEUE}/cmds" ] && rm -f "${QUEUEFOLDER}/${OPQUEUE}/cmds"

		if [ ! "${OPQUEUE}" = "default" ]; then
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
	if [ -d "${QUEUEFOLDER}/${OPQUEUE}" ]; then
		[ -e "${QUEUEFOLDER}/${OPQUEUE}/cmds" ] && rm -f "${QUEUEFOLDER}/${OPQUEUE}/cmds"

		CleanQueue
	else
		echo "${OPQUEUE} - does not currently exist"
	fi
}

# List Queues
function ListQueues()
{
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

		if [ - f ${item}/count ]; then
			count=$(( $(cat ${item}/count}) - ${running} ))
		else
			count=0
		fi

		echo "${bname} - ${cmds} queued, ${running} running, started ${started}, finished ${finished}, run time ${runtime}, ${count} finished"
	done < ${tmp}

	[ -e ${tmp} ] && rm ${tmp}
}

# Execute A Script with Completed command string
function Execute()
{
	# format all commands save in queue/cmds
	# set a start time, keep track of execution time and endtime
	# a file contains the "running" process count

	OP=${QUEUEFOLDER}/${OPQUEUE}

	if [ -f ${OP}/finished ]; then
		rm ${OP}/started
		rm ${OP}/finished
		rm ${OP}/runtime
		echo 0 > ${OP}/running
		rm ${OP}/cmds
		touch ${OP}/cmds
	fi

	if [ ! -f ${OP}/started ]; then
		date > ${OP}/started
	fi

	# Look for, and set flags, to prevent multiple running instances fromn clobbering one another
	[ -e ${OP}/flag ] && inotifywait -q -q -e delete_self ${OP}/flag
	touch ${OP}/flag

	# Fill in command file (if there is input)
	while read line; do
		cmd="${*} ${line}" >> ${OP}/cmds
	done

	rm ${OP}/flag

	running=0

	if [ ! -z ${OP}/cmds ]; then
		count=0

		while read cmd; do
			# Check for filled slots
			[ ${running} -ge ${SLOTS} ] && wait -n && running=$(( ${running} - 1 ))

			# Check for concurrent operations and wait if needed
			[ -e ${OP}/flag ] && inotifywait -q -q -e delete_self ${OP}/flag
			touch ${OP}/flag

			running=$(( ${running} + 1 ))
			echo "${running}" > ${OP}/running

			count=$(( ${count} + 1 ))
			echo "${count}" > ${OP}/count

			# Execute command
			echo "Cmd : ${cmd} - $(date)" > ${prefix}.stdout
			${cmd} > ${prefix}.stdout.${count} 2> ${prefix}.stderr.${count} &

			rm ${OP}/flag
		done < ${OP}/cmds

		cat ${OP}/${prefix}.stdout.* >> ${prefix}.stdout
		cat ${OP}/${prefix}.stderr.* >> ${prefix}.stderr
	fi
}

# Check for Queue Folder
function CheckQueueFolder()
{
	# If paraqueue folder does not exist, create with default queue
	[ ! -d "${QUEUEFOLDER}" ] && echo "Making Queue Management Folder" && mkdir -p "${QUEUEFOLDER}/default"
}

# Check Supplied Option for "-"
function OptCheck()
{
	if [[ ${1} =~ ^- ]]; then
		return 0
	fi

	return 1
}

#
# Main Loop
#

CheckQueueFolder
GetSlots

while getopts "hs:l:toqrcx:f" opt; do
	case "${opt}" in
	"h")	Usage; exit 0 ;;
	"s")	SLOTS=${OPTARG} ;;
	"l")	OPQUEUE="${OPTARG}";
		MkQueue ;;
	"t")	if OptCheck "${argv[${OPTIND}]}"; then
			OPQUEUE="default"
		else
			OPQUEUE="${argv[${OPTIND}]}"
			OPTIND=$(( ${OPTIND} + 1 ))
		fi

		CheckStatus
		;;
	"o")	ShowOutput ;;
	"q")	ListQueues ;;
	"r")	OPQUEUE="${OPTARG}";
		RemoveQueue ;;
	"c")	if OptCheck "${argv[${OPTIND}]}"; then
			OPQUEUE="default"
		else
			OPQUEUE="${argv[${OPTIND}]}"
			OPTIND=$(( ${OPTIND} + 1 ))
		fi
		CleanQueue ;;
	"x")	OPQUEUE="${OPTARG}";
		ForceRemove ;;
	"f")	if OptCheck "${argv[${OPTIND}]}"; then
			OPQUEUE="default"
		else
			OPQUEUE="${argv[${OPTIND}]}"
			OPTIND=$(( ${OPTIND} + 1 ))
		fi
		ForceClean ;;
	esac
done
