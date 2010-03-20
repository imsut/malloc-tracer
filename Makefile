target:=malloc_tracer.so test/memory_leak test/libmalloc_wrapper.so

ifeq "$(shell uname -m)" "ppc64"
CC:=ppu-gcc
else
CC:=gcc
endif

CFLAGS=-g -Wall -std=gnu99 -fPIC
LDLIBS=-lpthread -ldl

all: $(target)

test/memory_leak: test/libmalloc_wrapper.so

test/libmalloc_wrapper.o:
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ test/malloc_wrapper.c

check:
	MALLOC_TRACER_MAPS=maps LD_PRELOAD=./malloc_tracer.so \
	./test/memory_leak -t 3 -l 3 -p 0.5 && cat malloc_trace.log && cat maps
	./trace.rb -m maps malloc_trace.log

clean:
	rm -f $(target) *.o

.SUFFIXES: .so
.o.so:
	$(CC) -shared -o $@ $<
