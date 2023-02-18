/*
Adopted from Gravity's Array implementation.
Created by Marco Bambini on 31/07/14.
Copyright (c) 2014 CreoLabs. Licensed under the MIT License.
Owl Kernel Implementation by TalonFox.
Copyright (C) 2020-2023. Licensed under the MIT License.
*/

#ifndef _OWL_VEC_H
#define _OWL_VEC_H 1

#include <alloc/alloc.h>
#include <util/string.h>

#define VECTOR_DEFAULT_SIZE      8
#define Vector(type)             struct {size_t n, m; type *p;}
#define vec_init(v)              ((v).n = (v).m = 0, (v).p = 0)
#define vec_decl_init(_t,_v)     _t _v; vec_init(_v)
#define vec_destroy(v)           if ((v).p) free((v).p)
#define vec_get(v, i)            ((v).p[(i)])
#define vec_setnull(v, i)        ((v).p[(i)] = NULL)
#define vec_pop(v)               ((v).p[--(v).n])
#define vec_last(v)              ((v).p[(v).n-1])
#define vec_size(v)              ((v).n)
#define vec_max(v)               ((v).m)
#define vec_inc(v)               (++(v).n)
#define vec_dec(v)               (--(v).n)
#define vec_nset(v,N)            ((v).n = N)
#define vec_push(type, v, x)     {if ((v).n == (v).m) {                                        \
                                    (v).m = (v).m? (v).m<<1 : VECTOR_DEFAULT_SIZE;                \
                                    (v).p = (type*)realloc((v).p, sizeof(type) * (v).m);}        \
                                    (v).p[(v).n++] = (x);}
#define vec_resize(type, v, n)   (v).m += n; (v).p = (type*)realloc((v).p, sizeof(type) * (v).m)
#define vec_resize0(type, v, n)  (v).p = (type*)realloc((v).p, sizeof(type) * ((v).m+n));    \
                                    (v).m ? memset((v).p+(sizeof(type) * n), 0, (sizeof(type) * n)) : memset((v).p, 0, (sizeof(type) * n)); (v).m += n
#define vec_npop(v,k)            ((v).n -= k)
#define vec_reset(v,k)           ((v).n = k)
#define vec_reset0(v)            vec_reset(v, 0)
#define vec_set(v,i,x)           (v).p[i] = (x)

/* Commonly used vectors */
typedef Vector(void*) VectorPtr;
typedef Vector(uintptr_t) VectorUsize;

#endif