      ******************************************************************
      * OpenSubtitles Hash (OSHash) - COBOL implementation (GnuCOBOL).
      * hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last
      * 64KB). COMP-5 fields use the host's native (little-endian) byte
      * order and the full 8-byte binary range, so an 8-byte record read
      * straight into one IS the little-endian uint64; addition into an
      * 8-byte COMP-5 wraps modulo 2^64. The 64 KB chunks are extracted
      * with dd/tail (like the Bash and AWK ports) so we never stream a
      * multi-GB file.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. OSHASH.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT FIRST-FILE ASSIGN TO "/tmp/oshash_first"
               ORGANIZATION IS RECORD SEQUENTIAL
               FILE STATUS IS WS-FS.
           SELECT LAST-FILE ASSIGN TO "/tmp/oshash_last"
               ORGANIZATION IS RECORD SEQUENTIAL
               FILE STATUS IS WS-FS.
           SELECT SIZE-FILE ASSIGN TO "/tmp/oshash_size"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.
       DATA DIVISION.
       FILE SECTION.
       FD FIRST-FILE.
       01 FIRST-REC      PIC X(8).
       FD LAST-FILE.
       01 LAST-REC       PIC X(8).
       FD SIZE-FILE.
       01 SIZE-REC       PIC X(32).
       WORKING-STORAGE SECTION.
       01 WS-PATH        PIC X(4096).
       01 WS-CMD         PIC X(4200).
       01 WS-FS          PIC XX.
       01 WS-EOF         PIC X VALUE "N".
       01 WS-HASH        PIC 9(18) COMP-5 VALUE 0.
       01 WS-HASH-R REDEFINES WS-HASH.
          05 WS-HASH-BYTE PIC X OCCURS 8.
       01 WS-WORD        PIC 9(18) COMP-5.
       01 WS-WORD-R REDEFINES WS-WORD PIC X(8).
       01 WS-SIZE        PIC 9(18) COMP-5.
       01 WS-HEXDIGITS   PIC X(16) VALUE "0123456789abcdef".
       01 WS-HEX         PIC X(16).
       01 I              PIC 99.
       01 J              PIC 99.
       01 WS-BYTEVAL     PIC 999.
       01 WS-HI          PIC 99.
       01 WS-LO          PIC 99.
       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-PATH FROM COMMAND-LINE
           IF FUNCTION TRIM(WS-PATH) = SPACES
               DISPLAY "Usage: oshash <file>" UPON SYSERR
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

      *    NB: clear WS-CMD before each STRING — STRING leaves trailing bytes,
      *    and a shorter command would otherwise inherit the previous one's tail.
           MOVE SPACES TO WS-CMD
           STRING "stat -c%s '" DELIMITED BY SIZE
                  FUNCTION TRIM(WS-PATH) DELIMITED BY SIZE
                  "' > /tmp/oshash_size" DELIMITED BY SIZE
                  INTO WS-CMD
           CALL "SYSTEM" USING WS-CMD
           MOVE SPACES TO WS-CMD
           STRING "dd if='" DELIMITED BY SIZE
                  FUNCTION TRIM(WS-PATH) DELIMITED BY SIZE
                  "' bs=65536 count=1 of=/tmp/oshash_first 2>/dev/null"
                  DELIMITED BY SIZE
                  INTO WS-CMD
           CALL "SYSTEM" USING WS-CMD
           MOVE SPACES TO WS-CMD
           STRING "tail -c 65536 '" DELIMITED BY SIZE
                  FUNCTION TRIM(WS-PATH) DELIMITED BY SIZE
                  "' > /tmp/oshash_last" DELIMITED BY SIZE
                  INTO WS-CMD
           CALL "SYSTEM" USING WS-CMD

      *    file size
           OPEN INPUT SIZE-FILE
           READ SIZE-FILE
           CLOSE SIZE-FILE
           COMPUTE WS-SIZE = FUNCTION NUMVAL(SIZE-REC)
           ADD WS-SIZE TO WS-HASH

      *    first 64 KB (guard against a failed OPEN so we never spin forever)
           OPEN INPUT FIRST-FILE
           IF WS-FS = "00"
               MOVE "N" TO WS-EOF
               PERFORM UNTIL WS-EOF = "Y"
                   READ FIRST-FILE
                       AT END MOVE "Y" TO WS-EOF
                       NOT AT END
                           MOVE FIRST-REC TO WS-WORD-R
                           ADD WS-WORD TO WS-HASH
                   END-READ
               END-PERFORM
               CLOSE FIRST-FILE
           END-IF

      *    last 64 KB
           OPEN INPUT LAST-FILE
           IF WS-FS = "00"
               MOVE "N" TO WS-EOF
               PERFORM UNTIL WS-EOF = "Y"
                   READ LAST-FILE
                       AT END MOVE "Y" TO WS-EOF
                       NOT AT END
                           MOVE LAST-REC TO WS-WORD-R
                           ADD WS-WORD TO WS-HASH
                   END-READ
               END-PERFORM
               CLOSE LAST-FILE
           END-IF

      *    format 16 hex digits, most-significant byte first
           MOVE SPACES TO WS-HEX
           PERFORM VARYING I FROM 8 BY -1 UNTIL I < 1
               COMPUTE WS-BYTEVAL =
                   FUNCTION ORD(WS-HASH-BYTE(I)) - 1
               DIVIDE WS-BYTEVAL BY 16 GIVING WS-HI REMAINDER WS-LO
               COMPUTE J = (8 - I) * 2 + 1
               MOVE WS-HEXDIGITS(WS-HI + 1:1) TO WS-HEX(J:1)
               MOVE WS-HEXDIGITS(WS-LO + 1:1) TO WS-HEX(J + 1:1)
           END-PERFORM
           DISPLAY WS-HEX
           STOP RUN.
