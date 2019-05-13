#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>

#define MAX 1024

int main(int argc, char ** argv[]){
	int fd;
	int readNum=0;
	int writeNum=0;
	char buf[MAX];
	char *buf2 = "Success Writting tset\n";
	int i;

	fd=open("writeTest.txt", O_RDWR);
	if(fd==-1){
		printf("Fileopen Failed!\n");
		return 1;
	}

	writeNum=write(fd, buf2, strlen(buf2));

	memset(buf, 0x00, MAX);
	readNum=read(fd, buf, MAX-1);
	printf("ReadNum is : %d\n", readNum);
	printf("%s\n", buf);

	close(fd);
}
