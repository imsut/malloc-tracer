#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

#include "malloc_wrapper.h"

static const size_t MAX_NUM_THREADS = 32;

struct arg_t {
    int num_loop;
    double leak_prob;
};

static void* start_routine(void* p)
{
    struct arg_t* arg = (struct arg_t*) p;

    for (int i = 0; arg->num_loop < 0 || i < arg->num_loop; ++i) {
	void* p = foo_malloc(100);

	usleep(100 * 1000); // sleep 100 ms

	if (! ((double) rand() / RAND_MAX < arg->leak_prob)) {
	    foo_free(p);
	}
    }

    return NULL;
}

static void print_usage(const char* prog_name)
{
    fprintf(stderr,
	    "USAGE: %s [-t NUM_THREADS] [-l NUM_LOOP] [-p LEAK_PROB]\n"
	    "  -t: number of threads running (default: 2)\n"
	    "  -l: number of loop each thread repeats malloc and free (default: 8)\n"
	    "  -p: leak probability between 0.0 to 1.0 (default: 0.0)\n"
	    "",
	    prog_name);
}

int main(int argc, char** argv)
{
    int opt;

    int num_threads = 2;
    int num_loop = 8;
    double leak_prob = 0.0;
    
    while ((opt = getopt(argc, argv, "t:l:p:")) != -1) {
	switch (opt) {
	case 't':
	    num_threads = atoi(optarg);
	    if (num_threads > MAX_NUM_THREADS) {
		print_usage(argv[0]);
		exit(EXIT_FAILURE);
	    }
	    break;
	case 'l':
	    num_loop = atoi(optarg);
	    break;
	case 'p':
	    leak_prob = atof(optarg);
	    break;
	default:
	    print_usage(argv[0]);
	    exit(EXIT_FAILURE);
	}
    }

    pthread_t threads[MAX_NUM_THREADS];
    struct arg_t args[MAX_NUM_THREADS];

    for (int i = 0; i < num_threads; ++i) {
	args[i].num_loop = num_loop;
	args[i].leak_prob = leak_prob;
	pthread_create(&threads[i], NULL, start_routine, &args[i]);
    }

    for (int i = 0; i < num_threads; ++i) {
	pthread_join(threads[i], NULL);
    }

    exit(EXIT_SUCCESS);
}
