#!/usr/bin/perl -w
#
# Each Element::Web::Boolean is a check box.

package Debian::DebConf::Element::Web::Boolean;
use strict;
use Debian::DebConf::Element::Base;
use Debian::DebConf::ConfigDb;
use vars qw(@ISA);
@ISA=qw(Debian::DebConf::Element::Base);

# Just generates and returns some html.
sub show {
	my $this=shift;

	$_=$this->question->template->extended_description;
	s/\n/\n<br>\n/g;
	$_.="\n<p>\n";

	my $type=$this->question->template->type;
	my $default=$this->question->value || $this->question->template->default;
	my $id=$this->id;
	$_.="<input type=checkbox name=\"$id\"". ($default eq 'true' ? ' checked' : ''). ">\n<b>".
		$this->question->template->description."</b>";

	return $_;
}

# This gets called once the user has entered a value. It's passed the
# value they entered.
sub set {
	my $this=shift;
	my $value=shift;

	$this->question->value($value eq 'on' ? 'true' : 'false');
	$this->question->flag_isdefault('false');
}

1
