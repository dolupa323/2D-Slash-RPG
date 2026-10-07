# LUNE_PLAN — 「달의 계승자」(횡스크롤 MMORPG) 로블록스 개발 작업 메모 (Claude 작업용)

> 시작: 2026-10-06 사용자 "오케이 이제 우리 로블록스에서 본격적인 개발에 착수해봅시다".
> 단계와 진행 상태는 **공방 자료가 기준**이다: `dino-workshop/js/lune/design/devplan.js` → 공방 「개발 진행」 탭(http://localhost:8090/#dev). 단계가 끝날 때마다 그 파일을 고친다.
> 설계 기준은 공방의 설계 자료(`dino-workshop/js/lune/design/*.js`)와 탭들이다. 예전 닌자 게임 문서(NINJA_PLAN.md · NINJA_DESIGN.md)는 기준이 아니다.

## 어디에 무엇이 있나

- 게임 코드: `SpriteDemo/` (Rojo 프로젝트, Studio 플레이스 「슬래시 RPG」에 연결). 새 게임은 아래 세 곳에만 둔다.
  - `src/shared/lune/` — `config/game.luau`(상수) · `config/numbers.luau`(숫자 뼈대의 식 — 공방과 같은 값인지 테스트 11이 맞춰 본다) ·
    `sim/physics.luau`(움직임) · `sim/hero.luau`(체력 · 경험치 · 물약 · 쓰러짐) · `sim/room.luau`(졸개의 움직임과 공격 · 기술 판정 · 보상 · 줍기) ·
    `sim/quests.luau`(퀘스트: 받기 · 세기 · 돌려주기 — 서버와 클라이언트가 같은 함수를 쓴다) · `sim/party.luau`(파티 장부 · 경험치 몫) · `ui/tags.luau`(이름표가 겹칠 때 보일 것 고르기 — 옮기지 않는다 · 채팅 줄) ·
    `sim/items.luau`(장비 하나의 셈: 이름 · 점수 · 떨어지는 것 · 강화 · 분해 · 별 옮기기) · `sim/bag.luau`(가방 · 낀 장비 · 창고 · 상점에서 사기 — 캐릭터의 표에 얹는다) ·
    `net/net.luau` + `net/packets.luau`(패킷 정의는 여기에만) · `ui/format.luau`(칸에 맞는 글의 꼴) · `data/*.generated.luau`(공방에서 내보낸 것:
    chars · scenes · assets · numbers · combat · classes · ui · items · quests · kit)
  - `src/server/lune/modules/chat.luau` — 채팅이 누구에게 가는지(Roblox TextChatService의 채널에 얹는다: 둘레 = 같은 맵 · 파티 = 파티원).
  - `src/server/lune/` — `boot.luau` · `modules/world.luau`(사람 · 방 · 패킷을 sim에 잇는다. 시간은 `World.tick`으로 흘린다 — 테스트 13이 직접 돌린다)
  - `src/client/lune/` — `boot.luau`(시작점 · 주인공 · 기술 · 서버가 알려 주는 것 받기) · `stage.luau`(화면 틀 — 층 둘: 게임 세계 `view`와 화면 글씨 · 틀의 고운 격자 `ui`) · `sceneView.luau`(장면) ·
    `overlay.luau`(게임 세계의 자리에 붙는 화면 글씨 — 이름표 · 체력 띠 · 말풍선 · 알림 글의 자리를 "게임 도트 → 화면 틀의 점"으로 바꾼다) ·
    `sprite.luau`(캐릭터 그림) · `mobsView.luau`(졸개) · `effects.luau`(피해 숫자 · 화살 · 떨어진 것 · 알림 글) · `hud.luau`(왼쪽 아래의 체력 덩어리 · 스킬 칸 · 창을 여는 단추) · `input.luau`(조작 · 키 바꾸기) ·
    `chooser.luau`(직업 고르기) · `touch.luau`(스마트폰 단추) · `ui/ui.luau`(화면 틀의 부품 — 판 · 칸 · 단추 · 키 딱지 · 띠 · 글 · 그림 · 창) · `ui/kit.luau`(게임 세계의 부품 — 장비 그림 · 떨어진 것 · 피해 숫자) ·
    `ui/windows.luau`(창 관리 — 오른쪽 · 왼쪽의 옆 판. 레벨이 되어야 열린다) · `ui/statWindow.luau` · `ui/skillWindow.luau` · `ui/keysWindow.luau` · `ui/talk.luau`(주민의 말풍선) ·
    `questHud.luau`(퀘스트 알리미) · `ui/questWindow.luau` · `othersView.luau`(다른 사람들) · `partyHud.luau`(파티원 칸 · 초대 알림) · `ui/partyWindow.luau` · `chat.luau`(채팅 — 글은 TextChatService로 오간다) ·
    `ui/itemCell.luau`(장비 한 칸) · `ui/bagWindow.luau` · `ui/equipWindow.luau` · `ui/shopWindow.luau`(상점 · 창고 — 누구의 것인지는 창에 딸린 값으로) · `ui/forgeWindow.luau`(강화)
  - 물건을 다루는 요청은 패킷 하나(`Item`: 하는 일 + 대상 둘)로 간다. 서버는 결과를 `ItemDone`으로, 바뀐 가방을 `Bag`으로 보낸다. 상점 · 강화 · 창고는 서버가 주민 앞인지 본다.
  - 화면의 자리 셈 가운데 검사할 것은 `shared/lune/ui/`에 둔다: `layout.luau`(늘 보이는 화면과 창의 치수 — 화면과 테스트가 같은 값을 쓴다) · `format.luau`(칸에 맞는 글 · 키 이름 `keyShort` · 말풍선 `BUBBLE`) · `tags.luau`(이름표 쌓기 · 채팅 줄). 테스트 14 · 15가 본다.
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
0-1. 화면 부품을 고쳤으면(방식: 산나비 계열 — 사용자 2026-10-07 "제가말하는건 산나비같은 도트게임을말하는거에요" → 시안을 보고 "훌룡합니다. 하지만 글씨비율은 좀더 작아야합니다. 그리고 미니맵은 없애세요"):
   `node tools/build_lune_icons.mjs`(Codex가 그린 아이콘 시트 `raw_icons_a2.png` · `_b2.png` → 게임 세계의 장비 그림 18x18 `icons.png`) →
   `ICON_PREFIX=icons24 ICON_SHEETS=raw_icons_a.png,raw_icons_b.png ICON_MORE=skills_sheets.json node tools/build_lune_icons.mjs 24`(더 잔 처음 시트 + 스킬 시트 네 장 → 화면의 그림 24x24 `icons24.png` — 창을 여는 단추 · 기술 칸 · 버프 · 스킬 157개 전부 · 상태 표시 · 그 밖의 창 단추. 결과는 `icons24_check_N.png`로 원본과 나란히 본다) →
   `node tools/build_lune_ui.mjs`(부품 한 장 `kit.png` · `kit.json`) → `node tools/preview_lune_ui_hd.mjs`(실제 화면 크기 1920x1080의 시안 `hd_*.png` — 부품과 같은 색 · 같은 그리기를 쓴다. 공방 「개발 진행」 탭의 확인 요청에 뜬다).
   부품은 두 굵기다: 게임 세계의 것(굵은 도트 — icons · dmg · dropCoin · dropDust · tier*)과 화면의 것(고운 격자 — 이름이 u로 시작하는 판 · 칸 · 단추 · 말풍선과 pics).
   화면의 색 · 치수는 build_lune_ui.mjs의 `UIHEX` · `UIM`에서만 고친다. 화면 칸의 자리는 basics.js의 `HUD`(기준 격자 960x540과 붙는 구석 `at`).
   피해 숫자는 공방 시험 탭의 것(`js/lune/fx.js`의 `DIGITS` · `num`)을 그대로 읽어 만든다 — 따로 꾸미지 않는다(사용자 2026-10-07).
   스킬 아이콘은 `node tools/make_lune_skill_icon_prompts.mjs`가 설계(jobs.js)에서 프롬프트 네 장(`prompt_skills_N.txt`)과 칸의 차례(`skills_sheets.json`)를 짓는다 — 스킬마다 제 그림이 있어야 한다(패시브까지. 사용자 2026-10-07). 없으면 내보내기가 멈추고 테스트 18이 잡는다.
   새 아이콘이 필요하면 Codex로 시트를 뽑아(프롬프트 `assetpack/lune/ui/prompt_icons_*.txt`) 확인 요청으로 올린다. 아이콘은 알아보는 것이 먼저다 — 코드로 찍은 한 색짜리 기호는 퇴짜를 맞았다.
1. `cd dino-workshop && node tools/export_lune_game.mjs` — 캐릭터 · 졸개 동작을 한 판으로 묶고(빈 곳을 덜어 냄), 장면과 화면 부품(`ui_kit.png` · 글자판 `font_small_*.png` · 테두리를 두른 글자판 `font_small_o_*.png` · `font_body_o_*.png`)을 내보낸다. 끝에 "새로 올려야 하는 것 N장"이 나온다.
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

- **순서(사용자 2026-10-07): 보이는 것 · 느껴지는 것은 공방의 횡스크롤 시험 탭(`dino-workshop/js/lune/luneTab.js` — #lune)에 먼저 넣고, 사용자가 느낌을 본 뒤에 게임에 반영한다.** 게임을 먼저 고치지 않는다. 시험 탭이 본보기다 — 게임과 다르면 시험 탭이 맞다.
  화면의 색 · 치수 · 짜임 · 낱말은 `js/lune/design/ui.js`(UIHEX · UIM · UILAYOUT · BUBBLE · QUESTMARK · WORDS), 그리는 법은 `js/lune/ui/paint.js`(시험 탭과 시안 도구가 같이 쓴다). 게임에는 `tools/export_lune_game.mjs`가 그 값을 그대로 내보낸다(`ui.generated.luau`의 layout · bubble · questMark · words) — `shared/lune/ui/layout.luau` · `format.luau`는 숫자를 따로 적지 않고 그것을 읽는다.
  시험 탭 확인: 주소에 `&lunedemo=bag,talk,active,ready,hit`를 붙이면 그 모습으로 시작한다. 진짜 입력으로 눌러 볼 때는 Chrome을 `--remote-debugging-port`로 띄워 Node의 WebSocket으로 키 · 마우스를 보낸다(따로 깐 도구 없음).
- 주민 머리 위의 퀘스트 표시는 글자 "!"(받을 수 있다) · "?"(돌려줄 수 있다)다 — 전구 · 책 그림이 아니다(사용자 2026-10-07). 부품 `markNew` · `markDone` — 피해 숫자와 같은 작은 점 글자(사용자: "느낌표, 물음표 크기 너무 큽니다"). 게임에도 반영했다(2026-10-07).
- 낱말: 장비를 몸에 다는 일은 「장착」이다 — 「끼기」가 아니다(사용자 2026-10-07). 낱말은 `js/lune/design/ui.js`의 `WORDS`에서 정하고 게임은 `ui.generated.luau`의 words로 읽는다.

- 화면: 층이 둘이다(`stage.luau`). 게임 세계(`Stage.view`)는 384x216도트를 정수 배율로 키운다 — 좌표는 도트, 캐릭터와 놓인 것은 발밑 가운데가 기준. 왼쪽을 볼 때는 `ImageRectSize`의 폭을 음수로 줘서 뒤집는다(Play에서 확인됨).
  화면의 글씨와 틀(`Stage.ui`)은 그보다 고운 격자에 그린다 — 1080p에서 960x540(한 점 = 화면 2픽셀. 게임의 도트는 5픽셀). 격자는 창 크기에 따라 768x432부터 1152x648까지 달라지므로,
  그 안의 것은 기준 격자(960x540)의 자리와 붙는 구석으로 적고 `Stage.place` · `Stage.placeRect`로 놓는다(구석에서의 거리가 유지된다). 왼쪽 위에 붙는 것은 Roblox 기본 단추 아래로 저절로 내려간다(`Stage.insetTop`).
  게임 세계의 자리에 붙는 글씨(이름표 · 체력 띠 · 말풍선 · 알림 글)는 `overlay.luau`의 `Overlay.x` · `Overlay.y`로 화면마다 자리를 잡는다. 미니맵은 없다(사용자 결정 2026-10-07).
  Studio의 작은 창(게임 3배)에서는 화면 틀이 1배라 글씨가 10~12픽셀로 작게 보인다 — 1080p 전체 화면에서는 20~24픽셀(시안 `hd_*.png`와 같다).
- Roblox 기본 것: 3D 캐릭터는 만들지 않는다(`Players.CharacterAutoLoads = false`, server/lune/boot.luau). 참가자 목록 · 가방 · 체력 · 감정 표현 · 기본 조이스틱은 끈다(client/lune/stage.luau) —
  참가자 목록은 보이지 않을 때에도 화면 오른쪽 위를 덮어 그 자리의 단추를 가로챈다. 채팅은 켜 둔다.
- 테스트 실행기(run.py)는 정의되지 않은 이름도 찾는다(`[전역 이름]`) — 파일 아래쪽에서 정의한 지역 변수를 위쪽 함수가 쓰면 nil이 된다(컴파일은 된다).
- 테스트에서 맵을 옮길 때는 `goTo(player, 장면)`(테스트 13)을 쓴다 — 맵의 차례가 바뀌어도 따라간다. 퀘스트의 맵 · 졸개는 자료(`Q.def(id)`)에서 읽는다.
- 화면과 창의 치수는 `shared/lune/ui/layout.luau`에 두고(`Layout.VITALS` · `SKILLS` · `MENU` · `BAG` · `SHOP` …) 화면과 테스트 14 · 15가 같은 값으로 가장 긴 글을 재 본다 — 어림으로 잡으면 넘친다.
  장비 칸의 크기는 화면 틀의 배율을 따른다(`Layout.cellFor` — 1080p에서 50). 창의 크기도 그것으로 정해지므로 테스트는 게임 2배 ~ 10배에서 다 본다.
- 화면 틀의 부품(`ui/ui.luau`): `Ui.part`(부품 그림 — 크기를 주면 아홉 조각으로 늘인다) · `Ui.panel` · `Ui.text`(font = "small" | "body", outline = 테두리 두른 글 — 판 없이 게임 화면 위에 적는 글) ·
  `Ui.tag`(이름표) · `Ui.pic`(화면의 그림 24x24) · `Ui.worldIcon`(장비 그림을 게임과 같은 굵은 도트로 칸 가운데에) · `Ui.button`(main = 가장 하고 싶은 일 — 민트) · `Ui.keycap` · `Ui.slot` · `Ui.bar` · `Ui.tab` · `Ui.window`.
  글씨는 둘뿐: 작은 글씨("small" = 갈무리9)와 본문 글씨("body" = 갈무리11 — 이름 · 말 · 제목). 색은 `Ui.COLOR`(판은 무채색, 강조색은 민트 하나).
  창은 `ui/windows.luau`가 오른쪽 · 왼쪽 끝에 하나씩 놓는다(가방은 늘 오른쪽 — 가운데의 캐릭터를 가리지 않는다). 창 모듈은 `size()`로 속의 크기를 알린다.
  능력치 창: 능력치 줄에 마우스를 올리면(터치는 누르면) 창 옆에 설명 판(`uTip`)이 뜬다 — 글은 공방 `design/ui.js`의 `STATTIP`, 숫자는 `N.statGain`(1점의 값), 짜는 것은 `Format.statTip`(공방 `paint.js`의 `statTip`과 같은 글 — 테스트 18이 `ui.generated`의 `statTipCheck`로 맞춰 본다).
  스킬 창: 차수 탭 1차 ~ 4차(`CLASSES.classes[직업].tiers` — 공용 스킬은 4차 끝에). 서버는 아직 1차(`skills`)만 올려 준다 — 전직이 생기면 `me.job`을 보내면 된다(`SkillWindow.jobOf`).
- 사냥기 · 보스기의 쓰임(사용자 2026-10-07): `Room:skillHit(…, kind)` — 사냥기("mob")는 일반 몬스터에게, 보스기("boss")는 보스에게 피해가 `RULES.targetBonus`% 더 뜬다(숫자로 보인다). 그만큼 졸개 · 보스의 체력도 크다(`Room.new`) — 맞는 기술의 빠르기는 그대로, 맞지 않는 기술은 그만큼 느리다.
- 기술의 타는 "붙어 있는 적 한 마리가 설계한 피해(초당 피해 x 딜레이 x 몫)를 다 받게" 짠다 — 대지 강타의 가시가 바로 앞의 적을 못 맞혀 70%만 들어가던 일이 있었다(2026-10-07). 한 적이 같은 것을 두 번 맞지 않게 하려면 타에 `except`(그 범위 안의 적은 뺀다)를 쓴다. 테스트 18의 10)이 직업마다 본다.
- 떨어진 달돈 · 달가루는 12x12(`dropCoin` · `dropDust` — `ICON_PREFIX=icons12 node tools/build_lune_icons.mjs 12`로 옮긴 것), 장비 · 퀘스트의 물건은 18x18. 스킬 창의 설명 첫 줄에 적는다(`UI.skillWords.bonus`).
- 퀘스트의 길잡이: `Quests.stepHint`(「○○의 △△을 잡으면 떨어진다」 — 맵과 졸개의 이름에서 짓는다 · 을/를은 `Quests.josa`) · 알리미의 줄은 `Quests.trackText`(「검병 · 갑옷 조각 2/8」).
- 가방의 탭은 장비 · 소비 · 기타(사용자 2026-10-07 — "쓰는 것" · "재료"라고 적지 않는다). 
- 게임에 아직 없는 것: 온오프 스킬(사출기) · 핵심 장치 · 버프 — 시험 탭에만 있다. 게임의 기술은 직업마다 사냥기 · 보스기 · 이동기 셋(`COMBAT.skills`). 다음 일 = 1차 온오프 스킬을 옮기기.
- 퀘스트의 모으는 물건은 땅에 떨어지고 주워야 오른다(사용자 2026-10-07): `Quests.drops`(잡았을 때 굴린다) → `Room:addDrop({ kind = "quest", quest, step, name, icon })`(그 사람에게만 `DropAdd`) → 줍기 → `Quests.onLoot`. 그림은 공방 `questplay.js`의 `ITEM_ICON`(게임 세계의 그림 18x18 — `ICON_MORE=etc_sheets.json node tools/build_lune_icons.mjs`로 얹는다). 가방의 재료 탭은 `Quests.items`. 확인용: `Debug:FireServer("qdrop", 0)`.
- 피해 = 전투력(반올림 전 — `Hero.powerRaw`) x 그 타의 배수 x 스킬 레벨의 세기 x 흔들림 x `RULES.dmgScale`(10 — 피해 숫자와 졸개의 체력을 함께 키운다. 낮은 레벨에서 올린 만큼 숫자로 보이게 — 사용자 2026-10-07). 테스트 18의 7)이 스킬 한 레벨 · 능력치 1점마다 평균 피해가 오르는지 본다.
- 퀵슬롯(사용자 2026-10-07): 키는 스킬이 아니라 칸에 붙는다(`"slot:<칸>"` — 공방 `design/ui.js`의 `QUICK`: 열두 칸 · 기본 키 · 처음 차림). 칸의 셈은 `shared/lune/ui/quick.luau`(`place` · `clear` · `start` · `clean` — 공방의 `quickPlace` …와 같은 셈, 테스트 18이 `ui.generated`의 `quick.check`로 맞춰 본다).
  캐릭터가 `slots`를 갖고(저장된다) 서버는 `Slots`(묻고 답하는 꼴 — 서버의 칸들을 돌려준다)로 받는다. 화면은 `hud.luau`의 `setSlots` · `setEdit` · `setPick` · `slotAt`, 놓는 일은 `ui/quickEdit.luau`(끌어다 놓기 · 눌러서 놓기). 칸끼리 끄는 것은 늘 되고, 스킬은 스킬 창에서 · 소비 아이템(물약)은 가방의 소비 탭에서 끌어다 놓는다. 물약도 칸에서 뺄 수 있다. 열두 칸은 늘 보인다(빈 칸은 흐리게).
  스마트폰 단추는 예전처럼 `"skill:<id>"` · `"potion"`을 키 없이 누른다. 키 설정 창에는 스킬마다의 키가 없다(기본 동작 · 창 · 퀵슬롯의 키).
- 가시(`^`)는 닿아도 아무 일도 하지 않는다(사용자 2026-10-07 — 시작 자리로 되돌리던 것을 없앴다). 화면이 캐릭터를 혼자 옮기면 서버가 아는 자리와 어긋난다(서버는 순간이동을 믿지 않는다) — 캐릭터를 옮기는 일은 서버가 알게 한다. 서버는 맵의 시작 자리로 온 보고만은 받는다(`onMove`).
- 스킬 창의 차수 탭은 로마 숫자 I · II · III · IV다("차"라고 적지 않는다 — 사용자 2026-10-07).
- 이름표는 옮기지 않는다(사용자 2026-10-07: 내 이름이 주민 이름 아래로 밀려 내려가던 것을 없앴다). 겹치면 앞선 것(내 것 → 다른 사람 → 주민 · 문 → 졸개)만 보인다 — `Tags.visible`, 시험 탭은 `paint.js`의 `tagsVisible`.
- 대쉬의 효과(잔상 · 속도선)는 시험 탭의 값(`js/lune/fx.js`의 `DASHFX` → `combat.generated`의 `fx`)으로 `effects.luau`가 그린다(`ghost` · `trail` · `streaks`). 잔상은 흰 실루엣 판(`chars_mask_N.png` — `Sprite.new(…, true)`)에 직업 색을 입힌 것이다. 다른 사람의 대쉬는 `othersView.luau`가 같은 것을 부른다.
- 게임 세계의 부품(`ui/kit.luau`): `Kit.icon`(장비 그림 18x18 — 떨어진 것 · 머리 위의 표시) · `Kit.part`(떨어진 돈 · 달가루 · 귀퉁이 표시) · `Kit.dmg`(피해 숫자 — 시험 탭과 같은 3x5 점 숫자). 땅의 윗면은 화면의 y 150(`Kit.GROUND`)에 온다 — 장면은 세로로 따라가지 않는다.
- 글씨: 칸에 넣을 때는 `Ui.text`(폭 안에서 가운데 · 오른쪽 맞춤이 된다)를 쓴다. 테두리를 두른 글자판(small_o · body_o)은 칸이 글자보다 사방으로 한 점 크다(pixelText가 `pad`로 맞춘다).
- **마을은 메이플의 엘리니아 방식 + 건물의 실내다(사용자 승인 2026-10-08: "맨아랫길도 흙땅으로 하고 게임에 옮겨도됩니다. 완벽합니다." — 같은 날 게임에 옮겼다).**
  사용자가 고쳐 준 것(다른 마을 · 맵을 지을 때도 지킨다): ① **계단이 아니다**("계단을 만들라는게 아니라 메이플 엘리니아 방식으로 배치하라는거고") ② **너무 높으면 안 된다 — 2~3층**("너무 높고 2~3층구조") ③ **불규칙해야 한다**("지금 너무 규칙적이에요")
  ④ **발판은 잔디가 덮인 흙 발판, 우리 게임 색으로, 정확히 옆에서 본 그림으로**("나무 발판이 아니라 잔디의 흙발판이어야죠 대신 우리 게임색감에 맞춰서 … 앞쪽으로 기울인것같이 보이잖아요") ⑤ **건물은 문(포탈)으로 들어가는 실내가 있고, 일을 봐 주는 주민은 그 안에 있다**("대장간 건물로 포탈을 타면 실내로 가고 실내에 대장장이가 있는 방식").
  **횡스크롤의 지형 · 발판 그림은 옆에서 본 단면이다**: 윗선은 곧은 가로줄 하나, 윗면은 보이지 않는다. 그림을 생성할 때 글로 꼭 요구하고(orthographic cross-section, top surface NOT visible), 빌더가 조각의 맨 윗줄이 곧게 차 있는지 본다. 색은 사냥터의 땅(`prompt_tiles.txt` — 거의 검은 흙 + 달빛 받은 잔디 띠)과 같게.
  설계는 `js/lune/design/town.js`의 `TOWNMAP`(나무 `trees` · 발판 `decks`(isle · step) · 건물의 자리와 문 · 실내의 주민과 문), 짓는 것은 `node tools/build_lune_town2.mjs` → `assetpack/lune/town2/`(마을)와 `town2/indoor/<건물>/`(실내 다섯). 길은 사냥터의 땅 그림을 잘라 깐다. 시험 탭의 「마을」과 게임이 모두 이것을 쓴다.
  그림(Codex, 글로만 설명): `town2/art/raw_earth.png`(흙섬) · `raw_tree.png`(큰 나무 — 뒷배경의 두 색 실루엣). 흙섬은 두꺼워서(23~29도트) 걷는 자리 위에는 넉넉히 띄운다(빌더의 `HEAD` 검사) — 한 번에 오르는 자리는 서로 옆으로 비켜 있다. 높이 · 길이는 일부러 고르지 않게(턱 16 · 32 · 48도트를 섞는다).
  **게임 쪽**: `export_lune_game.mjs`가 `town` = town2와 `in_<건물>` 다섯을 내보낸다(장면 자료의 `tall` · `indoor`). `sceneView.luau` — `tall`이면 카메라가 선 층을 따라 세로로도 움직이고(시험 탭의 followCam과 같은 식), `indoor`는 방 그림 한 장(바닥 그림 · 소품 없음), 문 위의 퀘스트 표시(`doorMarks` — 그 실내의 주민에게 받을 · 돌려줄 퀘스트가 있으면 문의 이름표 위에 ! · ?).
  서버는 고친 것이 없다: `onTravel`이 도착한 장면에서 "떠나온 장면으로 가는 문"을 찾아 그 앞에 세운다(문 ↔ 실내가 짝이라 그대로 맞는다). 상점 · 강화 · 창고 · 퀘스트는 `nearNpc`가 지금 장면의 주민만 보므로 그 건물 안에서만 된다. 예전의 평평한 마을(`assetpack/lune/town`)은 내보내지 않는다 — 건물 · 소품 · 주민 그림만 새 마을이 가져다 쓴다(파일은 그대로).
  실내 그림의 벽 · 큰 나무처럼 캐릭터 뒤에 넓게 깔리는 것은 캐릭터의 몸(#393e46)보다 뚜렷이 밝아야 한다(빌더의 `LIFT` · 나무는 뒷배경의 두 색만). 진짜 입력 검사는 스크래치패드의 `cdp_town.mjs`(탭의 `window.__luneProbe()`를 읽는다). 밧줄 · 사다리는 없다(매달려 오르는 동작이 팩에 없다 — 물어 둠).
- **오르는 턱은 낮게(사용자 2026-10-08: "점프거리는 다들 전체적으로 좀 낮춰서 1층에서 기본점프로 잡화점정도라인은 그냥 올라갈수 있는정도").** 가게들이 있는 첫 줄은 길에서 제자리 점프 한 번(48도트) — 디딤 섬을 거치지 않는다. 옆으로 건너뛰며 오르는 턱은 32도트까지, 밑에서 곧장 뛰어오르는 턱은 48도트까지(뛰는 높이 57). `build_lune_town2.mjs`의 `RISE · SIDE · GAP · UNDER`와 "가게 셋은 한 번에" 검사. 낮게 뜬 섬은 얇은 조각(`KIT.thin`)으로 그린다.
- **스마트폰(사용자 2026-10-08: "모바일에서 거의 플레이가 불가능한 수준 … ui가 전면을 다가리는").** `stage.luau`의 `Stage.scalesFor`: 2배가 안 들어가는 화면은 정수 배율을 버리고 꽉 차게 키우고, 화면 틀의 격자는 가장 작은 격자(768x432) 그대로 둔다(전에는 1배 · 격자 384x216이 되어 화면의 칸들이 다 겹쳤다). 가로 화면 고정.
  손가락 단추가 켜지면 자리를 옮기는 칸은 `basics.js`의 `HUDTOUCH` → `ui.generated`의 `hudTouch`(체력 = 아래 가운데 · 퀘스트 알리미 = 메뉴 단추 아래 · 채팅 = 왼쪽 위) — `Hud.setTouch` · `QuestHud.setTouch` · `Chat.setTouch`. 설계 검사가 격자 셋에서 손가락 단추와 겹치지 않는지 본다.
  Studio에서 폰 화면 보기: Play 중 `PlayerGui.LuneStage`의 속성 `Screen = "844x390"` · `Touch = true`. **진짜 폰에서는 아직 확인하지 못했다**(글씨의 또렷함 · 화면 크기의 값).
- **스마트폰 단추(사용자 2026-10-08) — `client/lune/touch.luau`, 자리는 `basics.js`의 `TOUCH`(slot = 몇째 칸 · act = jump · interact · menu · chat).**
  칸 단추 열둘: 놓인 것의 그림 · 남은 수 · 다시 쓰기 시간. 놓는 법 = 빈 단추를 누르거나 「메뉴 → 단추 배치」 → 목록에서 고른다 / 배치 중에 끌어서 자리 바꾸기 / 스킬 창 · 가방에서 누르고 단추 누르기(`Hud.touchSlotAt` · `touchPick`). 글로 된 단추(사냥 · 보스 · 대쉬)는 없다.
  **폰의 배치는 PC의 퀵슬롯과 따로 저장한다**(캐릭터의 `tslots` · 패킷 `TouchSlots` · 입력 `"tslot:<칸>"`) — PC에서 E · D에 둔 스킬이 폰에서는 작은 단추로 가고 큰 단추가 비는 일이 있었다. `quickHooks`는 `Touch.on`이면 폰의 배치를 고친다.
  조이스틱 = 바깥 원 + 손잡이. **위로 미는 것은 아무 일도 없다** — 문 · 주민 · 줍기는 상호작용 단추 하나(`Touch.setAct`: pickup · portal · npc에 따라 글이 바뀐다). 오른쪽 위는 「메뉴」라고 적힌 단추. 공격 스킬은 누르고 있으면 이어서 쓴다(폰만).
- **창의 닫기(X)는 겹쳐도 먼저 눌린다(사용자 2026-10-08 — PC · 폰).** `ui/windows.luau`의 `Closers` 층(ZIndex 300 — 창 150 · 메뉴 160 · 목록 170보다 위)에 X를 누르는 자리를 따로 둔다(한 변 40). 새로 판을 띄울 때 300보다 위에 누르는 것을 두지 않는다.
- **플레이어의 이름표는 어두운 판 + 민트의 가는 테두리(사용자 2026-10-08).** `ui.js`의 `UILAYOUT.tag.plate`, 시험 탭 `P.nameTag`, 게임 `Ui.tag(…, true)` — 나와 다른 사람만. 주민 · 졸개 · 문의 이름표는 판이 없다.
- 클라이언트 코드를 고친 뒤에는 자동 검사만 믿지 말고 Studio에서 띄워 콘솔을 본다 — `ui.luau`에 없는 이름(`UI`)을 쓴 것이 검사를 통과하고 Play에서야 드러났다(2026-10-08).
- **맵에 놓는 물건은 캐릭터를 가리지 않는다(사용자 2026-10-08: "z 인덱스 설정 잘못해서 캐릭터를 가려버리는게 몇개 있습니다").** 풀 · 덤불 · 화분 · 통 같은 것을 캐릭터 앞에 그리던 것을 모두 뒤로 보냈다 — 장면 자료의 `front`는 늘 비어 있다(`build_lune_demo.mjs` · `build_lune_maps.mjs` · `build_lune_town.mjs` · `build_lune_town2.mjs`).
- 사냥터 땅 그림의 분홍 줄기(왼쪽 아래)는 원래 그림에 있는 장식이다 — 오류가 아니다.
- 조작: 방향키는 로블록스 기본 조작이 먼저 가져가므로 `InputBegan`의 "처리됨" 표시를 보지 않는다(글자 입력 중만 뺀다). 키는 `input.luau`의 "하는 일 → 키" 표를 거친다(키 설정 · 터치가 이 표와 같은 이름을 쓴다).
- 움직임 수치는 공방 시험판(`js/lune/luneTab.js`)과 같아야 한다 — `config/game.luau`.
- 사용자 결정은 공방 설계 자료의 머리말과 메모리(`lune-world-design`)에 있다: 자동 사냥 없음 · 게임패드 없음 · PC와 스마트폰 · 키를 눌러 줍기 · 경매장으로 전부 거래 · 강화 세 구간 등.
- 지우기 전에는 묻는다(닌자 게임 코드 포함).
