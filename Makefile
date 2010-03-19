target:=test malloc_wrapper.so

CC:=gcc
CFLAGS=-g -Wall -std=gnu99 -fPIC
LDLIBS=-lpthread -ldl

all: $(target)

$(target):

clean:
	rm -f $(target) *.o

.SUFFIXES: .so
.o.so:
	$(CC) -shared -o $@ $<
