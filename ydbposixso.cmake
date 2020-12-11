#################################################################
#								#
# Copyright (c) 2020 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################
foreach(v
    ydb_dist
    ydb_routines
    ydb_chset
    ydb_icu_version
    gtm_inc
    gtm_tools
    ydb_gbldir
    LC_ALL
    )
  if(DEFINED ${v})
    set("ENV{${v}}" "${${v}}")
  endif()
endforeach()

execute_process(
  COMMAND ${ydb} ${args}
  RESULT_VARIABLE res_var
  )
if(NOT "${res_var}" STREQUAL "0")
  # do something here about the failed "process" call...
  message(FATAL_ERROR "Command <${ydb} ${args}> failed with result ='${res_var}'")
endif()
execute_process(
  COMMAND ${CMAKE_C_COMPILER} -shared -fPIC -o ${sofile} _ydbposix.o _ydbposixtest.o
  RESULT_VARIABLE res_var
  )
if(NOT "${res_var}" STREQUAL "0")
  # do something here about the failed "process" call...
  message(FATAL_ERROR "Command <${CMAKE_C_COMPILER} -shared -fPIC -o ${sofile} _ydbposix.o _ydbposixtest.o> failed with result ='${res_var}'")
endif()
