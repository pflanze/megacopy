# megacp - copy huge numbers of files with hardlinks without running out of RAM

Copying filesystem trees on POSIX systems so that files which are hard
linked in the source tree will be linked the same way in the target
requires that the copying program maintains knowledge about which
paths belong to the same inode/device pair, at least for those files
which have a link count >1 (which can be many or most in some
cases).

The cp program from GNU coreutils (as of version 8.23) does this by
storing inode/device and the full path in a hash table. This requires
random access space (i.e. RAM) proportional to the number of files
being copied, which, with enough files, could be a problem.

megacp does it by creating a temporary file holding all the
inode/device/path combinations first, then sorting it according to
inode/device (hopefully in a way that's much less dependent on RAM),
then parsing it back to do the actual copying, now encountering all
the paths that need to be linked in groups.

This is a work in progress. It was motivated by the post
[My experience with using cp to copy 432 million files (39 TB)]
(http://lists.gnu.org/archive/html/coreutils/2014-08/msg00012.html)
([HN discussion](https://news.ycombinator.com/item?id=8305283)).

It now implements efficient file copying.

See limitations in --help text and in TODO file.


# Installation

- install Sys::Syscall (libsys-syscall-perl package on Debian)

- check it out

    # mkdir /opt/chj
    # cd /opt/chj
    # git clone https://github.com/pflanze/megacopy.git

- make it accessible to your PATH:

    # ln -s /opt/chj/megacopy/megacp /usr/local/bin

  or

    # PATH=/opt/chj/megacopy:"$PATH"

  or simply access it by its full path

    # /opt/chj/megacopy/megacp

