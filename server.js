const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3005;
const DEV = process.argv.includes('--dev');

const MIME_TYPES = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.avi': 'application/octet-stream',
    '.rar': 'application/x-rar-compressed',
};

// SSE clients for live reload
const clients = new Set();

const server = http.createServer((req, res) => {
    // Live reload SSE endpoint
    if (req.url === '/__reload') {
        res.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
        });
        clients.add(res);
        req.on('close', () => clients.delete(res));
        return;
    }

    const urlPath = req.url.split('?')[0];
    let filePath = urlPath === '/' ? '/index.html' : urlPath;
    filePath = path.join(__dirname, 'public', filePath);

    if (urlPath === '/test-results.json') {
        filePath = path.join(__dirname, 'test-results.json');
    }

    if (urlPath.startsWith('/api/source/')) {
        const lang = urlPath.replace('/api/source/', '');
        return serveSource(lang, res);
    }

    const ext = path.extname(filePath);
    const contentType = MIME_TYPES[ext] || 'text/plain';

    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(err.code === 'ENOENT' ? 404 : 500);
            return res.end(err.code === 'ENOENT' ? 'Not Found' : 'Server Error');
        }

        // Inject live reload script and timestamp
        if (ext === '.html') {
            const ts = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
            const tsScript = `<script>document.getElementById('footer-ts')&&(document.getElementById('footer-ts').textContent='Last updated: ${ts}')</script>`;
            const devScript = DEV ? `<script>new EventSource('/__reload').onmessage=()=>location.reload()</script>` : '';
            content = content.toString().replace('</body>', tsScript + devScript + '</body>');
        }

        res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-cache, no-store, must-revalidate' });
        res.end(content);
    });
});

function serveSource(lang, res) {
    const implDir = path.join(__dirname, 'implementations');
    const fileMap = {
        'c': 'c/oshash.c', 'cpp': 'cpp/oshash.cpp', 'python': 'python/oshash.py',
        'nodejs': 'nodejs/oshash.js', 'typescript': 'typescript/oshash.ts',
        'java': 'java/OSHash.java', 'csharp': 'csharp/oshash.cs', 'php': 'php/oshash.php',
        'perl': 'perl/oshash.pl', 'ruby': 'ruby/oshash.rb', 'lua': 'lua/oshash.lua',
        'bash': 'bash/oshash.sh', 'go': 'go/oshash.go', 'rust': 'rust/src/main.rs',
        'scala': 'scala/oshash.scala', 'kotlin': 'kotlin/oshash.kt',
        'groovy': 'groovy/oshash.groovy', 'haskell': 'haskell/oshash.hs',
        'pascal': 'pascal/oshash.pas', 'lisp': 'lisp/oshash.lisp',
        'powershell': 'powershell/oshash.ps1', 'vala': 'vala/oshash.vala',
        'dart': 'dart/oshash.dart', 'r': 'r/oshash.R', 'elixir': 'elixir/oshash.exs',
        'nim': 'nim/oshash.nim', 'zig': 'zig/oshash.zig', 'swift': 'swift/oshash.swift',
        'crystal': 'crystal/oshash.cr', 'julia': 'julia/oshash.jl', 'd': 'd/oshash.d',
        'clojure': 'clojure/oshash.clj', 'ocaml': 'ocaml/oshash.ml',
        'fsharp': 'fsharp/oshash.fsx', 'fortran': 'fortran/oshash.f90',
        'asm': 'asm/oshash.asm', 'raku': 'raku/oshash.raku', 'vlang': 'vlang/oshash.v',
        'erlang': 'erlang/oshash.erl', 'tcl': 'tcl/oshash.tcl', 'awk': 'awk/oshash.awk',
        'ada': 'ada/oshash.adb', 'scheme': 'scheme/oshash.scm',
        'objc': 'objc/oshash.m', 'sml': 'sml/oshash.sml', 'cobol': 'cobol/oshash.cob',
        'forth': 'forth/oshash.fs', 'prolog': 'prolog/oshash.pl', 'smalltalk': 'smalltalk/oshash.st',
        'modula2': 'modula2/oshash.mod',
    };

    const file = fileMap[lang];
    if (!file) { res.writeHead(404); return res.end('Unknown language'); }

    fs.readFile(path.join(implDir, file), 'utf8', (err, content) => {
        if (err) { res.writeHead(500); return res.end('Error reading source'); }
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(content);
    });
}

server.listen(PORT, '0.0.0.0', () => {
    console.log(`${DEV ? '[DEV] ' : ''}OpenSubtitles Hash server on http://localhost:${PORT}`);
});

// Dev mode: watch public/ for changes and trigger reload
if (DEV) {
    const chokidar = require('chokidar');
    chokidar.watch(path.join(__dirname, 'public'), { ignoreInitial: true }).on('all', () => {
        for (const c of clients) c.write('data: reload\n\n');
    });
}
