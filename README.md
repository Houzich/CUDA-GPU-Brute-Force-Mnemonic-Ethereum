# Brute-force Mnemonic Ethereum on GPU(CUDA)
## (Version 2.0)
## Генерация мнемонических фраз Ethereum и соответствующих приватных ключей адресов m/44'/60'/0'/0/x, m/44'/60'/0'/1/x. Поиск адресов в базе.
![](image/Screenshot_1.png)

## Файл config.cfg
* ***"folder_tables": "F:\\tables"***  - путь к папке с таблицами искомых адресов. Адреса в таблицах должны быть в формате hash160 и отсортированы программой https://github.com/Houzich/Convert-Addresses-To-Hash160-For-Brute-Force

* ***"number_of_generated_mnemonics": 18000000000000000000*** - Общее кол-во мнемоник которое мы хотим генерировать. Это введено для проверки скорости генерации или для сохранения результатов генерации в файлы. Если хотим бесконечно, то устанавливаем максимальное значение 18000000000000000000. 
* ***"num_child_addresses": 10*** - количество генерируемых адресов для каждого патча. От 1 до 65,535.</br></br>

* ***"path_m44h_60h_0h_0_x": "yes"*** - генерировать ли адреса патча m/44'/60'/0'/0/x? "yes" или "no".
* ***"path_m44h_60h_0h_1_x": "yes"*** - генерировать ли адреса патча m/44'/60'/0'/1/x? "yes" или "no".

* ***"chech_equal_bytes_in_adresses": "yes"*** - Проверять ли адереса на совпадение по байтам? "yes" или "no". Если "yes", то адреса будут проверяться на совпадение по байтам 
больше 8 байт. Смотри ниже в "Описание".
* ***"save_generation_result_in_file": "no"*** - Сохранять результат генерации в файл? "yes" или "no". Введено для проверки правильности генерации. Мнемоника и соответствующие ей адреса записываются в файл Save_Addresses.csv
Запись производится очень медленно. Так как преобразование hash160 в формат WIF производится на ЦПУ. При основной работе программы выбирать "no".</br></br>

* ***"static_words_generate_mnemonic": "potato toe drift ? trip garbage crouch ? state siren poem"*** - Какие слова генерировать? Можно задать слова из первых 11 слов мнемоники, которые будут постоянными. Генерироваться будут только те слова, которые указаны символом "?". К примеру, можно задать "potato toe drift ? trip garbage crouch ? state siren poem". Тогда генерироваться будут только 4, 8 и 12 слова.</br></br>

* ***"cuda_grid": 1024*** - настройка под видеокарту
* ***"cuda_block": 256*** - настройка под видеокарту
Кол-во генерируемых мнемоник за раунд равно cuda_grid*cuda_block



## Описание
При запуске программы, считываются настройки из файла config.cfg.
В консоли выводится надпись
> *Detected 3 CUDA Capable device(s)*

где число 3  - это количество найденных видеокарт NVIDIA.
Далее выводятся характеристики каждой карты:
> *Device 0: "NVIDIA GeForce GTX 1050 Ti"*</br>
> *...*</br>
> Device 1: "NVIDIA GeForce GTX 1050 Ti"</br>
> *...*</br>
> *Device 2: "NVIDIA GeForce GTX 1050 Ti"*</br>
> *Enter the number of the used video card:*</br>

Нужно ввести номер используемой карты.</br>

Начинается считывание и преобразование файлов таблиц с адресами:
> *PROCESSED 2168134 ROWS IN FILE F:\\tables\A0.csv*</br>
> *...* </br>
> *PROCESSED 1232455 ROWS IN FILE F:\\tables\A0.csv*</br>
> *...*</br>
> *PROCESSED 3455665 ROWS IN FILE F:\\tables\A0.csv*</br>
> *...*

Где 2168134 - это кол-во адресов в файле. Адреса в файле хранятся в 20 байтовом формате(hash160) в виде hex-строки. И отсортированы по возрастанию.

Далее выводится кол-во кошельков генерируемых за раунд. И начинается процесс генерации.
В ходе работы программы, постоянно обновляется надпись

> *GENERATE: 3,302 MNEMONICS/SEC AND 66,049 ADDRESSES/SEC | SCAN: 5.949203 TERA ADDRESSES/SEC | ROUND: 11*

Кол-во мнемоник и кол-во адресов генерируемых за секунду и общее кол-во отсканированных адресов в таблицах. В данном случае, для каждого сгенерированного кошелька генерировалось 20 адресов. 10 адресов патча m/44'/60'/0'/0/x и 10 адресов патча m/44'/60'/0'/1/x

## Проверка на совпадение по байтам
Если при старте программы ввести
Если в файле config.cfg установить ***"chech_equal_bytes_in_adresses": "yes"***. То периодически на экране будут появляться надписи такого формата:
> *!!!FOUND IN ADDRESS(HASH160) (m/44'/60'/0'/0/2) EQUAL 6 BYTES: twenty issue they collect wagon elder universe public humor north aspect cereal,0x02BC274418AAA6631F67C691A3B6A67C8FBC29A0,0x02BC274418AA160D42DF5825C724D674E149B056*

(*EQUAL 6 BYTES*) - количество совпавших байт. Мнемоника сгенерированного кошелька. Его адрес. Адрес в базе, который совпал по первым байтам с адресом мнемоники. Можно посчитать одинаковые байты и убедиться в этом.
Все эти адреса сохраняются в лог-файл Found_Bytes.csv.
В файле, строки хранятся в виде:
*EQUAL 6,twenty issue they collect wagon elder universe public humor north aspect cereal,address path m/44'/60'/0'/0/2:,0x02BC274418AAA6631F67C691A3B6A67C8FBC29A0,0x02BC274418AA160D42DF5825C724D674E149B056,Tue May  9 21:15:31 2023*


# Если нашли кошелек
В консоли появиться надписи:
> *!!!FOUND!!!*</br>
> *!!!FOUND!!!*</br>
> *!!!FOUND!!!*</br>
> *!!!FOUND!!!*</br>
> *!!!FOUND ADDRESS (m/44'/60'/0'/0/3): potato toe drift abuse trip garbage crouch satoshi state siren poem opera, 0xE0D05B513E6324EC9E3474087598AA7EAE352919*</br>
> *!!!FOUND!!!*</br>
> *!!!FOUND!!!*</br>
> *!!!FOUND!!!*</br>
> *!!!FOUND!!*

Соответственно мнемоника и адрес который мы нашли. И информация добавиться в файл Found_Addresses.csv.
В файле строки хранятся в виде:</br>
*potato toe drift abuse trip garbage crouch satoshi state siren poem opera,address path m/44'/60'/0'/0/3:,0xE0D05B513E6324EC9E3474087598AA7EAE352919,Sat Apr 29 18:24:58 2023*

## Файл BruteForceMnemonicEthereumV200.exe находится в папке exe


### ОБСУЖДЕНИЕ КОДА: https://t.me/BRUTE_FORCE_CRYPTO_WALLET


## If you want to support the project don't hesitate to donate.
**BTC** - bc1qqldn5lyk54rcvf5ndruh525v0qz8lf9yu5t9a5</br>
**ETH** - 0x1193901D25604F55f5fA93Be09F5203b4B6F265f