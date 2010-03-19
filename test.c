#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

static const size_t MAX_NUM_THREADS = 32;

static void* start_routine(void* arg)
{
    int num_loop = *(int*)arg;

    for (int i = 0; i < num_loop; ++i) {
	void* p = malloc(100);

	usleep(100 * 1000); // sleep 100 ms

	free(p);
    }

    return NULL;
}

static void print_usage(const char* prog_name)
{
    fprintf(stderr,
	    "USAGE: %s [-t NUM_THREADS]\n"
	    "  -t: number of threads running\n"
	    "",
	    prog_name);
}

int main(int argc, char** argv)
{
    int opt;

    int num_threads = 1;
    int num_loop = 8;
    
    while ((opt = getopt(argc, argv, "t:l:")) != -1) {
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
	default:
	    print_usage(argv[0]);
	    exit(EXIT_FAILURE);
	}
    }

    pthread_t threads[MAX_NUM_THREADS];
    for (int i = 0; i < num_threads; ++i) {
	pthread_create(&threads[i], NULL, start_routine, &num_loop);
    }

    for (int i = 0; i < num_threads; ++i) {
	pthread_join(threads[i], NULL);
    }

    exit(EXIT_SUCCESS);
}
