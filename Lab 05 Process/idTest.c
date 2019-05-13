#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>

int main(){
	printf("I am Process %1ld\n", (long)getpid());
	printf("My parent process id is %1ld\n", (long)getppid());
}
