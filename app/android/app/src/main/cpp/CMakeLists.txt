cmake_minimum_required(VERSION 3.22.1)
project(deepos_native C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")

# 1. libccenosys.so: seccomp SIGSYS -> ENOSYS preload library (no libc dependency)
add_library(ccenosys SHARED seccomp-enosys.c)
target_compile_options(ccenosys PRIVATE -O2 -fPIC -fno-stack-protector)
target_link_options(ccenosys PRIVATE -nostdlib -Wl,-z,noexecstack -Wl,--hash-style=both)

# 2. libccenosysrun.so: ptrace wrapper executable for static binaries (named lib*.so for nativeLibraryDir extraction)
add_executable(ccenosysrun seccomp-enosys-run.c)
set_target_properties(ccenosysrun PROPERTIES PREFIX "lib" SUFFIX ".so")
target_compile_options(ccenosysrun PRIVATE -O2)

# 3. libccptyhost.so: native PTY host for /api/term/* (stdin/stdout <-> pty, fd 3 resize)
add_executable(ccptyhost ptyhost.c)
set_target_properties(ccptyhost PROPERTIES PREFIX "lib" SUFFIX ".so")
target_compile_options(ccptyhost PRIVATE -O2)

# 4. libccexecshim.so: glibc-side execve loader rewrite shim (for targetSdk 36)
#    Symbols (__errno_location, getenv, environ, dlsym) resolve at runtime from glibc libc.so.6.
add_library(ccexecshim SHARED exec-shim.c)
target_compile_options(ccexecshim PRIVATE -O2 -fPIC -fno-stack-protector)
target_link_options(ccexecshim PRIVATE -nostdlib -Wl,-z,noexecstack -Wl,--hash-style=both -Wl,--unresolved-symbols=ignore-all)

# 5. libccexecshimb.so: bionic-side execve loader rewrite shim (for targetSdk 36)
add_library(ccexecshimb SHARED exec-shim.c)
target_compile_definitions(ccexecshimb PRIVATE BIONIC=1)
target_compile_options(ccexecshimb PRIVATE -O2 -fPIC -fno-stack-protector)
target_link_options(ccexecshimb PRIVATE -Wl,-z,noexecstack -Wl,--hash-style=both)
target_link_libraries(ccexecshimb dl)

# 6. libccrun.so: loader exec trampoline for static / raw-syscall binaries
add_executable(ccrun loader-run.c)
set_target_properties(ccrun PROPERTIES PREFIX "lib" SUFFIX ".so")
target_compile_options(ccrun PRIVATE -O2)

# 7. libccnodump.so: PR_SET_DUMPABLE=0 preload library (no libc dependency, works on bionic & glibc)
add_library(ccnodump SHARED nodump.c)
target_compile_options(ccnodump PRIVATE -O2 -fPIC -fno-stack-protector)
target_link_options(ccnodump PRIVATE -nostdlib -Wl,-z,noexecstack -Wl,--hash-style=both)
