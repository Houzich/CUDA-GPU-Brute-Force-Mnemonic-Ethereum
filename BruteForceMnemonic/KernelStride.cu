/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		29-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>
#include <stdio.h>
#include <stdint.h>


#include "KernelStride.hpp"
#include "Helper.h"
#include <GPU.h>
#include "../Tools/utils.h"


int KernelStrideClass::bruteforce_mnemonic(uint64_t grid, uint64_t block) {
	gl_bruteforce_mnemonic << <(uint32_t)grid, (uint32_t)block, 0, dt->stream1 >> > (dt->dev.entropy, dt->dev.dev_tables, dt->dev.ret);
	return 0;
}

int KernelStrideClass::bruteforce_mnemonic_for_save(uint64_t grid, uint64_t block) {
	gl_bruteforce_mnemonic_for_save << <(uint32_t)grid, (uint32_t)block, 0, dt->stream1 >> > (dt->dev.entropy, dt->dev.dev_tables, dt->dev.ret, dt->dev.hash160, dt->dev.save);
	return 0;
}

int KernelStrideClass::memsetGlobal()
{
	if (cudaMemcpyAsync(dt->dev.entropy, dt->host.entropy, dt->size_entropy_buf, cudaMemcpyHostToDevice, dt->stream1) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.entropy failed!"); return -1; }
	if (cudaMemsetAsync(dt->dev.ret, 0, sizeof(retStruct), dt->stream1) != cudaSuccess) { fprintf(stderr, "cudaMemset Board->dev.ret failed!"); return -1; }
	return 0;
}


int KernelStrideClass::cudaMallocDevice(uint8_t** point, uint64_t size, uint64_t* all_gpu_memory_size, std::string buff_name) {
	if (cudaMalloc(point, size) != cudaSuccess) {
		fprintf(stderr, "cudaMalloc (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return -1;
	}
	*all_gpu_memory_size += size;
	//if(size == 0)
	//	std::cout << "!!! WORNING !!! MALLOC GPU MEMORY SIZE (" << buff_name << "): 0.000000 MB\n";
	//else
	//	std::cout << "MALLOC GPU MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\r";
	return 0;
}

int KernelStrideClass::init()
{
	size_t memory_size = 0;
	for (int i = 0; i < 256; i++)
	{
		std::string name = "Table " + tools::byteToHexString(i);
		if (cudaMallocDevice((uint8_t**)&dt->dev.tables[i].table, dt->host.tables[i].size, &memory_size, name.c_str()) != 0)
		{
			std::cout << "Error cudaMallocDevice(), Board->dev.table[i]! i = " << i << std::endl;
			return -1;
		}
		dt->dev.tables[i].size = dt->host.tables[i].size;
		dt->dev.memory_size += dt->host.tables[i].size;
	}
	//std::cout << "MALLOC MEMORY SIZE (TABLES GPU): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";

	std::cout << "INIT GPU ... \n";
	for (int i = 0; i < 256; i++)
	{
		if (cudaMemcpy((void*)dt->dev.tables[i].table, dt->host.tables[i].table, dt->host.tables[i].size, cudaMemcpyHostToDevice) != cudaSuccess)
		{
			std::cout << "cudaMemcpy to Board->dev.table[i] failed! i = " << i << std::endl;
			return -1;
		}
		const size_t percentDone = (i * 100 / 256);
		std::cout << "  " << percentDone << "%\r";
	}
	if (cudaMemcpy(dt->dev.dev_tables, dt->dev.tables, 256 * sizeof(tableStruct), cudaMemcpyHostToDevice) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.table failed!"); return -1; }
	if (deviceSynchronize("init") != cudaSuccess) return -1;
	return 0;
}


int KernelStrideClass::start(uint64_t grid, uint64_t block)
{
	if (memsetGlobal() != 0) return -1;
	if (bruteforce_mnemonic(grid, block) != 0) return -1;

	return 0;
}

int KernelStrideClass::end()
{
	cudaError_t cudaStatus = cudaSuccess;
	if (deviceSynchronize("end") != cudaSuccess) return -1; //
	cudaStatus = cudaMemcpy(dt->host.ret, dt->dev.ret, sizeof(retStruct), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy ret failed!");
		return -1;
	}

	return 0;
}

int KernelStrideClass::start_for_save(uint64_t grid, uint64_t block)
{
	if (memsetGlobal() != 0) return -1;
	if (bruteforce_mnemonic_for_save(grid, block) != 0) return -1;

	return 0;
}

int KernelStrideClass::end_for_save()
{
	cudaError_t cudaStatus = cudaSuccess;


	if (deviceSynchronize("end_for_save") != cudaSuccess) return -1; //
	cudaStatus = cudaMemcpy(dt->host.save, dt->dev.save, dt->size_save_buf, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy save failed!");
		return -1;
	}
	cudaStatus = cudaMemcpy(dt->host.ret, dt->dev.ret, sizeof(retStruct), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy ret failed!");
		return -1;
	}

	return 0;
}