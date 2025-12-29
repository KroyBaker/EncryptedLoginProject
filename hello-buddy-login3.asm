;Problem 9.30
;
; Program asks user to enter their name, then greets the user:
; > Please enter your name: <user input>
; > Hello, <user input>
;
; 
; R0: holds the input (from TRAP x20) & uses as output (for TRAP x21) and starting addresses for output strings
; R1: R0's right hand man :d
; R2: General Comparator/Flag
; R3: Reserved for checking if the user clicked enter
; R4: 
; R6: basic counter to check if 3 times they tried
; R7: Used to return back from subroutine!!!
; ...

        .ORIG   x3000
        LD R6, ATTEMPTS
        LD R3, NEGENTER ;Making sure R3 is reserved for NEGENTER
START   
        BRz MAX_ATTEMPTS_REACHED
        JSR GET_USERNAME       ; gets username into USERBUF
        JSR CHECK_USERNAME     ; sets R5 = pointer to user entry or 0 if invalid
       
        BRz BAD_USER           ; not found
        LD R6, ATTEMPTS
        
GOOD_USER
        ; R5 = pointer to matching user entry
        BRz MAX_ATTEMPTS_REACHED
        LD  R3, NEGENTER       ;Reput R3 as being NEGENTER
        JSR GET_PASSWORD       ; gets password into PASSBUF
        JSR CHECK_PASSWORD     ; compares against encrypted stored password
        BRz BAD_PASS           ; incorrect
        
LOGIN_OK
        LEA R0, MSG_LOGGEDIN
        TRAP x22
        BR DONE

BAD_USER
        LEA R0, MSG_BADUSER
        TRAP x22
        LEA R0, USERBUF
        ADD R6, R6, #-1 ;Decrements our attempts counter
        BR START

BAD_PASS
        LEA R0, MSG_BADPASS 
        TRAP x22
        LEA R0, PASSBUF 
        ADD R6, R6, #-1 ;Decrements our attempts counter
        BR GOOD_USER ;Asks for password again

DONE   ;Program is finished!
        LEA R0, PASSBUF
        JSR CLEAR_BUFFER
        TRAP x25

;Clear BUFFERS

CLEAR_BUFFER ;Simple subroutine to clear the subroutines so that data stored from user isn't stored into system (would defeat the purpose :/)
        ;Uses R0 as pointer
        AND R2, R2, #0             ; R2 = 0 (value to store)
        AND R1, R1, #0             
        ADD R1, R1, #15            
        ADD R1, R1, #5             ; R1 = 20 (counter)
            
    CLEAR_LOOP
            STR R2, R0, #0             ; Store 0 at current position
            ADD R0, R0, #1             ; Increment pointer
            ADD R1, R1, #-1            ; Decrement counter
            BRp CLEAR_LOOP             ; Continue if counter > 0
            RET
            




GET_USERNAME    
        LEA R0, MSG_ENTERUSER   ;Starts from getting Enter username message
        TRAP x22
        LEA R1, USERBUF
    GULOOP  TRAP x20              ; GETC
            TRAP x21              ; OUT (output char for user on console)
            ADD R2, R0, R3        ; Checks to see if user clicked enter
            BRz ENDREADU          
          
            STR R0, R1, #0        ;Stores R0 into the USERBUFFER
            ADD R1, R1, #1

            BR GULOOP
            
    ENDREADU
            AND R0, R0, #0
            STR R0, R1, #0        ; store NULL
            RET



; --- GET_PASSWORD ---
; Same as GET_USERNAME, but stores into PASSBUF
GET_PASSWORD
        LEA R0, MSG_ENTERPASS
        TRAP x22

        LEA R1, PASSBUF
READP   TRAP x20
        TRAP x21
        ADD R2, R0, R3
        BRz ENDREADP
        STR R0, R1, #0
        ADD R1, R1, #1
        BR READP
ENDREADP
        AND R0, R0, #0
        STR R0, R1, #0
        RET

; --- CHECK_PASSWORD ---
; Encrypt PASSBUF and compare with stored encrypted password
CHECK_PASSWORD
        LEA R0, PASSBUF
        ST R7, CHECKPASS_SLOT7 ;Stores return address cuz this thing gonna get LOST
        
        JSR ENCRYPT_STRING

        ; Compare PASSBUF with password stored at R5
        ADD R1, R5, #0
        LEA R0, PASSBUF
        JSR STRCMP
        LD  R7, CHECKPASS_SLOT7
        ADD R2, R2, #0
        RET

; --- Decrypt? String ---
ENCRYPT_STRING
            ADD R1, R0, #0
    ENCLOOP LDR R2, R1, #0
            BRz ENCFINISH
            ADD R2, R2, #1      
            STR R2, R1, #0
            ADD R1, R1, #1
            BR ENCLOOP
    ENCFINISH 
            RET

; --- STRCMP ---
; Used to compare the two strings
; INPUT: R0 = str1, R1 = str2
; OUTPUT: R2 = 1 if equal, 0 if not
; STRCMP
; R0 = pointer to string1
; R1 = pointer to string2
; R2 = 1 if equal, 0 otherwise
; --- CHECK_USERNAME ---
; INPUT: USERBUF
; OUTPUT: R5 = pointer to matching user entry or 0
CHECK_USERNAME
        LEA R4, DB_USERNAMES  ; start of DB
        ST R7, CHECKUSER_SLOT7
    NEXTUSER
            LDR R0, R4, #0
            BRz NOUSER            ; reached end of DB
    
            ; Compare strings USERBUF with R0, which points to username
            
            ; JSR STRCMP returns R2=1 if match
            ADD R1, R0, #0       ; Uses R1 as temporary variable to check if equal
            LEA R0, USERBUF      ; Loads UserBUFF into R0
            JSR STRCMP
            
            ADD R2, R2, #0
            BRz NOMATCH
    
            ; MATCH FOUND
            
            
            ADD R5, R4, #1      ; password pointer stored 2 words later
            LDR R5, R5, #0       ; load actual password address
        
            LD R7, CHECKUSER_SLOT7 ;Gets back previous return address
            RET

    NOMATCH
           
            ADD R4, R4, #3       ; skip username ptr, password ptr, and padding And checks to see if the next slot in memory is the user
            BR NEXTUSER
    
    NOUSER  
            LD R7, CHECKUSER_SLOT7 ;Gets back previous return address
            AND R5, R5, #0       ; R5 = 0 means not found
            RET
            
STRCMP
        ; Save registers that will be modified
        ST R3, STRCMP_SAVE_R3
        ST R4, STRCMP_SAVE_R4
        ST R5, STRCMP_SAVE_R5
        
        AND R2, R2, #0      ; R2 = 0 (assume not equal)

    CMP_LOOP
        ; load characters
        LDR R3, R0, #0      ; char from string1
        LDR R4, R1, #0      ; char from string2

        ; check if we've reached end of string1
        ADD R3, R3, #0
        BRz CHECK_STR2      

        ; check if we've reached end of string2
        ADD R4, R4, #0
        BRz MISMATCH        

        ; compare characters using 2's complement
        NOT R5, R3
        ADD R5, R5, #1
        ADD R5, R5, R4      ; R5 = R4 - R3

        BRnp MISMATCH       

        ; characters matched → increment pointers
        ADD R0, R0, #1
        ADD R1, R1, #1
        BR CMP_LOOP

    CHECK_STR2
        ADD R4, R4, #0      
        BRnp MISMATCH       
        BR MATCH

    MISMATCH
        ; Restore registers
        LD R3, STRCMP_SAVE_R3
        LD R4, STRCMP_SAVE_R4
        LD R5, STRCMP_SAVE_R5
        AND R2, R2, #0      ; R2 = 0
        RET
    
    MATCH
        ; Restore registers
        LD R3, STRCMP_SAVE_R3
        LD R4, STRCMP_SAVE_R4
        LD R5, STRCMP_SAVE_R5
        ADD R2, R2, #1      ; R2 = 1 → match
        RET
            
MAX_ATTEMPTS_REACHED
        LEA R0, MSG_MAXATTEMPTS
        TRAP x22
        BR DONE
; -----
;DATA SECTION!!!!
;-----
HELLO       .STRINGZ    "Hello, "

            
NEGENTER    .FILL       xFFF6       ; -x0A
ATTEMPTS    .FILL       #3
STRCMP_SAVE_R3 .BLKW #1
STRCMP_SAVE_R4 .BLKW #1
STRCMP_SAVE_R5 .BLKW #1

CHECKUSER_SLOT7 .BLKW   #1  
CHECKPASS_SLOT7 .BLKW   #1  
USERBUF       .BLKW  #20
PASSBUF       .BLKW  #20
MSG_ENTERUSER .STRINGZ "Enter username: "
MSG_ENTERPASS .STRINGZ "Enter password: "
MSG_BADUSER   .STRINGZ "User not found.\n"
MSG_BADPASS   .STRINGZ "Password incorrect.\n"
MSG_LOGGEDIN  .STRINGZ "Login successful! \n"
MSG_MAXATTEMPTS .STRINGZ "Max attempts were exceeded, closing program now. \n"



DB_USERNAMES
        .FILL U1
        .FILL P1
        .FILL #0
        .FILL U2
        .FILL P2
        .FILL #0
        .FILL U3
        .FILL P3
        .FILL #0
        .FILL #0             ; terminator Lets program know that no more usernames exist
        .FILL #0
        .FILL #0
        
U1      .STRINGZ "panteater"
P1      .STRINGZ "qfufs"     ; "peter" +1 each char

U2      .STRINGZ "qv"

P2      .STRINGZ "ifmmpuifsf\"" 
; "hellothere!" +1 encryption

U3      .STRINGZ "areeb"
P3      .STRINGZ "nzqbttxpse"   ; "mypassword" shift +1

.END