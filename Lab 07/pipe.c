#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BUFF_SIZE 1024

int main(){
	int pipes_parent[2];
	int pipes_child[2];
	char buff[BUFF_SIZE];
	int counter =2;
	pid_t pid;

	if(-1==pipe(pipes_parent)){
		perror("failed to create pipe");
		exit(1);
	}

	if(-1==pipe(pipes_child)){
		perror("failed to create pipe");
		exit(1);
	}

	pid = fork();


	switch(pid){
		case -1:{
			printf("failed to create chlid process \n");
			return -1;
			}
		case 0:{
		while(1){
			
			sprintf(buff, "child message: %d", counter);
			counter = counter*counter;
			write(pipes_child[1], buff, strlen(buff));			memset(buff, 0, BUFF_SIZE);
			read(pipes_parent[0], buff, BUFF_SIZE);
			printf("child process: %s\n", buff);
			sleep(1);
		       }
		       }
		default:
		{
			while(1){
			sprintf(buff, "parent message: %d",counter);
			counter = counter*2;
			write(pipes_parent[1], buff, strlen(buff));
			memset(buff, 0, BUFF_SIZE);
			read(pipes_child[0], buff, BUFF_SIZE);
			printf("parent process: %s\n", buff);
			sleep(1);
			}
		}
	}
}

