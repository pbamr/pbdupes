Many thanks to Mikos Szeredi and all the many others.

Extension for the orphaned PROJECT SSHFS 
========================================

* For me this extension is very important.
------

* The extension/code can be found under "NEW:" in "sshfs.c"! Search "NEW:"

* The extensions are: "chmod FILE" and "chmod FOLDER"::

  -o chmod_file=owner/group/other
  -o chmod_dir=owner/group/other


Example::  

 -o chmod_file=660
 -o chmod_dir=2770


Working::

 when you create a file, the file gets the "chmod_file" rights.
 when you create a folder, the folder gets the "chmod_dir" rights.

 Copying files and folders works the same way.
 
 It should be noted that some file managers try to set the original file rights after copying.
 
 The program "cp" works fine.


--------------------

Example::

  sshfs -o allow_other -o default_permissions -o chmod_file=660 -o chmod_dir=2770 user@HOST:[directory] mount_point
  
  This is still possible. Or other.
  sshfs -o allow_other -o default_permissions user@HOST:[directory] mount_point
  
--------

I remember::
 
 I would like to remember ALICIA ALONSO, MAYA PLISETSKAYA, CARLA FRACCI, EVA EVDOKIMOVA,
 VAKHTANG CHABUKIANI and the "LAS CUATRO JOYAS DEL BALLET CUBANO".
 
 Admirable ballet dancers.
-------


About
-----

SSHFS allows you to mount a remote filesystem using SFTP.

It is recommended to run SSHFS as regular user (not as root).  For
this to work the mountpoint must be owned by the user.  If username is
omitted SSHFS will use the local username. If the directory is
omitted, SSHFS will mount the (remote) home directory.  If you need to
enter a password sshfs will ask for it (actually it just runs ssh
which asks for the password if needed).

Also many ssh options can be specified (see the manual pages for
*sftp(1)* and *ssh_config(5)*), including the remote port number
(``-oport=PORT``)

To unmount the filesystem::

    fusermount -u mountpoint

On BSD and macOS, to unmount the filesystem::

    umount mountpoint


Installation
------------

First, download pbamr/SSHFS release. You also need libfuse_ 3.1.0 or newer (or a
similar library that provides a libfuse3 compatible interface for your operating
system). Finally, you need the Glib_ library with development headers (which should be
available from your operating system's package manager).

The important file is sshfs.c in pbamr/sshfs.c

To build and install, we recommend to use Meson_ (version 0.38 or
newer) and Ninja_.  After extracting the sshfs tarball, create a
(temporary) build directory and run Meson::

    $ mkdir build; cd build
    $ meson ..

Normally, the default build options will work fine. If you
nevertheless want to adjust them, you can do so with the *mesonconf*
command::

    $ mesonconf                  # list options
    $ mesonconf -D strip=true    # set an option

To build, test and install SSHFS, you then use Ninja (running the
tests requires the `py.test`_ Python module)::

    $ ninja
    $ python3 -m pytest test/    # optional, but recommended
    $ sudo ninja install

