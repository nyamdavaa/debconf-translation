#!/usr/bin/perl

=head1 NAME

Debian::DebConf::Log -- debconf log module

=cut

=head1 DESCRIPTION

This is a log module for debconf. It can output messages at varying priorities.

This module uses Exporter.

=cut

=head1 METHODS

=cut

package Debian::DebConf::Log;
use strict;
use base qw(Exporter);
use vars qw(@EXPORT_OK %EXPORT_TAGS);
@EXPORT_OK=qw(debug warn);
# Import :all to get everything.
%EXPORT_TAGS = (all => [@EXPORT_OK]);

=head2 debug

Outputs an infomational message, if DEBCONF_DEBUG is set in the environment
to a value >= the first parameter.

=cut

sub debug {
	my $priority=shift;
	if (exists $ENV{DEBCONF_DEBUG} && $priority <= int($ENV{DEBCONF_DEBUG})) {
		print STDERR "debconf: ".join(" ", @_)."\n";
	}
}

=head2 warn

Outputs a warning message. This overrides the builtin perl warn() command.

=cut

sub warn {
	print STDERR "debconf: ".join(" ", @_)."\n";
}

=head1 AUTHOR

Joey Hess <joey@kitenet.net>

=cut

1
