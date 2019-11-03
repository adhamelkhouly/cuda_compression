#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <string>

using namespace std;

__global__ void test()
{
	//test
	printf("test gd");
}
int main(int argc, char* argv[])
{
	/*if (argc != 6 || argv[1] == NULL || argv[2] == NULL || argv[3] == NULL || argv[4] == NULL ||
		argv[1] == "-h" || argv[1] == "--help" || argv[1] == "--h") {
		cout << "Assignment1.exe <Command> <name of input png> <name of output png> < # threads>" << endl;
		return 0;
	}
	else {
		if (argv[2] != NULL) {
			inputImgName = argv[2];
		}
		if (argv[3] != NULL) {
			outImgName = argv[3];
		}
		if (argv[4] != NULL) {
			numOfThreads = stoi(argv[4]);
		}
	}*/

	/*if (argv[1] != NULL && !strcmp(argv[1], "rectify")) {
		cout << "Rectifing" << endl;
		cudaError_t status = imageRectificationWithCuda(numOfThreads, inputImgName, outImgName);
	}

	if (argv[1] != NULL && !strcmp(argv[1], "pool")) {
		cout << "Pooling" << endl;
		cudaError_t status = imagePoolingWithCuda(numOfThreads, inputImgName, outImgName);
	}*/

	imageConvolutionWithCuda(numOfThreads, weightMatDim, inputImgName, outImgName);

	std::cout << "Name of Input Image File: " << inputImgName << std::endl;
	std::cout << "Name of Output Image File: " << outImgName << std::endl;
	std::cout << "Number of Threads: " << numOfThreads << std::endl;

	return 0;
}

cudaError_t imageConvolutionWithCuda(int numOfThreads, int weightBoxDim, char* inputImageName, char* outputImageName) {
	cudaError_t cudaStatus = cudaError_t::cudaErrorDeviceUninitilialized;
	//GpuTimer gpuTimer; // Struct for timing the GPU
	unsigned char* inputImage = nullptr;
	unsigned width, height = 0;

	int error = lodepng_decode32_file(&inputImage, &width, &height, inputImageName);
	if (error != 0) {
		cout << "Failed to decode the image" << endl;
		cudaStatus = cudaError_t::cudaErrorAssert;
		goto Error;
	}

	int sizeOfArray = width * height * 4;
	int sizeOfOutputArray = (width - (weightBoxDim - 1)) * (height - (weightBoxDim - 1)) * 4;

	unsigned char* dev_RGBAArray, * dev_RArray, * dev_GArray, * dev_BArray, * dev_AArray, * dev_outArray;
	float* dev_outRArray, * dev_outGArray, * dev_outBArray, * dev_outAArray, * dev_wMs;

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}

	cudaStatus = cudaMallocManaged((void**)& dev_RGBAArray, sizeOfArray * sizeof(unsigned char));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	for (int i = 0; i < sizeOfArray; i++) {
		dev_RGBAArray[i] = inputImage[i];
	}

	// To make our life easier, we're going to split the RGBA values into separate arrays - let's start by mallocing them
	cudaStatus = cudaMallocManaged((void**)& dev_RArray, (sizeOfArray / 4) * sizeof(unsigned char));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	int numBlocks = ((numOfThreads + (MAX_NUMBER_THREADS - 1)) / MAX_NUMBER_THREADS);
	int threadsPerBlock = ((numOfThreads + (numBlocks - 1)) / numBlocks);
	/*************************************** Parrallel Part of Execution **********************************************/
	//gpuTimer.Start();
	test << <numBlocks, threadsPerBlock >> > ();
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
	cudaFree(dev_RGBAArray);

	return cudaStatus;
}
