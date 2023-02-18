#ifndef _OWL_AVL_H
#define _OWL_AVL_H 1

#include <stdint.h>

struct AVLNode {
  uint64_t key;
  void* value;
  struct AVLNode *left;
  struct AVLNode *right;
  int height;
};

#endif