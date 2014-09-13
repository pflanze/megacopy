#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

PFLANZE::copy

=head1 SYNOPSIS

 use PFLANZE::copy 'xcopy_fast';

 xcopy_fast $from, $to, $file_size;
   # dies on errors, with an PFLANZE::Exception::error_writing_to_target
   # object if the error was writing to the target

=head1 DESCRIPTION

Fast file copy using sendfile. Uses sendfile on Linux >= 2.6.33, falls
back to File::Copy otherwise.

=cut


package PFLANZE::copy;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(xcopy_fast);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

{
    package PFLANZE::Exception::error_writing_to_target;
    use overload '""'=> sub {
	my $s=shift;
	$$s[0]
    }
}
sub target_die {
    my $e= bless [join "", @_ ], "PFLANZE::Exception::error_writing_to_target";
    die $e
}

sub check_space_die {
    # XXX this is a hack for cases where it's not clear from the
    # context whether it was the source or target that failed. It
    # won't work for write errors to the target; but the close calls
    # might catch the latter anyway later on, so perhaps that's good
    # enough.
    my ($err,$msg)=@_;
    if ($err=~ /out of space/i) {
	target_die $msg;
    } else {
	die $msg
    }
}

our $use_sendfile;

sub xcopy_fast ($$$) {
    my ($from, $to, $size)=@_;
    open my $in, "<", $from
      or die "open '$from': $!";
    open my $out, ">", $to
      or target_die "open '$to': $!";
    if ($use_sendfile) {
	my $res= Sys::Syscall::sendfile (fileno($out), fileno($in), $size);
	if ($res < 0) {
	    check_space_die "$!", "sendfile to '$to': $!";
	} elsif ($res != $size) {
	    die "sendfile to '$to': transferred $res instead of $size bytes ($!)";
	}
    } else {
	File::Copy::copy($in,$out)
	    or check_space_die "$!", "copying '$from', '$to': $!";
    }
    close $in or die "close while copying from '$from': $!";
    close $out or target_die "close while copying to '$to': $!";
}

BEGIN {
    my $verbose= $ENV{VERBOSE};

    my $impl_sendfile= sub {
	require Sys::Syscall;
	$use_sendfile=1;
    };
    my $impl_fallback= sub {
	require File::Copy;
	$use_sendfile=0;
    };

    if (`uname -s` =~ /^Linux/) {
	my $revision= `uname -r`; # something like "2.6.32-5-686-bigmem"
	my ($major,$minor,$patch)=
	    $revision=~ /^([0-9]+)\.([0-9]+)\.([0-9]+)/
	    or die "no match for '$revision'";
	if ($major > 2
	    or
	    ($major == 2 and
	     ($minor > 6
	      or
	      ($minor == 6 and $patch >= 33)))) {
	    warn "using sendfile for speed"
		if $verbose;
	    &$impl_sendfile;
	} else {
	    warn "Linux version too old, falling back to File::Copy"
		if $verbose;
	    &$impl_fallback;
	}
    } else {
	warn "not on Linux, falling back to File::Copy"
	    if $verbose;
	&$impl_fallback;
    }
}

1
