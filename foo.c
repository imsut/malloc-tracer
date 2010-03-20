#include <stdlib.h>
#include "foo.h"

void* foo_malloc(size_t size)
{
    return malloc(size);
}

void foo_free(void* ptr)
{
    free(ptr);
}
