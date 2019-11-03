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

// substrIndexReversed checks if a needle is in a haystack and returns the index of the first matching character, -1 if there is no match
// it checks the string in reverse
int substrIndexReversed(char *haystack, char *needle, int haystackSize) {
	printf("totalHaystackLength = %d\n", haystackSize);

	for (int sizeOfTemp=1; sizeOfTemp <= haystackSize; sizeOfTemp++) {
		  // malloc a temporary string and copy values from the haystack in reverse
		char *tempHaystack = (char*)malloc(sizeOfTemp * sizeof(char));
		int haystackIndex;
		for(int j=0; j < sizeOfTemp; j++) {
			haystackIndex = haystackSize - sizeOfTemp + j;
			tempHaystack[j] = haystack[haystackIndex];
		}
		display(tempHaystack, sizeOfTemp);
		 // check if the needle is in the temp haystack, if so return it's index
		if (strstr(tempHaystack, needle) != NULL) {
			return haystackIndex;
		}
	}

	return -1;
}

int substrLastIdx(char *haystack, char *needle, int haystackSize) {
	char *src;
	char *dst;

	int itr = 1;
	while(itr < haystackSize) {
		src = (char*)malloc(itr * sizeof(char));
		memcpy(&src[0], &haystack[haystackSize - itr], itr * sizeof(char));
		display(src, itr);
		itr++;
	}
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
		while(substrIndexReversed(window, encode, window_size) != -1) {
			encode = (char*)realloc(encode, (++shift_size) * sizeof(char));
			memcpy(&encode[0], &text[encodeIdx], shift_size * sizeof(char));
		}
		shift_size--;
		//if shift_size == 0 -->no match
		if (shift_size == 0) shift_size++;

		// final char(s) to encode
		char *dst = (char*)malloc(shift_size * sizeof(char));
		memcpy(&dst[0], &text[encodeIdx], shift_size * sizeof(char));
		int subStringIndex =  substrIndexReversed(window, dst, window_size);
		printf("subStringIndex = %d\n", subStringIndex);

		 // Lookahead function
		// int buffer_size = 0;
		// char *lookaheadBuffer = (char*)malloc((++buffer_size) * sizeof(char));
		// while(/* lookahead possible - i.e I can add the next element to the lookahead buffer */) {
		// 	if(/* at the end of the string */) {
		// 		lookaheadBuffer = (char*)realloc(lookaheadBuffer, (++buffer_size) * sizeof(char));
		// 		memcpy(&lookaheadBuffer[0], &text[encodeIdx + shift_size], buffer_size * sizeof(char));
		// 	}


		// }
		// buffer_size--;

		// shift_size += buffer_size;

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
