/*
LZ77 Compression Algorithm - CUDA
*/

#include <stdio.h>
#include <stdlib.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

__global__ void LZ77() {

}

void start_LZ77() {

}

void display(char *input, int size) {
	for(int i = 0; i < size; i++) {
		printf("%c", input[i]);
	}
	printf("\n");
}

// checks if target is substring of {src[l], ..., src[r]}
int substr(char *haystack, char *needle) {
	if(strstr(haystack, needle) != NULL) {
		return 1;
	}
	return 0;
}

// TODO: in-place
void encode(char *text, int size, int window_size) {
	// window is the <window_size> chars starting at shift_size
	char window[window_size];
	memcpy(window, &text[0], window_size);
	printf("window: \n");
	display(window, window_size);

	// next set of elements start from window_size
	int encodeIdx = window_size;
	int windowIdx = 0;

	char *encode;
	while(encodeIdx < size) {
		// start with one char
		int shift_size = 0;

		// next set of elements to encode
		encode = (char*)malloc((++shift_size) * sizeof(char));
		memcpy(&encode[0], &text[encodeIdx], shift_size * sizeof(char));
		while(substr(window, encode)) {
			encode = (char*)realloc(encode, (++shift_size) * sizeof(char));
			memcpy(&encode[0], &text[encodeIdx], shift_size * sizeof(char));
		}
		shift_size--;
		//look-ahead shit
		if (shift_size == 0) shift_size++;
		printf("encode: \n");
		display(encode, shift_size);
		
		//shift window by shift_size
		windowIdx += shift_size;
		if(windowIdx >= size) {
			printf("here\n");
			break;
		}
		printf("encodeIdx = %d\n", encodeIdx);
		printf("shift_size = %d\n", shift_size);

		printf("window: \n");
		memcpy(window, &text[windowIdx], window_size);
		display(window, window_size);

		encodeIdx += shift_size;
	}
	free(encode);
}

void decode() {

}

int main() {
	// char* input_fname = argv[1];
	// char* output_fname = argv[2];
	// int thread_count = atoi(argv[3]);

	int size = 20;
	// int split = 2;
	// int s_size = size / split;

	char text[size] = "AAABABBABAAAAABABBAC";
	printf("original text: \n");
	display(text, size);
	encode(text, size, 4);

	// char *t1, *t2; //AAABABBABA && AAAABABBA

	// cudaMallocManaged((void**)& t1, s_size * sizeof(char));
	// cudaMallocManaged((void**)& t2, s_size * sizeof(char));

	// memcpy( &t1[0], &text[0], s_size * sizeof( char ) );
	// memcpy( &t2[0], &text[10], s_size * sizeof( char ) );
	// display(t1, 10);
	// display(t2, 10);

	return 0;
}