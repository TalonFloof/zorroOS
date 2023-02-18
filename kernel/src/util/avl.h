#ifndef _OWL_AVL_H
#define _OWL_AVL_H 1

#include <stdint.h>
#include <stddef.h>

struct AVLNode {
  uint64_t key;
  struct AVLNode *left;
  struct AVLNode *right;
  int height;
};

struct AVLNode *AVLInsertNode(struct AVLNode *node, uint64_t key, size_t data);
struct AVLNode *AVLDeleteNode(struct AVLNode *root, uint64_t key);
void* AVLSearch(struct AVLNode* node, uint64_t key);

#endif