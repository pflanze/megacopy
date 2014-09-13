# Copyright 2014 by Christian Jaeger. Published as open source under
# the MIT License. See COPYING.md

=head1 NAME

PFLANZE::Fileutils

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package PFLANZE::Fileutils;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(xxsystem
	      xlink
	      xtempfile
	      xsortfile
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

our $verbose;

sub xxsystem {
    system (@_)==0
      or die "system @_: $?";
}

sub xlink {
    my ($from,$to)=@_;
    warn "linking $from $to" if $verbose;
    link $from, $to
      or die "could not link '$from' to '$to': $!";
}

sub tempfile {
    my $tmp= `tempfile`;
    chomp $tmp;
    length $tmp or die;
    $tmp
}

{
    package PFLANZE::File;
    sub xopen {
	my $cl= shift;
	my ($mode,$path)=@_;
	open my $fh, $mode, $path
	  or die "open $mode '$path': $!";
	bless [$path,$fh], $cl
    }
    sub xprint {
	my $s=shift;
	my ($path,$fh)= @$s;
	print $fh @_
	  or die "writing to '$path': $!";
    }
    sub xclose {
	my $s=shift;
	my ($path,$fh)= @$s;
	close $fh
	  or die "closing '$path': $!";
    }
    sub xunlink {
	my $s=shift;
	my ($path,$fh)= @$s;
	unlink $path
	  or die "unlink '$path': $!";
    }
    sub path {
	my $s=shift;
	my ($path,$fh)= @$s;
	$path
    }
    sub fh {
	my $s=shift;
	my ($path,$fh)= @$s;
	$fh
    }
    sub reader {
	my $s=shift;
	my ($path,$fh)= @$s;
	ref($s)->xopen("<", $path)
    }
}


sub xtempfile {
    my $tmp= tempfile;
    PFLANZE::File->xopen (">",$tmp)
}

sub xsortfile {
    my ($path)=@_;
    local $ENV{LANG}="C";
    my $outpath= tempfile;
    xxsystem ("sort -z < ".quotemeta($path)." > ".quotemeta($outpath));
    $outpath
}

1
