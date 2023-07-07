#ifndef _LIBZORRO_COMMON_TIME_H
#define _LIBZORRO_COMMON_TIME_H
#include <stdint.h>

typedef struct { 
    int64_t secs;
    int64_t nsecs;
} UNIXTimestamp;

typedef struct {
    int year;
    int month;
    int day;
    int hour;
    int min;
    int sec;
} FormattedTime;

UNIXTimestamp GetTime();
FormattedTime GetFormattedTime(UNIXTimestamp time);

#endif