#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

#define COUNT_DONE 10
#define COUNT_HALT1 3
#define COUNT_HALT2 6

pthread_mutex_t count_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t condition_var = PTHREAD_COND_INITIALIZER;

void *functionCount1();
void *functionCount2();

int count=0;

int main(){
	pthread_t thread1, thread2;

	pthread_create(&thread1, NULL, &functionCount1,NULL);
	pthread_create(&thread2, NULL, &functionCount2, NULL);

	pthread_join(thread1, NULL);
	pthread_join(thread2, NULL);

	printf("Fianl count : %d\n", count);
	exit(0);

}

void *functionCount1(){
	for(;;){
		pthread_mutex_lock(&count_mutex);
		pthread_cond_wait(&condition_var, &count_mutex);
		count++;
		printf("Counter value functionCount1: %d\n", count);
		pthread_mutex_unlock(&count_mutex);
		if(count>=COUNT_DONE) return(NULL);
	}
}

void *functionCount2(){
	for(;;){
		pthread_mutex_lock(&count_mutex);
		if(count == 2 || count==3){
			pthread_cond_signal(&condition_var);
		}
		else if(count >6){
			pthread_cond_signal(&condition_var);
		}
		
		else{
			count++;
			printf("Counter value functionCount2: %d\n", count);
		}

		pthread_mutex_unlock(&count_mutex);

		if(count >= COUNT_DONE) return (NULL);
	}
}
