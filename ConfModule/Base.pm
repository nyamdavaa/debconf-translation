#!/usr/bin/perl -w
#
# Configuration module communication package for the Debian configuration
# management system. it can launch a configuration module script and
# communicate with it. Each instance of a ConfModule is connected to a
# separate, running configuration module.
#
# There are a number of stub methods that are called in response to commands
# from the client. Each has the same name as the command, and is fed in the
# parameters given after the command (split on whitespace), and whatever it
# returns is passed back to the configuration module.

package ConfModule::Base;
use strict;
use IPC::Open2;
use FileHandle;
use vars qw($AUTOLOAD);

# Pass the filename of the configuration module to start and pass in the
# FrontEnd it should use to ask questions.
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless ($self, $class);
	
	# Start up the script.
	$self->{confmodule} = shift;
	$self->{frontend} = shift;
	$self->{read_handle} = FileHandle->new;
	$self->{write_handle} = FileHandle->new;
	$self->{pid} = open2($self->{read_handle}, $self->{write_handle},
		             $self->{confmodule}) || die $!;
	return $self;
}

# Read one command and respond to it.
sub communicate {
	my $this=shift;
	
	my $r=$this->{read_handle};
	return if eof($r);
	$_=<$r> || die $!;
	return unless defined && ! /^\s*#/; # Skip blank lines, comments.
	chomp;
	my ($command, @params)=split(' ', $_);
	$command="command_".lc($command);
	my $w=$this->{write_handle};
	print $w join(' ', $this->$command(@params))."\n";
	return 1;
}

###############################################################################
# Communication with the frontend. Each function corresponds to a command
# from the frontend.

sub command_version {
	my $this=shift;
	my $version=shift;
	die "Version too low ($version)" if $version < 1;
	return "1.0";
}

sub command_capb {
	my $this=shift;
	$this->{capb}=[@_];
	return;
}

# Just store the title.
sub command_title {
	my $this=shift;
	$this->{'title'}=join(' ',@_);

	return;
}

# Don't handle blocks.
sub command_beginblock {}
sub command_endblock {}

# Tell the frontend to display items to the user.
sub command_go {
	my $this=shift;
	$this->frontend->go;

	return;
}

# Pull a value out of a question.
sub command_get {
	my $this=shift;
	my $question=shift;
	
	$question=ConfigDb::getquestion($question);
	return $question->value if $question->value ne '';
	return $question->template->default;
}

sub AUTOLOAD {
	my $this=shift;
	my $property = $AUTOLOAD;
	$property =~ s|.*:||; # strip fully-qualified portion
	if ($property=~/^command_/) {
		die "Unsupported command \"$property\" received from client configuration module.";
	}
	else {
		$this->{$property}=shift if @_;
		return $this->{$property};
	}
}

# Close filehandles and stop the script.
sub DESTROY {
	my $this=shift;
	
	$this->{read_handle}->close;
	$this->{write_handle}->close;
	kill 'TERM', $this->{pid};
}

1
