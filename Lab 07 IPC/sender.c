#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#define FIFO_FILE "/tmp/fifo1"

int main(void){
	int fd;
	char *str = "100";

	if(-1==(fd=open(FIFO_FILE, O_WRONLY))){
		perror("open() error");
		exit(1);
	}

	write(fd, str, strlen(str));
	close(fd);
}
