#pragma once
#include <stddef.h>
#include <stdint.h>

char *itoa(unsigned long long num, char *str, int base);
void *memset(void *src, int c, size_t count);
void *memcpy(void *dest, const void *src, size_t count);
int memcmp(const void *s1, const void *s2, size_t n);
void strcpy(char *dest, const char *src);
void strncpy(char *dest, const char *src, size_t n);
size_t strlen(const char *str);
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);
char *strchr(const char *s, int c);
char *strnchr(const char *s, int c, size_t n);