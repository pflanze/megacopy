#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

PFLANZE::copy

=head1 SYNOPSIS

 use PFLANZE::copy 'copy_fast';

 copy_fast $from, $to, $file_size; # dies on errors

=head1 DESCRIPTION

Fast file copy using sendfile. Uses sendfile on Linux >= 2.6.33, falls
back to File::Copy otherwise.

=cut


package PFLANZE::copy;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(copy_fast);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

sub copy_fast ($$$);

BEGIN {
    my $verbose= $ENV{VERBOSE};

    my $impl_sendfile= sub {
	require Sys::Syscall;
	*copy_fast= sub ($$$) {
	    my ($from, $to, $size)=@_;
	    open my $in, "<", $from
		or die "open '$from': $!";
	    open my $out, ">", $to
		or die "open '$to': $!";
	    my $res= Sys::Syscall::sendfile (fileno($out), fileno($in), $size);
	    if ($res < 0) {
		die "sendfile to '$to': $!";
	    } elsif ($res != $size) {
		die "sendfile to '$to': transferred $res instead of $size bytes ($!)";
	    }
	    close $in or die "close while copying from '$from': $!";
	    close $out or die "close while copying to '$to': $!";
	};
    };
    my $impl_fallback= sub {
	require File::Copy;
	*copy_fast= sub ($$$) {
	    my ($from, $to, $size)=@_;
	    File::Copy::copy($from,$to)
		or die "copying '$from', '$to': $!";
	};
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
