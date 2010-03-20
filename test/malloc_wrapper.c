#include <stdlib.h>
#include "malloc_wrapper.h"

void* foo_malloc(size_t size)
{
    return malloc(size);
}

void foo_free(void* ptr)
{
    free(ptr);
}
