#include "lz_ascii.h"

/*
A device function that writes bits by concatenating bits together
and writing in increments of bytes (the allowed way on a byte addressable processor)
*/
__device__ void write_bits(uint32_t* tmp, int bits, uint16_t code, int max_outsize_per_thread, int* out_len, int* o_bits, uint8_t* out, int segment_num, int fork) {
	//deciding which variable we are trying to concatenate
	if (fork == 0) {
		*tmp = (*tmp << bits) | code;
	}
	else if (fork == 1) {
		*tmp = (*tmp << bits) | M_CLR;
	}
	else if (fork == 2) {
		*tmp = (*tmp << bits) | M_EOD;
	}
	else if (fork == 3) {
		*tmp = (*tmp << bits) | *tmp;
	}
	*o_bits = *o_bits + bits;
	if (max_outsize_per_thread <= *out_len) {
		printf("\nEncoding using more momery than maximum size... Exiting\n");
		return;
	}
	//writing bytes
	while (*o_bits >= 8) {
		*o_bits = *o_bits - 8;
		out[(segment_num * max_outsize_per_thread) + *out_len] = *tmp >> *o_bits;
		*out_len = *out_len +1 ;
		*tmp = *tmp & ((1 << *o_bits) - 1);
	}
}

/****************Cuda Functions on GPU*************************/
/*
A GPU Kernel function that runs LZW compression algorithm in parallel
Inputs: 
	Input Array: which will be segmented into NUM_OF_THREADS segments and encodes each one independently
	Size of Input Array
	Threads per block

Outputs: 
	Encoded file: in one output array with with fragmentations in between segments
		 		  which will be resolved in the populate function
	Segments lengths: the length of each encoded segment to be used for clear the fragmentations
*/
__global__ void lz_encode_with_ascii_kernel(int threads_per_block, uint8_t* dev_in, int* segment_lengths, uint8_t* out, size_t size)
{
	//local dictionary per thread 
	uint16_t next_code = M_NEW;
	lzw_enc_t* dict = (lzw_enc_t*)malloc(512 * sizeof(lzw_enc_t));
	
	/*variables to allow for the segmentation of input and output arrays
	Basically, making each thread reads at a different segment of the input array
	and each thread write at a different segment of the output array 
	(to avoid synchronization which would make it sequential)
	The output array will have memory fragmentations which will be cleared in a the populate kernel
	*/
	int size_per_thread_const = (size + (NUM_OF_THREADS - 1)) / NUM_OF_THREADS;
	int size_per_thread_change = size_per_thread_const;
	int segment_num = (threadIdx.x + (blockIdx.x * threads_per_block));
	uint8_t* segment_input_ptr = &dev_in[segment_num * size_per_thread_const];
	
	//TODO: No need for syncthreads (look into all since no dependencies at all)
	__syncthreads();

	//number of bits used for a pattern
	//and size of dictionary (number of patters to store before having to reset dictionary)
	int bits = 9, next_shift = 512;
	uint16_t code, c, nc;

	int out_len = 0;
	int o_bits = 0;
	uint32_t tmp = 0;

	/*
	For loop to read the current letter and the one after, search if the pattern exists in the dictionary
	If not, add it. If it does, then take this pattern and add the next letter in the input array for a search of a new pattern
	*/
	for (code = *(segment_input_ptr++); --size_per_thread_change; ) {
		c = *(segment_input_ptr++);
		if (c == NULL) break;
		if ((nc = dict[code].next[c])) //if nc is not equal to 0 after assignment then enter if statment
			code = nc;
		else {
			write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 0);
			nc = dict[code].next[c] = next_code++;
			code = c;
		}
		
		__syncthreads();
		// when dictionary is full, reset table
		if (next_code == (next_shift-1)) {
			write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 1);

			bits = 9;
			next_shift = 512;
			next_code = M_NEW;  
			memset(dict, 0, sizeof(lzw_enc_t) * 512);
		}
	}

	//write last pattern
	write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 0);

	//write EOD at the end of each segment (for decoding purposes)
	//if (threadIdx.x == NUM_OF_THREADS-1) {
	write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 2);
	//}


	//write tmp (any leftovers i guess, not very important since won't be decoded anyways)
	if (tmp) {
		write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 3);
	}
	//length of segment, used for writing file
	segment_lengths[segment_num] = out_len;
	free(dict);
}

/*
Function to stitch the compressed segments together in one array without fragementations to write into a file
*/
__global__ void populate(int threads_per_block, size_t size, int* segment_lengths, uint8_t* out, uint8_t* encoded) {
	int segment_num = (threadIdx.x + (blockIdx.x * threads_per_block));
	int size_per_thread_const = (size + (NUM_OF_THREADS - 1)) / NUM_OF_THREADS;
	int writing_pos = 0;
	for (int z = 0; z < segment_num; z++) {
		writing_pos += segment_lengths[z];
	}
	memcpy(&encoded[writing_pos], &out[(segment_num * size_per_thread_const)], segment_lengths[segment_num]);
}

int main(int argc, char* argv[])
{
	char* inputFileName = nullptr;	
	char* outFileName = nullptr;
	int num_of_threads = 0;

	if (argc != 3 || argv[1] == NULL || argv[2] == NULL ||
		argv[1] == "-h" || argv[1] == "--help" || argv[1] == "--h") {
		cout << "lzAsc.exe <Name of Input File to Compress> < # threads to use>" << endl;
		return 0;
	}
	else {
		if (argv[1] != NULL) {
			inputFileName = argv[1];
		}
		if (argv[2] != NULL) {
			num_of_threads = stoi(argv[2]);
		}
	}

	outFileName = inputFileName+"_compressed";

	int i, fd = open(inputFileName, O_RDONLY);
	if (fd == -1) {
		fprintf(stderr, "Can't read file\n");
		return 1;
	};

	struct stat st;
	fstat(fd, &st);

	uint8_t* in = (uint8_t*)_new(unsigned char, st.st_size);
	read(fd, in, st.st_size);
	close(fd);

	printf("input size: %d\n", _len(in));

	lz_ascii_with_cuda(in, outFileName, num_of_threads);

	return 0;
}

cudaError_t lz_ascii_with_cuda(uint8_t* in, char* compressedFileName, int num_of_threads)
{
	//TODO: change NUM_OF_THREADS to num_of_threads and do necessary changes
	uint8_t* dev_in = 0;
	uint8_t* dev_final_out = 0;
	int* segment_lengths;
	uint8_t* encoded = 0;
	clock_t start_t, end_t;

	start_t = clock();
	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaError_t cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}

	//Mallocing and setting memory
	cudaStatus = cudaMallocManaged((void**)& dev_in, _len(in) * sizeof(uint8_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaMemcpy(dev_in, in, _len(in) * sizeof(uint8_t), cudaMemcpyKind::cudaMemcpyHostToDevice);

	cudaStatus = cudaMallocManaged((void**)& segment_lengths, (NUM_OF_THREADS) * sizeof(int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}
	//TODO: try cudaMemset cleaner
	//cudaMemset(segment_lengths, 0, (NUM_OF_THREADS + 1)*sizeof(int));
	for (int i = 0; i < NUM_OF_THREADS; i++) {
		segment_lengths[i] = 0;
	}

	cudaStatus = cudaMallocManaged((void**)& dev_final_out, _len(in) * sizeof(uint8_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaMemset(dev_final_out, 0, _len(in));

	int numBlocks = 1;
	int threadsPerBlock = 1;
	if (NUM_OF_THREADS != 1) {
		numBlocks = ((NUM_OF_THREADS + (MAX_NUMBER_THREADS_PER_BLOCK - 1)) / MAX_NUMBER_THREADS_PER_BLOCK) + 1;
		threadsPerBlock = ((NUM_OF_THREADS + (numBlocks - 1)) / numBlocks);
	}
	/*************************************** Parrallel Part of Execution **********************************************/
	lz_encode_with_ascii_kernel << <numBlocks, threadsPerBlock >> > (threadsPerBlock, dev_in, segment_lengths, dev_final_out, _len(in));
	/*****************************************************************************************************************/
	//printf("-- Number of Threads: %d -- Execution Time (ms): %g \n", numOfThreads, gpuTimer.Elapsed());
	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "returned error code %d after launching !\n", cudaStatus);
		goto Error;
	}

	//finding size of final compressed output file
	int sum = 0;
	for (int z = 0; z < NUM_OF_THREADS; z++) {
		sum += segment_lengths[z];
	}
	cudaStatus = cudaMallocManaged((void**)& encoded, sum * sizeof(uint8_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	/*************************************** Parrallel Part of Execution **********************************************/
	populate << <numBlocks, threadsPerBlock >> > (threadsPerBlock, _len(in), segment_lengths, dev_final_out, encoded);
	/*****************************************************************************************************************/

	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch. 
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "returned error code %d after launching !\n", cudaStatus);
		goto Error;
	} 
	
	end_t = clock();
	printf("\n time taken: %d \n",((end_t - start_t)));

	FILE* encodedFile = fopen(compressedFileName, "wb");
	printf("%d \n %d", sum, segment_lengths[NUM_OF_THREADS - 1]);
	//to write the last compressed segment only or any segment of choice
	int writing_pos = 0;
	for (int z = 0; z < NUM_OF_THREADS-1; z++) {
		writing_pos += segment_lengths[z];
	}
	fwrite(&encoded[writing_pos], segment_lengths[NUM_OF_THREADS - 1], 1, encodedFile);

Error:
	// BE FREE MY LOVLIES
	cudaFree(dev_in);
	cudaFree(dev_final_out);
	cudaFree(segment_lengths);
	cudaFree(encoded);
	
	return cudaStatus;
}