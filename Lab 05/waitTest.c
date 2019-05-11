#include <stdio.h>
#include <unistd.h>
#include <wait.h>

int main(){
	int counter = 1;
	int status;
	pid_t pid;
	pid_t pid_child;

	pid = fork();
	
	switch(pid){
		case -1:
		{
			printf("fail to create child process\n");
			return -1;
		}

		case 0:
		{
			printf("I will be terminated after I count 5 as a child process.\n");
			while(6 > counter){
				printf("child: %d\n", counter++);
				sleep(1);
			}
			return 99;
		}
		default:
		{
			printf("I am parent process. I will be waiting until child process ends.\n");

			pid_child = wait(&status);
			printf("The id of finished child process is %d,",pid_child);
			if(0==(status & 0xff)){
				printf("sucessfully finished and return value is %d\n", status>>8);
			}
			else
			{
				printf("unsuccessfully finished and exit value is %d\n", status);
			}
			printf("I will do my job.\n");
			while(1){
				printf("parent : %d\n", counter++);
				sleep(1);
			}
		}

	}
}
