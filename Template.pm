#!/usr/bin/perl -w

=head1 NAME

Debian::DebConf::Template - Template object

=cut

package Debian::DebConf::Template;
use strict;
use POSIX;
use vars qw($AUTOLOAD);
use base qw(Debian::DebConf::Base);

=head1 DESCRIPTION

This is an object that represents a Template. Each Template has some associated
data, the fields of the template structure. To get at this data, just use
$template->fieldname to read a field, and $template->fieldname(value) to write
a field. Any field names at all can be used, the convention is to lower-case
their names. All Templates should have a "template" field that is their name.
Most have "default", "type", and "description" fields as well. The field
named "extended_description" holds the extended description, if any.

Templates support internationalization. If LANG or a related environment
variable is set, and you request a field from a template, it will see if
"$ENV{LANG}-field" exists, and if so return that instead.

=cut

=head1 METHODS

=cut

# Helper for parse, sets a field to a value.
sub _savefield {
	my $this=shift;
	my $field=shift;
	my $value=shift;
	my $extended=shift;

	if ($field ne '') {
		$this->$field($value);
		my $e="extended_$field";
		$this->$e($extended);
	}
}

=head2 merge

Pass this another Template and all fields of the object you
call this method on will be copied over onto the other Template
and any old values in the other Template will be removed.

=cut

sub merge {
	my $this=shift;
	my $other=shift;

	# Breaking the abstraction just a little..
	foreach my $key (keys %$other) {
		delete $other->{$key};
	}

	foreach my $key (keys %$this) {
		$other->$key($this->{$key});
	}
}

=head2 parse

This method parses a string containing a template and stores all the
information in the Template object.

=cut

sub parse {
	my $this=shift;
	my $text=shift;

	my ($field, $value, $extended)=('', '', '');
	foreach (split "\n", $text) {
		chomp;
		if (/^([-_.A-Za-z0-9]*):\s+(.*)/) {
			# Beginning of new field.
			$this->_savefield($field, $value, $extended);
			$field=lc $1;
			$value=$2;
			$value=~s/\s*$//;
			$extended='';
		}
		elsif (/^\s+\.$/) {
			# Continuation of field that contains only a blank line.
			$extended.="\n\n";
		}
		elsif (/^\s+(.*)/) {
			# Continuation of field.
			$extended.=$1." ";
		}
		else {
			die "Template parse error near \"$_\"";
		}
	}

	$this->_savefield($field, $value, $extended);

	# Sanity checks.
	die "Template does not contain a Template: line"
		unless $this->template;
}

# Calculate the current locale, with aliases expanded, and normalized.
# May also generate a fallback. Returns both.
sub _getlangs {
	# I really dislike hard-coding 5 here, but the POSIX module sadly does
	# not let us get at the value of LC_MESSAGES in locale.h in a more 
	# portable way.
	my $language=setlocale(5); # LC_MESSAGES
	if ($language eq 'C' || $language eq 'POSIX') {
		return;
	}
	# Try to do one level of fallback.
	elsif ($language=~m/^(\w\w)_/) {
		return $language, $1;
	}
	return $language;
}

=head2 AUTOLOAD

Creates and calls accessor methods to handle fields. 
This supports internationalization.

=cut

{
	my @langs=_getlangs();

	sub AUTOLOAD {
		my $field;
		($field = $AUTOLOAD) =~ s/.*://;

		no strict 'refs';
		*$AUTOLOAD = sub {
			my $this=shift;
		
			$this->{$field}=shift if @_;
		
			# Check to see if i18n should be used.
			if (@langs) {
				foreach my $lang (@langs) {
					if (exists $$this{$field.'-'.$lang}) {
						$field.='-'.$lang;
						last;
					}
				}
			}
		
			return $this->{$field};
		};
		goto &$AUTOLOAD;
	}
}

=head1 AUTHOR

Joey Hess <joey@kitenet.net>

=cut

1
