#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

int num_loops=10000;
int cnt =0;

pthread_mutex_t m1 = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t m2 = PTHREAD_MUTEX_INITIALIZER;


void *Thread1(void *v), *Thread2(void *v);

int main(){
	int n;
	pthread_t t[2];
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_create(&t[0], &attr, Thread1, NULL);
	pthread_create(&t[1], &attr, Thread2, NULL);
	for(n=0; n<2; n++){
		pthread_join(t[n], NULL);
	}
	return 0;
}

void *Thread1(void *v){
	int n;
	for(n=1; n<=num_loops; n++){
		printf("Thread 1 tries locking m1\n");
		pthread_mutex_lock(&m1);
		sleep(1);
		printf("Thread 1 has locked m1, tries locking m2\n");

		if(pthread_mutex_trylock(&m2) == EBUSY){
			printf("m2 is busy\n");
			sleep(1);
			printf("Thread 1 unlocks m1\n");
			pthread_mutex_unlock(&m1);
			sleep(1);
		}
		else{
			sleep(1);
			printf("Thread 1 has locked m2\n");
			++cnt;
			printf("Thread 1 unlocks m2\n");
			pthread_mutex_unlock(&m2);
			sleep(1);
			printf("Thread 1 unlocks m1\n");
			pthread_mutex_unlock(&m1);
			sleep(1);
		}
	}

	return NULL;
}

void *Thread2(void *v){
        int n;
        for(n=1; n<=num_loops; n++){
                printf("Thread 2 tries locking m2\n");
                pthread_mutex_lock(&m2);
                sleep(1);
                printf("Thread 2 has locked m2, tries locking m1\n");

                if(pthread_mutex_trylock(&m1) == EBUSY){
                        printf("m1 is busy\n");
                        sleep(1);
                        printf("Thread 2 unlocks m2\n");
                        pthread_mutex_unlock(&m2);
                        sleep(1);
                }
                else{
                        sleep(1);
                        printf("Thread 2 has locked m1\n");
                        ++cnt;
                        printf("Thread 2 unlocks m1\n");
                        pthread_mutex_unlock(&m1);
                        sleep(1);
                        printf("Thread 1 unlocks m2\n");
                        pthread_mutex_unlock(&m2);
                        sleep(1);
                }
        }

        return NULL;
}
