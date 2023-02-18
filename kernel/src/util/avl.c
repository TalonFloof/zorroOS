/* Implements an AVL Tree
 * An AVL Tree is a self-balancing binary search tree
 * (and is one of the first self-balancing tree structures to be invented)
 * It works by shifting nodes around in specific conditions in an effort to balance the tree.
 * Adopted from programiz.com's implementation: https://www.programiz.com/dsa/avl-tree
 */
#include <alloc/alloc.h>
#include <util/avl.h>

// Calculate height
int AVLHeight(struct AVLNode *N) {
  if (N == NULL)
    return 0;
  return N->height;
}

static int max(int a, int b) {
  return (a > b) ? a : b;
}

// Create a node
struct AVLNode *AVLNewNode(uint64_t key, size_t data) {
  struct AVLNode *node = (struct AVLNode *)malloc(sizeof(struct AVLNode)+data);
  node->key = key;
  node->left = NULL;
  node->right = NULL;
  node->height = 1;
  return (node);
}

// Right rotate
struct AVLNode *AVLRightRotate(struct AVLNode *y) {
  struct AVLNode *x = y->left;
  struct AVLNode *T2 = x->right;

  x->right = y;
  y->left = T2;

  y->height = max(AVLHeight(y->left), AVLHeight(y->right)) + 1;
  x->height = max(AVLHeight(x->left), AVLHeight(x->right)) + 1;

  return x;
}

// Left rotate
struct AVLNode *AVLLeftRotate(struct AVLNode *x) {
  struct AVLNode *y = x->right;
  struct AVLNode *T2 = y->left;

  y->left = x;
  x->right = T2;

  x->height = max(AVLHeight(x->left), AVLHeight(x->right)) + 1;
  y->height = max(AVLHeight(y->left), AVLHeight(y->right)) + 1;

  return y;
}

// Get the balance factor
int AVLGetBalance(struct AVLNode *N) {
  if (N == NULL)
    return 0;
  return AVLHeight(N->left) - AVLHeight(N->right);
}

// Insert node
struct AVLNode *AVLInsertNode(struct AVLNode *node, uint64_t key, size_t data) {
  // Find the correct position to insertNode the node and insertNode it
  if (node == NULL)
    return (AVLNewNode(key,data));

  if (key < node->key)
    node->left = AVLInsertNode(node->left, key, data);
  else if (key > node->key)
    node->right = AVLInsertNode(node->right, key, data);
  else
    return node;

  // Update the balance factor of each node and
  // Balance the tree
  node->height = 1 + max(AVLHeight(node->left),
               AVLHeight(node->right));

  int balance = AVLGetBalance(node);
  if (balance > 1 && key < node->left->key)
    return AVLRightRotate(node);

  if (balance < -1 && key > node->right->key)
    return AVLLeftRotate(node);

  if (balance > 1 && key > node->left->key) {
    node->left = AVLLeftRotate(node->left);
    return AVLRightRotate(node);
  }

  if (balance < -1 && key < node->right->key) {
    node->right = AVLRightRotate(node->right);
    return AVLLeftRotate(node);
  }

  return node;
}

struct AVLNode *AVLMinValueNode(struct AVLNode *node) {
  struct AVLNode *current = node;

  while (current->left != NULL)
    current = current->left;

  return current;
}

// Delete a nodes
struct AVLNode *AVLDeleteNode(struct AVLNode *root, uint64_t key) {
  // Find the node and delete it
  if (root == NULL)
    return root;

  if (key < root->key)
    root->left = AVLDeleteNode(root->left, key);

  else if (key > root->key)
    root->right = AVLDeleteNode(root->right, key);

  else {
    if ((root->left == NULL) || (root->right == NULL)) {
      struct AVLNode *temp = root->left ? root->left : root->right;

      if (temp == NULL) {
        temp = root;
        root = NULL;
      } else
        *root = *temp;
      free(temp);
    } else {
      struct AVLNode *temp = AVLMinValueNode(root->right);

      root->key = temp->key;

      root->right = AVLDeleteNode(root->right, temp->key);
    }
  }

  if (root == NULL)
    return root;

  // Update the balance factor of each node and
  // balance the tree
  root->height = 1 + max(AVLHeight(root->left),
               AVLHeight(root->right));

  int balance = AVLGetBalance(root);
  if (balance > 1 && AVLGetBalance(root->left) >= 0)
    return AVLRightRotate(root);

  if (balance > 1 && AVLGetBalance(root->left) < 0) {
    root->left = AVLLeftRotate(root->left);
    return AVLRightRotate(root);
  }

  if (balance < -1 && AVLGetBalance(root->right) <= 0)
    return AVLLeftRotate(root);

  if (balance < -1 && AVLGetBalance(root->right) > 0) {
    root->right = AVLRightRotate(root->right);
    return AVLLeftRotate(root);
  }

  return root;
}

void* AVLSearch(struct AVLNode* node, uint64_t key) {
  if(node == NULL)
    return NULL;
  while(node->key != key) {
    if(key < node->key && node->left != NULL) {
      node = node->left;
    } else if(key > node->key && node->right != NULL) {
      node = node->right;
    } else {
      return NULL;
    }
  }
  return (void*)(((uintptr_t)node)+sizeof(struct AVLNode));
}