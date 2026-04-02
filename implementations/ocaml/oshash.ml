(* OpenSubtitles Hash (OSHash) - OCaml implementation.
   Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB) *)

let chunk_size = 65536

let read_le_u64 buf offset =
  let b i = Int64.of_int (Char.code (Bytes.get buf (offset + i))) in
  let shift i n = Int64.shift_left (b i) (n * 8) in
  Int64.logor (b 0)
    (Int64.logor (shift 1 1)
      (Int64.logor (shift 2 2)
        (Int64.logor (shift 3 3)
          (Int64.logor (shift 4 4)
            (Int64.logor (shift 5 5)
              (Int64.logor (shift 6 6) (shift 7 7)))))))

let compute_hash filepath =
  let ic = open_in_bin filepath in
  let fsize = in_channel_length ic in
  let hash = ref (Int64.of_int fsize) in
  let buf = Bytes.create chunk_size in

  (* Hash first 64KB *)
  really_input ic buf 0 chunk_size;
  for i = 0 to (chunk_size / 8) - 1 do
    hash := Int64.add !hash (read_le_u64 buf (i * 8))
  done;

  (* Hash last 64KB *)
  seek_in ic (max 0 (fsize - chunk_size));
  really_input ic buf 0 chunk_size;
  for i = 0 to (chunk_size / 8) - 1 do
    hash := Int64.add !hash (read_le_u64 buf (i * 8))
  done;

  close_in ic;
  Printf.sprintf "%016Lx" !hash

let () =
  if Array.length Sys.argv < 2 then
    (Printf.eprintf "Usage: oshash <file>\n"; exit 1)
  else
    print_endline (compute_hash Sys.argv.(1))
