#################################################################
#								#
# Copyright (c) 2018-2020 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/ydbcmake/")

project(YDBPosix C M)
cmake_minimum_required(VERSION 2.8)

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

add_library(_ydbposix SHARED
  _ydbposix.m _ydbposixtest.m
)

SET_TARGET_PROPERTIES(_ydbposix PROPERTIES PREFIX "")

install(FILES _ydbposix.m _ydbposixtest.m
  DESTINATION ${ydb_install_dir}/r/
)

if(M_UTF8_MODE)
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_ydbposix.so
    DESTINATION ${ydb_install_dir}/o/utf8
  )
else()
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_ydbposix.so
    DESTINATION ${ydb_install_dir}/o/
  )
endif()

# Handle the .xc file
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ydbposix.xc.in
  ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
)

add_custom_target(place_ydbposix_xc ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ydbposix.xc
  DESTINATION ${ydb_install_dir}/
)
