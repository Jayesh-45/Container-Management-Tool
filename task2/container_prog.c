#include <stdio.h>  
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/wait.h>

#define LOOP 10000
#define SEED 10111


void change_hostname() {

    const char *new_hostname = "new_hostname";
    if (sethostname(new_hostname, strlen(new_hostname)) != 0) {
        perror("sethostname");
        return;
    }

    char hostname[32];
    if (gethostname(hostname, sizeof(hostname)) != 0) {
        perror("gethostname");
        return;
    }

    printf("\nHostname within container: %s\n", hostname);

}

void list_root_directory() {

    struct dirent *de;  // Pointer for directory entry

    DIR *dr = opendir("/");

    if (dr == NULL)  // opendir returns NULL if couldn't open directory
    {
        printf("Could not open current directory" );
        return;
    }

    printf("_ _ _ _ _ _ _ _ _ _ _ _ _ _ \n");

    printf("\nFiles/Directories in root directory:\n");
    while ((de = readdir(dr)) != NULL)
            printf("%s\n", de->d_name);
    closedir(dr);

    printf("_ _ _ _ _ _ _ _ _ _ _ _ _ _ \n");
}


void compute_benchmark() {

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start); 

    long long val = 0;
    for (int i = 0; i < LOOP; i++) {
        for (int j = 0; j < LOOP; j++) {
            val += rand();
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    printf("\nComputation Benchmark:\n");
    printf("Time Taken: %ld ms\n", (end.tv_sec - start.tv_sec) * 1000000 + (end.tv_nsec - start.tv_nsec) / 1000);
    printf("Value (Ignore): %lld\n", val);
}


int main(int argc, char *argv[]) {

    struct dirent *de;  // Pointer for directory entry

    if (argc != 2) {
        printf("Usage: %s <subtask1|subtask2|subtask3>\n", argv[0]);
        return 1;
    }


    srand(SEED);

    printf("Process PID: %d\n", getpid());

    if (fork() == 0) {
        printf("Child Process PID: %d\n", getpid());
        exit(0);
    }

    wait(NULL);

    list_root_directory();

    if (strcmp(argv[1], "subtask2") == 0) {
        change_hostname();
    }


    if (strcmp(argv[1], "subtask3") == 0 || strcmp(argv[1], "subtask2") == 0){
        compute_benchmark();
    }
    
    return 0;
}


