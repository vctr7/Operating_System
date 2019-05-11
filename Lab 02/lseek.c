#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#define BUFF_SIZE 1024

int main(){
	int fd;
	char buff[BUFF_SIZE];
	off_t sz_file;

	fd = open("./lseek.txt", O_RDONLY);

	memset( buff, '\0', BUFF_SIZE);
	lseek(fd, 10, SEEK_SET);
	read(fd, buff, BUFF_SIZE);
	puts(buff);

	memset(buff, '\0', BUFF_SIZE);
	lseek(fd, 5, SEEK_SET);
	lseek(fd, 5, SEEK_CUR);
	read(fd, buff, BUFF_SIZE);
	puts(buff);

	memset(buff, '\0', BUFF_SIZE);
	lseek(fd, -5, SEEK_END);
	read(fd, buff, BUFF_SIZE);
	puts(buff);

	sz_file = lseek(fd, 0, SEEK_END);
	printf("file size = %d\n", (int)sz_file);

	close(fd);

	return 0;
}

