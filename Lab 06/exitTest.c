#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

void *t_function(void *data){
	long int num = *((long int *)data);
	num +=10;
	printf("num %ld\n", num);
	sleep(1);
	pthread_exit((void*)num);

}
int main(){
	pthread_t p_thread;
	int thr_id;
	int status;
	int a=100;

	thr_id = pthread_create(&p_thread, NULL, t_function, (void *)&a);
	if(thr_id<0){
		perror("thread create error : ");
		exit(0);
	}

//	pthread_join(p_thread, (void **)&status);
	printf("thread join : %d\n", status);

	return 0;

}

