#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

PFLANZE::copy

=head1 SYNOPSIS

=head1 DESCRIPTION

Fast file copy using sendfile. Uses sendfile on Linux >= 2.6.33;
actually just uses that right now and will fail otherwise.

=cut


package PFLANZE::copy;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(copy_fast);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Sys::Syscall ":sendfile";

sub copy_fast ($$$) {
    my ($from, $to, $size)=@_;
    open my $in, "<", $from
      or die "open '$from': $!";
    open my $out, ">", $to
      or die "open '$to': $!";
    my $res= sendfile (fileno($out), fileno($in), $size);
    if ($res < 0) {
	die "sendfile to '$to': $!";
    } elsif ($res != $size) {
	die "sendfile to '$to': transferred $res instead of $size bytes ($!)";
    }
    close $in or die "close while copying from '$from': $!";
    close $out or die "close while copying to '$to': $!";
}


1
