cmake_minimum_required(VERSION 3.16)
project(vyges_emap CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# lsils/mockturtle cloned here (recursive: it bundles fmt, kitty, lorina,
# parallel_hashmap, … in lib/ — no system fmt/abseil needed). Use its own CMake
# for the `mockturtle` INTERFACE target; disable its examples/tests/experiments.
set(MOCKTURTLE_DIR "${CMAKE_SOURCE_DIR}/mockturtle" CACHE PATH "cloned lsils/mockturtle (recursive)")
set(MOCKTURTLE_BUILD_EXAMPLES    OFF CACHE BOOL "" FORCE)
set(MOCKTURTLE_BUILD_TESTS       OFF CACHE BOOL "" FORCE)
set(MOCKTURTLE_BUILD_EXPERIMENTS OFF CACHE BOOL "" FORCE)
add_subdirectory(${MOCKTURTLE_DIR} mockturtle-build)

add_executable(vyges-emap src/emap-driver.cpp)
target_link_libraries(vyges-emap PRIVATE mockturtle)

install(TARGETS vyges-emap RUNTIME DESTINATION bin)
