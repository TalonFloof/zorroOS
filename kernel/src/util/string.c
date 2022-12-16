#include <util/string.h>

void *memset(void *src, int c, size_t count)
{
    uint8_t *xs = (uint8_t *)src;

    while (count--)
        *xs++ = c;

    return src;
}

void *memcpy(void *dest, const void *src, size_t count)
{
    const char *sp = (char *)src;
    char *dp = (char *)dest;
    size_t i;
    for (i = count; i >= sizeof(uint64_t); i = count)
    {
        *((uint64_t *)dp) = *((uint64_t *)sp);
        sp = sp + sizeof(uint64_t);
        dp = dp + sizeof(uint64_t);
        count -= sizeof(uint64_t);
    }

    for (i = count; i >= 4; i = count)
    {
        *((uint32_t *)dp) = *((uint32_t *)sp);
        sp = sp + 4;
        dp = dp + 4;
        count -= 4;
    }

    for (i = count; i > 0; i = count)
    {
        *(dp++) = *(sp++);
        count--;
    }

    return dest;
}

int memcmp(const void *s1, const void *s2, size_t n)
{
    const uint8_t *a = (uint8_t *)s1;
    const uint8_t *b = (uint8_t *)s2;
    size_t i;

    for (i = 0; i < n; i++)
    {
        if (a[i] < b[i])
        {
            return -1;
        }
        else if (a[i] > b[i])
        {
            return 1;
        }
    }

    return 0;
}

void strcpy(char *dest, const char *src)
{
    while (*src)
    {
        *(dest++) = *(src++);
    }
    *dest = 0;
}

void strncpy(char *dest, const char *src, size_t n)
{
    while (n-- && *src)
    {
        *(dest++) = *(src++);
    }
    *dest = 0;
}

size_t strlen(const char *str)
{
    size_t i = 0;
    while (str[i])
        i++;
    return i;
}

int strcmp(const char *s1, const char *s2)
{
    while (*s1 == *s2)
    {
        if (!*(s1++))
        {
            return 0;
        }

        s2++;
    }
    return (*s1) - *(s2);
}

int strncmp(const char *s1, const char *s2, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++)
    {
        if (s1[i] != s2[i])
        {
            return s1[i] < s2[i] ? -1 : 1;
        }
        else if (s1[i] == '\0')
        {
            return 0;
        }
    }

    return 0;
}

char *strchr(const char *s, int c)
{
    while (*s != (char)c)
        if (!*s++)
            return 0;
    return (char *)s;
}

char *strnchr(const char *s, int c, size_t n)
{
    while (n-- && *s != (char)c)
        if (!*s++)
            return 0;

    if (n <= 0)
    {
        return 0;
    }

    return (char *)s;
}