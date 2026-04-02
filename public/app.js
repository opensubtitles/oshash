const LANGUAGES = [
    // Systems
    { id: 'c', name: 'C', original: true },
    { id: 'cpp', name: 'C++', original: true },
    { id: 'rust', name: 'Rust', original: true },
    { id: 'zig', name: 'Zig', isNew: true },
    { id: 'go', name: 'Go', original: true },
    { id: 'd', name: 'D', isNew: true },
    { id: 'nim', name: 'Nim', isNew: true },
    { id: 'crystal', name: 'Crystal', isNew: true },
    { id: 'swift', name: 'Swift', original: true },
    // JVM
    { id: 'java', name: 'Java', original: true },
    { id: 'kotlin', name: 'Kotlin', original: true },
    { id: 'scala', name: 'Scala', original: true },
    { id: 'groovy', name: 'Groovy', original: true },
    { id: 'clojure', name: 'Clojure', isNew: true },
    // .NET
    { id: 'csharp', name: 'C#', original: true },
    { id: 'fsharp', name: 'F#', isNew: true },
    // Scripting
    { id: 'python', name: 'Python', original: true },
    { id: 'nodejs', name: 'Node.js', original: false },
    { id: 'typescript', name: 'TypeScript', isNew: true },
    { id: 'ruby', name: 'Ruby', original: true },
    { id: 'php', name: 'PHP', original: true },
    { id: 'perl', name: 'Perl', original: true },
    { id: 'lua', name: 'Lua', original: true },
    { id: 'elixir', name: 'Elixir', isNew: true },
    { id: 'r', name: 'R', isNew: true },
    { id: 'dart', name: 'Dart', original: true },
    { id: 'julia', name: 'Julia', isNew: true },
    // Shell
    { id: 'bash', name: 'Bash', original: true },
    { id: 'powershell', name: 'PowerShell', original: true },
    // Functional
    { id: 'haskell', name: 'Haskell', original: true },
    { id: 'ocaml', name: 'OCaml', isNew: true },
    { id: 'lisp', name: 'Common Lisp', original: true },
    // Other
    { id: 'pascal', name: 'Pascal', original: true },
    { id: 'vala', name: 'Vala', original: true },
    { id: 'fortran', name: 'Fortran', isNew: true },
    { id: 'asm', name: 'x86-64 Assembly', isNew: true },
    { id: 'raku', name: 'Raku', isNew: true },
    { id: 'vlang', name: 'V', isNew: true },
];

let testResults = [];
let sourceCache = {};

async function init() {
    try {
        const res = await fetch('/test-results.json');
        if (res.ok) testResults = await res.json();
    } catch (e) {}

    renderSummary();
    renderImplementations();
    setupFilters();
}

function getStatus(langName) {
    const r = testResults.find(r => r.language === langName);
    return r ? r.status : 'SKIP';
}

function getDetail(langName) {
    const r = testResults.find(r => r.language === langName);
    return r ? r.detail : '';
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
        const card = document.createElement('div');
        card.className = 'impl-card';
        card.dataset.status = status;
        card.dataset.lang = lang.id;

        card.innerHTML = `
            <div class="impl-header" onclick="toggleCard(this)">
                <span class="impl-lang">${lang.name}${lang.isNew ? '<span class="impl-new">NEW</span>' : ''}</span>
                <span class="impl-badge ${status.toLowerCase()}">${status}</span>
                <span class="impl-toggle">&#9660;</span>
            </div>
            <div class="impl-body">
                ${detail ? `<div class="impl-detail">${escapeHtml(detail)}</div>` : ''}
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
};

async function loadSource(langId) {
    const el = document.getElementById(`code-${langId}`);
    if (sourceCache[langId]) {
        el.textContent = sourceCache[langId];
        return;
    }

    // Try local API first (dev server), fall back to GitHub raw
    const urls = [
        `/api/source/${langId}`,
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
