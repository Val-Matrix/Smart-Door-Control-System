                     #start=simple.exe#
                     #start=stepper_motor.exe#
                     #start=traffic_lights.exe#
                     
                     JMP BEGIN
                     
                     PORT_THERMOPILE EQU 112      ;TEMPERATURE INPUT
                     PORT_CAMERA     EQU 110      ;FACE_MASK INPUT
                     PORT_CMD1       EQU 003H     ;FIRST PPI
                     PORT_LED        EQU 004      ;LED OUTPUT
                     PORT_STEPPER    EQU 007      ;STEPPER MOTOR OUTPUT
                     PORT_CMD2       EQU 008H     ;SECOND PPI (supposed to be 007H, but in conflict with virtual traffic light port of EMU8086)

                     MAX_HALF_STEPS  EQU 16       ;limit stepper motor rotation to 180 degrees (16 X 11.25 degrees)
                     DATCW_HS        DB 00000110B ;data to rotate stepper motor clockwise
                                     DB 00000100B
                                     DB 00000011B
                                     DB 00000010B
                     
                     DATCCW_HS	     DB 00000011B ;data to rotate stepper motor counterclocwise
	                                 DB 00000001B
	                                 DB 00000110B
	                                 DB 00000010B

BEGIN:               MOV AL, 10011011B            ;configure the 2 82C55s
                     OUT PORT_CMD1, AL            ;mode 00 input for all ports
                     MOV AL, 10000000B
                     OUT PORT_CMD2, AL            ;mode 00 output for all ports

                     MOV AX, 0800H                ;set ES at 0800H for segment override in SRAM memory addressing
                     MOV ES, AX
                     
                     MOV AL, 0
                     OUT PORT_LED, AL             ;turn off all LEDs
                                
TEMPERATURE:         IN AL, PORT_THERMOPILE
                     CMP AL, 170                  ;correspond to 35 degrees Celcius
                     JB TEMPERATURE
                     MOV ES:[0000H], AL           ;copy thermopile data to memory address 8000H
                     MOV AX, 0

FACE_MASK:           IN AL, PORT_CAMERA
                     MOV ES:[0001H], AL           ;copy camera data to memory address 8001H
                     MOV AX, 0

LED_RED:             MOV BL, ES:[0000H]           ;copy thermopile data from memory address 8000H to BL
                     CMP BL, 221                  ;correspond to 38 degrees Celcius
                     JB LED_AMBER                 ;skip next instruction if < 38 degrees Celcius
                     ADD AL, 1                    ;activate bit for red light (>= 38 degrees Celcius)

LED_AMBER:           MOV BL, ES:[0001H]           ;copy camera data from memory address 8001H to BL
                     TEST BL, 1
                     JNZ LED_OUTPUT               ;skip next instruction if face mask present (= 1)
                     ADD AL, 2                    ;activate bit for amber light (no face mask)

LED_OUTPUT:          OUT PORT_LED, AL             ;send LEDs' data in AL to LEDs' port

LED_CHECK:           CMP AL, 0                    ;detect red and amber LEDs
                     JE LED_GREEN                 ;skip next few instructions if no red and amber LEDs
                     MOV CX, 4CH
                     MOV DX, 4B40H                ;004C4B40H = 5000000 X 1 us = 5 s
                     MOV AH, 86H
                     INT 15H                      ;wait for 5 seconds
                     MOV AL, 0
                     OUT PORT_LED, AL             ;turn off all LEDs
                     JMP TEMPERATURE              ;return to temperature sensing

LED_GREEN:           MOV AX, 0
                     ADD AL, 4                    ;activate bit for green light

                     OUT PORT_LED, AL             ;send LEDs' data in AL to LEDs' port
                     CALL STEPPER_MOTOR_OPEN

MOTION:              MOV AH, 1H
                     INT 21H                      ;receive PIR motion sensor input via keyboard
                     TEST AL, 1                   ;check if person has passed through the gate (= 1?)
                     JZ MOTION                    ;loop if person hasn't passed through the gate (= 0)

                     CALL STEPPER_MOTOR_CLOSE
                     
                     MOV AL, 0
                     OUT PORT_LED, AL             ;turn off all LEDs
                     JMP TEMPERATURE              ;return to temperature sensing


PROC STEPPER_MOTOR_OPEN
                     MOV BX, OFFSET DATCW_HS      ;copy clockwise rotation data's offset addresses to BX
                     MOV SI, 0                    ;address first byte in DATCW_HS   
                     MOV CX, 0

WAIT1:               IN AL, 7     
                     TEST AL, 10000000B           ;test if stepper motor is ready to receive input
                     JZ WAIT1

                     MOV AL, [BX][SI]
                     OUT PORT_STEPPER, AL         ;rotate stepper motor clockwise by 1 half-step (11.25 degrees)
                     INC SI                       ;address next byte in DATCW_HS
                     INC CX                       ;increase count for no. of half-steps executed     
                     
                     CMP CX, MAX_HALF_STEPS       ;check if CX reached count limit
                     JAE EXIT_PROC1               ;exit procedure if CX reached count limit
                     
                     CMP SI, 4                    ;check if SI is out of bounds of DATCW_HS
                     JB WAIT1
                     MOV SI, 0                    ;reset back to first byte of DATCW_HS
                     JMP WAIT1

EXIT_PROC1:          RET                          ;return to main program
ENDP STEPPER_MOTOR_OPEN
                           
PROC STEPPER_MOTOR_CLOSE 
                     MOV BX, OFFSET DATCCW_HS     ;copy counterclockwise rotation data's offset addresses to BX
                     MOV SI, 0                    ;address first byte in DATCCW_HS
                     MOV CX, 0

WAIT2:               IN AL, 7     
                     TEST AL, 10000000B           ;test if stepper motor is ready to receive input
                     JZ WAIT2

                     MOV AL, [BX][SI]
                     OUT PORT_STEPPER, AL         ;rotate stepper motor counterclockwise by 1 half-step (11.25 degrees)
                     INC SI                       ;address next byte in DATCCW_HS
                     INC CX                       ;increase count for no. of half-steps executed

                     CMP CX, MAX_HALF_STEPS       ;check if CX reached count limit  
                     JAE EXIT_PROC2               ;exit procedure if CX reached count limit

                     CMP SI, 4                    ;check if SI is out of bounds of DATCCW_HS
                     JB WAIT2
                     MOV SI, 0                    ;reset back to first byte of DATCW_HS
                     JMP WAIT2

EXIT_PROC2:          RET                          ;return to main program
ENDP STEPPER_MOTOR_CLOSE   