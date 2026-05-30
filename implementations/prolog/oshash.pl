% OpenSubtitles Hash (OSHash) - Prolog implementation (GNU Prolog).
% hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
% GNU Prolog's integers are tag-limited (< 2^61), too small for a raw uint64, so
% the hash is kept as four 16-bit words with explicit carry (like the AWK/PHP
% ports). seek/4 truncates offsets to 32 bits, so the size and the last 64 KB
% come from stat/tail (the shell-out the Bash/AWK ports use).

:- initialization(main).

main :-
    ( argument_list([Path|_]) ->
        oshash(Path, Hex), format("~s~n", [Hex]), halt
    ; format(user_error, "Usage: oshash <file>~n", []), halt(1) ).

oshash(Path, Codes) :-
    file_size(Path, Size),
    open(Path, read, S1, [type(binary)]),
    read_words(S1, 8192, [0,0,0,0], H1),
    close(S1),
    shell_to(Path, 'tail -c 65536 "', '" > /tmp/oshash_pl_last'),
    open('/tmp/oshash_pl_last', read, S2, [type(binary)]),
    read_words(S2, 8192, H1, H2),
    close(S2),
    size_words(Size, SW),
    add4(H2, SW, H3),
    hash_hex(H3, Codes).

file_size(Path, Size) :-
    shell_to(Path, 'stat -c%s "', '" > /tmp/oshash_pl_size'),
    open('/tmp/oshash_pl_size', read, S, []),
    read_int_codes(S, Cs),
    close(S),
    number_codes(Size, Cs).

shell_to(Path, Pre, Post) :-
    atom_concat(Pre, Path, A), atom_concat(A, Post, Cmd), system(Cmd).

read_int_codes(S, Out) :-
    get_code(S, C),
    ( (C =:= -1 ; C =:= 0'\n) -> Out = []
    ; Out = [C|R], read_int_codes(S, R) ).

read_words(_, 0, Acc, Acc) :- !.
read_words(S, N, Acc, Out) :-
    get_byte(S, B0),
    ( B0 =:= -1 -> Out = Acc
    ; get_byte(S, B1), get_byte(S, B2), get_byte(S, B3),
      get_byte(S, B4), get_byte(S, B5), get_byte(S, B6), get_byte(S, B7),
      V0 is B0 + B1 * 256, V1 is B2 + B3 * 256,
      V2 is B4 + B5 * 256, V3 is B6 + B7 * 256,
      add4(Acc, [V0,V1,V2,V3], Acc1),
      N1 is N - 1,
      read_words(S, N1, Acc1, Out) ).

add4([A0,A1,A2,A3], [B0,B1,B2,B3], [R0,R1,R2,R3]) :-
    S0 is A0 + B0, R0 is S0 /\ 0xFFFF, C0 is S0 >> 16,
    S1 is A1 + B1 + C0, R1 is S1 /\ 0xFFFF, C1 is S1 >> 16,
    S2 is A2 + B2 + C1, R2 is S2 /\ 0xFFFF, C2 is S2 >> 16,
    S3 is A3 + B3 + C2, R3 is S3 /\ 0xFFFF.

size_words(Size, [W0,W1,W2,W3]) :-
    W0 is Size /\ 0xFFFF, W1 is (Size >> 16) /\ 0xFFFF,
    W2 is (Size >> 32) /\ 0xFFFF, W3 is (Size >> 48) /\ 0xFFFF.

hash_hex([W0,W1,W2,W3], Codes) :-
    hex4(W3, A), hex4(W2, B), hex4(W1, C), hex4(W0, D),
    append(A, B, AB), append(AB, C, ABC), append(ABC, D, Codes).

hex4(W, [C3,C2,C1,C0]) :-
    N3 is (W >> 12) /\ 15, N2 is (W >> 8) /\ 15,
    N1 is (W >> 4) /\ 15,  N0 is W /\ 15,
    nib(N3, C3), nib(N2, C2), nib(N1, C1), nib(N0, C0).

nib(N, C) :- ( N < 10 -> C is N + 0'0 ; C is N - 10 + 0'a ).
