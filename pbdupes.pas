(* 
   Copyright (c) 2023/04, Peter Boettcher, Germany/NRW, Muelheim Ruhr
 * Urheber: 2023/04/07, Peter Boettcher, Germany/NRW, Muelheim Ruhr

 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.


   Program                   : pbdupes 2023/4
                             : Finds duplicates. No delete, move only.

   Developer                 : Peter Boettcher, Germany/NRW, Muelheim Ruhr, peter.boettcher@gmx.net
   Development               : FreePascal

   FreePascal Project        : www.freepascal.org
   Packages, runtime library : modified LGPL, www.gnu.org

   Special Thanks            : Niklaus Wirth
                               Florian Klaempfl and others



  -------------------------------------------------------------------------------------------
  FreePascal Compile: fpc pbdupes.pas

  You can compile the program under all OS and architectures which support FreePascal.


  Parameter "SHOW-... " = Display all programs with the same "HASH"

  Parameter "MOVE-..."  = MOVE ONLY, NOT DELETE.
  The first identical existing "FILE" found is not moved.
  UNIX: Hard/Symlink are not FOLLOWED!!

  HASH-DEPTH     = multiple of 4096.
  MIN-FILE_SIZE  = 0

  Example Linux           :  pbdupes -MOVE-FAST-MD5-HASH '.' '*' Dup_Path 100 0
  Example Linux           :  pbdupes -MOVE-FAST-MD5-HASH '.' '*.pas' Dup_Path 100 100
  Example Windows or other:  pbdupes -MOVE-FAST-MD5-HASH . * Dup_Path 100 111


  The filname is changed in "Old-Path + File-Name"



  -------------------------------------------------------------------------------------------



  I would like to remember ALICIA ALONSO, MAYA PLISETSKAYA, CARLA FRACCI, EVA EVDOKIMOVA, VAKHTANG CHABUKIANI and the
  "LAS CUATRO JOYAS DEL BALLET CUBANO". Admirable ballet dancers.

*)
	
	
	
	
	
{$SMARTLINK ON}
{$mode objfpc}
{$Packrecords 1}
{$H+} //{$longstrings on}
	
{$define SYMLINKS}					//UNIX and Windows. All OS = Support Links. I hope?
	
	
	
	
Uses
	{$ifdef Unix} baseUnix, {$endif}	//Linux, BSD, Darwin/OSX, Solaris
	sysutils,
	strutils,
	md5,
	sha1;
	
	
	
	
type
	FILES_FOUND = record
		NAME		: ansistring;
		LENGTH		: int64;
		HASH		: ansistring;
		DUP		: boolean;
	end;
	
	
	
	
type
	TpFilesDup = class
		strict private
		var
			A : array of ^FILES_FOUND;
			B : array of ^FILES_FOUND;
			
			
			
		public
		Function FileRead(FILE_str	: ansistring;
			 var Buffer		: ansistring) : int64;
			
		Function CopyFile(SOURCE_str		: ansistring;
				  DESTINATION_str	: ansistring) : int64;
		
		
		Function GetFilesDir(PATH			: ansistring;
				     EXTENSIONS			: ansistring;
				     MIN_FILE_SIZE		: qword) : int64;
		
		Procedure SetArrayLen(Elements : int64);
		Procedure ArrayFree;
		Procedure AddElement;
		Function GetFileName(Nr : int64) : ansistring;
		Function GetFileLength(Nr : int64) : int64;
		Function GetFileHash(Nr : int64) : ansistring;
		Function GetArrayLen : int64;
		Procedure QuickSortFileLength;
		Procedure QuickSortFileHash;
		Procedure DupFilesFindLength;
		Procedure CalcFastMD5Hash(HASH_DEPTH : int64);
		Procedure CalcFullMD5Hash;
		Procedure DupFilesFindHash(FLAG : boolean);
		Procedure CalcFullSHA1Hash;
		Procedure CalcFastSHA1Hash(HASH_DEPTH : int64);
	end;
	
	
	
	
	
	
//****************************************************************************************************************************************
Function TpFilesDup.FileRead(FILE_str	: ansistring;
			     var Buffer	: ansistring) : int64;
	
Var
	FILE_Handle	: file Of char;
	RetRead		: int64;
	
	
	
Begin
	System.Assign(FILE_Handle, FILE_str);
	
	try
		System.Reset(FILE_Handle);
	except
		exit(-1);
	end;
	
	System.BlockRead(FILE_Handle, Buffer[1], length(Buffer), RetRead);
	
	System.Close(FILE_Handle);
	
	if RetRead <> length(Buffer) then exit(-1)
	else exit(0);
	
end;
	
	
	
	
	
Function TpFilesDup.CopyFile(SOURCE_str		: ansistring;
			     DESTINATION_str	: ansistring) : int64;
	
var
	SOURCE		: File of char;
	DESTINATION	: File of char;
	BUFFER		: ansistring;
	RetRead		: int64;
	RetWrite	: int64;
	
	
	
begin
	System.Assign(SOURCE, SOURCE_str);
	try
		System.Reset(SOURCE);
	except
		exit(-1);
	end;
	
	System.Assign(DESTINATION, DESTINATION_str);
	try
		System.Rewrite(DESTINATION);
	except
		System.Close(SOURCE);
		exit(-1);
	end;
	
	setlength(BUFFER, 1000000);
	
	while(TRUE) do begin
		System.BlockRead (SOURCE, BUFFER[1], 1000000, RetRead);
		if RetRead = 0 then break;
		System.BlockWrite (DESTINATION, BUFFER[1], RetRead, RetWrite);
		if RetWrite = 0 then break;
	end;
	
	
	System.Close(SOURCE);
	System.Close(DESTINATION);
	exit(0);
end;
	
	
	
	
	
	
Function TpFilesDup.GetFilesDir(PATH		: ansistring;
				EXTENSIONS	: ansistring;
				MIN_FILE_SIZE	: qword) : int64;
	
Var
	INFO	: TSearchRec;
	n	: int64;
	
	
	
Begin
	{$ifdef SYMLINKS}
	If SysUtils.FindFirst(PATH + PathDelim + '*', SysUtils.FaAnyFile and not SysUtils.FaSymlink, INFO) <> 0 Then exit(-1);
	{$else}
		If SysUtils.FindFirst(PATH + PathDelim + '*', SysUtils.FaAnyFile, INFO) <> 0 Then exit(-1);
	{$endif}
	
	
	Repeat
		If (Info.Attr And SysUtils.FaDirectory) = Sysutils.Fadirectory Then begin
			
			if Info.Name = '..' Then continue;
			If Info.Name = '.' Then continue;
			
			//test: folder is hard-link 
			{$ifdef unix}
			if fpreadlink(PATH) <> '' then continue;
			{$endif}
			
			
			GetFilesDir(PATH + PathDelim + Info.Name, EXTENSIONS, MIN_FILE_SIZE);
			continue;
		end;
		
		//test: file is hard-link
		{$ifdef unix}
		if fpreadlink(PATH + PathDelim + Info.Name) <> '' then continue;
		{$endif}
		
		if INFO.Size < MIN_FILE_SIZE then continue;
		
		//filter
		if StrUtils.IsWild(INFO.NAME, EXTENSIONS, true) = true then begin
			n := length(A); //only once
			setlength(A, n + 1);
			
			NEW(A[n]);
			A[n]^.NAME := PATH + PathDelim + Info.Name;
			A[n]^.LENGTH := INFO.Size;
			A[n]^.DUP := FALSE;
			
		end;
		
	Until SysUtils.FindNext (Info) <> 0;
	
	SysUtils.FindClose (Info);
	
	exit(0);
	
end;
	
	
	
	
	
	
Procedure TpFilesDup.SetArrayLen(Elements : int64);
var
	n : int64;
	
	
	
begin
	for n := 0 to length(A) - 1  do begin
		Dispose(A[n]);
	end;
	
	setlength(A, Elements);
end;
	
	
	
	
	
Procedure TpFilesDup.ArrayFree;
var
	n : int64;
	
	
	
begin
	for n := 0 to length(A) - 1  do begin
		Dispose(A[n]);
	end;
	
	for n := 0 to length(B) - 1  do begin
		Dispose(B[n]);
	end;
	
	setlength(A, 0);
	setlength(B, 0);
end;
	
	
	
	
	
Procedure TpFilesDup.AddElement;
var
	len : int64;
	
	
	
begin
	len := length(A);
	setlength(A, len + 1);
	New(A[len]);
end;
	
	
	
	
	
Function TpFilesDup.GetFileName(Nr : int64) : ansistring;
begin
	if Nr >= length(A) then exit('');
	exit(A[Nr]^.NAME);
end;
	
	
	
	
	
Function TpFilesDup.GetFileLength(Nr : int64) : int64;
begin
	if Nr >= length(A) then exit(-1);
	exit(A[Nr]^.LENGTH);
end;
	
	
	
	
	
Function TpFilesDup.GetFileHash(Nr : int64) : ansistring;
begin
	if Nr >= length(A) then exit('');
	exit(A[Nr]^.HASH);
end;
	
	
	
	
	
Function TpFilesDup.GetArrayLen : int64;
begin
	exit(length(A));
end;
	
	
	
	
	
Procedure TpFilesDup.QuickSortFileLength;
	
Procedure Sort(L : int64; R : int64);
var
	i, j	: int64;
	x	: int64;
	tmp	: pointer;
	
begin
	
	i	:= L;
	j	:= R;
	x	:= A[(L + R) div 2]^.LENGTH;
	
	repeat
		while A[i]^.LENGTH < x do inc(i);
		while x < A[j]^.LENGTH do dec(j);
		if i <= j then begin
			tmp := A[i];
			A[i] := A[j];
			A[j] := tmp;
			inc(i); dec(j);
		end;
	until I > J;
	
	if L < J then Sort(L, J);
	if I < R then Sort(i, R);
	
end;
	
	
begin
	Sort(0, length(A) - 1);
end;
	
	
	
	
	
Procedure TpFilesDup.QuickSortFileHash;
	
Procedure Sort(L : int64; R : int64);
var
	i, j	: int64;
	x	: ansistring;
	tmp	: pointer;
	
begin
	
	i	:= L;
	j	:= R;
	x	:= A[(L + R) div 2]^.HASH;
	
	repeat
		while A[i]^.HASH < x do inc(i);
		while x < A[j]^.HASH do dec(j);
		if i <= j then begin
			tmp := A[i];
			A[i] := A[j];
			A[j] := tmp;
			inc(i); dec(j);
		end;
	until I > J;
	
	if L < J then Sort(L, J);
	if I < R then Sort(i, R);
	
end;
	
	
begin
	Sort(0, length(A) - 1);
end;
	
	
	
	
	
	
Procedure TpFilesDup.DupFilesFindLength;
var
	n0, n1, len : int64;
	
	
	
begin
	len := length(a);
	//SIZE?
	for n0 := 0 to len - 2 do begin
		for n1 := n0 + 1 to len - 1 do begin
			if A[n0]^.LENGTH = A[n1]^.LENGTH then begin
					A[n0]^.DUP := TRUE;
					A[n1]^.DUP := TRUE;
			end;
		end;
	end;
	
	
	for n0 := 0 to length(B) - 1  do begin
		Dispose(B[n0]);
	end;
	setlength(B, 0);
	
	for n0 := 0 to length(A) - 1 do begin 
		if A[n0]^.DUP = TRUE then begin
			len := length(B);
			setlength(B, len + 1);
			B[len] := A[n0];
		end
		else Dispose(A[n0]);
	end;
	
	len := length(B);
	setlength(A, len);
	
	for n0 := 0 to len - 1 do begin
		A[n0] := B[n0];
		A[n0]^.DUP := FALSE;
	end;
	
	
	setlength(B, 0);
	
	if len > 1 then QuickSortFileLength;
	
end;
	
	
	
	
	
	
Procedure TpFilesDup.CalcFastMD5Hash(HASH_DEPTH : int64);
var
	n		: int64;
	ansistring_0	: ansistring;
	
	
	
begin
	for n := 0 to length(A) - 1 do begin 
		if A[n]^.LENGTH < HASH_DEPTH then begin 
			A[n]^.HASH := MD5Print(MD5File(A[n]^.NAME));
			writeln(A[n]^.HASH, '  ', A[n]^.LENGTH:18,'  ', A[n]^.NAME);
		end
		else begin
			setlength(ansistring_0, HASH_DEPTH - 100);
			FileRead(A[n]^.NAME, ansistring_0);
			A[n]^.HASH := MD5Print(MD5String(ansistring_0));
			writeln(A[n]^.HASH, '  ', A[n]^.LENGTH:18,'  ', A[n]^.NAME);
		end;
	end;
	
end;
	
	
	
	
	
Procedure TpFilesDup.CalcFullMD5Hash;
var
	n : int64;
	
	
	
begin
	//Hash?
	for n := 0 to length(A) - 1 do begin 
		A[n]^.HASH := MD5Print(MD5File(A[n]^.NAME));
		writeln(A[n]^.HASH, '   ', A[n]^.LENGTH:18, '    ', A[n]^.NAME);
	end;
	
end;
	
	
	
	
	
Procedure TpFilesDup.DupFilesFindHash(FLAG : boolean);
var
	n0, n1, len : int64;
	
	
	
begin
	len := length(a);
	//SIZE?
	for n0 := 0 to len - 2 do begin
		for n1 := n0 + 1 to len - 1 do begin
			if A[n0]^.HASH = A[n1]^.HASH then begin
					if FLAG = TRUE then A[n0]^.DUP := TRUE;
					A[n1]^.DUP := TRUE;
			end;
		end;
	end;
	
	
	for n0 := 0 to length(B) - 1  do begin
		Dispose(B[n0]);
	end;
	setlength(B, 0);
	
	for n0 := 0 to length(A) - 1 do begin 
		if A[n0]^.DUP = TRUE then begin
			len := length(B);
			setlength(B, len + 1);
			B[len] := A[n0];
		end
		else Dispose(A[n0]);
	end;
	
	len := length(B);
	setlength(A, len);
	
	for n0 := 0 to len - 1 do begin
		A[n0] := B[n0];
		A[n0]^.DUP := FALSE;
	end;
	
	
	setlength(B, 0);
	
	
end;
	
	
	
	
	
Procedure TpFilesDup.CalcFullSHA1Hash;
var
	n : int64;
	
	
	
begin
	//Hash?
	for n := 0 to length(A) - 1 do begin 
		try
			A[n]^.HASH := SHA1Print(SHA1File(A[n]^.NAME));
			writeln(A[n]^.HASH, '   ', A[n]^.LENGTH:18, '    ', A[n]^.NAME);
		except
			//do nothing
		end;
	end;
	
end;
	
	
	
	
	
Procedure TpFilesDup.CalcFastSHA1Hash(HASH_DEPTH : int64);
var
	n		: int64;
	ansistring_0	: ansistring;
	
	
	
begin
	for n := 0 to length(A) - 1 do begin 
		if A[n]^.LENGTH < HASH_DEPTH then begin 
			try
				A[n]^.HASH := SHA1Print(SHA1File(A[n]^.NAME));
				writeln(A[n]^.HASH, '  ', A[n]^.LENGTH:18,'  ', A[n]^.NAME);
			except
				//do nothing
			end;
		end
		else begin
			setlength(ansistring_0, HASH_DEPTH - 100);
			try
				FileRead(A[n]^.NAME, ansistring_0);
				A[n]^.HASH := SHA1Print(SHA1String(ansistring_0));
				writeln(A[n]^.HASH, '  ', A[n]^.LENGTH:18,'  ', A[n]^.NAME);
			except
				//do nothing
			end;
		end;
	end;
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure ErrorMessage;
begin
	writeln('Program                   : pbdupes 2023/4');
	writeln('Development               : FreePascal');
	writeln('FreePascal Project        : www.freepascal.org');
	writeln('Packages, runtime library : modified LGPL, www.gnu.org');
	writeln;
	writeln('                            Special Thanks Niklaus Wirth');
	writeln;
	writeln('Parameter                 : -SHOW-FULL-MD5-HASH <PATH> <EXTENSION> <MIN. FILE SIZE>. Only Show, no action');
	writeln('Parameter                 : -SHOW-FAST-MD5-HASH <PATH> <EXTENSION> <HASH-DEPTH> <MIN. FILE SIZE>. Only Show, no action');
	writeln;
	writeln('Parameter                 : -MOVE-FULL-MD5-HASH <PATH> <EXTENSION> <DESTINATION DUP> <MIN. FILE SIZE>');
	writeln('Parameter                 : -MOVE-FAST-MD5-HASH <PATH> <EXTENSION> <DESTINATION DUP> <HASH-DEPTH> <MIN. FILE_SIZE>');
	writeln;
	writeln('Parameter                 : -SHOW-FULL-SHA1-HASH <PATH> <EXTENSION> <MIN. FILE SIZE>. Only Show, no action');
	writeln('Parameter                 : -SHOW-FAST-SHA1-HASH <PATH> <EXTENSION> <HASH-DEPTH> <MIN. FILE SIZE>. Only Show, no action');
	writeln;
	writeln('Parameter                 : -MOVE-FULL-SHA1-HASH <PATH> <EXTENSION> <DESTINATION DUP> <MIN. FILE SIZE>');
	writeln('Parameter                 : -MOVE-FAST-SHA1-HASH <PATH> <EXTENSION> <DESTINATION DUP> <HASH-DEPTH> <MIN. FILE SIZE>');
	writeln;
	writeln('                            HASH-DEPTH    : multiple of 4096');
	writeln('                            MIN-FILE-SIZE : 0');
	writeln;
	writeln('                            UNIX      : LINKS are not FOLLOWED!');
	writeln('                            Windows   : SymLINKS are not FOLLOWED!');
	writeln;
	writeln('Example Linux             : pbdupes -MOVE-FAST-MD5-HASH ''.'' ''*'' Dup_Path 100 0');
	writeln;
	writeln('Example Windows or other  : pbdupes -MOVE-FAST-MD5-HASH . * Dup_Path 100 10000');
	writeln('Example Windows or other  : pbdupes -MOVE-FAST-MD5-HASH "c\Program Files" * Dup_Path 100 0');
	writeln;
	writeln;
	writeln('Parameter -MOVE-...       : "MOVE" ONLY, NOT DELETE.');
	writeln('                            The first identical existing "FILE" found is not moved');
	writeln;
	writeln('Parameter -SHOW-...       : Display all programs with the same "HASH"');
	writeln;
	writeln;
	writeln('                            I would like to remember ALICIA ALONSO, MAYA PLISETSKAYA,');
	writeln('                            CARLA FRACCI, EVA EVDOKIMOVA, VAKHTANG CHABUKIANI');
	writeln('                            and the "LAS CUATRO JOYAS DEL BALLET CUBANO".');
	writeln('                            Admirable ballet dancers.');
	writeln;
	halt(1);
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure SHOW_FULL_MD5_HASH;
var
	PATH		: ansistring;
	EXTENSION	: ansistring;
	MIN_FILE_SIZE	: qword;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	pFilesFound	: TpFilesDup;
	
	
	
begin
	if ParamCount <> 4 then ErrorMessage;
	
	PATH := ParamStr(2);
	EXTENSiON := ParamStr(3);
	
	pFilesFound := TpFilesDup.Create;
	
	if TryStrToQword(ParamStr(4), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	//pFilesFound.CalcFullHash;
	pFilesFound.CalcFullMD5Hash;
	pFilesFound.DupFilesFindHash(TRUE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE:');
	writeln;
	
	Counter := 0;
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin 
		writeln(pFilesFound.GetFileHash(n), '   ', pFilesFound.GetFileLength(n):18, '    ', pFilesFound.GetFileName(n));
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('MD5 HASH     : DEPTH      : FULL');
	writeln('FILES        : SAME HASH  : ', COUNTER);
	writeln('STORAGE      : FREE SPACE : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure SHOW_FAST_MD5_HASH;
	
var
	PATH		: ansistring;
	EXTENSION	: ansistring;
	HASH_DEPTH	: qword;
	MIN_FILE_SIZE	: qword;
	
	pFilesFound	: TpFilesDUP;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	
	
begin
	if ParamCount <> 5 then ErrorMessage;
	
	PATH := ParamStr(2);
	EXTENSiON := ParamStr(3);
	
	if TryStrToQword(ParamStr(4), HASH_DEPTH) = FALSE then ErrorMessage;
	if HASH_DEPTH < 1 then ErrorMessage;
	if HASH_DEPTH > 10000000 then ErrorMessage
	else HASH_DEPTH :=  HASH_DEPTH * 4096;
	
	if TryStrToQword(ParamStr(5), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound := TpFilesDup.Create;
	
	//test: strict private
	//FilesFound.A[0].HASH := 'aaaaaaaaa';
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	pFilesFound.CalcFastMD5Hash(HASH_DEPTH);
	pFilesFound.DupFilesFindHash(TRUE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE:');
	writeln;
	
	Counter := 0;
	
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin 
		writeln(pFilesFound.GetFileHash(n), '   ', pFilesFound.GetFileLength(n):18, '    ', pFilesFound.GetFileName(n));
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('MD5 HASH   : DEPTH       : ', HASH_DEPTH);
	writeln('FILES      : SAME HASH   : ', COUNTER);
	writeln('STORAGE    : FREE SPACE  : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure MOVE_FAST_MD5_HASH;
var
	PATH		: ansistring;
	PATH_DEST	: ansistring;
	EXTENSION	: ansistring;
	HASH_DEPTH	: qword;
	MIN_FILE_SIZE	: qword;
	
	pFilesFound	: TpFilesDup;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	ansistring_0	: ansistring;
	
	
	
begin
	if ParamCount <> 6 then ErrorMessage;
	
	PATH		:= ParamStr(2);
	EXTENSiON	:= ParamStr(3);
	PATH_DEST	:= ParamStr(4);
	
	if TryStrToQword(ParamStr(5), HASH_DEPTH) = FALSE then ErrorMessage;
	if HASH_DEPTH < 1 then ErrorMessage;
	if HASH_DEPTH > 10000000 then ErrorMessage
	else HASH_DEPTH :=  HASH_DEPTH * 4096;
	
	if TryStrToQword(ParamStr(6), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound := TpFilesDup.Create;
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	pFilesFound.CalcFastMD5Hash(HASH_DEPTH);
	pFilesFound.DupFilesFindHash(FALSE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE: MOVE');
	writeln;
	Counter := 0;
	
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin
		ansistring_0 := pFilesFound.GetFileName(n);
		if ansistring_0[1] = '.' then Delete(ansistring_0, 1, 1);
		ansistring_0 := StringReplace(ansistring_0, PathDelim, '::', [rfReplaceAll]);
		
		writeln(pFilesFound.GetFileName(n));
		writeln('-> ' + PATH_DEST + PathDelim + ansistring_0);
		
		if RenameFile(pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = FALSE then begin
			if pFilesFound.CopyFile (pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = 0 then
				DeleteFile(pFilesFound.GetFileName(n))
			else writeln('ERROR: MOVE FILE!');
		end;
			
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
		
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('MD5 HASH    : DEPTH       : ', HASH_DEPTH);
	writeln('FILES       : SAME HASH   : ', COUNTER);
	writeln('STORAGE     : FREE SPACE  : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure MOVE_FULL_MD5_HASH;
var
	PATH		: ansistring;
	PATH_DEST	: ansistring;
	EXTENSION	: ansistring;
	MIN_FILE_SIZE	: qword;
	
	pFilesFound	: TpFilesDup;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	ansistring_0	: ansistring;
	
	
	
begin
	if ParamCount <> 5 then ErrorMessage;
	
	PATH		:= ParamStr(2);
	EXTENSiON	:= ParamStr(3);
	PATH_DEST	:= ParamStr(4);
	
	pFilesFound := TpFilesDup.Create;
	
	if TryStrToQword(ParamStr(5), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	pFilesFound.CalcFullMD5Hash;
	pFilesFound.DupFilesFindHash(FALSE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE: MOVE');
	writeln;
	
	Counter := 0;
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin
		ansistring_0 := pFilesFound.GetFileName(n);
		if ansistring_0[1] = '.' then Delete(ansistring_0, 1, 1);
		ansistring_0 := StringReplace(ansistring_0, PathDelim, '::', [rfReplaceAll]);
		
		writeln(pFilesFound.GetFileName(n));
		writeln('-> ' + PATH_DEST + PathDelim + ansistring_0);
		
		if RenameFile(pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = FALSE then begin
			if pFilesFound.CopyFile (pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = 0 then
				DeleteFile(pFilesFound.GetFileName(n))
			else writeln('ERROR: MOVE FILE!');
		end;
			
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
		
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('MD5 HASH    : DEPTH       : FULL');
	writeln('FILES       : SAME HASH   : ', COUNTER);
	writeln('STORAGE     : FREE SPACE  : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure SHOW_FULL_SHA1_HASH;
var
	PATH		: ansistring;
	EXTENSION	: ansistring;
	MIN_FILE_SIZE	: qword;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	pFilesFound	: TpFilesDup;
	
	
	
begin
	if ParamCount <> 4 then ErrorMessage;
	
	PATH := ParamStr(2);
	EXTENSiON := ParamStr(3);
	
	pFilesFound := TpFilesDup.Create;
	
	if TryStrToQword(ParamStr(4), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	pFilesFound.CalcFullSHA1Hash;
	pFilesFound.DupFilesFindHash(TRUE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE:');
	writeln;
	
	Counter := 0;
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin 
		writeln(pFilesFound.GetFileHash(n), '   ', pFilesFound.GetFileLength(n):18, '    ', pFilesFound.GetFileName(n));
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('SHA1 HASH   : DEPTH      : FULL');
	writeln('FILES       : SAME HASH  : ', COUNTER);
	writeln('STORAGE     : FREE SPACE : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure SHOW_FAST_SHA1_HASH;
	
var
	PATH		: ansistring;
	EXTENSION	: ansistring;
	HASH_DEPTH	: qword;
	MIN_FILE_SIZE	: qword;
	
	pFilesFound	: TpFilesDUP;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	
	
begin
	if ParamCount <> 5 then ErrorMessage;
	
	PATH := ParamStr(2);
	EXTENSiON := ParamStr(3);
	
	if TryStrToQword(ParamStr(4), HASH_DEPTH) = FALSE then ErrorMessage;
	if HASH_DEPTH < 1 then ErrorMessage;
	if HASH_DEPTH > 10000000 then ErrorMessage
	else HASH_DEPTH :=  HASH_DEPTH * 4096;
	
	if TryStrToQword(ParamStr(5), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound := TpFilesDup.Create;
	
	//test: strict private
	//FilesFound.A[0].HASH := 'aaaaaaaaa';
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	pFilesFound.CalcFastSHA1Hash(HASH_DEPTH);
	pFilesFound.DupFilesFindHash(TRUE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE:');
	writeln;
	
	Counter := 0;
	
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin 
		writeln(pFilesFound.GetFileHash(n), '   ', pFilesFound.GetFileLength(n):18, '    ', pFilesFound.GetFileName(n));
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('SHA1 HASH  : DEPTH       : ', HASH_DEPTH);
	writeln('FILES      : SAME HASH   : ', COUNTER);
	writeln('STORAGE    : FREE SPACE  : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure MOVE_FAST_SHA1_HASH;
var
	PATH		: ansistring;
	PATH_DEST	: ansistring;
	EXTENSION	: ansistring;
	HASH_DEPTH	: qword;
	MIN_FILE_SIZE	: qword;
	
	pFilesFound	: TpFilesDup;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	ansistring_0	: ansistring;
	
	
	
begin
	if ParamCount <> 6 then ErrorMessage;
	
	PATH		:= ParamStr(2);
	EXTENSiON	:= ParamStr(3);
	PATH_DEST	:= ParamStr(4);
	
	if TryStrToQword(ParamStr(5), HASH_DEPTH) = FALSE then ErrorMessage;
	if HASH_DEPTH < 1 then ErrorMessage;
	if HASH_DEPTH > 10000000 then ErrorMessage
	else HASH_DEPTH :=  HASH_DEPTH * 4096;
	
	if TryStrToQword(ParamStr(6), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound := TpFilesDup.Create;
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.ArrayFree; pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	pFilesFound.CalcFastSHA1Hash(HASH_DEPTH);
	pFilesFound.DupFilesFindHash(FALSE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE: MOVE');
	writeln;
	Counter := 0;
	
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin
		ansistring_0 := pFilesFound.GetFileName(n);
		if ansistring_0[1] = '.' then Delete(ansistring_0, 1, 1);
		ansistring_0 := StringReplace(ansistring_0, PathDelim, '::', [rfReplaceAll]);
		
		writeln(pFilesFound.GetFileName(n));
		writeln('-> ' + PATH_DEST + PathDelim + ansistring_0);
		
		if RenameFile(pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = FALSE then begin
			if pFilesFound.CopyFile (pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = 0 then
				DeleteFile(pFilesFound.GetFileName(n))
			else writeln('ERROR: MOVE FILE!');
		end;
			
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
		
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('SHA1 HASH   : DEPTH       : ', HASH_DEPTH);
	writeln('FILES       : SAME HASH   : ', COUNTER);
	writeln('STORAGE     : FREE SPACE  : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	
//-------------------------------------------------------------------------------------------------------------
Procedure MOVE_FULL_SHA1_HASH;
var
	PATH		: ansistring;
	PATH_DEST	: ansistring;
	EXTENSION	: ansistring;
	MIN_FILE_SIZE	: qword;
	
	pFilesFound	: TpFilesDup;
	
	n		: int64;
	
	COUNTER		: int64 = 0;
	STORAGE_SPACE	: int64 = 0;
	
	ansistring_0	: ansistring;
	
	
	
begin
	if ParamCount <> 5 then ErrorMessage;
	
	PATH		:= ParamStr(2);
	EXTENSiON	:= ParamStr(3);
	PATH_DEST	:= ParamStr(4);
	
	if TryStrToQword(ParamStr(5), MIN_FILE_SIZE) = FALSE then ErrorMessage;
	
	pFilesFound := TpFilesDup.Create;
	
	pFilesFound.SetArrayLen(0);
	if pFilesFound.GetFilesDir (PATH, EXTENSION, MIN_FILE_SIZE) = -1 then begin pFilesFound.SetArrayLen(0); pFilesFound.Free; ErrorMessage; end;
	pFilesFound.DupFilesFindLength;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES: SAME LENGTH: ', pFilesFound.GetArrayLen);
	writeln('HASH : GET');
	writeln;
	
	//pFilesFound.CalcFullHash;
	pFilesFound.CalcFullSHA1Hash;
	pFilesFound.DupFilesFindHash(FALSE);
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('FILES EXISTS MORE THAN ONCE: MOVE');
	writeln;
	
	Counter := 0;
	for n := 0 to pFilesFound.GetArrayLen - 1 do begin
		ansistring_0 := pFilesFound.GetFileName(n);
		if ansistring_0[1] = '.' then Delete(ansistring_0, 1, 1);
		ansistring_0 := StringReplace(ansistring_0, PathDelim, '::', [rfReplaceAll]);
		
		writeln(pFilesFound.GetFileName(n));
		writeln('-> ' + PATH_DEST + PathDelim + ansistring_0);
		
		if RenameFile(pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = FALSE then begin
			if pFilesFound.CopyFile (pFilesFound.GetFileName(n), PATH_DEST + PathDelim +  ansistring_0) = 0 then
				DeleteFile(pFilesFound.GetFileName(n))
			else writeln('ERROR: MOVE FILE!');
		end;
			
		inc(COUNTER);
		STORAGE_SPACE := STORAGE_SPACE + pFilesFound.GetFileLength(n);
		
	end;
	
	writeln;
	writeln('--------------------------------------------------------------------');
	writeln('SHA1 HASH   : DEPTH       : FULL');
	writeln('FILES       : SAME HASH   : ', COUNTER);
	writeln('STORAGE     : FREE SPACE  : ', (STORAGE_SPACE / 1000 / 1000 / 1000):0:4, 'GB'); 
	writeln;
	
	pFilesFound.ArrayFree;
	pFilesFound.Free;
	halt(0);
	
end;
	
	
	
	
	

//-------------------------------------------------------------------------------------------------------------
begin
	
	if Paramcount < 1 then ErrorMessage;
	
	if ParamStr(1) = '-SHOW-FULL-MD5-HASH' then SHOW_FULL_MD5_HASH;
	if ParamStr(1) = '-SHOW-FAST-MD5-HASH' then SHOW_FAST_MD5_HASH;
	if ParamStr(1) = '-MOVE-FAST-MD5-HASH' then MOVE_FAST_MD5_HASH;
	if ParamStr(1) = '-MOVE-FULL-MD5-HASH' then MOVE_FULL_MD5_HASH;
	
	if ParamStr(1) = '-SHOW-FULL-SHA1-HASH' then SHOW_FULL_SHA1_HASH;
	if ParamStr(1) = '-SHOW-FAST-SHA1-HASH' then SHOW_FAST_SHA1_HASH;
	if ParamStr(1) = '-MOVE-FAST-SHA1-HASH' then MOVE_FAST_SHA1_HASH;
	if ParamStr(1) = '-MOVE-FULL-SHA1-HASH' then MOVE_FULL_SHA1_HASH;
	
	
	ErrorMessage;
	halt(1);
	
	
	
end.
