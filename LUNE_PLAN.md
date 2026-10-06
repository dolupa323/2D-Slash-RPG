# LUNE_PLAN — 「달의 계승자」(횡스크롤 MMORPG) 로블록스 개발 작업 메모 (Claude 작업용)

> 시작: 2026-10-06 사용자 "오케이 이제 우리 로블록스에서 본격적인 개발에 착수해봅시다".
> 단계와 진행 상태는 **공방 자료가 기준**이다: `dino-workshop/js/lune/design/devplan.js` → 공방 「개발 진행」 탭(http://localhost:8090/#dev). 단계가 끝날 때마다 그 파일을 고친다.
> 설계 기준은 공방의 설계 자료(`dino-workshop/js/lune/design/*.js`)와 탭들이다. 예전 닌자 게임 문서(NINJA_PLAN.md · NINJA_DESIGN.md)는 기준이 아니다.

## 어디에 무엇이 있나

- 게임 코드: `SpriteDemo/` (Rojo 프로젝트, Studio 플레이스 「슬래시 RPG」에 연결). 새 게임은 아래 세 곳에만 둔다.
  - `src/shared/lune/` — `config/game.luau`(상수) · `config/numbers.luau`(숫자 뼈대의 식 — 공방과 같은 값인지 테스트 11이 맞춰 본다) ·
    `sim/physics.luau`(움직임) · `sim/hero.luau`(체력 · 경험치 · 물약 · 쓰러짐) · `sim/room.luau`(졸개의 움직임과 공격 · 기술 판정 · 보상 · 줍기) ·
    `sim/quests.luau`(퀘스트: 받기 · 세기 · 돌려주기 — 서버와 클라이언트가 같은 함수를 쓴다) · `sim/party.luau`(파티 장부 · 경험치 몫) · `ui/tags.luau`(이름표 쌓기 · 채팅 줄) ·
    `sim/items.luau`(장비 하나의 셈: 이름 · 점수 · 떨어지는 것 · 강화 · 분해 · 별 옮기기) · `sim/bag.luau`(가방 · 낀 장비 · 창고 · 상점에서 사기 — 캐릭터의 표에 얹는다) ·
    `net/net.luau` + `net/packets.luau`(패킷 정의는 여기에만) · `ui/format.luau`(칸에 맞는 글의 꼴) · `data/*.generated.luau`(공방에서 내보낸 것:
    chars · scenes · assets · numbers · combat · classes · ui · items · quests · kit)
  - `src/server/lune/modules/chat.luau` — 채팅이 누구에게 가는지(Roblox TextChatService의 채널에 얹는다: 둘레 = 같은 맵 · 파티 = 파티원).
  - `src/server/lune/` — `boot.luau` · `modules/world.luau`(사람 · 방 · 패킷을 sim에 잇는다. 시간은 `World.tick`으로 흘린다 — 테스트 13이 직접 돌린다)
  - `src/client/lune/` — `boot.luau`(시작점 · 주인공 · 기술 · 서버가 알려 주는 것 받기) · `stage.luau`(화면 틀과 배율) · `sceneView.luau`(장면) ·
    `sprite.luau`(캐릭터 그림) · `mobsView.luau`(졸개) · `effects.luau`(피해 숫자 · 화살 · 떨어진 것) · `hud.luau`(체력 · 경험치 · 물약 · 기술 키 · 메뉴 칸) · `input.luau`(조작 · 키 바꾸기) ·
    `minimap.luau`(미니맵) · `chooser.luau`(직업 고르기) · `touch.luau`(스마트폰 단추) · `ui/kit.luau`(화면 부품 — 메이플풍 판 · 단추 · 탭 · 칸 · 아이콘 · 글 · 띠 · 이름표 · 창틀) · `ui/windows.luau`(창 관리 — 레벨이 되어야 열린다) ·
    `ui/statWindow.luau` · `ui/skillWindow.luau` · `ui/keysWindow.luau` · `ui/talk.luau`(주민 대화) ·
    `questHud.luau`(퀘스트 알리미) · `ui/questWindow.luau` · `othersView.luau`(다른 사람들) · `partyHud.luau`(파티원 칸 · 초대 알림) · `ui/partyWindow.luau` · `chat.luau`(채팅 칸 — 글은 TextChatService로 오간다) ·
    `ui/itemCell.luau`(장비 한 칸) · `ui/bagWindow.luau` · `ui/equipWindow.luau` · `ui/shopWindow.luau`(상점 · 창고 — 누구의 것인지는 창에 딸린 값으로) · `ui/forgeWindow.luau`(강화)
  - 물건을 다루는 요청은 패킷 하나(`Item`: 하는 일 + 대상 둘)로 간다. 서버는 결과를 `ItemDone`으로, 바뀐 가방을 `Bag`으로 보낸다. 상점 · 강화 · 창고는 서버가 주민 앞인지 본다.
  - 화면의 자리 셈 가운데 검사할 것은 `shared/lune/ui/`에 둔다: `format.luau`(칸에 맞는 글 · 키 이름 줄이기 `fitKey` · 대화 상자 자리 `TALK`) · `minimap.luau`(미니맵 줄이기). 테스트 14가 본다.
  - 글씨는 닌자 게임 때 만든 `client/modules/ui/pixelText.luau`(갈무리 글꼴)를 그대로 쓴다 — 닌자 코드를 지우게 되면 이것과 글꼴 자료는 남긴다.
  - 원칙: 화면이 필요 없는 셈은 모두 `shared/lune/sim`에 둔다(테스트로 돌린다). 클라이언트는 "하고 싶다"만 보내고 체력 · 경험치 · 돈 · 졸개의 진실은 서버가 갖는다.
  - 설계 수치는 공방 자료에서 온다: 싸움의 기본 수치 = `dino-workshop/js/lune/design/combat.js`(졸개 · 기술 판정 · 규칙) → `combat.generated.luau`.
  퀘스트의 놀이(누가 주고 무엇을 몇 개) = `js/lune/design/questplay.js` → `quests.generated.luau`. 새 맵의 생김새 = `js/lune/design/maps.js`.
  장비 · 가방 · 강화 · 상점 = `js/lune/design/items.js`(+ numbers.js · basics.js · economy.js의 수치) → `items.generated.luau`. 게임에서 성능 단(q)은 1부터 센다(공방은 0부터).
- 스위치: `src/shared/config/features.luau`의 `GAME` — `"lune"` 새 게임 / `"ninja"` 예전 닌자 게임. 닌자 게임 코드(`server/modules` · `client/modules` 등)는 지우지 않고 꺼 두었다(지울지는 사용자가 정한다).
- 그림: `SpriteDemo/assets/lune/*.png`(올린 그림) · `ids.json`(파일 → 그림 해시와 에셋 id) · `manifest.json`(목록과 다시 올려야 할 것).

## 공방에서 게임으로

0. 새 맵을 짓거나 고쳤으면 먼저 `node tools/build_lune_maps.mjs`(maps.js → `assetpack/lune/maps/<id>/`). 사냥터의 타일 · 소품 그림을 그대로 쓴다 — 예전 맵 도구(build_lune_demo.mjs · build_lune_town.mjs)는 건드리지 않는다.
   맵이 이어지는 차례는 maps.js의 `LINKS`(처음부터 있던 마을 · 사냥터의 문이 가는 곳을 내보낼 때 바꿔 적는다).
0-1. 화면 부품(메이플풍 UI — 사용자 2026-10-06: "메이플에 가까워야합니다" · "1 느낌 + 도트 게임 느낌")을 고쳤으면:
   `node tools/build_lune_icons.mjs`(Codex가 그린 아이콘 시트 `assetpack/lune/ui/raw_icons_a2.png` · `_b2.png` → 18x18 `icons.png` + 원본과 견주는 `icons_check_*.png`) →
   `node tools/build_lune_ui.mjs`(틀 · 칸 · 단추 · 게이지를 코드로 찍고 아이콘 · 아주 작은 글씨 · 큰 숫자와 한 장으로 묶는다 → `kit.png` · `kit.json` · 실제 해상도 미리 보기 `preview_*.png`).
   색 · 모서리 · 테두리는 build_lune_ui.mjs의 `HEX` · `PLATES`에서만 고친다 — 게임은 그 한 장(`ui_kit.png`)과 `kit.generated.luau`를 그대로 쓴다. 화면 칸의 자리는 basics.js의 `HUD`.
   새 아이콘이 필요하면 Codex로 시트를 뽑아(프롬프트 `assetpack/lune/ui/prompt_icons_*.txt` — 한 그림이 14x14 블록쯤 되게 굵게 시킨다. 24도트쯤으로 잘게 나오면 줄일 때 뭉개진다) 확인 요청으로 올린다.
1. `cd dino-workshop && node tools/export_lune_game.mjs` — 캐릭터 · 졸개 동작을 한 판으로 묶고(빈 곳을 덜어 냄), 장면과 화면 부품(`ui_kit.png` · 작은 글씨 글자판 `font_small_*.png`)을 내보낸다. 끝에 "새로 올려야 하는 것 N장"이 나온다.
2. 올릴 것이 있으면: `SpriteDemo/assets/lune`에서 `python -m http.server 8094 --bind 127.0.0.1` → Studio MCP `upload_image`(need 목록의 파일만) → 그 python을 끈다.
3. `node tools/write_lune_ids.mjs '<업로드 결과 JSON>'` — ids.json과 `assets.generated.luau`를 고친다.
- 게임 쪽 `*.generated.luau`는 손으로 고치지 않는다. 장면 · 그림 · 수치는 공방에서 고치고 다시 내보낸다.

## 확인하는 법

1. 자동 검사: `cd SpriteDemo && python tools/test/run.py` — 전 파일 컴파일 + 로직 테스트. 새 게임의 테스트는 `tools/test/tests/1x_lune_*.luau`. 화면이 필요 없는 셈은 `shared/lune`에 두어 테스트로 돌린다.
2. Play: Studio MCP `start_stop_play` → `user_keyboard_input`으로 조작 → `screen_capture`로 화면 · `get_console_output`으로 오류 → 끈다. (사용자가 2026-10-06에 Claude가 직접 Play를 켜도 된다고 했다.)
   - 명령 실행(`execute_luau`)에서 `require`한 모듈은 게임이 쓰는 것과 다른 사본이다 — 게임의 상태는 `PlayerGui.LuneStage`의 속성으로 읽는다
     (Scene · HeroX · HeroY · Level · Hp · Xp · Money · Potions · Dead — client/lune/boot.luau의 debugMarks가 0.25초마다 적는다).
   - 클라이언트 코드를 고치면 Play를 껐다 켜야 반영된다.
   - 마우스(`user_mouse_input`): 좌표는 화면 사진의 y에서 58(위쪽 띠)을 뺀 값 = `AbsolutePosition`. 단추는 `instance_path`로 누르는 것이 가장 확실하다
     (예: `LocalPlayer.PlayerGui.LuneStage.Holder.View.Hud.Menu.Menu_bag` · `…Hud.Menu.Menu_more`(누르면 `…View.More.More_keys`가 뜬다) · `…View.Windows.Window.close` · `…View.Chooser.Pick_riven` · `…View.Touch.T15` · `…Hud.PartyAsk.Accept`).
     창 안의 칸은 이름이 `Cell`이다 — `AbsolutePosition`으로 차례를 세어 좌표로 누른다.
   - 스마트폰 단추 켜 보기: `PlayerGui.LuneStage:SetAttribute("Touch", true)`(nil로 되돌린다). 이동 패드는 mouseButtonDown → wait → mouseButtonUp으로 누른다.
   - 키 저장을 확인하려면 reset 없이 Play를 껐다 켠다(끌 때 저장된다) — 다 보고 나서 reset.
   - 확인용 명령(Studio에서만 듣는다): 클라이언트에서 `game.ReplicatedStorage.LuneRemotes.Debug:FireServer("xp", 3000)` — "xp" · "money" · "hp" · "dust" · "reset"(캐릭터를 지운다 — **숫자를 꼭 같이 보낸다: `FireServer("reset", 0)`**. 숫자 없이 보내면 서버가 받지 않아 지워지지 않는다. 보낸 뒤 몇 초 기다렸다가 끈다) ·
     "gear"(n = 단계: 그 단계 장비 다섯을 가방에) · "drop"(n = 단계: 발 앞에 빼어난 무기와 달가루를 떨어뜨린다) ·
     "bot"(n = 1 리븐 · 2 리퍼 · 3 무니 · 4 살라맨더: 내 옆에 서버가 움직이는 가짜 사람을 세운다) · "botInvite"(가짜 사람이 나를 파티에 초대한다).
   - 화면 사진에는 Roblox의 CoreGui(기본 채팅 창 · 위쪽 띠)가 찍히지 않는다. Esc는 가짜 입력으로 누를 수 없다. 기술 키는 누르고 있어도 한 번만 나간다 — 여러 번 눌러야 한다.
   - 서버 코드에서 `player.없는값`을 읽으면 진짜 Player에서는 오류가 난다. 테스트 13의 가짜 플레이어(`person`)도 같은 오류를 내게 해 두었다.
   - Studio에서도 진짜 DataStore("LuneHero_v1")에 저장된다. **확인이 끝나면 `Debug reset`으로 확인용 캐릭터를 지우고 Play를 끈다** — 사용자가 켰을 때 직업 고르기부터 나오게.
3. 공방 「개발 진행」 탭에 확인한 것 · 못 한 것을 적고, Play 화면을 `dino-workshop/assetpack/lune/dev/`에 넣어 보여 준다.

## 지켜야 할 것

- 화면: 게임 화면은 384x216도트, 정수 배율(UIScale)로 키운다. 좌표는 도트, 캐릭터와 놓인 것은 발밑 가운데가 기준. 왼쪽을 볼 때는 `ImageRectSize`의 폭을 음수로 줘서 뒤집는다(Play에서 확인됨).
- Roblox 기본 것: 3D 캐릭터는 만들지 않는다(`Players.CharacterAutoLoads = false`, server/lune/boot.luau). 참가자 목록 · 가방 · 체력 · 감정 표현 · 기본 조이스틱은 끈다(client/lune/stage.luau) —
  참가자 목록은 보이지 않을 때에도 화면 오른쪽 위를 덮어 그 자리의 단추를 가로챈다. 채팅은 켜 둔다.
- 테스트 실행기(run.py)는 정의되지 않은 이름도 찾는다(`[전역 이름]`) — 파일 아래쪽에서 정의한 지역 변수를 위쪽 함수가 쓰면 nil이 된다(컴파일은 된다).
- 테스트에서 맵을 옮길 때는 `goTo(player, 장면)`(테스트 13)을 쓴다 — 맵의 차례가 바뀌어도 따라간다. 퀘스트의 맵 · 졸개는 자료(`Q.def(id)`)에서 읽는다.
- 창의 글은 칸의 폭을 상수로 두고(`ShopWindow.NAME_W` 등) 테스트 14 · 15에서 가장 긴 글을 재 본다 — 어림으로 잡으면 넘친다(갈무리는 한글 12, "Lv.10"이 33도트다).
- 화면 부품(`ui/kit.luau`): `Kit.part`(부품 그림 — 크기를 주면 아홉 조각으로 늘인다. 부품 한 장의 일부를 잘라 쓰는 ImageLabel에서도 SliceCenter가 그 조각 기준으로 먹는다 — Play에서 확인됨) ·
  `Kit.plate`(판 + 속) · `Kit.icon` · `Kit.button`(kind = "blue" | "orange") · `Kit.tab` · `Kit.bar`("hp" | "mp" | "exp") · `Kit.micro`(3x5 글씨 — 키 이름 · 개수) · `Kit.big`(피해 숫자) · `Kit.tag`(발밑의 이름표) · `Kit.window`.
  화면의 글은 작은 글씨("small" = 갈무리9 — `Kit.text`의 기본), 창의 제목과 주민의 말은 본문 글씨("body"). 땅의 윗면은 화면의 y 150(`Kit.GROUND`)에 온다 — 장면은 세로로 따라가지 않는다.
- 글씨: 칸에 넣을 때는 `ui/kit.luau`의 `Kit.text`(가운데 · 오른쪽 맞춤이 된다)를 쓴다 — pixelText의 Align = "center"는 MaxWidth 안에서 가운데로 가지 않는다.
- 사냥터 땅 그림의 분홍 줄기(왼쪽 아래)는 원래 그림에 있는 장식이다 — 오류가 아니다.
- 조작: 방향키는 로블록스 기본 조작이 먼저 가져가므로 `InputBegan`의 "처리됨" 표시를 보지 않는다(글자 입력 중만 뺀다). 키는 `input.luau`의 "하는 일 → 키" 표를 거친다(키 설정 · 터치가 이 표와 같은 이름을 쓴다).
- 움직임 수치는 공방 시험판(`js/lune/luneTab.js`)과 같아야 한다 — `config/game.luau`.
- 사용자 결정은 공방 설계 자료의 머리말과 메모리(`lune-world-design`)에 있다: 자동 사냥 없음 · 게임패드 없음 · PC와 스마트폰 · 키를 눌러 줍기 · 경매장으로 전부 거래 · 강화 세 구간 등.
- 지우기 전에는 묻는다(닌자 게임 코드 포함).
