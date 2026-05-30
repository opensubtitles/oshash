const LANGUAGES = [
    { id: 'ada', name: 'Ada', isNew: true },
    { id: 'awk', name: 'AWK', isNew: true },
    { id: 'bash', name: 'Bash', original: true },
    { id: 'c', name: 'C', original: true },
    { id: 'cpp', name: 'C++', original: true },
    { id: 'csharp', name: 'C#', original: true },
    { id: 'clojure', name: 'Clojure', isNew: true },
    { id: 'cobol', name: 'COBOL', isNew: true },
    { id: 'lisp', name: 'Common Lisp', original: true },
    { id: 'crystal', name: 'Crystal', isNew: true },
    { id: 'd', name: 'D', isNew: true },
    { id: 'dart', name: 'Dart', original: true },
    { id: 'elixir', name: 'Elixir', isNew: true },
    { id: 'erlang', name: 'Erlang', isNew: true },
    { id: 'fsharp', name: 'F#', isNew: true },
    { id: 'forth', name: 'Forth', isNew: true },
    { id: 'fortran', name: 'Fortran', isNew: true },
    { id: 'go', name: 'Go', original: true },
    { id: 'groovy', name: 'Groovy', original: true },
    { id: 'haskell', name: 'Haskell', original: true },
    { id: 'java', name: 'Java', original: true },
    { id: 'nodejs', name: 'JavaScript', original: true },
    { id: 'julia', name: 'Julia', isNew: true },
    { id: 'kotlin', name: 'Kotlin', original: true },
    { id: 'lua', name: 'Lua', original: true },
    { id: 'nim', name: 'Nim', isNew: true },
    { id: 'objc', name: 'Objective-C', isNew: true },
    { id: 'ocaml', name: 'OCaml', isNew: true },
    { id: 'pascal', name: 'Pascal', original: true },
    { id: 'perl', name: 'Perl', original: true },
    { id: 'php', name: 'PHP', original: true },
    { id: 'powershell', name: 'PowerShell', original: true },
    { id: 'prolog', name: 'Prolog', isNew: true },
    { id: 'python', name: 'Python', original: true },
    { id: 'r', name: 'R', isNew: true },
    { id: 'raku', name: 'Raku', isNew: true },
    { id: 'ruby', name: 'Ruby', original: true },
    { id: 'rust', name: 'Rust', original: true },
    { id: 'scala', name: 'Scala', original: true },
    { id: 'scheme', name: 'Scheme', isNew: true },
    { id: 'smalltalk', name: 'Smalltalk', isNew: true },
    { id: 'sml', name: 'Standard ML', isNew: true },
    { id: 'swift', name: 'Swift', original: true },
    { id: 'tcl', name: 'Tcl', isNew: true },
    { id: 'typescript', name: 'TypeScript', isNew: true },
    { id: 'vlang', name: 'V', isNew: true },
    { id: 'vala', name: 'Vala', original: true },
    { id: 'asm', name: 'x86-64 Assembly', isNew: true },
    { id: 'zig', name: 'Zig', isNew: true },
];

let testResults = [];
let sourceCache = {};

async function init() {
    try {
        const res = await fetch('test-results.json');
        if (res.ok) testResults = await res.json();
    } catch (e) {}

    renderSummary();
    renderPerformance();
    renderImplementations();
    setupFilters();
}

function renderPerformance() {
    const el = document.getElementById('perf-highlights');
    if (!el) return;
    const nameOf = id => (LANGUAGES.find(l => l.id === id) || {}).name;
    const rows = testResults
        .filter(r => r.status === 'PASS' && r.timeSec && r.timeSec !== '-')
        .map(r => ({ name: r.language, t: parseFloat(r.timeSec), m: parseFloat(r.memMB) }))
        .filter(r => !isNaN(r.t) && !isNaN(r.m));
    if (!rows.length) { el.style.display = 'none'; return; }

    const byTime = [...rows].sort((a, b) => a.t - b.t);
    const byMem = [...rows].sort((a, b) => a.m - b.m);
    const slowest = byTime[byTime.length - 1];
    const heaviest = byMem[byMem.length - 1];
    // "Fastest" is a cluster of near-instant native binaries, so report the count.
    const instant = rows.filter(r => r.t <= 0.02).length;

    const card = (label, value, sub) =>
        `<div class="perf-card"><div class="perf-label">${label}</div>` +
        `<div class="perf-value">${value}</div><div class="perf-sub">${sub}</div></div>`;

    el.innerHTML =
        card('Near-instant', `${instant}`, 'native binaries ≤ 0.02 s') +
        card('Leanest', `${byMem[0].m} MB`, byMem[0].name) +
        card('Heaviest', `${heaviest.m} MB`, heaviest.name) +
        card('Slowest', `${slowest.t}s`, slowest.name);
}

function getStatus(langName) {
    const r = testResults.find(r => r.language === langName);
    return r ? r.status : 'SKIP';
}

function getDetail(langName) {
    const r = testResults.find(r => r.language === langName);
    return r ? r.detail : '';
}

function getMetrics(langName) {
    const r = testResults.find(r => r.language === langName);
    if (!r || r.status !== 'PASS' || !r.timeSec || r.timeSec === '-') return null;
    return { time: r.timeSec, cpu: r.cpu, mem: r.memMB };
}

function renderSummary() {
    const pass = testResults.filter(r => r.status === 'PASS').length;
    const fail = testResults.filter(r => r.status === 'FAIL').length;
    const skip = LANGUAGES.length - pass - fail;
    const total = LANGUAGES.length;
    const allGood = fail === 0 && skip === 0;

    const el = document.getElementById('results-summary');
    const section = el.closest('section');

    if (allGood) {
        // Minimal: just a single line
        el.innerHTML = `<p class="all-pass">${pass}/${total} implementations verified</p>`;
    } else {
        // Show full breakdown when there are issues
        el.innerHTML = `
            <div class="results-cards">
                <div class="result-card pass"><div class="count">${pass}</div><div class="label">Verified</div></div>
                ${fail > 0 ? `<div class="result-card fail"><div class="count">${fail}</div><div class="label">Failed</div></div>` : ''}
                ${skip > 0 ? `<div class="result-card skip"><div class="count">${skip}</div><div class="label">Skipped</div></div>` : ''}
                <div class="result-card total"><div class="count">${total}</div><div class="label">Total</div></div>
            </div>
        `;
    }

    // Show filter bar only when there are mixed states
    const filterBar = document.getElementById('filter-bar');
    if (filterBar) {
        filterBar.style.display = allGood ? 'none' : 'flex';
    }
}

function renderImplementations(filter = 'all') {
    const container = document.getElementById('implementations-list');
    container.innerHTML = '';

    for (const lang of LANGUAGES) {
        const status = getStatus(lang.name);
        if (filter !== 'all' && status !== filter) continue;

        const detail = getDetail(lang.name);
        const m = getMetrics(lang.name);
        const card = document.createElement('div');
        card.className = 'impl-card';
        card.dataset.status = status;
        card.dataset.lang = lang.id;

        card.innerHTML = `
            <div class="impl-header" onclick="toggleCard(this)">
                <span class="impl-lang">${lang.name}${lang.isNew ? '<span class="impl-new">NEW</span>' : ''}</span>
                ${m ? `<span class="impl-time" title="Run time hashing the 4 GB test file">${m.time}s</span>` : ''}
                <span class="impl-badge ${status.toLowerCase()}">${status}</span>
                <span class="impl-toggle">&#9660;</span>
            </div>
            <div class="impl-body">
                ${detail ? `<div class="impl-detail">${escapeHtml(detail)}</div>` : ''}
                ${m ? `<div class="impl-metrics">
                    <span class="metric"><span class="metric-label">Time</span><span class="metric-val">${m.time}s</span></span>
                    <span class="metric"><span class="metric-label">CPU</span><span class="metric-val">${m.cpu}</span></span>
                    <span class="metric"><span class="metric-label">Peak memory</span><span class="metric-val">${m.mem} MB</span></span>
                    <span class="metric-note">whole-process, hashing the 4&nbsp;GB test file</span>
                </div>` : ''}
                <div class="impl-code-wrap">
                    <button class="copy-btn" onclick="copySource('${lang.id}', this)" title="Copy to clipboard">
                        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                            <path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 010 1.5h-1.5a.25.25 0 00-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 00.25-.25v-1.5a.75.75 0 011.5 0v1.5A1.75 1.75 0 019.25 16h-7.5A1.75 1.75 0 010 14.25z"/>
                            <path d="M5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0114.25 11h-7.5A1.75 1.75 0 015 9.25zm1.75-.25a.25.25 0 00-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 00.25-.25v-7.5a.25.25 0 00-.25-.25z"/>
                        </svg>
                        <span>Copy</span>
                    </button>
                    <pre class="impl-code" id="code-${lang.id}">Loading...</pre>
                </div>
            </div>
        `;

        container.appendChild(card);
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function toggleCard(header) {
    const card = header.parentElement;
    const wasOpen = card.classList.contains('open');
    card.classList.toggle('open');

    if (!wasOpen) {
        const langId = card.dataset.lang;
        loadSource(langId);
    }
}

const SOURCE_FILES = {
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
};

async function loadSource(langId) {
    const el = document.getElementById(`code-${langId}`);
    if (sourceCache[langId]) {
        el.textContent = sourceCache[langId];
        return;
    }

    // Try local API first (dev server), fall back to GitHub raw
    const urls = [
        `api/source/${langId}`,
        `https://raw.githubusercontent.com/opensubtitles/oshash/main/implementations/${SOURCE_FILES[langId]}`
    ];

    for (const url of urls) {
        try {
            const res = await fetch(url);
            if (res.ok) {
                const code = await res.text();
                sourceCache[langId] = code;
                el.textContent = code;
                return;
            }
        } catch (e) {}
    }
    el.textContent = 'Error loading source code';
}

async function copySource(langId, btn) {
    // Ensure source is loaded
    if (!sourceCache[langId]) {
        try {
            const res = await fetch(`/api/source/${langId}`);
            sourceCache[langId] = await res.text();
        } catch (e) {
            return;
        }
    }

    try {
        await navigator.clipboard.writeText(sourceCache[langId]);
        const span = btn.querySelector('span');
        span.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
            span.textContent = 'Copy';
            btn.classList.remove('copied');
        }, 2000);
    } catch (e) {
        // Fallback for non-HTTPS
        const textarea = document.createElement('textarea');
        textarea.value = sourceCache[langId];
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        const span = btn.querySelector('span');
        span.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
            span.textContent = 'Copy';
            btn.classList.remove('copied');
        }, 2000);
    }
}

function setupFilters() {
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            renderImplementations(btn.dataset.filter);
        });
    });
}

init();
