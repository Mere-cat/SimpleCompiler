# Readme

## 1. 編譯所有檔案
在當前目錄下執行：
```
make
```



## 2. 執行程式

這份檔案中，提供三個不同的測試程式，輸入以下指令以分別使用三個範例程式進行編譯+執行：
* `make run1 `
* `make run2 `
* `make run3 `

也可以使用額外的檔案進行測試：`make run filepath`
（其中 `filepath` 為使用者想測試的其他C程式路徑。）



## 3. 清空編譯後的檔案

在當前目錄下執行：
```
make clean
```


## 4. 關於本專題

### 4.1 這個編譯器支援的功能
* 指定功能：
	1. 支援 int
	2. 支援數學運算
	3. 支援關係運算
	4. 支援if-then/if-then-else
	5. 支援多參數printf
* 額外功能：
	6. 支援 while
	7. 支援 for

### 4.2 各測試檔測試功能
* `test1.c`：
   支援 int、數學運算、多參數printf
* `test2.c`：
   關係運算、if-then/if-then-else、多參數printf
* `test3.c`：額外功能
