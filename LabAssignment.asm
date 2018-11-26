﻿; -------------------------------------------------------------------------------------	;
;	Лабораторная работа №1 по курсу Программирование на языке ассемблера				;
;	Вариант №3.1																		;
;	Выполнил студент Бережных А. В.														;
;																						;
;	Исходный модуль LabAssignment														;
;	Содержит функции на языке ассемблера, разработанные в соответствии с заданием		;
; -------------------------------------------------------------------------------------	;
;	Задание: Реализовать функции вычисления синдромов и восстановления
;		утраченных дисков в массиве RAID-6
;	Размер блока - 32 байта
;	Общее количество блоков в страйпе N+2:
;		0...N-1 - блоки данных
;		N		- синдром P
;		N+1		- миндром Q
;	Поле Галуа, используемое для вычислений: GF(2^8)
;   Неприводимый многочлен: 1 71

.DATA 

		HIGH_BITS_MASK QWORD 0101010101010101h  ; Маска обнуления старшего бита каждого байта в 8-байтном блоке
		MODULE_MASK	   QWORD 7171717171717171h  ; Неприводимый многочлен 1 71 без старшего бита
		ZERO_MASK	   QWORD 0FEFEFEFEFEFEFEFEh ; Маска обнуления младшего бита каждого байта в 8-байтном блоке

.CODE

; -------------------------------------------------------------------------------------	;
;	Вспомогательная процедура для умножения многочлена на x по модулю					;
; -------------------------------------------------------------------------------------	;
;   Множимый блок многочленов: R12, R13, R14, R15										;
;	Результат на			 : R12, R13, R14, R15										;
;	Портит					 : RBX, RCX, RSI, RDI										;
; -------------------------------------------------------------------------------------	;
MUL_X PROC ;

		; В виду нехватки регистров и нежелания увеличивать их количество
		; За счёт большего количества обращений к памяти,
		; Разбиваем задачу умножения R12-R15 на х 
		; На подзадачи последовательного умножения на х сначала R12, R13 - потом R14, R15 

		MOV RBX, HIGH_BITS_MASK
		MOV RCX, RBX

		; Получаем старшие биты 8-байтных блоков R12 и R13 по маске HIGH_BITS_MASK
		AND RBX, R12
		AND RCX, R13

		; Хотим умножить на x все 8 многочленов внутри 8-байтных блоков;
		; Полученные старшие биты каждого из 8 многочленов в блоке позволят определить,
		; У каких многочленов произошёл перенос после сдвига влево
		;
		; Необходимо размножить полученые старшие биты вправо на 7, 
		; И & с MODULE_MASK, чтобы получить маску, прибавляющую порождающий многочлен 
		; Только к тем многочленам из блока, в которых произошёл перенос
		; Идея алгоритма размножения бита вправо:
		;
		;    |10000000 00000000 10000000| ->   |11000000 00000000 11000000| -> размножили на 3 вправо
		;  >> 01000000 00000000 01000000|	 >> 00110000 00000000 00110000|    и тд..
		;    +--------------------------|	   +--------------------------|
		;    |11000000 00000000 11000000|	   |11110000 00000000 11110000|

		; Копируем полученные 8-байтные вектора в RDI, RSI
		MOV RDI, RBX
		MOV RSI, RCX

		; Размножаем на 1 бит вправо
		SHR RBX, 1
		SHR RCX, 1

		OR RBX, RDI
		OR RCX, RSI

		MOV RDI, RBX
		MOV RSI, RCX

		; Размножаем на 3 бита вправо
		SHR RBX, 2
		SHR RCX, 2

		OR RBX, RDI
		OR RCX, RSI

		MOV RDI, RBX
		MOV RSI, RCX

		; Размножаем на 7 битов вправо
		SHR RBX, 4
		SHR RCX, 4

		; Итого -- размножили на 7 битов вправо
		OR RBX, RDI
		OR RCX, RSI

		MOV RSI, MODULE_MASK

		; Получаем маску, которая прибавляет порождающий многочлен 
		; Только к тем многочленам из блока, в которых произошёл перенос
		AND RBX, RSI
		AND RCX, RSI

		; Делаем сдвиг самих многочленов влево
		SHL R12, 1
		SHL R13, 1

		; Обнуляем лишние перенесённые разряды (младший бит в каждом многочлене)
		MOV RSI, ZERO_MASK 
		AND R12, RSI
		AND R13, RSI

		; Применяем полученную маску, 
		; Тем самым прибавив порождающий многочлен только там, где нужно 
		XOR R12, RBX
		XOR R13, RCX
		
;-----------------------------------------------------------------------;
;		Проделываем аналогичные операции с многочленами в R14, R15		;
;-----------------------------------------------------------------------;
		
		MOV RBX, HIGH_BITS_MASK
		MOV RCX, RBX

		AND RBX, R14
		AND RCX, R15

		MOV RDI, RBX
		MOV RSI, RCX

		SHR RBX, 1
		SHR RCX, 1

		OR RBX, RDI
		OR RCX, RSI

		MOV RDI, RBX
		MOV RSI, RCX

		SHR RBX, 2
		SHR RCX, 2

		OR RBX, RDI
		OR RCX, RSI

		MOV RDI, RBX
		MOV RSI, RCX

		SHR RBX, 4
		SHR RCX, 4

		OR RBX, RDI
		OR RCX, RSI

		MOV RSI, MODULE_MASK

		AND RBX, RSI
		AND RCX, RSI

		SHL R14, 1
		SHL R15, 1

		MOV RSI, ZERO_MASK 

		AND R14, RSI
		AND R15, RSI

		XOR R14, RBX
		XOR R15, RCX

		ret
MUL_X ENDP

; -------------------------------------------------------------------------------------	;
;	Вспомогательная процедура для умножения многочленов по модулю в столбик				;
; -------------------------------------------------------------------------------------	;
;   Множимый блок многочленов: R12, R13, R14, R15										;
;   Множитель                : RDX														;
;	Результат на			 : R12, R13, R14, R15										;
;	Портит					 : RBX, RCX, RDI, RSI, RDX, RAX								;
; -------------------------------------------------------------------------------------	;
MUL_POLYNOM PROC

		MOV RAX, 8		; Cчётчик

		; При вызове из Recover тут будет сохранён ~P_a,b
		; Который нужен после выхода этой процедуры, поэтому сохраняем регисты
		PUSH R8
		PUSH R9
		PUSH R10
		PUSH R11

		; Теперь они хранят множимый многочлен
		; Сделано для того, чтобы унифицировать вызов MUL_X
		MOV R8,  R12
		MOV R9,  R13
		MOV R10, R14
		MOV R11, R15

		; Очищаем, тут будет аккумулироваться результирующая сумма 
		XOR R12, R12
		XOR R13, R13
		XOR R14, R14
		XOR R15, R15

;------------Цикл умножения в столбик-------------
INNER_LOOP:
		
		; Умножаем сумму на x
		CALL MUL_X

		; Выделяем старшие биты у множителя на данной итерации 
		MOV RBX, HIGH_BITS_MASK	
		AND	RBX, RDX			

		; Размножаем старшие биты на 7 битов вправо
		; Идея размножения битов вправо описана в MUL_X
		MOV RCX, RBX
		SHR RBX, 1
		OR  RBX, RCX

		MOV RCX, RBX
		SHR RBX, 2
		OR  RBX, RCX

		MOV RCX, RBX
		SHR RBX, 4
		OR  RBX, RCX

		; Копируем получившуюся маску для оставшихся 8-байтных блоков
		MOV	RCX, RBX
		MOV	RDI, RBX
		MOV	RSI, RBX

		; применяем полученную маску к блоку множимомых многочленов
		AND	RBX, R8
		AND	RCX, R9
		AND	RDI, R10
		AND	RSI, R11

		; Получаем маску, которая прибавляет множитель
		; Только если у него текущий старший бит не ноль

		; прибавляем к сумме результат
		XOR	R12, RBX
		XOR	R13, RCX
		XOR	R14, RDI
		XOR	R15, RSI

		; сдвигаем множитель влево и обнуляем лишние перенесённые биты
		SHL	RDX, 1	
		AND	RDX, ZERO_MASK

		; переход к следующей итерации
		SUB	RAX, 1
		JG  INNER_LOOP

;----------Конец цикла умножения в столбик-----------
	
		; Записываем получившиеся суммы в результирующие регистры 
		MOV R12, R8
		MOV R13, R9
		MOV R14, R10
		MOV R15, R11

		; Восстанавливаем R8-R11
		POP R11
		POP R10
		POP R9
		POP R8

		ret	
MUL_POLYNOM ENDP

; -------------------------------------------------------------------------------------	;
; void CalculateSyndromes(void *D, unsigned int N)										;
;	Вычисление синдромов P и Q															;
;	D - Адрес страйпа, N - количество дисков данных										;
; -------------------------------------------------------------------------------------	;
;	Входные данные: [RCX] - D, RDX - N													;
;	Портит	      :  RAX, RCX, RDX, R8-R11												;
; -------------------------------------------------------------------------------------	;
CalculateSyndromes PROC

		; Так как размер поля 8, а размер диска 256,
		; То каждый диск будем хранить в 4-х 8-байтных регистрах
		;
		; Примечание: в данном коде практически всегда R8--R11 связаны с хранением P
		;											   R12-R15 связаны с хранением Q

		; Сохраняем регистры в связи с соглашением
		PUSH R12
		PUSH R13
		PUSH R14
		PUSH R15
		PUSH RBX
		PUSH RDI
		PUSH RSI

		; Обнуляем аккумуляторы для 8-байтных блоков P
		XOR R8,  R8 
		XOR R9,  R9
		XOR R10, R10
		XOR R11, R11
		; P = 0

		; Обнуляем аккумуляторы для 8-байтных блоков Q
		XOR R12, R12
		XOR R13, R13
		XOR R14, R14
		XOR R15, R15
		; Q = 0

		; Хотим передвигаться не по индексу, а по адресу,
		; Чтобы не было лишних операций вычисления адреса

		SHL RDX, 5		; в RDX значение N*32
		ADD RDX, RCX	; в RDX адрес P = RCX + N*32
		MOV RAX, RCX	; в RAX адрес начала страйпа

;--------------Цикл вычислений P и Q--------------
INNER_LOOP: 

		; Запоминаем значения 8-байтных блоков из D_i
		MOV RBX, [RAX	  ] ; первые 64 бита
		MOV RCX, [RAX + 8 ] ; ...
		MOV RDI, [RAX + 16] ; ...
		MOV RSI, [RAX + 24] ; последние 64 бита диска

		; P = (P + D_i)
		XOR R8,  RBX
		XOR R9,  RCX 
		XOR R10, RDI
		XOR R11, RSI

		; Получаем значение (Q + D_i)
		XOR R12, RBX
		XOR R13, RCX
		XOR R14, RDI
		XOR R15, RSI

		; Умножаем полученное значение (Q + D_i) на x
		CALL MUL_X

		; Пока не дошли до адреса P
		; Переходим к следующей итерации

		ADD RAX, 32
		CMP RAX, RDX
		JNE INNER_LOOP

;-----------Конец цикла вычислений P и Q-----------

		; На этом шаге RAX = адресу P
		; Записываем вычисленное P
		MOV [RAX	 ], R8
		MOV [RAX + 8 ], R9
		MOV [RAX + 16], R10
		MOV [RAX + 24], R11

		; Переходим к адресу Q
		ADD RAX, 32

		; Записываем вычисленное Q
		MOV [RAX 	 ], R12
		MOV [RAX + 8 ], R13
		MOV [RAX + 16], R14
		MOV [RAX + 24], R15

		; Восстанавливаем необходимые регистры
		; Согласно соглашениям о вызовах
		POP RSI
		POP RDI
		POP RBX
		POP R15
		POP R14
		POP R13
		POP R12

		ret
CalculateSyndromes ENDP

; -------------------------------------------------------------------------------------	;
; void Recover(void *D, unsigned int N, unsigned int a, unsigned int b)					;
;	Восстановление блоков с номерами a и b (b>a)										;
;	D - Адрес страйпа, N - количество дисков данных										;
; -------------------------------------------------------------------------------------	;
;	Входные данные: [RCX] - D, RDX - N, R8 - a, R9 - b									;
;	Портит	      :  RAX, RCX, RDX, R8-R11												;
; -------------------------------------------------------------------------------------	;
Recover PROC

		; Сохраняем регистры по соглашению
		PUSH R12
		PUSH R13
		PUSH R14
		PUSH R15
		PUSH RBX
		PUSH RDI
		PUSH RSI

		; Сохраняем адрес D_a в регистре RDI
		;		  И адрес D_b в регистре RSI
		MOV RDI, R8		; в RDI значение a
		MOV RSI, R9		; в RSI значение b

		SHL RDI, 5	    ; в RDI значение a*32
		SHL RSI, 5	    ; в RSI значение b*32

		ADD RDI, RCX	; в RDI адрес D_a = RCX + a*32
		ADD RSI, RCX	; в RSI адрес D_b = RCX + b*32

		PUSH RDI		; записываем адрес D_a
		PUSH RSI		; записываем адрем D_b

		SUB R9,  R8		; вычисляем значение b-a
		SUB R9,  1		; теперь в R9 лежит индекс в таблице REVERSE_XAB (от 0 до N-2) = b - a - 1
		SUB R8,  1		; теперь в R8 лежит индекс в таблице REVERSE_X   (от 0 до N-2) = a - 1
	
		SHL R9, 5		; вычисляем смещение в таблице REVERSE_XAB = индекс * 8  
		SHL R8, 5		; вычисляем смещение в таблице REVERSE_X   = индекс * 8  

		PUSH R9			; сохраняем смещение в таблице REVERSE_XAB для поиска нужной константы
		PUSH R8			; сохраняем смещение в таблице REVERSE_X   для поиска нужной константы

		XOR RAX, RAX	; Очищаем RAX

		; Очищаем D_a
		MOV [RDI	 ], RAX 
		MOV [RDI + 8 ], RAX
		MOV [RDI + 16], RAX
		MOV [RDI + 24], RAX

		; Очищаем D_b
		MOV [RSI	 ], RAX
		MOV [RSI + 8 ], RAX
		MOV [RSI + 16], RAX
		MOV [RSI + 24], RAX

		; Вычисляем адрес P
		MOV RAX, RDX	; в RAX лежит N
		SHL RAX, 5		; в RAX лежит N*32
		ADD RAX, RCX	; в RAX адрес P = RCX + N*32

		; Сохраняем Q в R12-R15
		MOV R12, [RAX + 32]
		MOV R13, [RAX + 40]
		MOV R14, [RAX + 48]
		MOV R15, [RAX + 56]

		; Сохраняем P в стек
		PUSH [RAX     ]
		PUSH [RAX + 8 ]
		PUSH [RAX + 16]
		PUSH [RAX + 24]

		CALL CalculateSyndromes	; Вычисляем синдромы без утраченных дисков

		; После вызова CalculateSyndromes:
		; в RDX		будет лежать адрес P_sum (т.е. и P = N*32)
		; В R8--R11 будет лежать вычисленное значение P_sum

		; Восстанавливаем из стека переданный в эту процедуру P
		POP RDI
		POP RCX
		POP RBX
		POP RAX

		; Возвращаем их по адресу P 
		; (Ибо нельзя неожиданно менять переданные по указателю данные!)
		MOV [RDX	 ], RAX 
		MOV [RDX + 8 ], RBX
		MOV [RDX + 16], RCX
		MOV [RDX + 24], RDI

		; Вычисляем				   ~P_a,b = (P - P_sum)
		; Поскольку + есть XOR, то ~P_a,b = (P_sum - P)
		XOR R8,  RAX
		XOR R9,  RBX
		XOR R10, RCX
		XOR R11, RDI

		; Переходим к адресу Q
		ADD RDX, 32 

		; Копируем Q в RAX-RDI
		MOV RAX, R11
		MOV RBX, R12
		MOV RCX, R13
		MOV RDI, R14

		; Вычисляем	~Q_a,b = (Q - Q_sum)
		XOR R12, [RDX	  ]
		XOR R13, [RDX + 8 ]
		XOR R14, [RDX + 16]
		XOR R15, [RDX + 24]

		; Возвращаем переданное в процедуру Q по адресу Q 
		; (Ибо нельзя неожиданно менять переданные по указателю данные!)
		MOV [RDX	 ], RAX 
		MOV [RDX + 8 ], RBX
		MOV [RDX + 16], RCX
		MOV [RDX + 24], RDI

		; Загружаем в RDX значение константы x^(a-N+1)
		; По индексу из стека
		POP RAX
		MOV RDX, OFFSET REVERSE_X
		MOV RDX, [RDX + RAX]   

		; Умножаем ~Q_a,b на x^(a-N+1)
		CALL MUL_POLYNOM

		; Вычисляем (~P_a,b - (~Q_a,b * x^(a-N+1)))
		; Поскольку + есть XOR, то вычисляем ((~Q_a,b * x^(a-N+1)) - ~P_a,b)
		XOR R12, R8
		XOR R13, R9
		XOR R14, R10
		XOR R15, R11
		
		; загружаем в RDX значение константы 1/(1 - x^(a - b))
		; По индексу из стека
		POP RAX
		MOV RDX, OFFSET REVERSE_XAB
		MOV RDX, [RDX + RAX] 

		; Умножаем вычисленное (~P_a,b - (~Q_a,b * x^(a-N+1))) на  1/(1 - x^(a - b))
		CALL MUL_POLYNOM

		; Выгружаем адреса D_a и D_b
		POP RSI
		POP RDI

		; Сохраняем результат в D_b
		MOV [RSI	 ], R12
		MOV [RSI + 8 ], R13
		MOV [RSI + 16], R14
		MOV [RSI + 24], R15

		; Вычисляем D_a как (~P_a,b - D_b)
		XOR R8,  R12
		XOR R9,  R13
		XOR R10, R14
		XOR R10, R15

		; Сохраняем результат в D_a
		MOV [RDI	 ], R8
		MOV [RDI + 8 ], R9
		MOV [RDI + 16], R10
		MOV [RDI + 24], R11

		; Выгружаем сохранённые по соглашению регистры 
		POP RSI
		POP RDI
		POP RBX
		POP R15
		POP R14
		POP R13
		POP R12

	ret
Recover ENDP
END