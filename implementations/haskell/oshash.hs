-- OpenSubtitles Hash (OSHash) - Haskell implementation.
module Main where

import qualified Data.ByteString as BS
import Data.Word (Word64, Word8)
import Data.Bits (shiftL, (.|.))
import System.Environment (getArgs)
import System.IO (openBinaryFile, hClose, hFileSize, hSeek, IOMode(ReadMode),
                  SeekMode(AbsoluteSeek, SeekFromEnd))
import Control.Exception (bracket)
import Text.Printf (printf)

chunkSize :: Int
chunkSize = 65536

bytesToWord64LE :: [Word8] -> Word64
bytesToWord64LE bs = foldl (\acc (b, i) -> acc .|. (fromIntegral b `shiftL` (i * 8))) 0
                     (zip bs [0..7])

sumChunk :: BS.ByteString -> Word64
sumChunk bs
    | BS.length bs < 8 = 0
    | otherwise =
        let (chunk, rest) = BS.splitAt 8 bs
            val = bytesToWord64LE (BS.unpack chunk)
        in val + sumChunk rest

computeHash :: FilePath -> IO Word64
computeHash filename = bracket (openBinaryFile filename ReadMode) hClose $ \h -> do
    fs <- hFileSize h
    hSeek h AbsoluteSeek 0
    beginData <- BS.hGet h chunkSize
    hSeek h SeekFromEnd (negate (fromIntegral chunkSize))
    endData <- BS.hGet h chunkSize
    let hash = fromIntegral fs + sumChunk beginData + sumChunk endData
    return hash

main :: IO ()
main = do
    args <- getArgs
    case args of
        [fn] -> do
            h <- computeHash fn
            printf "%016x\n" h
        _ -> putStrLn "Usage: oshash <file>"
