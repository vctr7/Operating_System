#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdlib.h>

int main(){
	int counter =0;
	pid_t pid;

	printf("child process creation \n");

	pid = fork();
	int i=5, j=5;

	switch(pid){
		case -1:
			printf("failed to create child process\n");
			return -1;
			break;
		case 0:
			printf("Discount to child process\n");
			while(i){
				printf("child : %d\n", counter--);
				sleep(1);
				i--;
			}
			break;
		default :
			printf("count to parent process\n");
			printf("pid of child process is %d.\n", pid);
			while(j){
				printf("parent : %d\n", counter++);
				sleep(1);
				j--;
			}
			break;
	}
}
