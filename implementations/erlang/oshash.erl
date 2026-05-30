#!/usr/bin/env escript
%%! -noshell
%% OpenSubtitles Hash (OSHash) - Erlang implementation.
%% hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB),
%% wrapping at 64 bits. Erlang integers are arbitrary precision, so the sum
%% is masked back to 64 bits at the end.

-define(CHUNK, 65536).
-define(MASK64, 16#FFFFFFFFFFFFFFFF).

main([Filename]) ->
    Size = filelib:file_size(Filename),
    {ok, Fd} = file:open(Filename, [read, binary, raw]),
    {ok, First} = file:pread(Fd, 0, ?CHUNK),
    LastOffset = erlang:max(0, Size - ?CHUNK),
    {ok, Last} = file:pread(Fd, LastOffset, ?CHUNK),
    ok = file:close(Fd),
    Hash = (Size + sum64(First, 0) + sum64(Last, 0)) band ?MASK64,
    io:format("~s~n", [pad16(string:to_lower(integer_to_list(Hash, 16)))]);
main(_) ->
    io:format(standard_error, "Usage: oshash.erl <file>~n", []),
    halt(1).

%% Sum the binary as little-endian unsigned 64-bit integers.
sum64(<<X:64/little-unsigned, Rest/binary>>, Acc) -> sum64(Rest, Acc + X);
sum64(_, Acc) -> Acc.

%% Left-pad a hex string to 16 characters.
pad16(S) when length(S) >= 16 -> S;
pad16(S) -> pad16([$0 | S]).
