;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;								;
; Copyright (c) 2012-2015 Fidelity National Information		;
; Services, Inc. and/or its subsidiaries. All rights reserved.	;
;								;
; Copyright (c) 2018-2019 YottaDB LLC and/or its subsidiaries.	;
; All rights reserved.						;
;								;
;	This source code contains the intellectual property	;
;	of its copyright holder(s), and is made available	;
;	under a license.  If you do not know the terms of	;
;	the license, please stop and do not read further.	;
;								;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ydbposixtest
	; test POSIX plugin
	; Initialization
        new %ydbposix,arch,clock,computeddh1,ddzh,dh1,dh2,diffca,diffma,dir,file,errmsg,errno,gid
	new hour,i,io,isdst,link,mask,mday,min,mode1,mode2,mon,msg,msg1,os,oslist,out,out1,out2,path
	new result,retval,sec,setenvtst,size,stat,tmp,tv,tvsec,tvusec,tvnsec,uid,value,ver1,ver2
	new wday,yday,year
        set io=$io
        set os=$piece($zv," ",3)
        set setenvtst=1
        set arch=$piece($zv," ",4)

        ; Get version - check it later
        set ver1=$$version^%ydbposix
        set ver2=$$VERSION^%ydbposix

        ; Verify that command line invocation fails with error message
        open "POSIX":(shell="/bin/sh":command="$ydb_dist/mumps -run %ydbposix":readonly:stderr="POSIXerr")::"pipe"
        use "POSIX" for i=1:1 read tmp quit:$zeof  set out1(i)=tmp
        use "POSIXerr" for i=1:1 read tmp quit:$zeof  set out2(i)=tmp
        use io close "POSIX"
        if "%ydbposix-F-BADINVOCATION Must call an entryref in %ydbposix"=$get(out1(1))&'$data(out2) write "PASS Invocation",!
        else  write "FAIL Invocation",! zwrite:$data(out1) out1  zwrite:$data(out2) out2

        ; Check $zhorolog/$ZHOROLOG
        ; retry until microsec returned by $zhorolog
        for  set dh1=$horolog,ddzh=$$zhorolog^%ydbposix,dh2=$horolog quit:(dh1=dh2)&$piece(ddzh,".",2)
        if dh1'=$piece(ddzh,".",2) write "PASS $zhorolog",!
        else  write "FAIL $zhorolog $horolog=",dh1," $$zhorolog^%ydbposix=",ddzh,!
        for  set dh1=$horolog,ddzh=$$ZHOROLOG^%ydbposix,dh2=$horolog quit:(dh1=dh2)&$piece(ddzh,".",2)
        if dh1=$piece(ddzh,".",2) write "FAIL $ZHOROLOG $horolog=",dh1," $$ZHOROLOG^%ydbposix=",ddzh,!
        else  write "PASS $ZHOROLOG",!

	; Check mktime()
	set tmp=$zdate(dh1,"YYYY:MM:DD:24:60:SS:DAY","","0,1,2,3,4,5,6"),isdst=-1
	set retval=$&ydbposix.mktime($piece(tmp,":",1)-1900,$piece(tmp,":",2)-1,+$piece(tmp,":",3),+$piece(tmp,":",4),+$piece(tmp,":",5),+$piece(tmp,":",6),.wday,.yday,.isdst,.tvsec,.errno)
	write "Daylight Savings Time is ",$select('isdst:"not ",1:""),"in effect",!
	set retval=$&ydbposix.localtime(tvsec,.sec,.min,.hour,.mday,.mon,.year,.wday,.yday,.isdst,.errno)
	set computeddh1=($$FUNC^%DATE(mon+1_"/"_mday_"/"_(1900+year))_","_($$FUNC^%TI($translate($justify(hour,2)_$justify(min,2)," ",0))+sec))
	if $piece(tmp,":",7)=wday&(dh1=computeddh1) write "PASS mktime()",!
	else  write "FAIL mktime() $horolog=",dh1," Computed=",computeddh1,!

        ; Check that we get at least fractional second times - this test has 1 in 10**12 chance of failing incorrectly
        set tmp="PASS Microsecond resolution"
        for i=0:1  set retval=$&ydbposix.gettimeofday(.tvsec,.tvusec,.errno) quit:tvusec  set:i $extract(tmp,1,4)="FAIL"
        write tmp,!
        set tv=tvusec/1E6+tvsec

        ; Check regular expression pattern matching
        set oslist="AIXHP-UXLinuxSolaris"
        if $$regmatch^%ydbposix(oslist,"ux",,,.result,3)&("ux"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS regmatch^%ydbposix 1",!
        else  write "FAIL regmatch^%ydbposix 1",!
        set tmp=$order(%ydbposix("regmatch","ux","")) do regfree^%ydbposix("%ydbposix(""regmatch"",""ux"","_tmp_")")
        if $data(%ydbposix("regmatch","ux",tmp))#10 write "FAIL regfree^%ydbposix",!
        else  write "PASS regfree^%ydbposix",!
        if $$REGMATCH^%ydbposix(oslist,"ux",,,.result,3)&("ux"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS REGMATCH^%ydbposix 1",!
        else  write "FAIL REGMATCH^%ydbposix 1",!
        set tmp=$order(%ydbposix("regmatch","ux","")) do REGFREE^%ydbposix("%ydbposix(""regmatch"",""ux"","_tmp_")")
        if $data(%ydbposix("regmatch","ux",tmp))#10 write "FAIL REGFREE^%ydbposix",!
        else  write "PASS REGFREE^%ydbposix",!
        if $$regmatch^%ydbposix(oslist,"ux","REG_ICASE",,.result,3)&("UX"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS regmatch^%ydbposix 2",!
        else  write "FAIL regmatch^%ydbposix 2",!
        do regfree^%ydbposix("%ydbposix(""regmatch"",""ux"","_$order(%ydbposix("regmatch","ux",""))_")")
        if $$REGMATCH^%ydbposix(oslist,"ux","REG_ICASE",,.result,3)&("UX"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS REGMATCH^%ydbposix 2",!
        else  write "FAIL REGMATCH^%ydbposix 2",!
        do REGFREE^%ydbposix("%ydbposix(""regmatch"",""ux"","_$order(%ydbposix("regmatch","ux",""))_")")
        if $$regmatch^%ydbposix(oslist,"S$","REG_ICASE",,.result,3)&("s"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS regmatch^%ydbposix 3",!
        else  write "FAIL regmatch^%ydbposix 3",!
        do regfree^%ydbposix("%ydbposix(""regmatch"",""S$"","_$order(%ydbposix("regmatch","S$",""))_")")
        if $$REGMATCH^%ydbposix(oslist,"S$","REG_ICASE",,.result,3)&("s"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS REGMATCH^%ydbposix 3",!
        else  write "FAIL REGMATCH^%ydbposix 3",!
        do REGFREE^%ydbposix("%ydbposix(""regmatch"",""S$"","_$order(%ydbposix("regmatch","S$",""))_")")
        if $$regmatch^%ydbposix(oslist,"S$","REG_ICASE",,.result,3)&("s"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS regmatch^%ydbposix 3",!
        else  write "FAIL regmatch^%ydbposix 3",!
        do regfree^%ydbposix("%ydbposix(""regmatch"",""S$"","_$order(%ydbposix("regmatch","S$",""))_")")
        if $$REGMATCH^%ydbposix(oslist,"S$","REG_ICASE",,.result,3)&("s"=$extract(oslist,result(1,"start"),result(1,"end")-1)) write "PASS REGMATCH^%ydbposix 3",!
        else  write "FAIL REGMATCH^%ydbposix 3",!
        do REGFREE^%ydbposix("%ydbposix(""regmatch"",""S$"","_$order(%ydbposix("regmatch","S$",""))_")")
        if $$regmatch^%ydbposix(oslist,"\([[:alnum:]]*\)-\([[:alnum:]]*\)",,,.result,5)&(oslist=$extract(oslist,result(1,"start"),result(1,"end")-1))&("AIXHP"=$extract(oslist,result(2,"start"),result(2,"end")-1))&("UXLinuxSolaris"=$extract(oslist,result(3,"start"),result(3,"end")-1))&(3=$order(result(""),-1)) write "PASS regmatch^%ydbposix 4",!
        else  write "FAIL regmatch^%ydbposix 4",!
        do regfree^%ydbposix("%ydbposix(""regmatch"",""\([[:alnum:]]*\)-\([[:alnum:]]*\)"","_$order(%ydbposix("regmatch","\([[:alnum:]]*\)-\([[:alnum:]]*\)",""))_")")
        if $$REGMATCH^%ydbposix(oslist,"\([[:alnum:]]*\)-\([[:alnum:]]*\)",,,.result,5)&(oslist=$extract(oslist,result(1,"start"),result(1,"end")-1))&("AIXHP"=$extract(oslist,result(2,"start"),result(2,"end")-1))&("UXLinuxSolaris"=$extract(oslist,result(3,"start"),result(3,"end")-1))&(3=$order(result(""),-1)) write "PASS REGMATCH^%ydbposix 4",!
        else  write "FAIL REGMATCH^%ydbposix 4",!
        do REGFREE^%ydbposix("%ydbposix(""regmatch"",""\([[:alnum:]]*\)-\([[:alnum:]]*\)"","_$order(%ydbposix("regmatch","\([[:alnum:]]*\)-\([[:alnum:]]*\)",""))_")")
        if $$regmatch^%ydbposix(oslist,"^AIX",,"REG_NOTBOL",.result,3) write "FAIL regmatch^%ydbposix 5",!
        else  write "PASS regmatch^%ydbposix 5",!
        do regfree^%ydbposix("%ydbposix(""regmatch"",""^AIX"","_$order(%ydbposix("regmatch","^AIX",""))_")")
        if $$REGMATCH^%ydbposix(oslist,"^AIX",,"REG_NOTBOL",.result,3) write "FAIL REGMATCH^%ydbposix 5",!
        else  write "PASS REGMATCH^%ydbposix 5",!
        do REGFREE^%ydbposix("%ydbposix(""regmatch"",""^AIX"","_$order(%ydbposix("regmatch","^AIX",""))_")")

        ; Check statfile - indirectly tests mkdtemp also. Note that not all stat parameters can be reliably tested
        set dir="/tmp/posixtest"_$j_"_XXXXXX"
        set retval=$$mktmpdir^%ydbposix(.dir) write:'retval "FAIL mktmpdir retval=",retval,!
        set retval=$$statfile^%ydbposix(.dir,.stat) write:retval "FAIL statfile retval=",retval,!
        if stat("ino") write "PASS mktmpdir",!
        else  write "FAIL mktmpdir stat(ino)=",stat("ino"),!
        ; Check that mtime atime and ctime atime are no more than 1 sec apart and tvsec is not greater that ctime
        set diffma=(stat("mtime")-stat("atime"))*1E9+(stat("nmtime")-stat("natime"))
        set:diffma<0 diffma=-diffma
        set diffca=(stat("ctime")-stat("atime"))*1E9+(stat("nctime")-stat("natime"))
        set:diffca<0 diffca=-diffca
	; Normally tvsec is no greater than each of mtime, ctime and atime. However, we have seen one failure that made us change
	; tvsec<=stat("ctime") to tvsec-1<=stat("ctime") <time_shift_ydbposix>
        if ((diffma'>1E9)&(diffca'>1E9)&(tvsec-1'>stat("ctime"))) write "PASS statfile.times",!
        else  write "FAIL statfile.times dir=",dir," atime=",stat("atime")," natime=",stat("natime")," ctime=",stat("ctime")," nctime=",stat("nctime")," mtime=",stat("mtime")," nmtime=",stat("nmtime")," tv_sec=",tvsec,!
        open "uid":(shell="/bin/sh":command="id -u":readonly)::"pipe"
        use "uid" read uid use io close "uid"
        open "gid":(shell="/bin/sh":command="id -g":readonly)::"pipe"
        use "gid" read gid use io close "gid"
        if stat("gid")=gid&(stat("uid")=uid) write "PASS statfile.ids",!
        else  write "FAIL statfile.ids gid=",gid," stat(""gid"")=",stat("gid")," uid=",uid," stat(""uid"")=",stat("uid"),!
	; Check that mode from stat has directory bit set, but not regular file bit
	set tmp=$$filemodeconst^%ydbposix("S_IFREG"),tmp=$$filemodeconst^%ydbposix("S_IFDIR")
	if stat("mode")\%ydbposix("filemode","S_IFDIR")#2&'(stat("mode")\%ydbposix("filemode","S_IFREG")#2) write "PASS filemodeconst^%ydbposix",!
	else  write "FAIL filemodeconst^%ydbposix mode=",stat("mode")," S_IFDIR=",%ydbposix("filemode","S_IFDIR")," S_IFREG=",%ydbposix("filemode","S_IFREG"),!

        ; Check signal & STATFILE
        set file="YDB_JOBEXAM.ZSHOW_DMP_"_$j_"_1"
        if $&ydbposix.signalval("SIGUSR1",.result)!$zsigproc($j,result) write "FAIL signal",!
        else  write "PASS signal",!
        set retval=$$STATFILE^%ydbposix(file,.stat) write:retval "FAIL STATFILE",!
        if ((stat("mtime")-(stat("atime")+stat("ctime")/2)'>1)&(tvsec-1'>stat("ctime"))) write "PASS STATFILE.times",!
        else  write "FAIL STATFILE.times file=",file," atime=",stat("atime")," ctime=",stat("ctime")," mtime=",stat("mtime")," tv_sec=",tvsec,!
        open "uid":(shell="/bin/sh":command="id -u":readonly)::"pipe"
        use "uid" read uid use io close "uid"
        open "gid":(shell="/bin/sh":command="id -g":readonly)::"pipe"
        use "gid" read gid use io close "gid"
        if stat("gid")=gid&(stat("uid")=uid) write "PASS STATFILE.ids",!
        else  write "FAIL STATFILE.ids gid=",gid," stat(""gid"")=",stat("gid")," uid=",uid," stat(""uid"")=",stat("uid"),!
        zsystem "rm -f "_file

	; Execute the syslog test; wait upto 60 seconds for messages to show up in syslog
	if '$$hasSystemd() write "SKIP journalctl test on non-systemd system"
	else  do
	. set msg="Warning from process "_$j_" at "_ddzh,out="FAIL syslog1 - msg """_msg_""" not found in syslog"
	. set msg1="Notice from process "_$j_" at "_ddzh,out1="FAIL syslog2 - msg """_msg1_""" not found in syslog"
	. if $$syslog^%ydbposix(msg,"LOG_USER","LOG_WARNING")
	. if $$SYSLOG^%ydbposix(msg1,"LOG_ERR","LOG_INFO")
	. set dh1=60E6+$zut
	. open "journalctl":(shell="/bin/sh":command="journalctl -f -S """_$zdate(ddzh,"YYYY-MM-DD 24:60:SS")_"""":readonly)::"pipe"
	. use "journalctl"
	. for  read tmp do  quit:"PASS syslog1"=out&("PASS syslog2"=out1)!(dh1<$zut)
	. . set:$find(tmp,msg) out="PASS syslog1"
	. . set:$find(tmp,msg1) out1="PASS syslog2"
	. use io close "journalctl"
	. write out,!,out1,!

        ; Check setenv and unsetenv
        if 1=setenvtst do
        . set retval=$&ydbposix.setenv("ydbposixtest",dir,0,.errno)
        . set tmp=$ztrnlnm("ydbposixtest") if tmp=dir write "PASS setenv",!
        . else  write "FAIL setenv $ztrnlnm(""ydbposixtest"")=",tmp," should be ",dir,!
        . set retval=$&ydbposix.unsetenv("ydbposixtest",.errno)
        . set tmp=$ztrnlnm("ydbposixtest") if '$length(tmp) write "PASS unsetenv",!
        . else  write "FAIL unsetenv $ztrnlnm(""ydbposixtest"")=",tmp," should be unset",!

        ; Check rmdir
        set retval=$&ydbposix.rmdir(dir,.errno)
	if retval write "FAIL rmdir - return value from rmdir is ",retval,!
	else  do
	. set retval=$$statfile^%ydbposix(dir,.errno)
	. if 2'=retval write "FAIL rmdir – return value from statfile is ",retval,!
	. else  write "PASS rmdir",!

        ; Check MKTMPDIR
        set dir="/tmp/posixtest"_$j_"_XXXXXX"
        set retval=$$MKTMPDIR^%ydbposix(.dir) write:'retval "FAIL MKTMPDIR retval=",retval,!
        set retval=$$STATFILE^%ydbposix(dir,.stat) write:retval "FAIL STATFILE retval=",retval,!
        if stat("ino") write "PASS MKTMPDIR",!
        else  write "FAIL MKTMPDIR stat(ino)=",stat("ino"),!
        set retval=$&ydbposix.rmdir(dir,.errno)

        ; Check mkdir
        set dir="/tmp/posixtest"_$j_$$^%RANDSTR(6)
        set retval=$$mkdir^%ydbposix(dir,"S_IRWXU") write:retval "FAIL MKTMPDIR retval=",retval,!
        set retval=$$STATFILE^%ydbposix(dir,.stat) write:retval "FAIL STATFILE retval=",retval,!
        if stat("ino") write "PASS mkdir",!
        else  write "FAIL mkdir stat(ino)=",stat("ino"),!
        set retval=$&ydbposix.rmdir(dir,.errno)

        ; Check MKDIR
        set dir="/tmp/posixtest"_$j_$$^%RANDSTR(6)
        set retval=$$MKDIR^%ydbposix(dir,"S_IRWXU") write:retval "FAIL MKTMPDIR retval=",retval,!
        set retval=$$STATFILE^%ydbposix(dir,.stat) write:retval "FAIL STATFILE retval=",retval,!
        if stat("ino") write "PASS MKDIR",!
        else  write "FAIL MKDIR stat(ino)=",stat("ino"),!
        set retval=$&ydbposix.rmdir(dir,.errno)

	; Check UMASK and UTIMES
	set mode1=$$filemodeconst^%ydbposix("S_IWUSR")
	set retval=$$UMASK^%ydbposix(mode1,.tmp) write:'retval "FAIL UMASK retval=",retval,!
	set file="/tmp/posixtest"_$j_$$^%RANDSTR(6)
	open file:newversion
	close file
	set retval=$$STATFILE^%ydbposix(file,.stat) write:retval "FAIL STATFILE retval=",retval,!
	set tvsec=stat("mtime"),tvnsec=stat("nmtime")
	hang 0.1	; OSs cluster timestamps that are close to each other
	set retval=$$UTIMES^%ydbposix(file) write:'retval "FAIL UTIMES retval=",retval,!
	set retval=$$STATFILE^%ydbposix(file,.stat) write:retval "FAIL STATFILE retval=",retval,!
	if ((0'=tmp)&(tvsec'=stat("mtime"))!(tvnsec'=stat("nmtime")!((0=tvnsec)&(0=stat("nmtime"))))) write "PASS UTIMES",!
	else  write "FAIL UTIMES stat(mtime)=",stat("mtime")," stat(nmtime)=",stat("nmtime"),!
	set mode2=$$FUNC^%DO(stat("mode"))#1000 ; Get the last three digits
	set mode1=$$FUNC^%DO(mode1)
	set mask=$$octalAnd(mode1,mode2)
	if (666=mask) write "PASS UMASK",! ; comparing with octal 0666
	else  write "FAIL UMASK stat(mode)=",stat("mode"),!

	; Check CHMOD
	set mode1=$$filemodeconst^%ydbposix("S_IXGRP")
	set retval=$$CHMOD^%ydbposix(file,mode1) write:'retval "FAIL CHMOD retval=",retval,!
	set retval=$$STATFILE^%ydbposix(file,.stat) write:retval "FAIL STATFILE retval=",retval,!
	set mode2=$$FUNC^%DO(stat("mode"))#1000 ; Get the last three digits
	set mode1=$$FUNC^%DO(mode1)
	if (+mode1=+mode2) write "PASS CHMOD",!
	else  write "FAIL CHMOD stat(mode)=",stat("mode"),!

	; Check SYMLINK and REALPATH
	set link="/tmp/posixtest"_$j_$$^%RANDSTR(6)
	set retval=$$SYMLINK^%ydbposix(file,link) write:'retval "FAIL SYMLINK retval=",retval,!
	set retval=$$STATFILE^%ydbposix(link,.stat) write:retval "FAIL STATFILE retval=",retval,!
	if stat("ino") write "PASS SYMLINK",!
	else  write "FAIL SYMLINK stat(ino)=",stat("ino"),!
	set retval=$$REALPATH^%ydbposix(file,.path) write:'retval "FAIL REALPATH retval=",retval,!
	if (file=path) write "PASS REALPATH",!
	else  write "FAIL REALPATH path=",path,!
	set retval=$$CHMOD^%ydbposix(file,"S_IRWXU") write:'retval "FAIL CHMOD retval=",retval,!
	open link
	close link:delete

	; Check CP
	; Append to the existing (empty) file.
	open file:append
	use file
	set value=""
	for i=1:1:10 set tmp=$$^%RANDSTR(1000) set value=value_tmp_$char(10) write tmp,!
	close file
	set retval=$$STATFILE^%ydbposix(file,.stat) write:retval "FAIL STATFILE retval=",retval,!
	set size=stat("size")
	; Copy to a non-existent destination.
	set retval=$$CP^%ydbposix(file,link) write:'retval "FAIL CP retval=",retval,!
	set retval=$$STATFILE^%ydbposix(link,.stat) write:retval "FAIL STATFILE retval=",retval,!
	; Verify the contents and size file of the copy.
	open link
	use link
	set tmp=""
	for  read i quit:$zeof  set tmp=tmp_i_$char(10)
	close link
	if ((tmp'=value)&(size'=stat("size"))) write "FAIL CP stat(size)=",stat("size")," content=",$zwrite(tmp),!
	open link
	close link:delete
	; Create a smaller file.
	open link:newversion
	use link
	set value="abc"
	write value
	close link
	set value=value_$char(10)
	set retval=$$STATFILE^%ydbposix(link,.stat) write:retval "FAIL STATFILE retval=",retval,!
	set size=stat("size")
	; Copy the new small file onto the existent destination.
	set retval=$$CP^%ydbposix(link,file) write:'retval "FAIL CP retval=",retval,!
	set retval=$$STATFILE^%ydbposix(file,.stat) write:retval "FAIL STATFILE retval=",retval,!
	; Verify the contents and size file of the copy.
	open file:readonly
	use file
	set tmp=""
	for  read i quit:$zeof  set tmp=tmp_i_$char(10)
	close file
	if ((tmp=value)&(size=stat("size"))) write "PASS CP",!
	else  write "FAIL CP stat(size)=",stat("size")," content=",$zwrite(tmp),!
	; Clean up.
	open link:readonly
	close link:delete
	open file:readonly
	close file:delete

	; Check that we get at least fractional second times - this test has 1 in 10**18 chance of failing incorrectly
	set tmp="PASS Nanosecond resolution"
	for i=0:1  set retval=$$CLOCKGETTIME^%ydbposix("CLOCK_REALTIME",.tvsec,.tvnsec) quit:tvnsec  set:i $extract(tmp,1,4)="FAIL"
	write tmp,!

	; Check SYSCONF
	set retval=$$SYSCONF^%ydbposix("ARG_MAX",.value) write:'retval "FAIL SYSCONF retval=",retval,!
	if (0<value) write "PASS SYSCONF",!
	else  write "FAIL SYSCONF ARG_MAX=",value,!

	; All done with posix test
	quit

BADOPEN
       use $p
       write "Cannot open "_tname_" for reading.  Check permissions",!
       quit

hasSystemd()
	; if the os init system is systemd:
	; - /proc/1/cmdline would start with "/lib/systemd/systemd" followed by arguments
	; - /proc/1/comm would be equal to "systemd"_$C(10)
	new comm,f
	set f="/proc/1/comm" open f:readonly use f read comm close f
	quit $extract(comm,1,7)="systemd"

octalAnd(num1,num2)
	new i,j,num,bnum1,bnum2,len1,len2,digit,piece,bnum
	set (bnum1,bnum2,bnum,result)=""
	for i=1:1:2 do
	.	set num=$select(1=i:num1,1:num2)
	.	for  set digit=num#10,num=num\10 do  quit:(0=num)
	.	.	set piece=""
	.	.	for j=4,2,1 do
	.	.	.	if (j'>digit) set digit=digit-j,piece=piece_"1"
	.	.	.	else  set piece=piece_"0"
	.	.	if (1=i) set bnum1=piece_bnum1
	.	.	else  set bnum2=piece_bnum2
	set len1=$length(bnum1)
	set len2=$length(bnum2)
	if (len1>len2) for i=1:1:(len1-len2) set bnum2="0"_bnum2
	else  set len1=len2 for i=1:1:(len2-len1) set bnum1="0"_bnum1
	for i=1:1:len1 set bnum=bnum_$select((1=+$extract(bnum1,i))!(1=+$extract(bnum2,i)):1,1:0)
	for i=1:3:$length(bnum)-1 do
	.	set digit=0
	.	set:(1=+$extract(bnum,i)) digit=digit+4
	.	set:(1=+$extract(bnum,i+1)) digit=digit+2
	.	set:(1=+$extract(bnum,i+2)) digit=digit+1
	.	set result=result_digit
	quit result
