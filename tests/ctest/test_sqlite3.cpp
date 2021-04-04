#include <iostream>
#include <string>
#include <sqlite3.h>

int main()
{
  std::string expected_version = CMAKE_EXPECTED_SQLite3_VERSION;
  std::string found_version = SQLITE_VERSION;
  std::cout << "SQLite3: expecting version " << expected_version
            << ", found verison " << found_version << std::endl;
  return expected_version.compare(found_version);
}
