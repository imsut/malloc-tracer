#define _GNU_SOURCE
#include <dlfcn.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <inttypes.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define MAX_BUFFER (4 * 1024)

static void* (*malloc0)(size_t size);
static void (*free0)(void* ptr);

static int fd;

static void __attribute__((constructor))
init()
{
    * (void**)&malloc0 = dlsym(RTLD_NEXT, "malloc");
    * (void**)&free0 = dlsym(RTLD_NEXT, "free");

    char* filename = getenv("MALLOC_WRAPPER_FILENAME");
    fd = open(filename ? filename : "malloc.log",
	      O_RDWR | O_CREAT | O_TRUNC,
	      S_IRUSR | S_IWUSR | S_IRGRP | S_IWOTH);
}

static void __attribute__((destructor))
fin()
{
    close(fd);
}

/*
 * the struct below showing stack frame structure is
 * copied from glibc code.
 * see glibc/sysdeps/<ARCH>/backtrace.c
 */
struct layout_t {
#if (defined __x86_64) || (defined __x86)
    struct layout *next;
    void *ret;
#elif (defined __PPC64__)
    struct layout *__unbounded next;
    long condition_register;
    void *__unbounded ret;
#elif (defined __PPC32__)
    struct layout *__unbounded next;
    void *__unbounded ret;
#endif
};

static char hex2char(int hex)
{
    if (hex < 10) {
	return hex + '0';
    }

    return (hex - 10) + 'a';
}

static int hexdump(char* buf, const char* ptr, size_t length)
{
    int idx = 0;
    buf[idx++] = '0';
    buf[idx++] = 'x';
    
    for (int i = 0; i < length; ++i) {
#if (defined __BIG_ENDIAN__)
	const unsigned char c = ptr[i];
#else
	const unsigned char c = ptr[length - 1 - i];
#endif
	buf[idx++] = hex2char(c / 16);
	buf[idx++] = hex2char(c % 16);
    }

    return idx;
}

void* malloc(size_t size)
{
    void* ptr = malloc0(size);

    char buf[MAX_BUFFER];

    int pos = 0;
    buf[pos++] = 'm';
    buf[pos++] = ' ';

    pos += hexdump(&buf[pos], (char*) &ptr, sizeof(ptr));
    buf[pos++] = ' ';
    pos += hexdump(&buf[pos], (char*) &size, sizeof(size));

    struct layout_t* lo = __builtin_frame_address(0);
    while (lo) {
	void* caller = lo->ret;
	buf[pos++] = ' ';
	pos += hexdump(&buf[pos], (char*) &caller, sizeof(caller));
	
	lo = (struct layout_t*) lo->next;
    }

    buf[pos++] = '\n';
    write(fd, buf, pos);

    return ptr;
}

void free(void* ptr)
{
    free0(ptr);

    if (ptr == NULL) return;

    char buf[MAX_BUFFER];

    int pos = 0;
    buf[pos++] = 'f';
    buf[pos++] = ' ';

    pos += hexdump(&buf[pos], (char*) &ptr, sizeof(ptr));

    buf[pos++] = '\n';
    write(fd, buf, pos);
}
