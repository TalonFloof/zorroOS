#include <Filesystem/Filesystem.h>
#include <System/Team.h>
#include <System/Thread.h>
#include <System/Syscall.h>

int main() {
    RyuLog("zorroOS (C) 2020-2024 TalonFloof, Licensed Under the MIT License\n\n");
    RyuLog("Starting Raven Compositor service...\n");
    TeamID ravenTeam = NewTeam("Raven Compositor Service");
    LoadExecImage(ravenTeam,(const char*[]){"/bin/raven",NULL},NULL);
    //while(1) {

    //}
    return 0;
}