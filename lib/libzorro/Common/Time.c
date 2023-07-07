#include "Time.h"
#include <System/Syscall.h>

UNIXTimestamp GetTime() {
    UNIXTimestamp ret;
    Syscall(0x30002,(uintptr_t)&ret,0,0,0,0,0);
    return ret;
}

static int Time_DaysInYear(int year) {
    return (((year % 4) == 0 && (year % 100) != 0) || (year % 400) == 0) ? 366 : 365;
}

static int Time_DaysInMonth(int month, int year) {
    switch(month) {
        case 0:
        case 2:
        case 4:
        case 6:
        case 7:
        case 9:
        case 11:
            return 31;
        case 3:
        case 5:
        case 8:
        case 10:
            return 30;
        case 1:
            return (Time_DaysInYear(year) == 366) ? 29 : 28;
        default:
            return 0;
    }
}

FormattedTime GetFormattedTime(UNIXTimestamp time) {
    FormattedTime f;
    f.sec = time.secs % 60;
    f.min = (time.secs / 60) % 60;
    f.hour = ((time.secs / 60) / 60) % 24;
    int year = 1970;
    int days = time.secs / (60 * 60 * 24);
    int month = 0;
    while(days >= Time_DaysInYear(year)) {
        days -= Time_DaysInYear(year);
        year++;
    }
    while(days >= Time_DaysInMonth(month,year)) {
        days -= Time_DaysInMonth(month,year);
        month++;
    }
    f.year = year;
    f.month = month;
    f.day = days;
    return f;
}
