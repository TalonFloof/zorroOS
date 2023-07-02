#ifndef _LIBZORRO_SYSTEM_TEAM_H
#define _LIBZORRO_SYSTEM_TEAM_H
#include "Syscall.h"

typedef int64_t TeamID;

TeamID NewTeam(const char* name);
SyscallCode LoadExecImage(TeamID id, const char** argv, const char** envp);

#endif