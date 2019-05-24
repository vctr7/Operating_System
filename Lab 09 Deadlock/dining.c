#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <pthread.h>
#include <stdbool.h>
#include <errno.h>

#define NUM_PHILOSOPHERS 5

typedef struct philos{
	char *status;
	pthread_mutex_t *right, *left;
}Philosopher;

void philosopherSetup(Philosopher *philosopher, pthread_mutex_t *left, pthread_mutex_t *right){
	philosopher->left = left;
	philosopher->right = right;
}

void *philosopherRun(void *phil){
	Philosopher *philosopher = phil;
	while(true){
		philosopher->status = "thinking";
		sleep(rand()%5+1);
		philosopher->status = "hungry";
		if(rand()%2){
			pthread_mutex_lock(philosopher->left);
			sleep(1);
			pthread_mutex_lock(philosopher->right);
		}
		else{
			pthread_mutex_lock(philosopher->right);
			sleep(1);
			pthread_mutex_lock(philosopher->left);
		}
		philosopher->status = "eating";
		sleep(rand()%5+1);
		pthread_mutex_unlock(philosopher->left);
		pthread_mutex_unlock(philosopher->right);
	}
}


int main(int argc, char** argv){
	int number = NUM_PHILOSOPHERS;
	printf("Creating %d philosophers.\n", number);
	Philosopher philosophers[number];
	pthread_mutex_t chopstick[number];
	pthread_t threads[number];
	int i;

	for(i=0; i<number; i++){
		if(pthread_mutex_init(&chopstick[i], NULL)){
			fprintf(stderr, "Unable to create locks.\n");
			return (EXIT_FAILURE);
		}
	}
	for(i=0; i<number; i++){
		philosopherSetup(&philosophers[i], &chopstick[i], &chopstick[(i+1) % number]);
	}

	for(i=0; i<number; i++){
		pthread_create(&threads[number], NULL, philosopherRun, &philosophers[i]);
	}
	while(true){
		sleep(1);
		for(i=0; i<number; i++){
			usleep(1000);
			printf("%d : %s ", i, philosophers[i].status);
		}
		printf("\n");
	}
	return (EXIT_SUCCESS);
}
