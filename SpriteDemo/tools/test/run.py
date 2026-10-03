# Studio 없이 게임 로직을 돌려 보는 테스트 실행기.
#   python tools/test/run.py            (SpriteDemo 폴더에서)
# 하는 일: src/shared · src/server 의 .luau 모듈을 전부 한 파일로 묶고(모듈마다 함수로 감쌈), 로블록스 환경을 흉내 낸
#  가짜 환경(tools/test/mock.luau: game · script · require · Vector2 · Random · task(가짜 시계) …) 위에서
#  tools/test/tests/*.luau 를 차례로 실행한다. 실행은 tools/luau/luau.exe(공식 Luau).
# 클라이언트 화면 모듈(src/client)은 GUI가 필요해서 묶지 않는다 — 컴파일 검사(luau-compile)만 한다.
import os, subprocess, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LUAU = os.path.join(ROOT, 'tools', 'luau', 'luau.exe')
COMPILE = os.path.join(ROOT, 'tools', 'luau', 'luau-compile.exe')
OUT = os.path.join(HERE, '_bundle.luau')
NL = chr(10)

# client/modules/ui(도트 글씨 — 폭 재기 · 줄바꿈)는 화면 없이도 돌릴 수 있어 같이 묶는다
MOUNTS = [('shared', 'ReplicatedStorage/shared'), ('server', 'ServerScriptService/server'), ('client/modules/ui', 'Client/ui')]
PARAMS = 'script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick'

def compile_all():
    bad = 0; n = 0
    for f in glob.glob(os.path.join(SRC, '**', '*.luau'), recursive=True):
        n += 1
        r = subprocess.run([COMPILE, '--null', f], capture_output=True, text=True, encoding='utf-8', errors='replace')
        if 'Compiled' not in (r.stdout + r.stderr):
            bad += 1; print('  컴파일 실패', os.path.relpath(f, SRC), (r.stdout + r.stderr).strip())
    print(f'[컴파일] {n}개 파일, 실패 {bad}개')
    return bad

def bundle():
    parts = [open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read()]
    count = 0
    for folder, mount in MOUNTS:
        base = os.path.join(SRC, folder)
        for f in sorted(glob.glob(os.path.join(base, '**', '*.luau'), recursive=True)):
            rel = os.path.relpath(f, base).replace(os.sep, '/')
            name = rel[:-len('.luau')]
            if name.endswith('.server') or name.endswith('.client'):
                continue  # 스크립트(모듈이 아님)는 묶지 않는다
            src = open(f, encoding='utf-8').read()
            parts.append(f'MODULES[{mount + "/" + name!r}] = function({PARAMS})' + NL + src + NL + 'end')
            count += 1
    tests = sorted(glob.glob(os.path.join(HERE, 'tests', '*.luau')))
    only = [a for a in sys.argv[1:] if not a.startswith('-')]
    for t in tests:
        tname = os.path.basename(t)[:-5]
        if only and tname not in only:
            continue
        parts.append(f'runTest({tname!r}, function()' + NL + open(t, encoding='utf-8').read() + NL + 'end)')
    parts.append('finish()')
    open(OUT, 'w', encoding='utf-8', newline=NL).write(NL.join(parts))
    return count, len(tests)

def lint_ui_names():
    """클라이언트 코드가 글자로 적은 UI 부품 이름(아이콘 · 버튼 색 · 게이지 색 · 부품)이 UI 키트에 실제로 있는지 본다.
    없는 이름은 실행 중에야 터지므로(pixelUI.Part의 assert) 여기서 미리 잡는다."""
    import re
    kit = open(os.path.join(SRC, 'shared', 'data', 'uiKit.generated.luau'), encoding='utf-8').read()
    names = set(re.findall(r'^		(\w+) = \{ x = ', kit, re.M))
    icons = open(os.path.join(SRC, 'shared', 'data', 'itemIcons.generated.luau'), encoding='utf-8').read()
    names |= set(re.findall(r'^		(\w+) = \{ x = ', icons, re.M))
    rules = [
        (r'Icon = "(\w+)"', 'icon_%s'), (r'UI\.Icon\([^,()]+,\s*"(\w+)"', 'icon_%s'), (r'Image = "(\w+)"', '%s'),
        (r'[Cc]olor = "(\w+)"', 'button_%s'), (r'UI\.Bar\([^()]*"(\w+)"\)', 'bar_fill_%s'),
        (r'UI\.Part\([^,()]+,\s*"(\w+)"\s*[,)]', '%s'), (r'RectOffset\("(\w+)"\)', '%s'), (r'(?:then|else) "(tab_\w+|slot\w*)"', '%s'),
    ]
    bad = 0
    for f in glob.glob(os.path.join(SRC, 'client', '**', '*.luau'), recursive=True):
        rel = os.path.relpath(f, SRC).replace(os.sep, '/')
        for n, line in enumerate(open(f, encoding='utf-8').read().split(NL), 1):
            if line.strip().startswith('--') or 'lint: optional' in line:
                continue
            for pattern, fmt in rules:
                for m in re.finditer(pattern, line):
                    name = fmt % m.group(1)
                    if name not in names:
                        bad += 1; print(f'  UI 부품 없음 {name} ({rel}:{n})')
    print(f'[UI 부품 이름] 키트 부품 {len(names)}개, 없는 이름 {bad}개')
    return bad

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    bad = compile_all()
    bad += lint_ui_names()
    mods, tests = bundle()
    print(f'[묶음] 모듈 {mods}개 · 테스트 파일 {tests}개')
    r = subprocess.run([LUAU, OUT], capture_output=True, text=True, encoding='utf-8', errors='replace')
    print(r.stdout.rstrip())
    if r.stderr.strip():
        print(r.stderr.rstrip())
    sys.exit(1 if (bad or r.returncode != 0 or 'FAIL' in r.stdout) else 0)
