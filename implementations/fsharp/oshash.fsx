// OpenSubtitles Hash (OSHash) - F# implementation.
// Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)
open System
open System.IO

let chunkSize = 65536

let computeHash (filepath: string) =
    use stream = File.OpenRead(filepath)
    let filesize = stream.Length
    let mutable hash = uint64 filesize
    let buffer = Array.zeroCreate<byte> 8

    // Hash first 64KB
    for _ in 0 .. (chunkSize / 8 - 1) do
        stream.Read(buffer, 0, 8) |> ignore
        hash <- hash + BitConverter.ToUInt64(buffer, 0)

    // Hash last 64KB
    stream.Position <- max 0L (filesize - int64 chunkSize)
    for _ in 0 .. (chunkSize / 8 - 1) do
        stream.Read(buffer, 0, 8) |> ignore
        hash <- hash + BitConverter.ToUInt64(buffer, 0)

    sprintf "%016x" hash

[<EntryPoint>]
let main argv =
    if argv.Length < 1 then
        eprintfn "Usage: oshash <file>"
        1
    else
        printfn "%s" (computeHash argv.[0])
        0
