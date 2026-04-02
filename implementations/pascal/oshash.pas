{
  OpenSubtitles Hash (OSHash) - Free Pascal implementation.
}
{$mode objfpc}{$H+}
program oshash;

uses SysUtils, Classes;

function ComputeHash(const FileName: string): string;
var
    Stream: TFileStream;
    hashQ: QWord;
    s: array[0..7] of Byte;
    tmp: QWord absolute s;
    i, bytesRead: Integer;
begin
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
        hashQ := Stream.Size;

        i := 0;
        bytesRead := 1;
        while (i < 8192) and (bytesRead > 0) do
        begin
            FillChar(s, SizeOf(s), 0);
            bytesRead := Stream.Read(s, SizeOf(s));
            if bytesRead > 0 then
                hashQ := hashQ + tmp;
            Inc(i);
        end;

        Stream.Seek(-65536, soFromEnd);

        i := 0;
        bytesRead := 1;
        while (i < 8192) and (bytesRead > 0) do
        begin
            FillChar(s, SizeOf(s), 0);
            bytesRead := Stream.Read(s, SizeOf(s));
            if bytesRead > 0 then
                hashQ := hashQ + tmp;
            Inc(i);
        end;

        Result := LowerCase(Format('%.16x', [hashQ]));
    finally
        Stream.Free;
    end;
end;

begin
    if ParamCount < 1 then
    begin
        WriteLn(StdErr, 'Usage: oshash <file>');
        Halt(1);
    end;
    WriteLn(ComputeHash(ParamStr(1)));
end.
