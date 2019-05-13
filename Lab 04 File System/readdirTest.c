#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>

int main(){
	DIR *dir_info;
	struct dirent *dir_entry;

	mkdir("test_A", 0755);
	mkdir("test_B", 0755);

	dir_info = opendir(".");
	if(NULL != dir_info){
		while(dir_entry = readdir(dir_info)){
			printf("%s\n", dir_entry -> d_name);
		}
		closedir(dir_info);
	}
}
