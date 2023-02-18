#ifndef _OWL_OBJECT_H
#define _OWL_OBJECT_H 1
#include <util/avl.h>
#include <stdint.h>

typedef struct {
  uint64_t objType;

} Object;

typedef struct {
  uint64_t objectSize;
  
} ObjectType;

#endif