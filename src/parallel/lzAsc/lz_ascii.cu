#include "lz_ascii.h"

using namespace std;

/****************Cuda Functions on GPU*************************/
__global__ void lz_encode_with_ascii_kernel(int num_of_threads, int threads_per_block, uint8_t* dev_in, uint8_t* out[], lzw_enc_t* dict, size_t size, int max_bits)
{
	int size_per_thread = size / num_of_threads;
	int segment_num = size_per_thread * (threadIdx.x + (blockIdx.x * threads_per_block));
	
	uint8_t* segment_input_ptr = &dev_in[segment_num];

	int bits = 9, next_shift = 512;
	uint16_t code, c, nc, next_code = M_NEW;
	size_t out_segment_size = sizeof(size_t) * 2 + 4 * sizeof(uint16_t);

	if (max_bits > 15) max_bits = 15;
	if (max_bits < 9) max_bits = 12;

	//size_t* y = new uint16_t[]

	size_t* y = (size_t*)malloc(sizeof(size_t) * 2 + 4 * sizeof(uint16_t));
	y[0] = sizeof(uint16_t);
	y[1] = 4;
	out[segment_num] = (uint8_t*)(y + 2);

	//out[segment_num] = (uint8_t*)gpu_mem_alloc(sizeof(uint16_t), 4);
	int out_len = 0, o_bits = 0;
	uint32_t tmp = 0;

	for (code = *(segment_input_ptr++); --size_per_thread; ) {
		c = *(segment_input_ptr++);
		if ((nc = dict[code].next[c])) //if nc is not equal to 0 after assignment then enter if statment
			code = nc;
		else {
			///
			tmp = (tmp << bits) | code; //shifting tmp 9 bits to the left (multiplying 2^9) then or with code (an ascii variable or new added one e.x code of 'ab')
			o_bits += bits;
			if (_len(out[segment_num]) <= out_len) {
				size_t new_n = _len(out[segment_num]) * 2;
				size_t* z = (size_t*)(out[segment_num] - 2); //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
				cudaError_t cudaStatus = cudaMalloc((void**)& z, sizeof(size_t) * 2 + *z * new_n); //
				if (new_n > z[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
					memset((char*)(z + 2) + z[0] * z[1], 0, z[0] * (new_n - z[1]));
				z[1] = new_n;
				out[segment_num] = (uint8_t*)(z + 2);

				//out[segment_num] = (uint8_t*)gpu_mem_extend(out[segment_num], _len(out[segment_num]) * 2); //extend by doubling size
			}
			while (o_bits >= 8) { 	//checks for how many bytes it can write out of the bits given
				o_bits -= 8;

				//shifting o_bits to the right, shifting to the right means dividing by 2^(o_bits)
				//eleminating the leftover bits on the right to write one byte to the ouput
				out[segment_num][out_len++] = tmp >> o_bits;
				//printf("%i" , out[segment_num][out_len-1]);

				//shift 1 to the left by o_bits, basically multiplying 1 by 2^(o_bits) ... then mask this value-1 on tmp
				//saving the leftover bits on the right from the previous line for the next iteration
				//e.x 1110 1110 11, tmp will be the 11 at the right
				tmp &= (1 << o_bits) - 1;
			}
			///
			nc = dict[code].next[c] = next_code++;
			code = c;
		}
	}
}

//__global__ void* gpu_mem_alloc(size_t item_type, size_t n_item) {
//	size_t* x = nullptr;
//	cudaError_t cudaStatus = cudaMalloc((void**)& x, sizeof(size_t) * 2 + n_item * sizeof(item_type));
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "cudaMalloc failed!");
//		return;
//	}
//	x[0] = sizeof(item_type);
//	x[1] = n_item;
//	return x+2;
//}
//
//__global__ void* gpu_mem_extend(void* m, size_t new_n)
//{
//	size_t* x = (size_t*)m - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
//	cudaError_t cudaStatus = cudaMalloc((void**)& x, sizeof(size_t) * 2 + *x * new_n); //
//	if (new_n > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
//		cudaMemset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (new_n - x[1]));
//	x[1] = new_n;
//	return x + 2;
//}

/*******************Helper Functions***************************/
//Pass in item_size in bytes and how many items to allocate on the heap
void* pc_heap_mem_alloc(size_t item_size, size_t n_item)
{
	size_t* x = (size_t*)calloc(1, sizeof(size_t) * 2 + n_item * item_size);
	x[0] = item_size; //in bytes
	x[1] = n_item;
	return x + 2; //return pointer starting at data
}

void* pc_heap_mem_extend(void* m, size_t new_n)
{
	size_t* x = (size_t*)m - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
	x = (size_t*)realloc(x, sizeof(size_t) * 2 + *x * new_n); //
	if (new_n > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
		memset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (new_n - x[1]));
	x[1] = new_n;
	return x + 2;
}

inline void _clear(void* m)
{
	size_t* x = (size_t*)m - 2;
	memset(m, 0, x[0] * x[1]);
}
/************************************************************/

int main(int argc, char* argv[])
{
	int i, fd = open("test.txt", O_RDONLY);
	if (fd == -1) {
		fprintf(stderr, "Can't read file\n");
		return 1;
	};

	struct stat st;
	fstat(fd, &st);

	uint8_t* in = (uint8_t*)_new(unsigned char, st.st_size);
	read(fd, in, st.st_size);
	//_setsize(in, st.st_size);
	close(fd);

	printf("input size:   %d\n", _len(in));

	lz_ascii_with_cuda(in, NUM_OF_THREADS);

	return 0;
}

cudaError_t lz_ascii_with_cuda(uint8_t* in, int numOfThreads)
{
	uint8_t* dev_in = 0;
	uint8_t* dev_final_out[] = { 0 };
	size_t* x = 0;

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaError_t cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}

	cudaStatus = cudaMallocManaged((void**)& dev_in, _len(in) * sizeof(unsigned char));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaMemcpy(dev_in, in, _len(in) * sizeof(unsigned char), cudaMemcpyKind::cudaMemcpyHostToDevice);

	cudaStatus = cudaMallocManaged((void**)& dev_final_out, NUM_OF_THREADS * sizeof(unsigned char));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMallocManaged((void**)& x, sizeof(size_t) * 2 + 512 * sizeof(lzw_enc_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	x[0] = sizeof(lzw_enc_t);
	x[1] = 512;
	
	lzw_enc_t* dict = (lzw_enc_t*)(x+2);

	//size_t heapsize = sizeof(int) * size_t(20000) * size_t(2 * 10000);
	//cudaDeviceSetLimit(cudaLimitMallocHeapSize, heapsize);

	int numBlocks = ((NUM_OF_THREADS + (MAX_NUMBER_THREADS_PER_BLOCK - 1)) / MAX_NUMBER_THREADS_PER_BLOCK);
	int threadsPerBlock = ((NUM_OF_THREADS + (numBlocks - 1)) / numBlocks);
	/*************************************** Parrallel Part of Execution **********************************************/
	//gpuTimer.Start();
	lz_encode_with_ascii_kernel << <numBlocks, threadsPerBlock >> > (numOfThreads, threadsPerBlock, dev_in, dev_final_out, dict, _len(in), 9);
	//gpuTimer.Stop();
	/*****************************************************************************************************************/
	//printf("-- Number of Threads: %d -- Execution Time (ms): %g \n", numOfThreads, gpuTimer.Elapsed());

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "convolutionKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching convolutionKernel!\n", cudaStatus);
		goto Error;
	}

Error:
	// BE FREE MY LOVLIES
	cudaFree(dev_in);
	cudaFree(dev_final_out);

	return cudaStatus;
}