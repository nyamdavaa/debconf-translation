#!/usr/bin/perl -w
#
# Question object for Debian configuration database.

package Debian::DebConf::Question;
use strict;
use vars qw($AUTOLOAD);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = {};
	$self->{flag_isdefault}='true';
	bless ($self, $class);
	return $self;
}

# Set/get property.
sub AUTOLOAD {
	my $this=shift;
	my $property = $AUTOLOAD;
	$property =~ s|.*:||; # strip fully-qualified portion

	$this->{$property}=shift if @_;
	$this->{$property};
}

1
