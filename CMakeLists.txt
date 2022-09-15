#################################################################
#								#
# Copyright (c) 2018-2022 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

# Prelim
cmake_minimum_required(VERSION 3.14)
include(FetchContent)
FetchContent_Declare(YDBCMake
	GIT_REPOSITORY	https://gitlab.com/YottaDB/Tools/YDBCMake.git
	GIT_TAG		50e7f4a2484b1a8649d6ef1c4a17e626806c886b
)
FetchContent_MakeAvailable(YDBCMake)
message(STATUS "YDBCMake Source Directory: ${ydbcmake_SOURCE_DIR}")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${ydbcmake_SOURCE_DIR}/ydbcmake/")

# Needed because we are compiling C code with flags
if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

project(YDBPosix C M)

# Find YottaDB
find_package(YOTTADB REQUIRED)

# Compile/Install the C callout library
add_library(ydbposix SHARED ydbposix.c)
target_include_directories(ydbposix PRIVATE ${YOTTADB_INCLUDE_DIRS})
install(TARGETS ydbposix DESTINATION ${YOTTADB_C_PLUGIN_DIR})

# Compile/Install the M Plugin
set(m_sources _ydbposix.m _ydbposixtest.m)
add_ydb_library(_ydbposix SOURCES ${m_sources})
install_ydb_library(_ydbposix)
install(FILES ${m_sources} DESTINATION ${YOTTADB_PLUGIN_PREFIX}/r/)

# Handle the .xc file
# Runtime version
set(install_dir ${YOTTADB_PLUGIN_PREFIX})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ydbposix.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
  DESTINATION ${YOTTADB_PLUGIN_PREFIX}/
)
# Test version
set(install_dir ${CMAKE_CURRENT_BINARY_DIR})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ydbposix.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc
)

# Testing
enable_testing()
add_test(ydbposixtest_m ${CMAKE_M_COMPILER} -run %ydbposixtest)
set_tests_properties(ydbposixtest_m PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL;YDB-E-")
set_tests_properties(ydbposixtest_m PROPERTIES
	ENVIRONMENT "ydb_xc_ydbposix=${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}/_ydbposix.so ${mumps_dir}/libyottadbutil.so;ydb_chset=M")

if(EXISTS ${mumps_dir}/utf8)
	add_test(ydbposixtest_utf8 ${CMAKE_M_COMPILER} -run %ydbposixtest)
	set_tests_properties(ydbposixtest_utf8 PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL;YDB-E-")
	set_tests_properties(ydbposixtest_utf8 PROPERTIES
		ENVIRONMENT "ydb_xc_ydbposix=${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}/utf8/_ydbposix.so ${mumps_dir}/utf8/libyottadbutil.so;ydb_chset=UTF-8;ydb_icu_version=${ydb_icu_version}")
endif()
