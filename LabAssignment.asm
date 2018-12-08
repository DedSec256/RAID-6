; -------------------------------------------------------------------------------------	;
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
;	Испольуземая технология: AVX

.DATA 
				MODULE_MASK	QWORD 7171717171717171h  ; Блок из неприводимых многочленов 1 71 без старшего бита
				ZERO_MASK	QWORD 0FEFEFEFEFEFEFEFEh ; Маска обнуления младшего бита каждого байта

REVERSE_X       QWORD 0B8B8B8B8B8B8B8B8h ; x^(-1)
                QWORD 5C5C5C5C5C5C5C5Ch  ; x^(-2)
                QWORD 2E2E2E2E2E2E2E2Eh  ; x^(-3)
                QWORD 1717171717171717h  ; x^(-4)
                QWORD 0B3B3B3B3B3B3B3B3h ; x^(-5)
                QWORD 0E1E1E1E1E1E1E1E1h ; x^(-6)
                QWORD 0C8C8C8C8C8C8C8C8h ; x^(-7)
                QWORD 6464646464646464h  ; x^(-8)
                QWORD 3232323232323232h  ; x^(-9)
                QWORD 1919191919191919h  ; x^(-10)
                QWORD 0B4B4B4B4B4B4B4B4h ; x^(-11)
                QWORD 5A5A5A5A5A5A5A5Ah  ; x^(-12)
                QWORD 2D2D2D2D2D2D2D2Dh  ; x^(-13)
                QWORD 0AEAEAEAEAEAEAEAEh ; x^(-14)
                QWORD 5757575757575757h  ; x^(-15)
                QWORD 9393939393939393h  ; x^(-16)
                QWORD 0F1F1F1F1F1F1F1F1h ; x^(-17)
                QWORD 0C0C0C0C0C0C0C0C0h ; x^(-18)
                QWORD 6060606060606060h  ; x^(-19)
                QWORD 3030303030303030h  ; x^(-20)
                QWORD 1818181818181818h  ; x^(-21)
                QWORD 0C0C0C0C0C0C0C0Ch  ; x^(-22)
                QWORD 0606060606060606h  ; x^(-23)
                QWORD 0303030303030303h  ; x^(-24)
                QWORD 0B9B9B9B9B9B9B9B9h ; x^(-25)
                QWORD 0E4E4E4E4E4E4E4E4h ; x^(-26)
                QWORD 7272727272727272h  ; x^(-27)
                QWORD 3939393939393939h  ; x^(-28)
                QWORD 0A4A4A4A4A4A4A4A4h ; x^(-29)

REVERSE_XAB     QWORD 0D1D1D1D1D1D1D1D1h ; 1/(1-x^(-1))
                QWORD 9E9E9E9E9E9E9E9Eh  ; 1/(1-x^(-2))
                QWORD 0ACACACACACACACACh ; 1/(1-x^(-3))
                QWORD 0FDFDFDFDFDFDFDFDh ; 1/(1-x^(-4))
                QWORD 0E9E9E9E9E9E9E9E9h ; 1/(1-x^(-5))
                QWORD 3D3D3D3D3D3D3D3Dh  ; 1/(1-x^(-6))
                QWORD 0AAAAAAAAAAAAAAAAh ; 1/(1-x^(-7))
                QWORD 7B7B7B7B7B7B7B7Bh  ; 1/(1-x^(-8))
                QWORD 5454545454545454h  ; 1/(1-x^(-9))
                QWORD 1A1A1A1A1A1A1A1Ah  ; 1/(1-x^(-10))
                QWORD 1919191919191919h  ; 1/(1-x^(-11))
                QWORD 9595959595959595h  ; 1/(1-x^(-12))
                QWORD 0C6C6C6C6C6C6C6C6h ; 1/(1-x^(-13))
                QWORD 2929292929292929h  ; 1/(1-x^(-14))
                QWORD 5E5E5E5E5E5E5E5Eh  ; 1/(1-x^(-15))
                QWORD 0B7B7B7B7B7B7B7B7h ; 1/(1-x^(-16))
                QWORD 4C4C4C4C4C4C4C4Ch  ; 1/(1-x^(-17))
                QWORD 5757575757575757h  ; 1/(1-x^(-18))
                QWORD 0EBEBEBEBEBEBEBEBh ; 1/(1-x^(-19))
                QWORD 3535353535353535h  ; 1/(1-x^(-20))
                QWORD 0B5B5B5B5B5B5B5B5h ; 1/(1-x^(-21))
                QWORD 3030303030303030h  ; 1/(1-x^(-22))
                QWORD 8686868686868686h  ; 1/(1-x^(-23))
                QWORD 0B8B8B8B8B8B8B8B8h ; 1/(1-x^(-24))
                QWORD 0202020202020202h  ; 1/(1-x^(-25))
                QWORD 0FAFAFAFAFAFAFAFAh ; 1/(1-x^(-26))
                QWORD 0EDEDEDEDEDEDEDEDh ; 1/(1-x^(-27))
                QWORD 0F4F4F4F4F4F4F4F4h ; 1/(1-x^(-28))
                QWORD 0E7E7E7E7E7E7E7E7h ; 1/(1-x^(-29))

.CODE

; -------------------------------------------------------------------------------------	;
;	Проверяет поддержку технологий FMA/AVX												;
; -------------------------------------------------------------------------------------	;
FMA_CHECKER PROC

			PUSH RAX
			PUSH RBX
			PUSH RCX
			PUSH RDX

			; Проверка поддержки AVX, FMA, XGETBV процессором
			MOV EAX, 1
			CPUID
			AND ECX, 018001000h		; Выделение битов 12-FMA, 27-OSXSAVE, 28-AVX
			CMP ECX, 018001000h		; Все ли биты установлены в 1?
			JNE FMA_NOT_SUPPORTED	; Если нет, то необходимой поддержки нет
			
			; Проверка поддержки AVX и FMA операционной системой
			;MOV EAX, 0				; чтение регистра XCR
			;XGETBV					; чтение XCR0 в пару EDX:EAX
			;AND EAX, 06h			; Выделение битов 1 и 2
			;CMP EAX, 06h			; Оба ли они установлены в 1?
			;JNE FMA_NOT_SUPPORTED	; Если нет, то необходимой поддержки нет
			
			POP RDX
			POP RCX
			POP RBX
			POP RAX
			JMP FMA_SUPPORTED		; Иначе FMA можно использовать

FMA_NOT_SUPPORTED:
			; Принудительно завершаем программу
			MOV AH, 0
			INT 21H

FMA_SUPPORTED:
			RET
FMA_CHECKER ENDP


; -------------------------------------------------------------------------------------	;
;	Вспомогательная процедура для умножения многочлена на x по модулю					;
; -------------------------------------------------------------------------------------	;
;   Множимый блок многочленов: YMM1, Модуль: YMM3, Обнуляющая маска: YMM7				;
;	Результат на			 : YMM1														;
;	Портит					 : YMM2														;
; -------------------------------------------------------------------------------------	;
MUL_X PROC

			VPXOR YMM2,	YMM2, YMM2

			; выделяем многочлены, у которых старший бит = 1
			VPCMPGTB YMM2, YMM2, YMM1

			; получаем маску, которая прибавляет модуль лишь к таким многочленам
			VPAND YMM2,	YMM3, YMM2	

			; эмулируем VPSLLB, ибо её не существует:
			; сдвигаем многочлены влево на 1 и обнуляем переносы
			VPSLLW YMM1, YMM1, 1		
			VPAND  YMM1, YMM7, YMM1	

			; прибавляем маску к многочленам
			VPXOR YMM1,	YMM2, YMM1		

			RET	
MUL_X ENDP

; -------------------------------------------------------------------------------------	;
;	Вспомогательная процедура для умножения многочленов по модулю в столбик				;
; -------------------------------------------------------------------------------------	;
;   Множимый блок многочленов: YMM1, Обнуляющая маска: YMM7								;
;   Множитель                : YMM4														;
;	Результат на			 : YMM1														;
;	Портит					 : YMM4, YMM5, YMM6, RAX									;
; -------------------------------------------------------------------------------------	;
MUL_POLYNOM PROC

			VMOVDQU YMM5, YMM1			; для унификации умножения на x сохраняем YMM1
			VPXOR   YMM1, YMM1, YMM1	; дальше будем использовать YMM1 как сумму
			MOV     RAX,  8				; счётчик

INNER_LOOP:
			; умножаем сумму на x
			CALL MUL_X

			VPXOR YMM6,	YMM6, YMM6

			VPCMPGTB YMM6, YMM6, YMM4	; выделяем многочлены, у которых старший бит = 1
			VPAND    YMM6, YMM5, YMM6	; применяем полученную маску к множимым многочленам
			VPXOR    YMM1, YMM6, YMM1	; прибавляем к сумме результат

			; эмулируем VPSLLB, ибо её не существует:
			; сдвигаем многочлены влево на 1 и обнуляем переносы
			VPSLLW	 YMM4, YMM4, 1		
			VPAND    YMM4, YMM7, YMM4	

			SUB	RAX, 1
			JG  INNER_LOOP

			RET
MUL_POLYNOM ENDP

; -------------------------------------------------------------------------------------	;
;	Вспомогательная процедура для вычисления синдромов P и Q без записи в память		;
; -------------------------------------------------------------------------------------	;
;   Множимый блок многочленов: YMM1														;
;   Множитель                : YMM4														;
;	Результат на			 : R12, R13, R14, R15										;
;	Портит					 : RAX, RDX													;
; -------------------------------------------------------------------------------------	;
CalculateSyndromesInternal PROC

			VPXOR YMM0, YMM0, YMM0
			VPXOR YMM1,	YMM1, YMM1

			SHL RDX, 5		; в RDX значение N*32
			ADD RDX, RCX	; в RDX N-ый адрес = RCX + N*32
			MOV RAX, RCX	; в RAX адрес начала страйпа	

INNER_LOOP: 

			; Q = Q * x
			CALL MUL_X

			; считываем D_i
			VMOVDQU YMM8, YMMWORD PTR [RAX]	

			VPXOR YMM0,	YMM0, YMM8	; P = P + D_i
			VPXOR YMM1,	YMM1, YMM8	; Q = Q + D_i		

			ADD RAX, 32
			CMP RAX, RDX
			JNE INNER_LOOP

			RET
CalculateSyndromesInternal ENDP

; -------------------------------------------------------------------------------------	;
; void CalculateSyndromes(void *D, unsigned int N)										;
;	Вычисление синдромов P и Q															;
;	D - Адрес страйпа, N - количество дисков данных										;
; -------------------------------------------------------------------------------------	;
;	Входные данные: [RCX] - D, RDX - N													;
;	Портит	      :  RAX, RDX															;
; -------------------------------------------------------------------------------------	;
CalculateSyndromes PROC

			; проверяем, поддерживается ли FMA/AVX 
			; закомментировал, ибо сильно влияет на производительность
			;CALL FMA_CHECKER

			VBROADCASTSD YMM3, MODULE_MASK	; получаем и размножаем модуль 
			VBROADCASTSD YMM7, ZERO_MASK	; получаем и размножаем обнуляющую перенесённые биты маску

			; вычисляем P и Q
			CALL CalculateSyndromesInternal
	
			VMOVDQU  YMMWORD PTR [RAX], YMM0    ; записываем P на N-ое место
			ADD RAX, 32							; переходим к N+1 месту
			VMOVDQU  YMMWORD PTR [RAX], YMM1	; записываем Q на N+1-ое место	

			; обнуляем все AVX регистры
			VZEROALL

FMA_NOT_SUPPORTED:
			RET
CalculateSyndromes ENDP

; -------------------------------------------------------------------------------------	;
; void Recover(void *D, unsigned int N, unsigned int a, unsigned int b)					;
;	Восстановление блоков с номерами a и b (b>a)										;
;	D - Адрес страйпа, N - количество дисков данных										;
; -------------------------------------------------------------------------------------	;
;	Входные данные: [RCX] - D, RDX - N, R8 - a, R9 - b									;
;	Портит	      :  RAX, R10, R11														;
; -------------------------------------------------------------------------------------	;
Recover PROC

			; проверяем, поддерживается ли FMA/AVX 
			; закомментировал, ибо сильно влияет на производительность
			;CALL FMA_CHECKER

			VBROADCASTSD YMM3, MODULE_MASK	; получаем и размножаем модуль 
			VBROADCASTSD YMM7, ZERO_MASK	; получаем и размножаем обнуляющую перенесённые биты маску

			LEA R10, [RDX - 2]    ; в R10 лежит N - 2
			LEA R11, [R9  - 1]    ; в R11 лежит b - 1

			SUB R10, R8    ; в R10 лежит индекс в таблице REVERSE_X   = N - a - 2
			SUB R11, R8	   ; в R11 лежит индекс в таблице REVERSE_XAB = b - a - 1

			SHL R10, 3	; в R10 лежит смещение в таблице REVERSE_X   = индекс * 8
			SHL R11, 3	; в R11 лежит смещение в таблице REVERSE_XAB = индекс * 8

			MOV RAX, OFFSET REVERSE_X
			ADD R10, RAX	; в R10 лежит адрес x^(a-N+1) 
			MOV RAX, OFFSET REVERSE_XAB
			ADD R11, RAX	; в R11 лежит адрес 1/(1 - x^(a - b))

			MOV RAX, RDX	; в RAX значение N
			SHL RAX, 5		; в RAX значение N*32
			ADD RAX, RCX	; в RAX адрес N-ого блока = RCX + N*32

			; сохраняем значение синдрома P
			VMOVDQU	YMM4, YMMWORD PTR [RAX]
	
			; сохраняем значение синдрома Q
			VMOVDQU	YMM5, YMMWORD PTR [RAX + 32]		

			; считает синдромы P_sum и Q_sum без блоков D_a и D_b
			CALL CalculateSyndromesInternal

			VPXOR YMM0,	YMM0, YMM4	; вычисляем ~P = P - P_sum
			VPXOR YMM1,	YMM1, YMM5	; вычисляем ~Q = Q - Q_sum

			VBROADCASTSD YMM4, QWORD PTR [R10]	; получаем значение x^(a-N+1) и размножаем его

			; Умножаем ~Q на x^(a-N+1)
			CALL MUL_POLYNOM

			; Вычисляем ~P - (~Q * x^(a-N+1)))
			VPXOR YMM1,	YMM0, YMM1

			VBROADCASTSD YMM4, QWORD PTR [R11]	; получаем значение 1/(1 - x^(a - b)) и размножаем его

			; Умножаем вычисленное (~P - (~Q * x^(a-N+1))) на  1/(1 - x^(a - b))
			CALL MUL_POLYNOM 

			MOV R10, R9		; в R10 значение b
			MOV R11, R8		; в R11 значение a

			SHL R10, 5	    ; в R10 значение b*32
			SHL R11, 5	    ; в R11 значение a*32

			; записываем D_b
			VMOVDQU YMMWORD PTR [RCX + R10], YMM1

			; вычисляем D_a = ~P - D_b
			VPXOR YMM1,	YMM0, YMM1

			; записываем D_a
			VMOVDQU YMMWORD PTR [RCX + R11], YMM1

			; обнуляем все AVX регистры
			VZEROALL

FMA_NOT_SUPPORTED:
			RET
Recover ENDP
END