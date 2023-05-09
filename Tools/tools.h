/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		29-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#pragma once
#include <vector>
#include <string>
#include "../BruteForceMnemonic/stdafx.h"
namespace tools {

	void generateRandomUint64Buffer(uint64_t* buff, size_t len);
	int pushToMemory(uint8_t* addr_buff, std::vector<std::string>& lines, int max_len);
	int readAllTables(tableStruct* tables, std::string path, std::string prefix, size_t* num_lines);
	void clearFiles(void);
	void saveResult(char* data, size_t len);
	int checkResult(retStruct* ret);
	int stringToWordIndices(std::string str, int16_t* gen_words_indices);
}