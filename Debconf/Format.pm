#!/usr/bin/perl -w

=head1 NAME

Debconf::Format - base class for formatting database output

=cut

package Debconf::Format;
use strict;
use base qw(Debconf::Base);

=head1 DESCRIPTION

This is the base of a class of objects that format database output in
various ways, and can read in parse the result.

=head1 METHODS

=head2 read(filehandle)

Read one record from the filehandle, parse it, and return a list with two
elements. The first is the name of the item that was read, and the second
is a structure as required by Debconf::DbDriver::Cached. Note that the
filehandle may contain multiple records, so it must be able to recognize an
end-of-record delimiter of some kind and stop reading after it.

=head2 write(filehandle, data, itemname)

Format a record and and write it out to the filehandle. Should include an
end-of-record marker of some sort that can be recognized by the parse
function.

data is the same structure parse should return.

=head1 AUTHOR

Joey Hess <joey@kitenet.net>

=cut

1
