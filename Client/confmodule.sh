#!/bin/sh
# This is a shell library to interface to the Debian configration management
# system.

###############################################################################
# Initialization.

# Check to see if a FrontEnd is running.
if [ ! "$DEBIAN_HAS_FRONTEND" ]; then
	# Ok, this is pretty crazy. Since there is no FrontEnd, this
	# program execs a FrontEnd. It will then run a new copy of $0 that
	# can talk to it.
	exec /usr/share/debconf/frontend $0 $*
fi

# Only do this once.
if [ -z "$DEBCONF_REDIR" ]; then
	# Redirect standard output to standard error. This prevents common
	# mistakes by making all the output of the postinst or whatever
	# script is using this library not be parsed as confmodule commands.
	#
	# To actually send something to standard output, send it to fd 3.
	exec 3>&1 1>&2
	DEBCONF_REDIR=1
fi

# For internal use, send text to the frontend.
_command () {
	echo $* >&3
}

###############################################################################
# Commands.

# Generate subroutines for all commands that don't have special handlers.
# Each command must be listed twice, once in lower case, once in upper.
# Doing that saves us a lot of calls to tr at load time. I just wish shell had
# an upper-case function.
old_opts="$@"
for i in "capb CAPB" "stop STOP" "set SET" "reset RESET" "title TITLE" \
         "input INPUT" "beginblock BEGINBLOCK" "endblock ENDBLOCK" "go GO" \
	 "get GET" "register REGISTER" "unregister UNREGISTER" "subst SUBST" \
	 "previous_module PREVIOUS_MODULE" "fset FSET" "fget FGET" \
	 "visible VISIBLE" "purge PURGE" "metaget METAGET" "exist EXIST"; do
	# Break string up into words.
	set -- $i
	eval "db_$1 () { _command \"$2 \$@\" ; read RET; }"
done
# $@ was clobbered above, unclobber.
set -- $old_opts
unset old_opts

# By default, the current protocol version is sent to the frontend. You can
# pass in a different version to override this.
db_version () {
	if [ "$1" ]; then
		_command "VERSION $1"
	else
		_command "VERSION 1.0"
	fi
	read RET
}

# Just an alias for input. It tends to make more sense to use this to display
# text, since displaying text isn't really asking for input.
db_text () {
	db_input $@
}
