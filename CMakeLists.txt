#################################################################
#								#
# Copyright (c) 2018-2021 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/ydbcmake/")

unset(M_UTF8_MODE)
project(YDBPosix C M)
cmake_minimum_required(VERSION 3.0.0)

# Find YottaDB
find_package(YOTTADB REQUIRED)
include_directories("${YOTTADB_INCLUDE_DIRS}")

set(ydb_install_dir ${YOTTADB_INCLUDE_DIRS}/plugin)

# Compile the plugin
add_library(ydbposix SHARED
  ydbposix.c
)

install(TARGETS ydbposix
  DESTINATION ${ydb_install_dir}
)

# Add commands to compile .m files

install(FILES _ydbposix.m _ydbposixtest.m
  DESTINATION ${ydb_install_dir}/r/
)

set(args "_ydbposix.m _ydbposixtest.m")
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/_ydbposixm.so
  DEPENDS ${in} ${CMAKE_CURRENT_SOURCE_DIR}/ydbposixso.cmake ${CMAKE_M_COMPILER}
  COMMAND ${CMAKE_COMMAND}
    -D ydb_dist=${ydb_install_dir}
    -D ydb_routines=.
    -D ydb_chset=""
    -D ydb_icu_version=""
    -D LC_ALL=""
    -D ydb=${CMAKE_M_COMPILER}
    -D CMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -D "args=${args}"
    -D "sofile=${CMAKE_CURRENT_BINARY_DIR}/_ydbposixm.so"
    -P ${CMAKE_CURRENT_SOURCE_DIR}/ydbposixso.cmake
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  VERBATIM
  )
add_custom_target(ydbposixm ALL DEPENDS _ydbposixm.so)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_ydbposixm.so
  DESTINATION ${ydb_install_dir}/o/ RENAME _ydbposix.so
)

if(EXISTS ${ydb_install_dir}/o/utf8)
  # If UTF-8 mode is installed, build the UTF8 version of _ydbposix.so too
  find_program(PKGCONFIG NAMES pkg-config)
  if(PKGCONFIG)
    execute_process(
      COMMAND ${PKGCONFIG} --modversion icu-io
      OUTPUT_VARIABLE icu_version
      RESULT_VARIABLE icu_failed
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    if(icu_failed)
      message(FATAL_ERROR "Command\n ${PKGCONFIG} --modversion icu-io\nfailed (${icu_failed}).")
    elseif("x${icu_version}" MATCHES "^x([0-9]+\\.[0-9]+)")
      set(ydb_icu_version "${CMAKE_MATCH_1}")
    else()
      message(FATAL_ERROR "Command\n ${PKGCONFIG} --modversion icu-io\nproduced unrecognized output:\n ${icu_version}")
    endif()
  else()
    message(FATAL_ERROR "Unable to find 'pkg-config'.  Set PKGCONFIG in CMake cache.")
  endif()

  find_program(LOCALECFG NAMES locale)
  if(LOCALECFG)
    execute_process(
      COMMAND ${LOCALECFG} -a
      OUTPUT_VARIABLE locale_list
      RESULT_VARIABLE locale_failed
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    if(locale_failed)
      message(FATAL_ERROR "Command\n ${LOCALECFG} -a\nfailed (${locale_failed}).")
    endif()
    STRING(REGEX REPLACE "\n" ";" locale_list "${locale_list}")
    foreach(lc ${locale_list})
      string(TOLOWER "${lc}" lc_lower)
      if("x${lc_lower}" MATCHES "^x[a-zA-Z_]+\\.?utf-?8")
	set(LC_ALL ${lc})
	message("-- Setting locale to ${LC_ALL}")
	break()
      endif()
    endforeach(lc)
    if("${LC_ALL}" STREQUAL "")
      message("Locale undefined. Expect to see NONUTF8LOCALE during M routine compilation: ${locale_list}\n")
    endif()
  else()
    message(FATAL_ERROR "Unable to find 'locale'.  Set LOCALECFG in CMake cache.")
  endif()
  set(CMAKE_M_COMPILER ${mumps_dir}/utf8/mumps)
  set(ydb_chset "UTF-8")
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/_ydbposixutf8.so
    DEPENDS ${in} ${CMAKE_CURRENT_SOURCE_DIR}/ydbposixso.cmake ${mumps_dir}/utf8/mumps
    COMMAND ${CMAKE_COMMAND}
      -D ydb_dist=${ydb_install_dir}
      -D ydb_routines=.
      -D ydb_chset=${ydb_chset}
      -D ydb_icu_version=${ydb_icu_version}
      -D LC_ALL=${LC_ALL}
      -D ydb=${mumps_dir}/utf8/mumps
      -D CMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -D "args=${args}"
      -D "sofile=${CMAKE_CURRENT_BINARY_DIR}/_ydbposixutf8.so"
      -P ${CMAKE_CURRENT_SOURCE_DIR}/ydbposixso.cmake
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    VERBATIM
    )
  add_custom_target(ydbposixutf8 ALL DEPENDS _ydbposixutf8.so)
  add_dependencies(ydbposixutf8 ydbposixm)
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_ydbposixutf8.so
    DESTINATION ${ydb_install_dir}/o/utf8/ RENAME _ydbposix.so
  )
endif()

# Handle the .xc file
set(install_dir ${ydb_install_dir})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ydbposix.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
)
set(install_dir ${CMAKE_CURRENT_BINARY_DIR})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ydbposix.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc
)

add_custom_target(place_ydbposix_xc ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
  DESTINATION ${ydb_install_dir}/
)

# Testing
enable_testing()
add_test(ydbposixtest_m ${CMAKE_M_COMPILER} -run %ydbposixtest)
set_tests_properties(ydbposixtest_m PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL;YDB-E-")
set_tests_properties(ydbposixtest_m PROPERTIES
	ENVIRONMENT "ydb_xc_ydbposix=${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}/_ydbposixm.so ${mumps_dir}/libyottadbutil.so;ydb_chset=M")

if(EXISTS ${mumps_dir}/utf8)
	add_test(ydbposixtest_utf8 ${CMAKE_M_COMPILER} -run %ydbposixtest)
	set_tests_properties(ydbposixtest_utf8 PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL;YDB-E-")
	set_tests_properties(ydbposixtest_utf8 PROPERTIES
		ENVIRONMENT "ydb_xc_ydbposix=${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}/_ydbposixutf8.so ${mumps_dir}/utf8/libyottadbutil.so;ydb_chset=UTF-8;ydb_icu_version=${ydb_icu_version}")
endif()
