# 2019.5.21
# Project Tooru
# CMakeFile

cmake_minimum_required (VERSION 3.0)
project (Tooru)
# The version number.
set (Tooru_VERSION_MAJOR 0)
set (Tooru_VERSION_MINOR 1)

configure_file (
  "${PROJECT_SOURCE_DIR}/config.h.in"
  "${PROJECT_BINARY_DIR}/config.h"
)

include_directories("${PROJECT_BINARY_DIR}")
include_directories("${PROJECT_SOURCE_DIR}/lib/include") # 依赖头文件

find_library(libgt_path libgt ${PROJECT_SOURCE_DIR}/lib/gt) # 第三方依赖，这里是GameTracer
find_library(liblua54 lua54 ${PROJECT_SOURCE_DIR}) # Lua54，53在旧版本兼容，此版本不再兼容，注意54随后释出版本的接口变动

add_compile_definitions(_CRT_SECURE_NO_WARNINGS) # 如果需要发布，请关注这里

aux_source_directory("${PROJECT_SOURCE_DIR}/tooru/src" TOORU_SRC)

add_library(tooru SHARED ${TOORU_SRC})
target_link_libraries(tooru ${liblua54} ${libgt_path})
