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
	      xbacktick
	      xtempdir
	      xtouch
	      xmkdir
	      xchdir
	      xfork
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
    my $dir= defined $maybe_dir ? $maybe_dir : ($ENV{TMPDIR} || "/tmp");
    my $template= ($main::myname || "pflanze") . "-XXXXXXXX";
    my ($fh, $path)= File::Temp::tempfile ($template, DIR=> $dir);
    $path
}

{
    package PFLANZE::File;
    sub xopen {
	my $cl= shift;
	my ($mode,$path)=@_;
	open my $fh, $mode, $path
	  or die "open $mode '$path': $!";
	bless +{path=> $path,fh=> $fh}, $cl
    }
    sub xprint {
	my $s=shift;
	my $fh= $$s{fh};
	print $fh @_
	  or die "writing to '$$s{path}': $!";
    }
    sub xclose {
	my $s=shift;
	close $$s{fh}
	  or die "closing '$$s{path}': $!";
    }
    sub xunlink {
	my $s=shift;
	unlink $$s{path}
	  or die "unlink '$$s{path}': $!";
    }
    sub path {
	my $s=shift;
	$$s{path}
    }
    sub fh {
	my $s=shift;
	$$s{fh}
    }
    sub reader {
	my $s=shift;
	# not using ref($s) as we don't want to make it a TempFile if
	# we are, just a normal File
	__PACKAGE__->xopen("<", $$s{path})
    }
    sub xsortfile {
	my $s=shift;
	PFLANZE::Fileutils::xsortfile($s->path, @_);
    }
}

{
    package PFLANZE::TempFile;
    our @ISA= qw(PFLANZE::File);
    use POSIX ();  # for getpid, as $$ doesn't work correctly
    sub xopen {
	my $cl=shift;
	my $s= $cl->SUPER::xopen(@_);
	$$s{pid}= POSIX::getpid;
	$s
    }
    sub xunlink {
	my $s=shift;
	$s->SUPER::xunlink(@_);
	undef $$s{pid};
    }
    sub DESTROY {
	my $s=shift;
	my $pid= POSIX::getpid;
	if (defined $$s{pid}
	    and $$s{pid}==$pid
	    ) {
	    undef $$s{pid};
	    print STDERR "leaving tempfile $$s{path}\n";
	}
    }
}


sub xtempfile {
    my ($maybe_dir)=@_;
    my $tmp= _tempfile $maybe_dir;
    PFLANZE::TempFile->xopen (">",$tmp)
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
    PFLANZE::TempFile->xopen("<", _xsortfile(@_));
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

sub xmkdir {
    if (@_==1) {
	mkdir $_[0]
	  or croak "xmkdir($_[0]): $!";
    } elsif (@_==2) {
	mkdir $_[0],$_[1]
	  or croak "xmkdir(".join(", ",@_)."): $!";
    } else {
	croak "xmkdir: wrong number of arguments";
    }
}

sub xchdir {
    chdir $_[0] or croak "xchdir '$_[0]': $!";
}

sub xfork() {
    my $pid=fork;
    defined $pid or croak "xfork: $!";
    $pid
}

# / copies

# reimplementation without need for dependencies

sub xbacktick {
    open my $in, "-|", @_
      or die "can't run '$_[0]': $!";
    my $res;
    {
	local $/;
	$res= <$in>;
    }
    close $in
      or do {
	  if (length "$!") {
	      die "closing output from '$_[0]': $!";
	  } else {
	      die "command '$_[0]' exited with code: $?";
	  }
      };
    chomp $res;
    $res
}


sub xtempdir {
    xbacktick "tempdir"
}

sub xtouch {
    xbacktick "touch", @_;
}

1
