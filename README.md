# paraqueue
Shell script to execute jobs in parallel, with a finite length queue

While I realize there are a number of really good alternatives, GNU Parallel, sift, task-spooler, I needed something quick, dirty, simple and requires no fuss to install or maintain.

Usage is simple...

some-input-generator | pq -s [number] [script|command]

You can include or leave out the "-s" command, "s" for slots (ala task-spooler terminology).

The slots indicate how many items to run in parallel, queuing the rest.

The script or command must take stdin for it's parameters. The input line will be placed at the end of the command.

If no "-s" is supplied, "pq" does it's best to determine how many processors you have and schedules jobs based on the following rules.

If 1-3 CPU's, one thread.
If CPU's > 3, N - 2 threads.

This can be overridden by supplying the "-s" option. The reason for N-2 is to make sure "pq" does not indavertantly bog down the machine it's running on by leaving at least 2 cores untouched.

Be careful in how you choose to select the "-s" value. I would recommend never going above N-1. If pressed, never exceeding "N".

Advanced features:
o I will be adding multiple "named" queues to submit jobs to. Queues can be executed one at a time in order, limited by the N-2 rules or in "-s" multiples.
o Queues will default to a user's home folder
o Queues can be placed in other locations, this is useful if you wish to run processes on multiple computer systems. For example, place the queues and the data on NFS shares (or Samba, or what have you) and the 'pq's on different systems will extract commands from the queue (or queues) and execute them on multiple different systems without colliding or duplicating effort.

Future Features:
o Ability to remotely launch parallel executions from a single host.
o Timed launches (either through cron or "atq" or with delayed/deferred/event based triggering)

Otherwise, use at your own risk unless you "nice" the script being parallelized/queued.
