// OpenSubtitles Hash (OSHash) - Rust implementation.
use std::env;
use std::fs::{self, File};
use std::io::{BufReader, Read, Seek, SeekFrom};

const HASH_BLK_SIZE: u64 = 65536;

fn compute_hash(file: File, fsize: u64) -> Result<String, std::io::Error> {
    let mut buf = [0u8; 8];
    let mut hash_val: u64 = fsize;
    let iterations = HASH_BLK_SIZE / 8;

    let mut reader = BufReader::with_capacity(HASH_BLK_SIZE as usize, file);

    // Hash first 64KB
    for _ in 0..iterations {
        reader.read_exact(&mut buf)?;
        let word = u64::from_le_bytes(buf);
        hash_val = hash_val.wrapping_add(word);
    }

    // Hash last 64KB
    reader.seek(SeekFrom::Start(fsize - HASH_BLK_SIZE))?;
    for _ in 0..iterations {
        reader.read_exact(&mut buf)?;
        let word = u64::from_le_bytes(buf);
        hash_val = hash_val.wrapping_add(word);
    }

    Ok(format!("{:016x}", hash_val))
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <file>", args[0]);
        std::process::exit(1);
    }

    let fname = &args[1];
    let fsize = fs::metadata(fname).expect("Cannot stat file").len();
    if fsize < HASH_BLK_SIZE * 2 {
        eprintln!("File too small: {} bytes", fsize);
        std::process::exit(1);
    }

    let file = File::open(fname).expect("Cannot open file");
    let hash = compute_hash(file, fsize).expect("Error computing hash");
    println!("{}", hash);
}
