#include "Team.h"

TeamID NewTeam(const char* name) {
    return (TeamID)Syscall(0x20003,(uintptr_t)name,0,0,0,0,0);
}
SyscallCode LoadExecImage(TeamID id, const char** argv, const char** envp) {
    return (TeamID)Syscall(0x20005,id,(uintptr_t)argv,(uintptr_t)envp,0,0,0);
}