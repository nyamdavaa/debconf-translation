#!/usr/bin/perl -w

=head1 NAME

Debconf::FrontEnd::Kde - GUI Kde frontend

=cut

package Debconf::FrontEnd::Kde;
use strict;
use utf8;
use Debconf::Gettext;
use Debconf::Config;
eval q{
	use Qt;
	# use Qt::debug qw(verbose gc calls);
};
die "Unable to load Qt -- is libqt-perl installed?\n" if $@;
use Debconf::FrontEnd::Kde::Wizard;
use Debconf::Log ':all';
use base qw{Debconf::FrontEnd};

=head1 DESCRIPTION

This FrontEnd is a Kde/Qt UI for Debconf.

=head1 METHODS

=over 4

=item init

Set up the UI. Most of the work is really done by
Debconf::FrontEnd::Kde::Wizard and Debconf::FrontEnd::Kde::WizardUi.

=cut

our @ARGV_KDE=();

sub init {
	my $this=shift;
    
	$this->SUPER::init(@_);
	$this->interactive(1);
	$this->cancelled(0);
	$this->createdelements([]);
	$this->dupelements([]);
	$this->capb('backup');
    
	debug frontend => "QTF: initializing app";
	$this->qtapp(Qt::Application(\@ARGV_KDE));
	debug frontend => "QTF: initializing wizard";
	$this->win(Debconf::FrontEnd::Kde::Wizard(undef, undef, $this));
	debug frontend => "QTF: setting size";
	$this->win->resize(620, 430);
	$this->hostname(`hostname`);
	debug frontend => "QTF: setting title";
	$this->win->setCaption(sprintf(gettext("Debconf on %s"), $this->hostname));
	debug frontend => "QTF: initializing main widget";
	$this->toplayout(Qt::HBoxLayout($this->win->mainFrame));
	$this->page(Qt::ScrollView($this->win->mainFrame));
	$this->page->setResizePolicy(&Qt::ScrollView::AutoOneFit());
	$this->page->setFrameStyle(&Qt::Frame::NoFrame());
	$this->frame(Qt::Frame($this->page));
	$this->page->addChild($this->frame);
	$this->toplayout->addWidget($this->page);
	$this->vbox(Qt::VBoxLayout($this->frame, 0, 6, "wizard-main-vbox"));
	$this->win->show;
	$this->space(Qt::SpacerItem(1, 1, 1, 5));
	$this->win->setTitle(sprintf(gettext("Debconf on %s"), $this->hostname));
}

=item go

Creates and lays out all the necessary widgets, then runs them to get
input.

=cut

sub go {
	my $this=shift;
	my @elements=@{$this->elements};
    
	my $interactive='';
	debug frontend => "QTF: -- START ------------------";
	foreach my $element (@elements) {
		$element->create($this->frame);
		# Noninteractive elemements have no tops.
		next unless $element->top;
		$interactive=1;
		debug frontend => "QTF: ADD: " . $element->question->description;
		$this->vbox->addWidget ($element->top);
	}
	
	if ($interactive) {
		foreach my $element (@elements) {
			next unless $element->top;
			debug frontend => "QTF: SHOW: " . $element->question->description;
			$element->top->show;
		}
	
		$this->vbox->addItem($this->space);
	
		if ($this->capb_backup) {
			$this->win->setBackEnabled(1);
		}
		else {
			$this->win->setBackEnabled(0);
		}
	
		$this->win->show;
		debug frontend => "QTF: -- ENTER EVENTLOOP --------";
		$this->qtapp->exec;
		debug frontend => "QTF: -- LEFT EVENTLOOP --------";
	
		foreach my $element (@elements) {
			next unless $element -> top;
			debug frontend => "QTF: HIDE: " . $element->question->description;
			$this->vbox->remove($element->top);
			$element->top->hide;
			debug frontend => "QTF: DESTROY: " . $element->question->description;
			$element->destroy;
		}
		
		$this->vbox->removeItem($this->space);
	}
	
	debug frontend => "QTF: -- END --------------------";
	if ($this->cancelled) {
		$this->shutdown;
		exit;
	}
	return '' if $this->goback;
	return 1;
}

=item shutdown

Called to terminate the UI.

=cut

sub shutdown {
	my $this = shift;
	$this->win->hide;
	$this->frame->reparent(undef, 0, Qt::Point(0, 0), 0);
	$this->frame(undef);
	$this->win->mainFrame->reparent(undef, 0, Qt::Point(0, 0), 0);
	$this->win->mainFrame(undef);
	$this->win(undef);
	$this->space(undef);
}

=back

=head1 AUTHOR

Peter Rockai <mornfall@logisys.dyndns.org>

=cut

1