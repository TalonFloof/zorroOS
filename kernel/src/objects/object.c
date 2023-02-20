#include <objects/object.h>

Lock owlObjTypeTreeLock = {
    .name = "Owl ObjectType Tree Lock",
    .atomic = 0,
    .permitInterrupts = 0,
};

struct AVLNode* owlObjTypeTree = NULL;

/*
KERNEL BUILTIN OBJECT IDs
0x6A624F7265707553: SuperObj
0x0000646165726854: Thread
0x0000000061657241: Area
0x0000646F6874654D: Method
*/

int Object_InvokeMethod(CapabilityID* cap) {
    Lock_Acquire(&owlObjTypeTreeLock);
    ObjectType* obj = AVLSearch(owlObjTypeTree,cap->objName);
    if(obj == NULL) {
        Lock_Release(&owlObjTypeTreeLock);
        return -2; /* Unknown Object Type */
    }
    Lock_Release(&owlObjTypeTreeLock);
    return 0;
}