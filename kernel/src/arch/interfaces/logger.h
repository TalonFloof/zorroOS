#ifndef _OWL_LOGGER_H
#define _OWL_LOGGER_H 1

#include <stdarg.h>
#include <stddef.h>
#include <util/string.h>

typedef void (*IOwlLogger)(const char*, size_t);

/* The LogWrite routine is based off of LemonOS's WriteF routine, which can be
 * found here:
 * https://github.com/LemonOSProject/LemonOS/blob/master/Kernel/src/Logging.cpp
 * LemonOS is licensed under the Simplified (2-clause) BSD License. */

static void LogWrite(IOwlLogger logger, const char* __restrict format,
                     va_list args) {
  char buf[64];
  while (*format != '\0') {
    if (format[0] != '%' || format[1] == '%') {
      if (format[0] == '%') format++;
      size_t amount = 1;
      while (format[amount] && format[amount] != '%') amount++;
      logger(format, amount);
      format += amount;
      continue;
    }
    const char* format_begun_at = format++;
    char hex = 1;
    char isHalf = 0;
    char isLong = 0;
  again:
    switch (*format) {
      case 'l':
        isLong = 1;
        format++;
        goto again;
      case 'h':
        if (!isLong) {
          isHalf = 1;
        }
        format++;
        goto again;
      case 'c': {
        format++;
        char arg = (char)va_arg(args, int);
        logger(&arg, 1);
        break;
      }
      case 'b': {
        format++;
        unsigned int arg = va_arg(args, unsigned int);
        const char* str = (arg ? "true" : "false");
        logger(str, strlen(str));
        break;
      }
      case 's': {
        format++;
        const char* arg = va_arg(args, const char*);
        size_t len = strlen(arg);
        logger(arg, len);
        break;
      }
      case 'd':
      case 'i': {
        format++;
        long arg = 0;

        if (isHalf) {
          arg = va_arg(args, int);
        } else {
          arg = va_arg(args, long);
        }

        if (arg < 0) {
          logger("-", 1);
          (void)itoa(-arg, (char*)&buf, 10);
        } else {
          (void)itoa(arg, (char*)&buf, 10);
        }
        logger((char*)&buf, strlen((char*)&buf));
        break;
      }
      case 'u': {
        hex = 0;
        __attribute__((fallthrough));
      }
      case 'x': {
        format++;
        if (isHalf) {
          unsigned int arg = va_arg(args, unsigned int);
          (void)itoa(arg, (char*)&buf, hex ? 16 : 10);
          if (hex) {
            logger("0x", 2);
          }
          logger((char*)&buf, strlen((char*)&buf));
        } else {
          unsigned long long arg = va_arg(args, unsigned long long);
          (void)itoa(arg, (char*)&buf, hex ? 16 : 10);
          if (hex) {
            logger("0x", 2);
          }
          logger((char*)&buf, strlen((char*)&buf));
        }
        break;
      }
      default:
        format = format_begun_at;
        size_t len = strlen(format);
        logger(format, len);
        format += len;
    }
  }
}

static inline void LogDebug(IOwlLogger logger, const char* __restrict fmt,
                            ...) {
  logger("\x1b[0;32m[DEBUG] | -> ", 21);
  va_list args;
  va_start(args, fmt);
  LogWrite(logger, fmt, args);
  va_end(args);
}

static inline void LogInfo(IOwlLogger logger, const char* __restrict fmt, ...) {
  logger("\x1b[0;36m[INFO] | -> ", 20);
  va_list args;
  va_start(args, fmt);
  LogWrite(logger, fmt, args);
  va_end(args);
}

static inline void LogWarn(IOwlLogger logger, const char* __restrict fmt, ...) {
  logger("\x1b[0;33m[WARN] | -> ", 20);
  va_list args;
  va_start(args, fmt);
  LogWrite(logger, fmt, args);
  va_end(args);
}

static inline void LogError(IOwlLogger logger, const char* __restrict fmt,
                            ...) {
  logger("\x1b[0;31m[ERROR] | -> ", 20);
  va_list args;
  va_start(args, fmt);
  LogWrite(logger, fmt, args);
  va_end(args);
}

static inline void LogFatal(IOwlLogger logger, const char* __restrict fmt,
                            ...) {
  logger("\x1b[0;1;31m[FATAL] | -> ", 20);
  va_list args;
  va_start(args, fmt);
  LogWrite(logger, fmt, args);
  va_end(args);
}

#endif