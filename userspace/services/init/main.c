#include <Filesystem/Filesystem.h>
#include <System/Team.h>
#include <System/Thread.h>
#include <System/Syscall.h>

int main() {
    RyuLog("zorroOS (C) 2020-2023 TalonFox, Licensed Under the MIT License\n\n");
    RyuLog("Starting Raven Compositor service...\n");
    TeamID ravenTeam = NewTeam("Raven Compositor Service");
    LoadExecImage(ravenTeam,(const char*[]){"/bin/raven",NULL},NULL);
    Eep(20);
    RyuLog("Starting Desktop...\n");
    TeamID desktopTeam = NewTeam("Desktop Service");
    LoadExecImage(desktopTeam,(const char*[]){"/bin/desktop",NULL},NULL);
    RyuLog("Starting Welcome App...\n");
    TeamID welcomeApp = NewTeam("Welcome App");
    LoadExecImage(welcomeApp,(const char*[]){"/bin/welcome",NULL},NULL);
    //while(1) {

    //}
    return 0;
}