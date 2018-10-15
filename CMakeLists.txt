project(YDBPosix)
cmake_minimum_required(VERSION 2.8)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/")

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
add_custom_command(TARGET ydbposix POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${CMAKE_CURRENT_SOURCE_DIR}/_POSIX.m
    $<TARGET_FILE_DIR:ydbposix>
)

add_custom_command(TARGET ydbposix POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${CMAKE_CURRENT_SOURCE_DIR}/_POSIX.m
    $<TARGET_FILE_DIR:ydbposix>
)

add_custom_command(TARGET ydbposix POST_BUILD
  COMMAND ${YOTTADB_INCLUDE_DIRS}/mumps
  ${CMAKE_CURRENT_BINARY_DIR}/_POSIX.m
)

install(FILES _POSIX.m
  DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins/r/
) 

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/_POSIX.o
  DESTINATION ${YOTTADB_INCLUDE_DIRS}/plugins/o/
) 

## If we can build the utf8 version, do it

if(EXISTS ${YOTTADB_INCLUDE_DIRS}/utf8)
	add_custom_command(TARGET ydbposix POST_BUILD
		COMMAND mkdir ${CMAKE_CURRENT_BINARY_DIR}/utf8/ && ${YOTTADB_INCLUDE_DIRS}/utf8/mumps
		-object=${CMAKE_CURRENT_BINARY_DIR}/utf8/_POSIX.o ${CMAKE_CURRENT_BINARY_DIR}/_POSIX.m
	)

  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/utf8/_POSIX.o
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
