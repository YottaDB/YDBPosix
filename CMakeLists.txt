#################################################################
#								#
# Copyright (c) 2018-2024 YottaDB LLC and/or its subsidiaries.	#
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
# The GIT_TAG is, at the time of this writing, the latest commit in YDBCMake.
# It is fixed at that point to ensure reproducible builds.
# Keep this periodically up to date with future YDBCMake commits.
FetchContent_Declare(YDBCMake
	GIT_REPOSITORY	https://gitlab.com/YottaDB/Tools/YDBCMake.git
	GIT_TAG		e980b310b464c43d98a9731f126bdc6375b3fe1e
)
FetchContent_MakeAvailable(YDBCMake)
message(STATUS "YDBCMake Source Directory: ${ydbcmake_SOURCE_DIR}")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${ydbcmake_SOURCE_DIR}/ydbcmake/")

# Needed because we are compiling C code with flags
if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "")
endif()
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

project(YDBPosix C M)

# Option to enable ASAN
option(ENABLE_ASAN "Enable address sanitizer in build?" OFF)

# Check if YottaDB is compiled using ASAN. If so, enable ASAN by default
execute_process(COMMAND nm $ENV{ydb_dist}/libyottadb.so
	COMMAND grep -c "U __asan_init"
	OUTPUT_VARIABLE YDBASAN)
if(${YDBASAN} GREATER_EQUAL 1)
	set(ENABLE_ASAN ON)
	message(STATUS "Forcing Address Sanitizer usage as YottaDB is compiled using Address Sanitizer")
endif()

if(${ENABLE_ASAN})
        # Address sanitizer enabled. Use proper compiler/linker flags
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fsanitize-recover=address")
	execute_process(
		COMMAND gcc -print-file-name=libasan.so
		OUTPUT_VARIABLE LIBASAN_PATH
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)
endif()

# Find YottaDB
find_package(YOTTADB REQUIRED)

# Compile/Install the C callout library
add_library(ydbposix SHARED ydbposix.c)
target_include_directories(ydbposix PRIVATE ${YOTTADB_INCLUDE_DIRS})
target_link_libraries(ydbposix PRIVATE m)

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

# Copy math library output ref file
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libmath.ref
  ${CMAKE_CURRENT_BINARY_DIR}/libmath.ref
  COPYONLY
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libmath.ref
  DESTINATION ${YOTTADB_PLUGIN_PREFIX}/posix/
)

# Testing
enable_testing()
add_test(ydbposixtest_m ${CMAKE_M_COMPILER} -run %ydbposixtest)
set_tests_properties(ydbposixtest_m PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL;YDB-E-")
set_tests_properties(ydbposixtest_m PROPERTIES
	ENVIRONMENT "ydb_xc_ydbposix=${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}/_ydbposix.so ${mumps_dir}/libyottadbutil.so;ydb_chset=M;ASAN_OPTIONS=detect_leaks=0")

if(EXISTS ${mumps_dir}/utf8)
	add_test(ydbposixtest_utf8 ${CMAKE_M_COMPILER} -run %ydbposixtest)
	set_tests_properties(ydbposixtest_utf8 PROPERTIES FAIL_REGULAR_EXPRESSION "FAIL;YDB-E-")
	set_tests_properties(ydbposixtest_utf8 PROPERTIES
		ENVIRONMENT "ydb_xc_ydbposix=${CMAKE_CURRENT_BINARY_DIR}/ydbposix_test.xc;ydb_routines=${CMAKE_CURRENT_BINARY_DIR}/utf8/_ydbposix.so ${mumps_dir}/utf8/libyottadbutil.so;ydb_chset=UTF-8;ydb_icu_version=${ydb_icu_version};ASAN_OPTIONS=detect_leaks=0")
	if(ENABLE_ASAN)
		set_property(TEST ydbposixtest_utf8 APPEND PROPERTY ENVIRONMENT ";LD_PRELOAD=${LIBASAN_PATH}")
	endif()

endif()

if(ENABLE_ASAN)
	set_property(TEST ydbposixtest_m APPEND PROPERTY ENVIRONMENT ";LD_PRELOAD=${LIBASAN_PATH}")
endif()
