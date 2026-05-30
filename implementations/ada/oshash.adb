--  OpenSubtitles Hash (OSHash) - Ada implementation.
--  hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
--  Unsigned_64 is a modular type, so addition wraps modulo 2**64 automatically.

with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Streams.Stream_IO; use Ada.Streams.Stream_IO;
with Ada.Streams;           use Ada.Streams;
with Ada.Text_IO;           use Ada.Text_IO;
with Interfaces;            use Interfaces;

procedure OSHash is

   Chunk : constant := 65536;

   --  Sum a buffer as little-endian unsigned 64-bit words.
   function Sum (Data : Stream_Element_Array) return Unsigned_64 is
      Total : Unsigned_64 := 0;
      Word  : Unsigned_64;
      Base  : Stream_Element_Offset;
   begin
      for I in 0 .. Natural (Data'Length) / 8 - 1 loop
         Word := 0;
         Base := Data'First + Stream_Element_Offset (I * 8);
         for B in 0 .. 7 loop
            Word := Word or
              Shift_Left (Unsigned_64 (Data (Base + Stream_Element_Offset (B))), 8 * B);
         end loop;
         Total := Total + Word;  --  modular: wraps at 2**64
      end loop;
      return Total;
   end Sum;

   --  16 lowercase hex digits.
   function Hex (Value : Unsigned_64) return String is
      Digits_Set : constant String := "0123456789abcdef";
      Result     : String (1 .. 16);
      V          : Unsigned_64 := Value;
   begin
      for I in reverse 1 .. 16 loop
         Result (I) := Digits_Set (Integer (V and 16#F#) + 1);
         V := Shift_Right (V, 4);
      end loop;
      return Result;
   end Hex;

   File     : Ada.Streams.Stream_IO.File_Type;
   Size     : Ada.Streams.Stream_IO.Count;
   First    : Stream_Element_Array (1 .. Chunk);
   Last     : Stream_Element_Array (1 .. Chunk);
   L1, L2   : Stream_Element_Offset;
   Hash     : Unsigned_64;
   Last_Pos : Ada.Streams.Stream_IO.Positive_Count;

begin
   if Argument_Count < 1 then
      Put_Line (Standard_Error, "Usage: oshash <file>");
      Set_Exit_Status (1);
      return;
   end if;

   Open (File, In_File, Argument (1));
   Size := Ada.Streams.Stream_IO.Size (File);

   Read (File, First, L1);

   if Size > Ada.Streams.Stream_IO.Count (Chunk) then
      Last_Pos := Ada.Streams.Stream_IO.Positive_Count
                    (Size - Ada.Streams.Stream_IO.Count (Chunk) + 1);
   else
      Last_Pos := 1;
   end if;
   Set_Index (File, Last_Pos);
   Read (File, Last, L2);
   Close (File);

   Hash := Unsigned_64 (Size)
         + Sum (First (First'First .. L1))
         + Sum (Last (Last'First .. L2));

   Put_Line (Hex (Hash));
end OSHash;
