#!/usr/bin/perl -w

=head1 NAME

Debconf::DbDriver::DirTree - store database in a directory hierarchy

=cut

package Debconf::DbDriver::DirTree;
use strict;
use Debconf::Log qw(:all);
use base 'Debconf::DbDriver::Directory';

=head1 DESCRIPTION

This is an extention to the Directory driver that uses a deeper directory
tree. I find such a tree easier to navigate, and it will also scale better
for huge databases on ext2. It does use a little more disk space/inodes
though.

=head1 FIELDS

=over 4

=item extention

This field is mandatory for this driver. If it is not set, it will be set
to ".dat" by default.

=back

=head1 METHODS

Note that the extention field is mandatory for this driver, so it checks
that on initialization.

=cut

sub init {
	my $this=shift;
	if (! defined $this->{extention} or ! length $this->{extention}) {
		$this->{extention}=".dat";
	}
	$this->SUPER::init(@_);
}

=head2 save(itemname,value)

Before saving as usual, we have to make sure the subdirectory exists.

=cut

sub save {
	my $this=shift;
	my $item=shift;

	return unless $this->accept($item);
	return if $this->{readonly};
	
	my @dirs=split(m:/:, $this->filename($item));
	pop @dirs; # the base filename
	my $base=$this->{directory};
	foreach (@dirs) {
		$base.="/$_";
		next if -d $base;
		mkdir $base or $this->error("mkdir $base: $!");
	}
	
	$this->SUPER::save($item, @_);
}

=head2 accept(itemname)

Accept is overridden to reject any item names that contain either "../" or
"/..". Either could be used to break out of the directory tree.

=cut

sub accept {
	my $this=shift;
	my $name=shift;

	return if $name=~m#\.\./# or $name=~m#/\.\.#;
	$this->SUPER::accept($name, @_);
}	

=head2 filename(itemname)

We actually use the item name as the filename, subdirs and all.

We also still append the extention to the item name. And the extention is
_mandatory_ here; otherwise this would try to use filenames and directories
with the same names sometimes.

=cut

sub filename {
	my $this=shift;
	my $item=shift;
	$item =~ s/\.\.//g;
	return $item.$this->{extention};
}

=head2 iterator

Iterating over the whole directory hierarchy is the one annoying part of
this driver.

=cut

sub iterator {
	my $this=shift;
	
	# Stack of pending directories.
	my @stack=();
	my $currentdir="";
	my $handle;
	opendir($handle, $this->{directory}) or
		$this->error("opendir: $this->{directory}: $!");
		
	my $iterator=Debconf::Iterator->new(callback => sub {
		my $i;
		while ($handle or @stack) {
			while (@stack and not $handle) {
				$currentdir=pop @stack;
				opendir($handle, "$this->{directory}/$currentdir") or
					$this->error("opendir: $this->{directory}/$currentdir: $!");
			}
			$i=readdir($handle);
			if (not defined $i) {
				closedir $handle;
				$handle=undef;
				next;
			}
			next if $i eq '.lock'; # ignore lock files
			if (-d "$this->{directory}/$currentdir$i") {
				if ($i ne '..' and $i ne '.') {
					push @stack, "$currentdir$i/";
				}
				next;
			}
			# Ignore files w/o our extention, and strip it.
			next unless $i=~s/$this->{extention}$//;
			return $currentdir.$i;
		}
		return undef;
	});

	# Gag. Perhaps my parent needs some work..
	$this->Debconf::DbDriver::Cache::iterator($iterator);
}

=head2 remove(itemname)

Unlink a file. Then, rmdir any empty directories.

=cut

sub remove {
	my $this=shift;
	my $item=shift;

	my $ret=$this->SUPER::unlink($item);
	return $ret unless $ret;

	my $dir=$this->filename($item);
	while ($dir=~s:.*/[^/]*:$1: and length $dir) {
		rmdir $dir or last; # not empty, I presume
	}
	return $ret;
}

=head1 AUTHOR

Joey Hess <joey@kitenet.net>

=cut

1