
pbdupes 2023/4
===============

Program finds duplicates files.
-----------

Features are::

 SHOW-...   Display all programs with the same HASH
 MOVE-...   MOVE ONLY, NOT DELETE

 The first identical existing "FILE" found is not moved.

 UNIX   : Hard/Symlinks are not followed
 Windows: Symlinks ar not followed
 
 HASH: MD5 ord SHA1
 FULL or HASH-DEPTH = multiple of 4096
 MIN-FILE_SIZE      = 0


 The filname in the New folder is changed in "Old-Path + File-Name"


--------

Parameters are::

 pbdupes -SHOW-FULL-MD5-HASH <PATH> <EXTENSION>. Only Show, no action.
 pbdupes -SHOW-FAST-MD5-HASH <PATH> <EXTENSION> <HASH-DEPTH>. Only Show, no action.
	
 pbdupes -MOVE-FULL-MD5-HASH <PATH> <EXTENSION> <DESTINATION DUP>.
 pbdupes -MOVE-FAST-MD5-HASH <PATH> <EXTENSION> <DESTINATION DUP> <HASH-DEPTH>.
	
 pbdupes -SHOW-FULL-SHA1-HASH <PATH> <EXTENSION>. Only Show, no action.
 pbdupes -SHOW-FAST-SHA1-HASH <PATH> <EXTENSION> <HASH-DEPTH>. Only Show, no action.
	
 pbdupes -MOVE-FULL-SHA1-HASH <PATH> <EXTENSION> <DESTINATION DUP>.
 pbdupes -MOVE-FAST-SHA1-HASH <PATH> <EXTENSION> <DESTINATION DUP> <HASH-DEPTH>.
	
--------

Example::

 Example Linux           :  pbdupes -MOVE-FAST-SHA1-HASH '.' '*' DUP_Path 100
 Example Linux           :  pbdupes -SHOW-FAST-MD5-HASH '.' '*.pas' 100 >dup_list
 
 Example Windows or other:  pbdupes -MOVE-FAST-SHA1-HASH . * 100 >dup_list
 Example Windows or other:  pbdupes -MOVE-FAST-MD5-HASH "c:\Program Files" * DUP_Path 100

--------

Compile::

 fpc pbdupes.pas

 You can compile the program under all OS and architectures which support FreePascal.

--------

Program : pbdupes 2023/4, Finds duplicates. No delete, move only, Developer : Peter Boettcher, Germany/NRW, Muelheim Ruhr, peter.boettcher@gmx.net,
Development : FreePascal, FreePascal Project : www.freepascal.org, Packages, runtime library : modified LGPL, www.gnu.org, Special Thanks : Niklaus Wirth, Florian Klaempfl and others

--------

I remember::
 
 I would like to remember ALICIA ALONSO, MAYA PLISETSKAYA, CARLA FRACCI, EVA EVDOKIMOVA,
 VAKHTANG CHABUKIANI and the "LAS CUATRO JOYAS DEL BALLET CUBANO".
 
 Admirable ballet dancers.
-------

