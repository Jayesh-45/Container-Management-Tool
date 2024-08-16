#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/utsname.h>
#include <sched.h>
#include <sys/syscall.h>

#define errExit(msg)        \
    do                      \
    {                       \
        perror(msg);        \
        exit(EXIT_FAILURE); \
    } while (0)


#define CHILD_STACK_SIZE 0x800000



int child_function(void *arg) {

    int *pipefd = (int *)arg;

    close(pipefd[0]);

    const char *hostname = "Child1Hostname";
    char hostname_buf[32];
    if (sethostname(hostname, strlen(hostname)) == -1) {
        errExit("sethostname");
    }
    printf("Child1 Process PID: %d\n", getpid());
    gethostname(hostname_buf, 32);
    printf("Child1 Hostname: %s\n", hostname_buf);

    write(pipefd[1], "1", 1);
    close(pipefd[1]);

    while (1)
    {
        sleep(1);
    }
    
    return 0;
}


int child2_function() {

    char hostname_buf[32];
    printf("Child2 Process PID: %d\n", getpid());
    gethostname(hostname_buf, 32);
    printf("Child2 Hostname: %s\n", hostname_buf);

    return 0;
}



int main() {

    char hostname_buf[32];
    char buf[32];

    void *child_stack = malloc(CHILD_STACK_SIZE);

    int pipefd[2];

    pid_t child_pid;
    
    if (pipe(pipefd) == -1) {
        errExit("pipe");
    }

    if (!child_stack) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }

    printf("----------------------------------------\n");
    printf("Parent Process PID: %d\n", getpid());
    gethostname(hostname_buf, 32);
    printf("Parent Hostname: %s\n", hostname_buf);
    printf("----------------------------------------\n");

    /**
     * 1. Create a new child process that runs child1_function
     * 2. The child process will have its own UTS and PID namespace
     * 3. You should pass the pointer to the pipefd array as an argument to the child1_function
     * 4. PID of child1 should be assigned to child_pid variable
    */

   // ------------------ WRITE CODE HERE ------------------

    pid_t child_pid = clone(child_function, (char *)child_stack + CHILD_STACK_SIZE, CLONE_NEWUTS | CLONE_NEWPID | SIGCHLD, pipefd);
    if (child_pid == -1) {
        errExit("clone");
    }

   // -----------------------------------------------------

    close(pipefd[1]);
    read(pipefd[0], buf, 1);
    close(pipefd[0]);

    /**
     * You can write any code here as per your requirement
     * Note: PID namespace of a process will only change the PID namespace of its subsequent children, not the process itself.
     * You are allowed to make modifications to the parent process such that PID namespace of child2 is same as that of child1
    */

    // ------------------ WRITE CODE HERE ------------------

    int pid_fd = syscall(SYS_pidfd_open, child_pid, 0);
    if (pid_fd == -1) {
        errExit("pidfd_open");
    }

    if (setns(pid_fd, CLONE_NEWPID ) == -1) {
        errExit("setns");
    }


    // -----------------------------------------------------


    printf("----------------------------------------\n");
    printf("Parent Process PID: %d\n", getpid());
    gethostname(hostname_buf, 32);
    printf("Parent Hostname: %s\n", hostname_buf);
    printf("----------------------------------------\n");
    

    if (fork() == 0) {

        /**
         * 1. Join the existing UTS namespace and PID namespace
        */

        // ------------------ WRITE CODE HERE ------------------
        
	if (setns(pid_fd, CLONE_NEWUTS ) == -1) {
            errExit("setns");
        }


        // -----------------------------------------------------

        child2_function();
        exit(0);
    }

    wait(NULL);
    kill(child_pid, SIGKILL);
    wait(NULL);

    printf("----------------------------------------\n");
    printf("Parent Process PID: %d\n", getpid());
    gethostname(hostname_buf, 32);
    printf("Parent Hostname: %s\n", hostname_buf);
    printf("----------------------------------------\n");
    
    

    free(child_stack);
    return 0;
}
