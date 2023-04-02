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
#include <string>



struct ConfigClass
{
public:
	std::string folder_database = "F:\\database";
	std::string folder_save_result = "F:\\result";
	uint64_t lines_in_file_save = 18;
	uint64_t cuda_grid = 0;
	uint64_t cuda_block = 0;
public:
	ConfigClass()
	{
	}
	~ConfigClass()
	{
	}
};


int parse_config(ConfigClass* config, std::string path);

