/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.0.0
  * @date		2-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */


#include <stdafx.h>

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



#include "Dispatcher.h"
#include "GPU.h"
#include "KernelStride.hpp"
#include "Helper.h"


#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "../config/Config.hpp"


class SaveClass {
	uint32_t _num_file;

public:
	DataClass *dt;
	ConfigClass *cfg;
	size_t count_line;
	std::string file_path;
public:
	SaveClass(DataClass *data, ConfigClass *config)
	{
		dt = data;
		cfg = config;
		count_line = 0;
		setNumFile(0);
	}

public:
	void setFilePath(uint32_t num)
	{
		std::ostringstream ostr;
		ostr << std::setfill('0') << std::setw(4) << num;
		file_path = cfg->folder_save_result + "\\" + ostr.str() + ".csv";
	}
	void setNumFile(uint32_t num)
	{
		_num_file = num;
		setFilePath(num);
	}
	uint32_t getNumFile() {
		return _num_file;
	}
	void incNumFile()
	{
		_num_file++;
		setFilePath(_num_file);
	}
};

void clearFiles(SaveClass* sv) {
	std::ofstream out;
	uint32_t num = sv->getNumFile();
	for (int i = 0; i < 100; i++)
	{
		sv->setNumFile(i);
		out.open(sv->file_path);
		out.close();
	}
	sv->setNumFile(num);
}



void saveResult(SaveClass* sv) {
	std::ofstream out;
	if (sv->count_line + sv->dt->wallets_in_round_gpu > sv->cfg->lines_in_file_save) {
		size_t cnt_line = 0;
		size_t remaining_lines = sv->dt->wallets_in_round_gpu;
		size_t lines = sv->cfg->lines_in_file_save - sv->count_line;
		while (remaining_lines != 0) {
			out.open(sv->file_path, std::ios::app);
			out.write((char*)sv->dt->host.save + cnt_line * SIZE_SAVE_FRAME, lines * SIZE_SAVE_FRAME);
			out.close();
			cnt_line += lines;
			remaining_lines -= lines;
			if(remaining_lines) sv->incNumFile();
			sv->count_line = lines;
			if (remaining_lines > sv->cfg->lines_in_file_save) lines = sv->cfg->lines_in_file_save;
			else lines = remaining_lines;
		}
	}
	else
	{
		out.open(sv->file_path, std::ios::app);
		out.write((char*)sv->dt->host.save, sv->dt->size_save_buf);
		out.close();
		sv->count_line += sv->dt->wallets_in_round_gpu;
	}
	if (sv->count_line >= sv->cfg->lines_in_file_save)
	{
		sv->count_line = sv->count_line - sv->cfg->lines_in_file_save;
		sv->incNumFile();
	}
}

static std::thread save_thread;

int Generate_Mnemonic(void)
{
	cudaError_t cudaStatus = cudaSuccess;
	ConfigClass Config;
	try {
		parse_config(&Config, "config.cfg");
	}
	catch (...) {
		for (;;)
			std::this_thread::sleep_for(std::chrono::seconds(30));
	}

	devicesInfo();
	// Choose which GPU to run on, change this on a multi-GPU system.
	uint32_t num_device = 0;
#ifndef TEST_MODE
	std::cout << "\n\nEnter number of device: ";
	std::cin >> num_device;
#endif //GENERATE_INFINITY
	cudaStatus = cudaSetDevice(num_device);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		return -1;
	}

	size_t num_wallets_gpu = Config.cuda_grid * Config.cuda_block;
	//18,446,744,073,709,551,615
	size_t number_of_addresses = 0;
	size_t count_save_data_in_file = 0;
	int num_bytes = 0;

	std::cout << "\nNUM WALLETS IN ROUND GPU: " << tools::formatWithCommas(num_wallets_gpu) << std::endl << std::endl;
#ifndef TEST_MODE
	std::cout << "Max value: 18,000,000,000,000,000,000 (18000000000000000000)" << std::endl;
	std::cout << "Enter number of generate mnemonic: ";
	std::cin >> number_of_addresses;
	std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
	number_of_addresses = (((number_of_addresses - 1) / (num_wallets_gpu)+1) * (num_wallets_gpu));

	std::string answer = "";
	while ((answer != "Y") && (answer != "y") && (answer != "N") && (answer != "n"))
	{
		answer = "";
		std::cout << "Save data in files? [Y/n] : ";
		std::getline(std::cin, answer);
		//std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
	}
	if (answer == "Y" || answer == "y")
	{
		count_save_data_in_file = 0xFFFFFFFFFFFFFFFF;
	}


	std::cout << "Enter num bytes for check 6...8: ";
	std::cin >> num_bytes;
	if (num_bytes != 0)
		if ((num_bytes < 6) || (num_bytes > 8)) {
			std::cout << "Error num bytes. Won't be used!" << std::endl;
			num_bytes = 0;
		}


#else
	number_of_addresses = num_wallets_gpu*15;
	num_bytes = 6;
	count_save_data_in_file = 15;
#endif //TEST_MODE

	DataClass* Data = new DataClass();
	KernelStrideClass* Stride = new KernelStrideClass(Data);
	SaveClass* Save = new SaveClass(Data, &Config);
	std::cout << "READ TABLES! WAIT..." << std::endl;
	clearFiles(Save);
	int err = tools::readAllTables(Data->host.tables, Config.folder_database, "");
	if (err == -1) {
		std::cout << "Error readAllTables!" << std::endl;
		goto Error;
	}


	if (Data->malloc(Config.cuda_grid, Config.cuda_block, count_save_data_in_file == 0 ? false : true) != 0) {
		std::cout << "Error Data->Malloc()!" << std::endl;
		goto Error;
	}

	if (Stride->init() != 0) {
		printf("Error INIT!!\n");
		goto Error;
	}

	Data->host.freeTableBuffers();

	std::cout << "START GENERATE ADDRESSES!" << std::endl;
	std::cout << "PATH: m/44'/60'/0'/0/0.." << (NUM_CHILDS - 1) << ", m/44'/60'/0'/1/0.." << (NUM_CHILDS - 1) << std::endl;
	std::cout << "\nGENERATE " << tools::formatWithCommas(number_of_addresses) << " MNEMONICS. " << tools::formatWithCommas(number_of_addresses * NUM_ALL_CHILDS) << " ADDRESSES. MNEMONICS IN ROUNDS " << tools::formatWithCommas(Data->wallets_in_round_gpu) << ". WAIT...\n\n";

	tools::generateRandomUint64Buffer(Data->host.entropy, Data->size_entropy_buf / (sizeof(uint64_t)));

	if (cudaMemcpyToSymbol(num_bytes_find, &num_bytes, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		fprintf(stderr, "cudaMemcpyToSymbol to num_bytes_find failed!");
		goto Error;
	}


	static int start_save = 0;
	for (size_t step = 0; step < number_of_addresses / (Data->wallets_in_round_gpu); step++)
	{
		tools::start_time();
		if (start_save < count_save_data_in_file) {
			if (Stride->start_for_save(Config.cuda_grid, Config.cuda_block) != 0) {
				printf("Error START!!\n");
				goto Error;
			}
		}
		else
		{
			if (Stride->start(Config.cuda_grid, Config.cuda_block) != 0) {
				printf("Error START!!\n");
				goto Error;
			}
		}

		tools::generateRandomUint64Buffer(Data->host.entropy, Data->size_entropy_buf / (sizeof(uint64_t)));

		if (save_thread.joinable()) save_thread.join();

		if (start_save < count_save_data_in_file) {
			if (Stride->end_for_save() != 0) {
				printf("Error END!!\n");
				goto Error;
			}
		}
		else
		{
			if (Stride->end() != 0) {
				printf("Error END!!\n");
				goto Error;
			}
		}

		if (start_save < count_save_data_in_file) {
			start_save++;
			save_thread = std::thread(&saveResult, Save);
		}

		tools::checkResult(Data->host.ret);

		float delay;
		tools::stop_time_and_calc(&delay);
		std::cout << "\rSPEED: " << std::setw(8) << std::fixed << tools::formatWithCommas((float)Data->wallets_in_round_gpu / (delay / 1000.0f)) << " MNEMONICS/SECOND AND "
			<< tools::formatWithCommas(((float)Data->wallets_in_round_gpu * NUM_ALL_CHILDS) / (delay / 1000.0f)) << " ADDRESSES/SECOND, ROUND: " << step;
	}

	std::cout << "\n\nEND!" << std::endl;
	if (save_thread.joinable()) save_thread.join();

	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return 0;
Error:
	std::cout << "\n\nERROR!" << std::endl;
	if (save_thread.joinable()) save_thread.join();

	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return -1;
}







