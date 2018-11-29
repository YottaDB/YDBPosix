# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org/>


# Sets the following variables:
#  CMAKE_MUMPS_COMPILER

find_path(YOTTADB_INCLUDE_DIR NAMES libyottadb.h
          HINTS $ENV{ydb_dist} $ENV{gtm_dist})

set(YOTTADB_INCLUDE_DIRS ${YOTTADB_INCLUDE_DIR})

if(MUMPS_UTF8_MODE)
  find_program(ICUCONFIG NAMES icu-config)
  if(ICUCONFIG)
    execute_process(
      COMMAND ${ICUCONFIG} --version
      OUTPUT_VARIABLE icu_version
      RESULT_VARIABLE icu_failed
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    if(icu_failed)
      message(FATAL_ERROR "Command\n ${ICUCONFIG} --version\nfailed (${icu_failed}).")
    elseif("x${icu_version}" MATCHES "^x([0-9]+\\.[0-9]+)")
      set(ydb_icu_version "${CMAKE_MATCH_1}")
    else()
      message(FATAL_ERROR "Command\n ${ICUCONFIG} --version\nproduced unrecognized output:\n ${icu_version}")
    endif()
  else()
    message(FATAL_ERROR "Unable to find 'icu-config'.  Set ICUCONFIG in CMake cache.")
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
      message("Locale undefined. Expect to see NONUTF8LOCALE during MUMPS routine compilation: ${locale_list}\n")
    endif()
  else()
    message(FATAL_ERROR "Unable to find 'locale'.  Set LOCALECFG in CMake cache.")
  endif()
  set(CMAKE_MUMPS_COMPILER ${YOTTADB_INCLUDE_DIRS}/utf8/mumps)
  set(ydb_chset "UTF-8")
else()
  set(CMAKE_MUMPS_COMPILER ${YOTTADB_INCLUDE_DIRS}/mumps)
endif()


configure_file(${CMAKE_CURRENT_LIST_DIR}/CMakeMUMPSCompiler.cmake.in
  ${CMAKE_PLATFORM_INFO_DIR}/CMakeMUMPSCompiler.cmake
  )

set(CMAKE_MUMPS_COMPILER_ENV_VAR "mumps")