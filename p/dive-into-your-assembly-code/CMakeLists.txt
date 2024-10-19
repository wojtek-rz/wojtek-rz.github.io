cmake_minimum_required(VERSION 3.15)
project(AsmTargetTutorial)

add_executable(main main.cpp)
target_compile_options(main PRIVATE -g -O2)
set(CMAKE_CXX_CREATE_ASSEMBLY_SOURCE "<CMAKE_CXX_COMPILER> \
    $(CXX_DEFINES) $(CXX_INCLUDES) ${CMAKE_CXX_FLAGS} \
    -O1 -S -fverbose-asm -fno-asynchronous-unwind-tables -fno-exceptions -masm=intel \
    <SOURCE> -o <ASSEMBLY_SOURCE>")