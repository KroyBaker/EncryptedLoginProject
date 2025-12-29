
; Login authentication program that:
; 1. Asks user to enter username and password
; 2. Verifies credentials against encrypted database
; 3. On success, displays "Hello, <username>"
; 4. Allows 3 total attempts before locking out
; 
; Register Usage:
; R0: holds input (from TRAP x20) & output (for TRAP x21) and string addresses
; R1: R0's right hand man :)
; R2: General comparator/flag register
; R3: Reserved for checking if the user pressed enter (holds NEGENTER value)
; R4: Database pointer for iterating through usernames
; R5: Pointer to matched password in database
; R6: Attempts counter (starts at 3, decrements on failure)
; R7: Return address for subroutines

        .ORIG   x3000                   ; Program starts at memory address x3000
        LD R6, ATTEMPTS                 ; Load R6 with 3 (number of attempts allowed)
        LD R3, NEGENTER                 ; Load R3 with -10 (negative of Enter key ASCII)
        
START   
        BRz MAX_ATTEMPTS_REACHED        ; If R6=0, no attempts left, branch to max attempts
        JSR GET_USERNAME                ; Call subroutine to get username into USERBUF
        JSR CHECK_USERNAME              ; Call subroutine to verify username exists
       
        BRz BAD_USER                    ; If R5=0 (not found), branch to BAD_USER
        LD R6, ATTEMPTS                 ; Reset password attempts to 3 for this user
        
GOOD_USER                               ; Username was found, now check password
        BRz MAX_ATTEMPTS_REACHED        ; If R6=0, no password attempts left
        LD  R3, NEGENTER                ; Reload R3 with -10 for Enter key checking
        JSR GET_PASSWORD                ; Call subroutine to get password into PASSBUF
        JSR CHECK_PASSWORD              ; Call subroutine to encrypt and compare password
        BRz BAD_PASS                    ; If R2=0 (no match), branch to BAD_PASS
        BR LOGIN_OK                     ; Password correct, branch to success message

;===============================================================================
; CLEAR_BUFFER Subroutine
; Clears 20 words of memory to remove sensitive data
; INPUT: R0 = pointer to buffer to clear
; MODIFIES: R0, R1, R2
;===============================================================================
CLEAR_BUFFER
        AND R2, R2, #0                  ; Set R2 = 0 (value to store in buffer)
        AND R1, R1, #0                  ; Clear R1
        ADD R1, R1, #15                 ; R1 = 15
        ADD R1, R1, #5                  ; R1 = 20 (counter for 20 words)
            
    CLEAR_LOOP
            STR R2, R0, #0              ; Store 0 at current memory location
            ADD R0, R0, #1              ; Increment pointer to next location
            ADD R1, R1, #-1             ; Decrement counter
            BRp CLEAR_LOOP              ; Continue if counter > 0
            RET                         ; Return to caller
        

BAD_USER                                ; Username not found in database
        LEA R0, MSG_BADUSER             ; Load address of "User not found" message
        TRAP x22                        ; PUTS: print error message
        LEA R0, USERBUF                 ; Load address of username buffer (for potential clearing)
        ADD R6, R6, #-1                 ; Decrement attempts counter
        BR START                        ; Branch back to start for new attempt

BAD_PASS                                ; Password incorrect
        LEA R0, MSG_BADPASS             ; Load address of "Password incorrect" message
        TRAP x22                        ; PUTS: print error message
        LEA R0, PASSBUF                 ; Load address of password buffer (for potential clearing)
        ADD R6, R6, #-1                 ; Decrement attempts counter
        BR GOOD_USER                    ; Branch back to ask for password again

;===============================================================================
; DONE - Successful Login Greeting
; Appends username to "Hello, " and displays the complete greeting
;===============================================================================
DONE
        LEA R1, HELLO                   ; R1 = starting address of "Hello, " string
        
        ; Find the end of the HELLO string (null terminator position)
    AGAIN   
            LDR R2, R1, #0              ; Load character at current position into R2
            BRz NEXT                    ; If null terminator (x0000), go to NEXT
            ADD R1, R1, #1              ; Increment pointer to next character
            BR AGAIN                    ; Continue searching for end of string
            
    NEXT    
            LEA R0, USERBUF             ; R0 = pointer to username buffer
        ; R1 now points to null terminator of HELLO string
        ; Copy username from USERBUF to end of HELLO string
        
        NEXTLOOP
            LDR R2, R0, #0              ; Load character from username buffer into R2
            BRz FINISHSUCCESS           ; If null terminator, done copying
            STR R2, R1, #0              ; Store character at end of HELLO string
            ADD R0, R0, #1              ; Increment source pointer (USERBUF)
            ADD R1, R1, #1              ; Increment destination pointer (HELLO)
            BR NEXTLOOP                 ; Continue copying characters
           
            
    FINISHSUCCESS
            LEA R0, HELLO               ; Load address of complete greeting string
            TRAP x22                    ; PUTS: output "Hello, <username>" to console
        FINISHFAIL                      ; Entry point for failed login termination
            TRAP x25                    ; HALT: terminate program

;===============================================================================
; LOGIN_OK - Successful Login Handler
; Displays success message and proceeds to greeting
;===============================================================================
LOGIN_OK
        LEA R0, MSG_LOGGEDIN            ; Load address of "Login successful!" message
        TRAP x22                        ; PUTS: print success message
        BR DONE                         ; Branch to display personalized greeting

;===============================================================================
; GET_USERNAME Subroutine
; Prompts user and reads username into USERBUF until Enter is pressed
; OUTPUT: USERBUF contains null-terminated username string
; MODIFIES: R0, R1, R2
;===============================================================================
GET_USERNAME    
        LEA R0, MSG_ENTERUSER           ; Load address of "Enter username: " prompt
        TRAP x22                        ; PUTS: print prompt
        LEA R1, USERBUF                 ; Load R1 with address of username buffer
        
    GULOOP  
            TRAP x20                    ; GETC: read one character from keyboard into R0
            TRAP x21                    ; OUT: echo character to console
            ADD R2, R0, R3              ; R2 = R0 + R3 (R3 = -10, checking for Enter)
            BRz ENDREADU                ; If R2=0, Enter was pressed, exit loop
          
            STR R0, R1, #0              ; Store character into username buffer
            ADD R1, R1, #1              ; Increment buffer pointer

            BR GULOOP                   ; Continue reading characters
            
    ENDREADU
            AND R0, R0, #0              ; Set R0 = 0 (null terminator)
            STR R0, R1, #0              ; Store null terminator at end of string
            RET                         ; Return to caller

;===============================================================================
; GET_PASSWORD Subroutine
; Prompts user and reads password into PASSBUF until Enter is pressed
; OUTPUT: PASSBUF contains null-terminated password string
; MODIFIES: R0, R1, R2
;===============================================================================
GET_PASSWORD
        LEA R0, MSG_ENTERPASS           ; Load address of "Enter password: " prompt
        TRAP x22                        ; PUTS: print prompt
        LEA R1, PASSBUF                 ; Load R1 with address of password buffer
        
READP   
        TRAP x20                        ; GETC: read one character from keyboard into R0
        TRAP x21                        ; OUT: echo character to console
        ADD R2, R0, R3                  ; R2 = R0 + R3 (checking for Enter key)
        BRz ENDREADP                    ; If R2=0, Enter was pressed, exit loop
        STR R0, R1, #0                  ; Store character into password buffer
        ADD R1, R1, #1                  ; Increment buffer pointer
        BR READP                        ; Continue reading characters
        
ENDREADP
        AND R0, R0, #0                  ; Set R0 = 0 (null terminator)
        STR R0, R1, #0                  ; Store null terminator at end of string
        RET                             ; Return to caller

;===============================================================================
; CHECK_PASSWORD Subroutine
; Encrypts PASSBUF and compares with stored encrypted password
; INPUT: R5 = pointer to stored encrypted password
; OUTPUT: R2 = 1 if match, 0 if no match (sets condition codes)
; MODIFIES: R0, R1, R2, R7
;===============================================================================
CHECK_PASSWORD
        LEA R0, PASSBUF                 ; Load address of password buffer
        ST R7, CHECKPASS_SLOT7          ; Save return address (will be overwritten by JSR)
        
        JSR DECRYPT_STRING              ; Encrypt the password in PASSBUF (misleading name)

        ADD R1, R5, #0                  ; R1 = R5 (pointer to stored password)
        LEA R0, PASSBUF                 ; R0 = pointer to encrypted user input
        JSR STRCMP                      ; Compare the two strings
        LD  R7, CHECKPASS_SLOT7         ; Restore return address
        ADD R2, R2, #0                  ; Set condition codes based on R2
        RET                             ; Return to caller

;===============================================================================
; DECRYPT_STRING Subroutine (Actually performs ENCRYPTION)
; Caesar cipher: shifts each character by +1
; INPUT: R0 = pointer to string to encrypt
; MODIFIES: R1, R2, and the string contents
;===============================================================================
DECRYPT_STRING
            ADD R1, R0, #0              ; R1 = R0 (copy pointer to string)

    DCLOOP  
            LDR R2, R1, #0              ; Load character from string
            BRz DCFINISH                ; If null terminator, exit loop
            ADD R2, R2, #1              ; Shift character by +1 (Caesar cipher)
            STR R2, R1, #0              ; Store encrypted character back
            ADD R1, R1, #1              ; Move to next character
            BR DCLOOP                   ; Continue encrypting
            
    DCFINISH 
            RET                         ; Return to caller

;===============================================================================
; STRCMP Subroutine
; Compares two null-terminated strings character by character
; INPUT: R0 = pointer to string1, R1 = pointer to string2
; OUTPUT: R2 = 1 if strings match, 0 if different
; MODIFIES: R0, R1, R2, R3, R4, R5
;===============================================================================
STRCMP
        ST R3, STRCMP_SAVE_R3           ; Save R3 on stack
        ST R4, STRCMP_SAVE_R4           ; Save R4 on stack
        ST R5, STRCMP_SAVE_R5           ; Save R5 on stack
        
        AND R2, R2, #0                  ; R2 = 0 (assume strings don't match)

    CMP_LOOP
        LDR R3, R0, #0                  ; Load character from string1
        LDR R4, R1, #0                  ; Load character from string2

        ADD R3, R3, #0                  ; Set condition codes for string1 char
        BRz CHECK_STR2                  ; If null, check if string2 also ended

        ADD R4, R4, #0                  ; Set condition codes for string2 char
        BRz MISMATCH                    ; If null but string1 wasn't, mismatch

        NOT R5, R3                      ; R5 = NOT R3
        ADD R5, R5, #1                  ; R5 = -R3 (two's complement)
        ADD R5, R5, R4                  ; R5 = R4 - R3

        BRnp MISMATCH                   ; If R5≠0, characters different, mismatch

        ADD R0, R0, #1                  ; Increment string1 pointer
        ADD R1, R1, #1                  ; Increment string2 pointer
        BR CMP_LOOP                     ; Continue comparing

    CHECK_STR2
        ADD R4, R4, #0                  ; Check if string2 also at null terminator
        BRnp MISMATCH                   ; If not null, strings different length
        BR MATCH                        ; Both null, strings match

    MISMATCH
        LD R3, STRCMP_SAVE_R3           ; Restore R3
        LD R4, STRCMP_SAVE_R4           ; Restore R4
        LD R5, STRCMP_SAVE_R5           ; Restore R5
        AND R2, R2, #0                  ; R2 = 0 (no match)
        RET                             ; Return to caller
    
    MATCH
        LD R3, STRCMP_SAVE_R3           ; Restore R3
        LD R4, STRCMP_SAVE_R4           ; Restore R4
        LD R5, STRCMP_SAVE_R5           ; Restore R5
        ADD R2, R2, #1                  ; R2 = 1 (match found)
        RET                             ; Return to caller
        
;===============================================================================
; MAX_ATTEMPTS_REACHED - Lockout Handler
; Called when user exceeds maximum number of login attempts
;===============================================================================            
MAX_ATTEMPTS_REACHED
        LEA R0, MSG_MAXATTEMPTS         ; Load address of max attempts message
        TRAP x22                        ; PUTS: print lockout message
        LEA R0, PASSBUF
        JSR CLEAR_BUFFER ;Clears password so 
        BR FINISHFAIL                   ; Branch to program termination
        
;===============================================================================
; CHECK_USERNAME Subroutine
; Searches database for matching username
; INPUT: USERBUF contains username to search for
; OUTPUT: R5 = pointer to encrypted password if found, 0 if not found
; MODIFIES: R0, R1, R2, R4, R5, R7
;===============================================================================
CHECK_USERNAME
        LEA R4, DB_USERNAMES            ; R4 = pointer to start of username database
        ST R7, CHECKUSER_SLOT7          ; Save return address
        
    NEXTUSER
            LDR R0, R4, #0              ; Load pointer to next username
            BRz NOUSER                  ; If null, reached end of database, not found
                
            ; Compare USERBUF with current username
            ADD R1, R0, #0              ; R1 = pointer to current username
            LEA R0, USERBUF             ; R0 = pointer to user input
            JSR STRCMP                  ; Compare the strings
            
            ADD R2, R2, #0              ; Set condition codes based on R2
            BRz NOMATCH                 ; If R2=0, no match, try next user
    
            ; MATCH FOUND
            ADD R5, R4, #1              ; R5 = R4 + 1 (points to password pointer)
            LDR R5, R5, #0              ; Load actual password address from database
        
            LD R7, CHECKUSER_SLOT7      ; Restore return address
            RET                         ; Return with R5 = password pointer

    NOMATCH
            ADD R4, R4, #3              ; Skip to next entry (3 words per entry)
            BR NEXTUSER                 ; Check next username
    
    NOUSER  
            LD R7, CHECKUSER_SLOT7      ; Restore return address
            AND R5, R5, #0              ; R5 = 0 (indicates not found)
            RET                         ; Return to caller
            
;===============================================================================
; DATA SECTION
;===============================================================================
HELLO       .STRINGZ    "Hello, "       ; Greeting string to be appended with username
            .BLKW       #25             ; Reserve 25 words for concatenated string
            
NEGENTER    .FILL       xFFF6           ; -10 in two's complement (negative of Enter key ASCII x0A)
ATTEMPTS    .FILL       #3              ; Initial number of login attempts allowed
STRCMP_SAVE_R3 .BLKW #1                 ; Storage for R3 during STRCMP
STRCMP_SAVE_R4 .BLKW #1                 ; Storage for R4 during STRCMP
STRCMP_SAVE_R5 .BLKW #1                 ; Storage for R5 during STRCMP
CHECKUSER_SLOT7 .BLKW   #1              ; Storage for R7 during CHECK_USERNAME
CHECKPASS_SLOT7 .BLKW   #1              ; Storage for R7 during CHECK_PASSWORD
USERBUF       .BLKW  #20                ; Buffer for username input (20 words)
PASSBUF       .BLKW  #20                ; Buffer for password input (20 words)
MSG_ENTERUSER .STRINGZ "Enter username: "       ; Username prompt
MSG_ENTERPASS .STRINGZ "Enter password: "       ; Password prompt
MSG_BADUSER   .STRINGZ "User not found.\n"      ; Invalid username message
MSG_BADPASS   .STRINGZ "Password incorrect.\n"  ; Invalid password message
MSG_LOGGEDIN  .STRINGZ "Login successful! \n"   ; Success message
MSG_MAXATTEMPTS .STRINGZ "Max attempts were exceeded, closing program now. \n"  ; Lockout message

;===============================================================================
; USER DATABASE
; Structure: Each entry contains 3 words:
;   - Word 0: Pointer to username string
;   - Word 1: Pointer to encrypted password string
;   - Word 2: Padding/reserved (0)
; Database ends with three null words
;===============================================================================
DB_USERNAMES
        .FILL U1                        ; Pointer to first username
        .FILL P1                        ; Pointer to first password (encrypted)
        .FILL #0                        ; Padding
        .FILL U2                        ; Pointer to second username
        .FILL P2                        ; Pointer to second password (encrypted)
        .FILL #0                        ; Padding
        .FILL U3                        ; Pointer to third username
        .FILL P3                        ; Pointer to third password (encrypted)
        .FILL #0                        ; Padding
        .FILL #0                        ; Terminator: indicates end of database
        .FILL #0                        ; Terminator continuation
        .FILL #0                        ; Terminator continuation
      
U1      .STRINGZ "panteater"            ; First username
P1      .STRINGZ "qfufs"                ; Encrypted password for "peter" (+1 shift)

U2      .STRINGZ "qv"                   ; Second username

P2      .STRINGZ "ifmmpuifsf\""        
        ; Encrypted password for "hellothere!" (+1 shift)

U3      .STRINGZ "areeb"                ; Third username
P3      .STRINGZ "nzqbttxpse"          ; Encrypted password for "mypassword" (+1 shift)

.END                                    ; End of program