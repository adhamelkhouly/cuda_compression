//#include "cuda_runtime.h"
//#include "device_launch_parameters.h"
//
//#include <stdlib.h>
//#include <stdio.h>
//#include <iostream>
//#include <string>
//#include <map>
//
//using namespace std;
//
///*************************Global*************************/
//#define MAX_NUMBER_THREADS_PER_BLOCK 1024
//unsigned char inputArray[124] = "aslknbafbsldiodfnsklafaios;asfn;fnb;so;anfsjnuisanfkjsanfslfuibalsfjsbflhabsufgieljkab;sohgsknsajbflasjfbaoiuebqwlibasfsfaa";
//
//
///****************Function Declarations*************************/
//cudaError_t lz_ascii_with_cuda(int numOfThreads, int inputFileSize, unsigned char* inputFilePtr);
//
//
///****************Cuda Functions on GPU*************************/
//__global__ void lz_with_ascii_dict_kernel(int numOfThreads, int inputFileSize, unsigned char* inputArray)
//{
//	//for (int i = 0; i < inputFileSize / numOfThreads; i++) {
//	//	int j = (threadIdx.x + numOfThreads * i) + (blockIdx.x * numOfThreads);
//	//	outputToGPUArray[j] = inputFromCPUArray[j];
//	//	printf("%c", outputToGPUArray[j]);
//	//}
//}
//
//__global__ void helllo(void* mapl) {
//	__shared__ map<string, int>* maptest;
//	maptest->at("a");
//}
//
//int main(int argc, char* argv[])
//{
//	//char * fileOutDir = "./";
//	int inputFileSize = 124;	
//	int numOfThreads = 6;
//
//	lz_ascii_with_cuda(numOfThreads, inputFileSize, inputArray);
//
//	return 0;
//}
//
//cudaError_t lz_ascii_with_cuda(int numOfThreads, int inputFileSize, unsigned char* inputFilePtr)
//{
//	unsigned char* dev_fileArray = nullptr;
//	void* dev_dictGPU = nullptr;
//
//	int initialDictSize = 256;
//	int maxDictSize = 1024;
//	map<string, int> dictionary;
//
//	for (int i = 0; i < initialDictSize; i++) {
//		dictionary[string(1, i)] = i;
// 	}
//
//	// Choose which GPU to run on, change this on a multi-GPU system.
//	cudaError_t cudaStatus = cudaSetDevice(0);
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
//		goto Error;
//	}
//
//	cudaStatus = cudaMallocManaged((void**)& dev_fileArray, inputFileSize * sizeof(unsigned char));
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "cudaMalloc failed!");
//		goto Error;
//	}
//
//	cudaStatus = cudaMallocManaged((void**)& dev_dictGPU, maxDictSize * 10); //10 bits to represent 1024 keys in the map
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "cudaMalloc failed!");
//		goto Error;
//	}
//
//	memcpy(dev_fileArray, inputFilePtr, inputFileSize);
//
//
//	helllo <<<1,1>>>(dev_dictGPU);
//	
//	// Compress a string to a list of output symbols.
//	// The result will be written to the output iterator
//	// starting at "result"; the final iterator is returned.
//	
//
//
//	//	std::string w;
//	//	for (std::string::const_iterator it = uncompressed.begin();
//	//		it != uncompressed.end(); ++it) {
//	//		char c = *it;
//	//		std::string wc = w + c;
//	//		if (dictionary.count(wc))
//	//			w = wc;
//	//		else {
//	//			*result++ = dictionary[w];
//	//			// Add wc to the dictionary.
//	//			dictionary[wc] = dictSize++;
//	//			w = std::string(1, c);
//	//		}
//	//	}
//
//	//	// Output the code for w.
//	//	if (!w.empty())
//	//		* result++ = dictionary[w];
//	//	return result;
//	//}
//
//	int numBlocks = ((numOfThreads + (MAX_NUMBER_THREADS_PER_BLOCK - 1)) / MAX_NUMBER_THREADS_PER_BLOCK);
//	int threadsPerBlock = ((numOfThreads + (numBlocks - 1)) / numBlocks);
//	/*************************************** Parrallel Part of Execution **********************************************/
//	//gpuTimer.Start();
//	lz_with_ascii_dict_kernel << <numBlocks, threadsPerBlock >> > (numOfThreads, inputFileSize, dev_fileArray);
//	//gpuTimer.Stop();
//	/*****************************************************************************************************************/
//	//printf("-- Number of Threads: %d -- Execution Time (ms): %g \n", numOfThreads, gpuTimer.Elapsed());
//
//	// Check for any errors launching the kernel
//	cudaStatus = cudaGetLastError();
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "convolutionKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
//		goto Error;
//	}
//
//	// cudaDeviceSynchronize waits for the kernel to finish, and returns
//	// any errors encountered during the launch.
//	cudaStatus = cudaDeviceSynchronize();
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching convolutionKernel!\n", cudaStatus);
//		goto Error;
//	}
//
//Error:
//	// BE FREE MY LOVLIES
//	cudaFree(dev_fileArray);
//
//	return cudaStatus;
//}