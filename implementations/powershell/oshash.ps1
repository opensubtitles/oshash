# OpenSubtitles Hash (OSHash) - PowerShell implementation.

param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

function LongSum([UInt64]$a, [UInt64]$b) {
    [UInt64](([Decimal]$a + $b) % ([Decimal]([UInt64]::MaxValue) + 1))
}

function StreamHash([IO.Stream]$stream) {
    $dataLength = 65536
    $hashLength = 8
    [UInt64]$lhash = 0
    [byte[]]$buffer = New-Object byte[] $hashLength
    $i = 0
    while (($i -lt ($dataLength / $hashLength)) -and ($stream.Read($buffer, 0, $hashLength) -gt 0)) {
        $i++
        $lhash = LongSum $lhash ([BitConverter]::ToUInt64($buffer, 0))
    }
    $lhash
}

function MovieHash([string]$path) {
    try {
        $stream = [IO.File]::OpenRead($path)
        [UInt64]$lhash = $stream.Length
        $lhash = LongSum $lhash (StreamHash $stream)
        $stream.Position = [Math]::Max(0L, $stream.Length - 65536)
        $lhash = LongSum $lhash (StreamHash $stream)
        "{0:x16}" -f $lhash
    }
    finally {
        $stream.Close()
    }
}

MovieHash $Path
