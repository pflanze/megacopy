# Copyright 2003-2014 by Christian Jaeger. Published as Open Source
# software under the MIT License. See COPYING.md

=head1 NAME

PFLANZE::Xstat

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a copy of a section of
https://github.com/pflanze/chj-perllib/blob/master/Chj/xperlfunc.pm

=cut


package PFLANZE::Xstat;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(
		 xstat
		 xlstat
		 Xstat
		 Xlstat
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

use Carp;
use POSIX "ENOENT";

our $time_hires=0;

sub stat_possiblyhires {
    if ($time_hires) {
	require Time::HiRes; # (that's not slow, right?)
	Time::HiRes::stat(@_ ? @_ : $_)
    } else {
	stat(@_ ? @_ : $_)
    }
}

sub lstat_possiblyhires {
    if ($time_hires) {
	require Chj::Linux::HiRes;
	Chj::Linux::HiRes::lstat(@_ ? @_ : $_)
    } else {
	lstat(@_ ? @_ : $_)
    }
}

sub xstat {
    my @r;
    @_<=1 or croak "xstat: too many arguments";
    @r= stat_possiblyhires(@_);
    @r or croak (@_ ? "xstat: '@_': $!" : "xstat: '$_': $!");
    if (wantarray) {
	@r
    } elsif (defined wantarray) {
	my $self=\@r;
	bless $self,'Chj::xperlfunc::xstat'
    }
}

sub xlstat {
    my @r;
    @_<=1 or croak "xlstat: too many arguments";
    @r= lstat_possiblyhires(@_ ? @_ : $_);
    @r or croak (@_ ? "xlstat: '@_': $!" : "xlstat: '$_': $!");
    if (wantarray) {
	@r
    } elsif (defined wantarray) {
	my $self=\@r;
	bless $self,'Chj::xperlfunc::xstat'
    }
}

use Carp 'cluck';
sub Xstat {
    my @r;
    @_<=1 or croak "Xstat: too many arguments";
    @r= stat_possiblyhires(@_ ? @_ : $_);
    @r or do {
	if ($!== ENOENT) {
	    return;
	} else {
	    croak (@_ ? "Xstat: '@_': $!" : "Xstat: '$_': $!");
	}
    };
    if (wantarray) {
	cluck "Xstat call in array context doesn't make sense";
	@r
    } elsif (defined wantarray) {
	bless \@r,'Chj::xperlfunc::xstat'
    } else {
	cluck "Xstat call in void context doesn't make sense";
    }
}
sub Xlstat {
    my @r;
    @_<=1 or croak "Xlstat: too many arguments";
    @r= lstat_possiblyhires(@_ ? @_ : $_);
    @r or do {
	if ($!== ENOENT) {
	    return;
	} else {
	    croak (@_ ? "Xlstat: '@_': $!" : "Xlstat: '$_': $!");
	}
    };
    if (wantarray) {
	cluck "Xlstat call in array context doesn't make sense";
	@r
    } elsif (defined wantarray) {
	bless \@r,'Chj::xperlfunc::xstat'
    } else {
	cluck "Xlstat call in void context doesn't make sense";
    }
}

{
    package Chj::xperlfunc::xstat;
    ## Alternative to arrays: hashes, so that slices like
    ## ->{"dev","ino"} could be done? One can't have everything.
    sub dev     { shift->[0] }
    sub ino     { shift->[1] }
    sub mode    { shift->[2] }
    sub nlink   { shift->[3] }
    sub uid     { shift->[4] }
    sub gid     { shift->[5] }
    sub rdev    { shift->[6] }
    sub size    { shift->[7] }
    sub atime   { shift->[8] }
    sub mtime   { shift->[9] }
    sub ctime   { shift->[10] }
    sub blksize { shift->[11] }
    sub blocks  { shift->[12] }

    sub set_dev     { my $s= shift; ($s->[0])=@_; }
    sub set_ino     { my $s= shift; ($s->[1])=@_; }
    sub set_mode    { my $s= shift; ($s->[2])=@_; }
    sub set_nlink   { my $s= shift; ($s->[3])=@_; }
    sub set_uid     { my $s= shift; ($s->[4])=@_; }
    sub set_gid     { my $s= shift; ($s->[5])=@_; }
    sub set_rdev    { my $s= shift; ($s->[6])=@_; }
    sub set_size    { my $s= shift; ($s->[7])=@_; }
    sub set_atime   { my $s= shift; ($s->[8])=@_; }
    sub set_mtime   { my $s= shift; ($s->[9])=@_; }
    sub set_ctime   { my $s= shift; ($s->[10])=@_; }
    sub set_blksize { my $s= shift; ($s->[11])=@_; }
    sub set_blocks  { my $s= shift; ($s->[12])=@_; }

    # test helpers:
    sub permissions { shift->[2] & 07777 }
    sub permissions_oct { sprintf('%o',shift->permissions) } # 'copy' from Chj/BinHexOctDec.pm
    sub permissions_u { (shift->[2] & 00700) >> 6 }
    sub permissions_g { (shift->[2] & 00070) >> 3 }
    sub permissions_o { shift->[2] & 00007 }
    sub permissions_s { (shift->[2] & 07000) >> 9 }
    sub setuid { !!(shift->[2] & 04000) }
    # ^ I have no desire to put is_ in front.
    sub setgid { !!(shift->[2] & 02000) }
    sub sticky { !!(shift->[2] & 01000) }
    sub filetype { (shift->[2] & 0170000) >> 12 } # 4*3bits
    # guess access rights from permission bits
    # note that these might guess wrong (because of chattr stuff,
    # or things like grsecurity,lids,selinux..)!
    # also, this does not check parent folders of this item of course.
    sub checkaccess_for_submask_by_uid_gids {
	my $s=shift;
	my ($mod,$uid,$gids)=@_; # the latter being an array ref!
	return 1 if $uid==0;
	if ($s->[4] == $uid) {
	    #warn "uid do?";
	    return !!($s->[2] & (00100 * $mod))
	} else {
	    if ($gids) {
		for my $gid (@$gids) {
		    length($gid)==length($gid+0)
			or Carp::croak "invalid gid argument '$gid' - maybe "
			." you forgot to split '\$)'?";
		    ## todo: what if one is member of group 0, is this special?
		    if ($s->[5] == $gid) {
			if ($s->[2] & (00010 * $mod)) {
			    #warn "gid yes";
			    return 1;
			} else {
			    # groups stick just like users, so even if
			    # others are allowed, we are not
			    return 0;
			}
		    }
		}
		# check others
		#warn "others. mod=$mod, uid=$uid, gids sind @$gids";
		return !!($s->[2] & (00001 * $mod))
	    } else {
		Carp::croak "missing gids argument - might just be a ref to "
		    ."an empty array";
	    }
	}
    }
    sub readable_by_uid_gids {
	splice @_,1,0,4;
	goto &checkaccess_for_submask_by_uid_gids;
    }
    sub writeable_by_uid_gids {
	splice @_,1,0,2;
	goto &checkaccess_for_submask_by_uid_gids;
    }
    *writable_by_uid_gids= *writeable_by_uid_gids;
    sub executable_by_uid_gids {
	splice @_,1,0,1;
	goto &checkaccess_for_submask_by_uid_gids;
    }

    sub Filetype_is_file { shift == 8 }
    sub is_file { Filetype_is_file(shift->filetype) } # call it is_normalfile ?
    sub Filetype_is_dir { shift == 4 }
    sub is_dir { Filetype_is_dir(shift->filetype) }
    sub Filetype_is_link { shift == 10 }
    sub is_link { Filetype_is_link(shift->filetype) }
    *is_symlink= \&is_link;
    sub Filetype_is_socket { shift == 12 }
    sub is_socket { Filetype_is_socket(shift->filetype) }
    sub Filetype_is_chardevice { shift == 2 }
    sub is_chardevice { Filetype_is_chardevice(shift->filetype) }
    sub Filetype_is_blockdevice { shift == 6 }
    sub is_blockdevice { Filetype_is_blockdevice(shift->filetype) }
    sub Filetype_is_pipe { shift == 1 } # or call it is_fifo?
    sub is_pipe { Filetype_is_pipe(shift->filetype) }

    sub type {
	my $s=shift;
	if ($s->is_dir) { "dir" }
	elsif ($s->is_link) { "link" }
	elsif ($s->is_file) { "file" }
	elsif ($s->is_socket) { "socket" }
	elsif ($s->is_chardevice) { "chardevice" }
	elsif ($s->is_blockdevice) { "blockdevice" }
	elsif ($s->is_pipe) { "pipe" }
	else { die "unknown type of filetype: ".$s->filetype }
    }

    # check whether "a file has changed"
    sub equal_content {
	my $s=shift;
	my ($s2)=@_;
	($s->dev == $s2->dev
	 and $s->ino == $s2->ino
	 and $s->size == $s2->size
	 and $s->mtime == $s2->mtime)
    }
    sub equal {
	my $s=shift;
	my ($s2)=@_;
	# permissions:
	($s->equal_content($s2)
	 and $s->mode == $s2->mode
	 and $s->uid == $s2->uid
	 and $s->gid == $s2->gid
	)
    }
    sub same_node {
	my $s=shift;
	my ($s2)=@_;
	($s->ino == $s2->ino
	 and $s->dev == $s2->dev)
    }
}


1
