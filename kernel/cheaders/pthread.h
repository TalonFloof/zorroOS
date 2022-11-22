#pragma once

struct __thread_data {
    void *ptr;
};

struct __threadattr {
    void *ptr;
};

typedef struct __thread_data *pthread_t;