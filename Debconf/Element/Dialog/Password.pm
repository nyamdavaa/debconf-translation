#!/usr/bin/perl -w

=head1 NAME

Debconf::Element::Dialog::Password - A password input field in a dialog box

=cut

package Debconf::Element::Dialog::Password;
use strict;
use Debconf::Element; # perlbug
use base qw(Debconf::Element);

=head1 DESCRIPTION

This is an input element that can display a dialog box with a password input
field on it.

=cut

sub show {
	my $this=shift;
	
	my ($text, $lines, $columns)=
		$this->frontend->makeprompt($this->question);

	my @params=('--passwordbox', $text,
		$lines + $this->frontend->spacer, $columns);

	my $ret=$this->frontend->showdialog(@params);

	# The password isn't passed in, so if nothing is entered,
	# use the default.
	if (! defined $ret || $ret eq '') {
		my $default='';
		$default=$this->question->value
			if defined $this->question->value;
		return $default
	}
	else {
		return $ret;
	}
}

1