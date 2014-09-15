# Copyright 2014 by Christian Jaeger. Published as Open Source
# software under the MIT License. See COPYING.md

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
	      dirname
	      basename
	      xmkdir_p
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use File::Temp;
use Chj::singlequote ':all';

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

sub _tempfile {
    my ($maybe_dir)=@_;
    my $template= ($main::myname || "pflanze") . "-XXXXXXXX";
    my ($fh, $path)= File::Temp::tempfile
	($template,
	 (defined $maybe_dir ? (DIR=> $maybe_dir) : ()));
    $path
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
    sub xsortfile {
	my $s=shift;
	PFLANZE::Fileutils::xsortfile($s->path, @_);
    }
}


sub xtempfile {
    my ($maybe_dir)=@_;
    my $tmp= _tempfile $maybe_dir;
    PFLANZE::File->xopen (">",$tmp)
}

sub _xsortfile {
    my ($path, $maybe_tmp, $maybe_options)=@_;
    my $options= defined ($maybe_options) ? $maybe_options : "";
    local $ENV{LANG}="C";
    my $outpath= _tempfile $maybe_tmp;
    xxsystem ("sort -z $options < ".singlequote_sh($path)
	      ." > ".singlequote_sh($outpath));
    $outpath
}

sub xsortfile {
    PFLANZE::File->xopen("<", _xsortfile(@_));
}


# copies from xperlfunc:

use Carp;

BEGIN {
    if ($^O eq 'linux') {
	eval 'sub EEXIST() {17} sub ENOENT() {2}'; die if $@;
    } else {
	eval 'use POSIX "EEXIST","ENOENT"'; die if $@;
    }
}

sub dirname ($ ) {
    my ($path)=@_;
    if ($path=~ s|/+[^/]+/*\z||) {
	if (length $path) {
	    $path
	} else {
	    "/"
	}
    } else {
	# deviates from the shell in that dirname of . and / are errors. good?
	if ($path=~ m|^/+\z|) {
	    die "can't go out of file system"
	} elsif ($path eq ".") {
	    die "can't go above cur dir in a relative path";
	} elsif ($path eq "") {
	    die "can't take dirname of empty string";
	} else {
	    "."
	}
    }
}

sub xmkdir_p ($ );
sub xmkdir_p ($ ) {
    my ($path)=@_;
    if (mkdir $path) {
	#done
	()
    } else {
	if ($! == EEXIST) {
	    if (-d $path) {
		# done
		()
	    } else {
		die "exists but not a directory: '$path'";
	    }
	} elsif ($! == ENOENT) {
	    xmkdir_p(dirname $path);
	    mkdir $path or die "could not mkdir('$path'): $!";
	} else {
	    die "could not mkdir('$path'): $!";
	}
    }
}

sub basename ($ ; $ ) {
    my ($path,$maybe_suffix)=@_;
    my $copy= $path;
    $copy=~ s|.*/||s;
    my $res= do {
    length($copy) ? $copy : do {
	# path ending in slash--or empty from the start.
	if ($path=~ s|/+\z||s) {
	    $path=~ s|.*/||s;
	    # ^ this is necessary since we did it on $copy only,
	    #   before!
	    if (length $path) {
		$path
	    } else {
		"/"  # or die? no.
	    }
	} else {
	    croak "basename(".singlequote_many(@_)
	      ."): cannot get basename from empty string";
	}
    }};
    if (defined $maybe_suffix and length $maybe_suffix) {
	$res=~ s/\Q$maybe_suffix\E\z//
	  or croak "basename (".singlequote_many(@_)
	    ."): suffix does not match '$res'";
    }
    $res
}

# / copies

1
