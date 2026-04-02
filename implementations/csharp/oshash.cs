// OpenSubtitles Hash (OSHash) - C# implementation.
using System;
using System.IO;

class OSHash
{
    static string ComputeHash(string filename)
    {
        using (Stream input = File.OpenRead(filename))
        {
            long streamsize = input.Length;
            ulong hash = (ulong)streamsize;

            byte[] buffer = new byte[sizeof(long)];
            long i = 0;

            // Hash first 64KB
            while (i < 65536 / sizeof(long) && input.Read(buffer, 0, sizeof(long)) > 0)
            {
                i++;
                unchecked { hash += BitConverter.ToUInt64(buffer, 0); }
            }

            // Hash last 64KB
            input.Position = Math.Max(0, streamsize - 65536);
            i = 0;
            while (i < 65536 / sizeof(long) && input.Read(buffer, 0, sizeof(long)) > 0)
            {
                i++;
                unchecked { hash += BitConverter.ToUInt64(buffer, 0); }
            }

            return hash.ToString("x16");
        }
    }

    static void Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("Usage: oshash <file>");
            Environment.Exit(1);
        }
        Console.WriteLine(ComputeHash(args[0]));
    }
}
