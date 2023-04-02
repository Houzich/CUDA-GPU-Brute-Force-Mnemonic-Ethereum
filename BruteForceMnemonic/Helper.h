/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.0.0
  * @date		2-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */

#pragma once
#include <stdint.h>
#include <string>
#include <iostream>
#include <chrono>
#include <thread>
#include <fstream>
#include <string>
#include <memory>
#include <sstream>
#include <iomanip>
#include <vector>
#include <map>
#include <omp.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "stdafx.h"
#include "../Tools/utils.h"



class host_buffers_class
{
public:
	tableStruct tables[256] = { NULL };

	uint64_t* entropy = NULL;
	uint8_t* save = NULL;
	retStruct* ret = NULL;
	uint64_t memory_size = 0;
public:
	host_buffers_class()
	{
	}

	int alignedMalloc(void** point, uint64_t size, uint64_t* all_ram_memory_size, std::string buff_name) {
		*point = _aligned_malloc(size, 4096);
		if (NULL == *point) { fprintf(stderr, "_aligned_malloc (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return 1; }
		*all_ram_memory_size += size;
		//std::cout << "MALLOC RAM MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	int mallocHost(void** point, uint64_t size, uint64_t* all_ram_memory_size, std::string buff_name) {
		if (cudaMallocHost((void**)point, size) != cudaSuccess) {
			fprintf(stderr, "cudaMallocHost (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return -1;
		}
		*all_ram_memory_size += size;
		//std::cout << "MALLOC RAM MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	int malloc(size_t size_entropy_buf, size_t size_save_buf)
	{
		memory_size = 0;
		if (mallocHost((void**)&entropy, size_entropy_buf, &memory_size, "entropy") != 0) return -1;
		if (alignedMalloc((void**)&save, size_save_buf, &memory_size, "save") != 0) return -1;
		if (mallocHost((void**)&ret, sizeof(retStruct), &memory_size, "ret") != 0) return -1;
		std::cout << "MALLOC ALL RAM MEMORY SIZE (HOST): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	void freeTableBuffers(void) {
		for (int x = 0; x < 256; x++) {
			if (tables[x].table != NULL)
			{
				free(tables[x].table);
				tables[x].table = NULL;
			}			
		}	
	}

	~host_buffers_class()
	{
		freeTableBuffers();
		cudaFreeHost(entropy);
		cudaFreeHost(ret);
		//for CPU
		_aligned_free(save);

	}

};

class device_buffers_class
{
public:
	tableStruct tables[256] = { NULL };
	tableStruct* dev_tables;

	uint64_t* entropy = NULL;
	uint8_t* save = NULL;

	retStruct* ret = NULL;

	uint64_t memory_size = 0;
public:
	device_buffers_class()
	{
	}

	int cudaMallocDevice(uint8_t** point, uint64_t size, uint64_t* all_gpu_memory_size, std::string buff_name) {
		if (cudaMalloc(point, size) != cudaSuccess) {
			fprintf(stderr, "cudaMalloc (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return -1;
		}
		*all_gpu_memory_size += size;
		//std::cout << "MALLOC GPU MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	int malloc(size_t size_entropy_buf, size_t size_save_buf)
	{
		memory_size = 0;	
		if (cudaMallocDevice((uint8_t**)&entropy, size_entropy_buf, &memory_size, "entropy") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&save, size_save_buf, &memory_size, "save") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&dev_tables, sizeof(tableStruct) * 256, &memory_size, "dev_tables") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&ret, sizeof(retStruct), &memory_size, "ret") != 0) return -1;

		std::cout << "MALLOC ALL MEMORY SIZE (GPU): " << std::to_string((float)(memory_size) / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}

	void freeTableBuffers(void) {
		for (int x = 0; x < 256; x++) {
			if (tables[x].table != NULL)
				cudaFree((void *)tables[x].table);
		}
		cudaFree(dev_tables);
	}

	~device_buffers_class()
	{
		freeTableBuffers();
		cudaFree(entropy);
		cudaFree(save);
		cudaFree(dev_tables);
		cudaFree(ret);
	}
};


class DataClass
{
public:
	device_buffers_class dev;
	host_buffers_class host;

	cudaStream_t stream1 = NULL;
	size_t size_entropy_buf = 0;
	size_t size_save_buf = 0;
	size_t wallets_in_round_gpu = 0;
public:
	DataClass()
	{

	}

	int malloc(size_t cuda_grid, size_t cuda_block, bool alloc_buff_for_save)
	{
		size_t num_wallet = cuda_grid * cuda_block;
		size_t size_entropy_buf = SIZE_ENTROPY_FRAME;
		size_t size_save_buf = SIZE_SAVE_FRAME * num_wallet;
		if (!alloc_buff_for_save)
		{
			size_save_buf = 0;
		}


		if (cudaStreamCreate(&stream1) != cudaSuccess) { fprintf(stderr, "cudaStreamCreate failed!  stream1"); return -1; }
		if (dev.malloc(size_entropy_buf, size_save_buf) != 0) return -1;
		if (host.malloc(size_entropy_buf, size_save_buf) != 0) return -1;
		this->size_entropy_buf = size_entropy_buf;
		this->size_save_buf = size_save_buf;
		this->wallets_in_round_gpu = num_wallet;
		return 0;
	}
	~DataClass()
	{
		cudaStreamDestroy(stream1);
	}
};


cudaError_t deviceSynchronize(std::string name_kernel);
void devicesInfo(void);

