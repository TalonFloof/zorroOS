#include <util/avl.h>
#include <sync/lock.h>

Lock owlObjTreeLock = {
    .name = "Owl Object Tree Lock",
    .atomic = 0,
    .permitInterrupts = 0,
};

Lock owlObjTypeTreeLock = {
    .name = "Owl ObjectType Tree Lock",
    .atomic = 0,
    .permitInterrupts = 0,
};

struct AVLNode* owlObjTree = NULL;
struct AVLNode* owlObjTypeTree = NULL;
