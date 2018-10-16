set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/")

project(YDBPosix C MUMPS)
cmake_minimum_required(VERSION 2.8)


# Find YottaDB
find_package(YOTTADB REQUIRED)
include_directories("${YOTTADB_INCLUDE_DIRS}")

# Compile the plugin
add_library(ydbposix SHARED
  gtmposix.c
)

install(TARGETS ydbposix
  DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins/
)

# Add commands to compile .m files

add_library(_POSIX SHARED
  _POSIX.m
  )

SET_TARGET_PROPERTIES(_POSIX PROPERTIES PREFIX "")

install(FILES _POSIX.m
  DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins/r/
) 

if(NOT MUMPS_UTF8_MODE)
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_POSIX.so
    DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins/o/
  )
else()
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_POSIX.so
    DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins/o/utf8/
  )
endif()

# Handle the .xc file

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/gtmposix.xc
	COMMAND sed 's/sizeofptr/${CMAKE_SIZEOF_VOID_P}/g' ${CMAKE_CURRENT_SOURCE_DIR}/gtmposix.xc_proto > ${CMAKE_CURRENT_BINARY_DIR}/gtmposix.xc
  DEPENDS ydbposix
)

add_custom_target(place_gtmposix_xc ALL
	DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/gtmposix.xc
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/gtmposix.xc
	DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins
)
