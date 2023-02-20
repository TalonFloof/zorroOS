#ifndef _OWL_OBJECT_H
#define _OWL_OBJECT_H 1
#include <util/avl.h>
#include <util/vec.h>
#include <sync/lock.h>
#include <stdint.h>

typedef struct {
  uint64_t type;
  uint64_t name;
  uint64_t nextCapID;
  uint64_t nextDataID;
  struct AVLNode* capabilities;
  struct AVLNode* data;
  /* Data will have a machine-sized word containing the reference count before the actual data */
} ObjectType;

typedef struct {
  uint64_t id;
  uint64_t objName;
} CapabilityID;

typedef struct {
  CapabilityID id;
  CapabilityID owner;
  uint64_t dataID;
  uint8_t flags; /* Bit 0: Public (If set, all capabilities can access this one)
                  * Bit 1: Sharable (If set, this capability can be copied)
                  * That's it for now...
                  */
} Capability;

typedef struct {
  ObjectType header;
  CapabilityID owner; /* Can be set to zero */
  uint64_t dataSize;
  Lock spinlock;
} UspaceObject;

#endif