# These are required in every CMakeLists.txt file
cmake_minimum_required(VERSION 2.8.9)
project(project_name)

# This is the name of the final executable
set(EXE_NAME mindytest)

# This is the base name of the library
set(LIB_NAME mindy)

# Use the C++17 language standard
set (CMAKE_CXX_STANDARD 17)

# Specify where all of the header files are
include_directories(src/mindylib)

# Find the names of all the source files
file(GLOB SOURCES "src/mindylib/*.cpp")

# Specify what source files our library is built from
add_library(${LIB_NAME} STATIC ${SOURCES})

# Get a list of all the source files used for the executable application
file(GLOB SOURCES src/mindytest/*.cpp)

# Specify what source files our executable is built from
add_executable(${EXE_NAME} ${SOURCES})

# And our executable statically links in these libraries
target_link_libraries(${EXE_NAME} ${LIB_NAME})
target_link_libraries(${EXE_NAME} pthread)

# After the build, strip debug symbols from the target
add_custom_command(
  TARGET ${EXE_NAME} POST_BUILD
  COMMAND strip ${EXE_NAME}
  VERBATIM
)
