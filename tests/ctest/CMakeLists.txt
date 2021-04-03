cmake_minimum_required(VERSION 3.14.7)
project(manylinux_ctest)
include(CTest)

# SQLite3 test Derived from CMake unit test for FindSQLite3
# https://gitlab.kitware.com/cmake/cmake/-/tree/master/Tests/FindSQLite3/Test
find_package(SQLite3 3.34 REQUIRED)
add_definitions(-DCMAKE_EXPECTED_SQLite3_VERSION="${SQLite3_VERSION}")
add_executable(test_sqlite3 test_sqlite3.cpp)
target_link_libraries(test_sqlite3 SQLite::SQLite3)
add_test(NAME test_sqlite3 COMMAND test_sqlite3)
