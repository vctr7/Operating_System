#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

void main(void){
	if(open("temp", O_RDWR)<0){
		perror("open");
		exit(1);
	}
	if(unlink("temp")<0){
		perror("unlink");
		exit(2);
	}
	printf("Unlink done!\n");
	sleep(15);
	printf("END.\n");
	exit(0);
}
