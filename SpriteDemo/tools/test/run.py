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
MOUNTS = [('shared', 'ReplicatedStorage/shared'), ('server', 'ServerScriptService/server'), ('client/modules/ui', 'Client/ui'), ('client/lune', 'Client/lune')]
PARAMS = 'script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick'

def compile_all():
    bad = 0; n = 0
    for f in glob.glob(os.path.join(SRC, '**', '*.luau'), recursive=True):
        n += 1
        r = subprocess.run([COMPILE, '--null', f], capture_output=True, text=True, encoding='utf-8', errors='replace')
        if 'Compiled' not in (r.stdout + r.stderr) or 'Error' in (r.stdout + r.stderr) or r.returncode != 0:  # 문법 오류가 있어도 'Compiled 0 KLOC'이 찍힌다
            bad += 1; print('  컴파일 실패', os.path.relpath(f, SRC), (r.stdout + r.stderr).strip())
    print(f'[컴파일] {n}개 파일, 실패 {bad}개')
    return bad

def bundle():
    parts = [open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read()]
    # LUNE_PLAY=axion,salamander: tests/29_lune_playthrough.luau that plays to the 2nd job with those classes (unset = its short check only)
    play = os.environ.get('LUNE_PLAY', '')  # a trailing 0 ("axion0") = never visits the smith
    parts.append('PLAY_FULL = ' + ('"' + ''.join(c for c in play if c.isalnum() or c == ',') + '"' if play else 'nil'))
    # LUNE_PLAY_XP=2: a what-if for that playthrough - experience from Lv.10 on is multiplied (same as dividing the experience a level needs)
    try:
        parts.append('PLAY_XP = %g' % float(os.environ.get('LUNE_PLAY_XP', '1')))
    except ValueError:
        parts.append('PLAY_XP = 1')
    # LUNE_PLAY_NODODGE=1: the virtual player does NOT dodge story-boss attacks (it stands and hits) - measures whether the bosses can be beaten without dodging
    parts.append('PLAY_NODODGE = %s' % ('true' if os.environ.get('LUNE_PLAY_NODODGE') else 'false'))
    # LUNE_RAID=1: tests/104_lune_raid_dps.luau measures the 4-player max DPS against the weekly boss for real (about 2 minutes); unset = it only checks the recorded numbers against the boss HP
    parts.append('RAID_FULL = %s' % ('true' if os.environ.get('LUNE_RAID') else 'false'))
    # LUNE_RAID_LV=98,118: measure at these entry levels (normal,hard) instead of the weekly boss's own — sizing a new boss's HP (2026-10-29 용암 거인)
    rl = os.environ.get('LUNE_RAID_LV', '')
    parts.append('RAID_LV = %s' % (('{ normal = %d, hard = %d }' % tuple(int(x) for x in rl.split(',')[:2])) if rl else 'nil'))
    # LUNE_RAID_STAR=17,5: weapon/armor stars for the measured heroes (instead of RAIDDPS.gear) · LUNE_RAID_MAXSKILL=1: every skill of the hero's jobs at its max ·
    #   LUNE_RAID_BOSSLV=150: the boss level while measuring (instead of entry + 2) — sizing the Lv.150 lava giant (2026-11-03)
    rs = os.environ.get('LUNE_RAID_STAR', '')
    parts.append('RAID_STAR = %s' % (('{ weapon = %d, armor = %d }' % tuple(int(x) for x in rs.split(',')[:2])) if rs else 'nil'))
    parts.append('RAID_MAXSKILL = %s' % ('true' if os.environ.get('LUNE_RAID_MAXSKILL') else 'false'))
    parts.append('RAID_BOSSLV = %s' % (str(int(os.environ['LUNE_RAID_BOSSLV'])) if os.environ.get('LUNE_RAID_BOSSLV') else 'nil'))
    # LUNE_RAID_ONLY=salamander: only that class, alone (no parties, no checks) · LUNE_RAID_ENH=0.5: the salamander empowered skill's x times this (0 = off) — tuning one class quickly (2026-11-04)
    parts.append('RAID_ONLY = %s' % (('"%s"' % os.environ['LUNE_RAID_ONLY']) if os.environ.get('LUNE_RAID_ONLY') else 'nil'))
    parts.append('RAID_ENH = %s' % (repr(float(os.environ['LUNE_RAID_ENH'])) if os.environ.get('LUNE_RAID_ENH') else 'nil'))
    # LUNE_LANG_SWEEP=1: every dot-font text is translated to English while the tests run; finish() lists what could not be translated (mock.luau)
    parts.append('LANG_SWEEP = %s; SWEEP_MISSING = {}; SWEEP_TEST = ""' % ('true' if os.environ.get('LUNE_LANG_SWEEP') else 'false'))
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

def lint_windows():
    """「달의 계승자」의 화면 코드가 등록하는 창(Windows.register("id", …))이 공방의 창 목록(ui.generated.luau의 windows — 공방 design/basics.js의 WINDOWS)에 모두 있는지 본다.
    없으면 게임이 시작할 때 windows.luau의 assert(「공방에 없는 창」)로 멈춘다 — 2026-10-24 보스 창(weekly)을 목록에 빠뜨려 캐릭터 선택에서 「잠시만 기다려 주세요」로 멈췄다."""
    import re
    ui = open(os.path.join(SRC, 'shared', 'lune', 'data', 'ui.generated.luau'), encoding='utf-8').read()
    have = set(re.findall(r'\{ id = "(\w+)", name = "[^"]*", key = ', ui))
    bad, n = 0, 0
    for f in glob.glob(os.path.join(SRC, 'client', 'lune', '**', '*.luau'), recursive=True):
        for k, line in enumerate(open(f, encoding='utf-8').read().split(NL), 1):
            for m in re.finditer(r'Windows\.register\("(\w+)"', line):
                n += 1
                if m.group(1) not in have:
                    bad += 1; print(f'  공방 창 목록에 없는 창 {m.group(1)} ({os.path.relpath(f, SRC)}:{k}) — 공방 design/basics.js의 WINDOWS에 넣을 것')
    print(f'[창 등록] 등록 {n}곳, 공방 목록에 없는 창 {bad}개')
    return bad

def lint_packets():
    """「달의 계승자」의 화면 코드가 서버에 보내는 것(Net.FireServer · Net.Invoke("이름", …))의 인자 수가 패킷 정의(shared/lune/net/packets.luau의 Args)와 맞는지 본다.
    서버의 net.luau는 정의보다 많은 인자 · 모자란 인자(t.any가 아닌 자리)를 「형식에 맞지 않아 버려졌다」로 조용히 버린다 — 2026-11-04 Skill에 여섯째(살라맨더의 강화판)를 더하고
    정의를 고치지 않아 모든 기술이 버려졌다(사용자 "공격자체가 고장났는데"). 시험은 핸들러를 바로 불러 그 검사를 지나지 않았다."""
    import re
    def args_of(text, i):  # text[i] == '(' 또는 '{' — 맨 바깥의 쉼표로 나눈 조각들과 끝난 자리
        close = {'(': ')', '{': '}', '[': ']'}
        stack, parts, cur, j = [text[i]], [], '', i + 1
        while j < len(text) and stack:
            c = text[j]
            if c in (chr(34), chr(39), chr(96)):  # 따옴표 " ' ` 안은 건너뛴다
                k = j + 1
                while k < len(text) and text[k] != c:
                    k += 2 if text[k] == chr(92) else 1
                cur += text[j:k + 1]; j = k + 1; continue
            if text.startswith('--', j):
                k = text.find(NL, j); j = len(text) if k < 0 else k; continue
            if c in close:
                stack.append(c)
            elif c in ')}]':
                stack.pop()
                if not stack:
                    break
            elif c == ',' and len(stack) == 1:
                parts.append(cur.strip()); cur = ''; j += 1; continue
            cur += c; j += 1
        if cur.strip():
            parts.append(cur.strip())
        return parts, j
    src = open(os.path.join(SRC, 'shared', 'lune', 'net', 'packets.luau'), encoding='utf-8').read()
    defs = {}
    for m in re.finditer(r'^	(\w+) = \{', src, re.M):
        body, _ = args_of(src, m.end() - 1)
        for part in body:
            if part.startswith('Args = {'):
                defs[m.group(1)] = args_of(part, part.index('{'))[0]
    bad, n = 0, 0
    for f in glob.glob(os.path.join(SRC, 'client', 'lune', '**', '*.luau'), recursive=True):
        text = open(f, encoding='utf-8').read()
        for m in re.finditer(r'Net\.(FireServer|Invoke)\(\s*"(\w+)"', text):
            name = m.group(2)
            if name not in defs:
                continue
            parts, _ = args_of(text, text.index('(', m.start()))
            got, want = parts[1:], defs[name]
            n += 1
            line = text.count(NL, 0, m.start()) + 1
            if got and got[-1] == '...':
                continue
            if len(got) > len(want) or any(a != 't.any' for a in want[len(got):]):
                bad += 1; print(f'  인자 수가 패킷 정의와 다르다 {name}: 보냄 {len(got)} · 정의 {len(want)} ({os.path.relpath(f, SRC)}:{line}) — shared/lune/net/packets.luau의 Args를 고칠 것')
    print(f'[패킷 인자] 보내는 곳 {n}곳, 정의와 다른 곳 {bad}개')
    return bad

def lint_render_step():
    """「달의 계승자」의 화면 코드(src/client/lune)는 화면을 RunService.RenderStepped 이벤트(PreRender 포함)에서 고치면 안 된다 — RunService:BindToRenderStep으로 고친다.
    그 이벤트는 Roblox가 그 장의 틀 크기를 셈한 뒤에 불려서, 그림의 자리(ImageRect)는 이번 장에 · 틀의 크기(Size)는 다음 장에 적용된다.
    그러면 동작의 장이 바뀔 때마다 한 장씩 그림이 앞 장의 크기로 늘어나 그려진다(2026-10-10 캐릭터 만들기 화면 — 사용자의 영상 bug.mp4).
    chooser.luau는 쓰지 않는 예전 화면이라 뺀다(머리말에 적어 두었다)."""
    import re
    bad = 0; n = 0
    base = os.path.join(SRC, 'client', 'lune')
    for f in glob.glob(os.path.join(base, '**', '*.luau'), recursive=True):
        if os.path.basename(f) == 'chooser.luau':
            continue
        n += 1
        for k, line in enumerate(open(f, encoding='utf-8').read().split(NL), 1):
            code = line.split('--')[0]
            if re.search(r'\.(RenderStepped|PreRender)\s*:\s*(Connect|Once|Wait)', code):
                bad += 1; print(f'  RenderStepped 이벤트에서 화면을 고친다 ({os.path.relpath(f, SRC)}:{k}) — BindToRenderStep을 쓸 것')
    print(f'[화면을 고치는 때] 파일 {n}개, RenderStepped 이벤트를 쓰는 곳 {bad}개')
    return bad

def lint_globals():
    """새 게임(lune) 코드에서 정의되지 않은 이름을 쓰는 곳을 찾는다(luau-analyze의 "Unknown global").
    아래쪽에서 정의한 지역 변수를 위쪽 함수가 쓰면 Luau는 그것을 전역(nil)으로 본다 — 컴파일은 되고 실행 중에야 터지므로 여기서 잡는다."""
    import re
    known = {'script', 'game', 'workspace', 'Enum', 'Instance', 'task', 'UDim2', 'UDim', 'Color3', 'Vector2', 'Vector3', 'Random', 'warn', 'tick',
             'CFrame', 'TweenInfo', 'Rect', 'NumberSequence', 'ColorSequence', 'NumberRange', 'Font', 'shared', 'time', 'wait', 'spawn', 'delay', 'Content'}
    analyze = os.path.join(ROOT, 'tools', 'luau', 'luau-analyze.exe')
    files = [f for d in ('shared', 'server', 'client') for f in glob.glob(os.path.join(SRC, d, 'lune', '**', '*.luau'), recursive=True) if not f.endswith('.generated.luau')]
    if not os.path.exists(analyze) or not files:
        print('[전역 이름] luau-analyze가 없어 건너뜀'); return 0
    r = subprocess.run([analyze] + files, capture_output=True, text=True, encoding='utf-8', errors='replace')
    bad = 0
    for line in (r.stdout + r.stderr).split(NL):
        m = re.search(r"^(.*?\(\d+,\d+\)).*Unknown global '([^']+)'", line)
        if m and m.group(2) not in known:
            bad += 1; print(f'  정의되지 않은 이름 {m.group(2)} — {os.path.relpath(m.group(1).split("(")[0], SRC)}({m.group(1).split("(")[1]}')
    print(f'[전역 이름] 파일 {len(files)}개, 정의되지 않은 이름 {bad}개')
    return bad

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    bad = compile_all()
    bad += lint_ui_names()
    bad += lint_globals()
    bad += lint_render_step()
    bad += lint_windows()
    bad += lint_packets()
    mods, tests = bundle()
    print(f'[묶음] 모듈 {mods}개 · 테스트 파일 {tests}개')
    r = subprocess.run([LUAU, OUT], capture_output=True, text=True, encoding='utf-8', errors='replace')
    print(r.stdout.rstrip())
    if r.stderr.strip():
        print(r.stderr.rstrip())
    sys.exit(1 if (bad or r.returncode != 0 or 'FAIL' in r.stdout) else 0)
