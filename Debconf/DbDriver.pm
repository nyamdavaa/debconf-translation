#!/usr/bin/perl -w

=head1 NAME

Debconf::DbDriver - base class for debconf db drivers

=cut

package Debconf::DbDriver;
use Debconf::Log qw{:all};
use strict;

=head1 DESCRIPTION

This is a base class that may be inherited from by debconf database
drivers. It provides a simple interface that debconf uses to look up
information related to items in the database.

=cut

=head1 FIELDS

=over 4

=item name

The name of the database. This field is required.

=item readonly

Set to true if this database driver is read only. Defaults to false.

In the config file the literal strings "true" and "false" can be used.
Internally it uses 1 and 0 and.

=item required

Tells if a database driver is required for proper operation of
debconf. Required drivers can cause debconf to abort if they are not
accessible. It can be useful to make remote databases non-required, so
debconf is usable if connections to them go down. Defaults to true.

In the config file the literal strings "true" and "false" can be used.
Internally it uses 1 and 0 and.

=item failed

Tells if a database driver failed to work. If this is set the driver should
begin to reject all requests.

=item accept_type

A regular expression indicating types of items that may be queried in this
driver. Defaults to accepting all types of items.

=item reject_type

A regular expression indicating types of items that are rejected by this
driver.

=item accept_name

A regular expression that is matched against item names to see if they are
accepted by this driver. Defaults to accepting all item names.

=item accept_name

A regular expression that is matched against item names to see if they are
rejected by this driver.

=back

=cut

# I rarely base objects on fields, but I want strong compile-time type
# checking for this class of objects, and speed.
use fields qw(name readonly required failed
              accept_type reject_type accept_name reject_name);

# Class data.
our %drivers;

=head1 METHODS

=head2 new

Create a new object of this class. A hash of fields and values may be
passed in to set initial state. (And you have to use this to set the name,
at the very least.)

=cut

sub new {
	my Debconf::DbDriver $this=shift;
	unless (ref $this) {
		$this = fields::new($this);
	}
	# Set defaults.
	$this->{required}=1;
	$this->{readonly}=0;
	$this->{failed}=0;
	# Set fields from parameters.
	my %params=@_;
	foreach my $field (keys %params) {
		if ($field eq 'readonly' || $field eq 'required') {
			# Convert from true/false strings to numbers.
			$this->{$field}=1,next if lc($params{$field}) eq "true";
			$this->{$field}=0,next if lc($params{$field}) eq "false";
		}
		elsif ($field=~/^(accept|reject)_/) {
			# Internally, store these as pre-compiled regexps.
			$this->{$field}=qr/$params{$field}/i;
		}
		$this->{$field}=$params{$field};
	}
	# Name is a required field.
	unless (exists $this->{name}) {
		# Set to something since error function uses this field..
		$this->{name}="(unknown)";
		$this->error("no name specified");
	}
	# Register in class data.
	$drivers{$this->{name}} = $this;
	# Other initialization.
	$this->init;
	return $this;
}

=head2 init

Called when a new object of this class is instantiated. Override to
add initialization code.

=cut

sub init {}

=head2 error(message)

Rather than ever dying on errors, drivers should instead call
this method to state than an error was encountered. If the driver is
required, it will be a fatal error. If not, the error message will merely
be displayed to the user, the driver will be marked as failed, and debconf
will continue on, "dazed and confuzed".

=cut

sub error {
	my $this=shift;

	if ($this->{required}) {
		print STDERR 'debconf: DbDriver "'.$this->{name}.'" error: '.
			shift()."\n";
		exit(1);
	}
	else {
		print STDERR 'debconf: DbDriver "'.$this->{name}.'" warning: '.
			shift()."\n";
	}

	$this->{failed}++;
}

=head2 driver(drivername)

This is a class method that allows any driver to be looked up by name.
If any driver with the given name exists, it is returned.

=cut

sub driver {
	my $this=shift;
	my $name=shift;
	
	return $drivers{$name};
}

=head2 accept(itemname)

Return true if this driver will accept queries for the given item. Uses the
various accept_* and reject_* fields to determine this.

=cut

# TODO: types are not yet implemented. We have to get at the Template to
# determine type.

sub accept {
	my $this=shift;
	my $name=shift;
	
	return if $this->{failed};
	
	if ((exists $this->{accept_name} && $name!~/$this->{accept_name}/) ||
	    (exists $this->{reject_name} && $name=~/$this->{reject_name}/)) {
		debug "DbDriver $this->{name}" => "reject $name";
		return;
	}

	if (exists $this->{accept_type} || exists $this->{reject_type}) {
		my $template=Debconf::Template::Persistent->get($name);
		return 1 unless $template; # no type to act on
		my $type=$template->type || '';
		return if exists $this->{accept_type} && $name!~/$this->{accept_type}/;
		return if exists $this->{reject_type} && $name=~/$this->{reject_type}/
	}

	return 1;
}

=head2 ispassword(itemname)

Returns true if the item appears to hold a password. This is pretty messy;
we have to dig up its template (unless it _is_ a template).

=cut

sub ispassword {
	my $this=shift;
	my $item=shift;

	my $template=Debconf::Template::Persistent->get($item);
	return unless $template;
	my $type=$template->type || '';
	return 1 if $type eq 'password';
	return 0;
}

=head2 iterator

Create an object of type Debconf::Iterator that can be used to iterate over
each item in the db, and return it.

=cut

sub iterate {}

=head2 savedb

Save the entire database state.

=cut

sub savedb {}

=head2 exists(itemname)

Return true if the given item exists in the database.

=cut

sub exists {}

=head2 addowner(itemname, ownername)

Register an owner for the given item. Returns the owner name, or undef
if this failed.

Note that adding an owner can cause a new item to spring into
existance.

=cut

sub addowner {}

=head2 removeowner(itemname, ownername)

Remove an owner from a item. Returns the owner name, or undef if
removal failed. If the number of owners goes to zero, the item should
be removed.

=cut

sub removeowner {}

=head2 owners(itemname)

Return a list of all owners of the item.

=cut

sub owners {}

=head2 getfield(itemname, fieldname)

Return the given field of the given item, or undef if getting that
field failed.

=cut

sub getfield {}

=head2 setfield(itemname, fieldname, value)

Set the given field the the given value, and return the value, or undef if
setting failed.

=cut

sub setfield {}

=head2 fields(itemname)

Return the fields present in the item.

=cut

sub fields {}

=head2 getflag(itemname, flagname)

Return 'true' if the given flag is set for the given item, "false" if
not.

=cut

sub getflag {}

=head2 setflag(itemname, flagname, value)

Set the given flag to the given value (will be one of "true" or "false"),
and return the value. Or return undef if setting failed.

=cut

sub setflag {}

=head2 flags(itenname)

Return the flags that are present for the item.

=cut

sub flags {}

=head2 getvariable(itemname, variablename)

Return the value of the given variable of the given item, or undef if
there is no such variable.

=cut

sub getvariable {}

=head2 setvariable(itemname, variablename, value)

Set the given variable of the given item to the value, and return the
value, or undef if setting failed.

=cut

sub setvariable {}

=head2 variables(itemname)

Return the variables that exist for the item.

=cut

sub variables {}

=head1 AUTHOR

Joey Hess <joey@kitenet.net>

=cut

1
