target:=test malloc_wrapper.so

ifeq "$(shell uname -m)" "ppc64"
CC:=ppu-gcc
else
CC:=gcc
endif

CFLAGS=-g -Wall -std=gnu99 -fPIC
LDLIBS=-lpthread -ldl

all: $(target)

$(target):

check:
	LD_PRELOAD=./malloc_wrapper.so ./test -t 3 -l 3 && cat malloc.log

clean:
	rm -f $(target) *.o

.SUFFIXES: .so
.o.so:
	$(CC) -shared -o $@ $<
