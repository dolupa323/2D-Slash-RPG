# LUNE_PLAN — 「달의 계승자」(횡스크롤 MMORPG) 로블록스 개발 작업 메모 (Claude 작업용)

> 시작: 2026-10-06 사용자 "오케이 이제 우리 로블록스에서 본격적인 개발에 착수해봅시다".
> 단계와 진행 상태는 **공방 자료가 기준**이다: `dino-workshop/js/lune/design/devplan.js` → 공방 「개발 진행」 탭(http://localhost:8090/#dev). 단계가 끝날 때마다 그 파일을 고친다.
> 설계 기준은 공방의 설계 자료(`dino-workshop/js/lune/design/*.js`)와 탭들이다. 예전 닌자 게임 문서(NINJA_PLAN.md · NINJA_DESIGN.md)는 기준이 아니다.

## 어디에 무엇이 있나

- 게임 코드: `SpriteDemo/` (Rojo 프로젝트, Studio 플레이스 「슬래시 RPG」에 연결). 새 게임은 아래 세 곳에만 둔다.
  - Rojo(2026-10-20): 포트 34872 · `servePlaceIds` = 「슬래시 RPG」(96192775933291)에만 붙는다 · 켜기 `SpriteDemo/rojo_serve.cmd`. 같은 PC의 다른 게임 Gwimun(`C:\YJS\Roblox\Gwimun\game`)은 포트 34873이고 이 장소에는 붙지 않는다(`blockedPlaceIds`). Studio 창이 둘일 수 있으니 MCP는 `list_roblox_studios`의 「슬래시 RPG」 창을 고르고 `game.PlaceId`로 확인한 뒤에 쓴다.
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
- 1차의 온오프 사출기 · 핵심 장치 · 패시브(직업마다 셋 — 2026-10-08에 옮겼다): 자료는 공방 `design/combat.js`의 `KIT1`(→ `COMBAT.kit` · `kitSkill` · `kitEffects`), 셈은 `sim/kit.luau`(캐릭터의 `h.kit` — 저장하는 것은 사출기를 켰는지뿐), 맞혔을 때 따라 나가는 것은 `Room:kitAfter`(`sim/room.luau` — `strike` · `proc` · `mark` · 수정). 세기는 모두 마스터했을 때의 값 x 그 스킬 레벨의 세기(레벨 1에서 40%) — 확률 · 시간 · 개수는 레벨과 상관없다. 테스트 19.
  사출기: 퀵슬롯에 놓고 누르면 `Skill(id, 1, …)` 패킷 → 서버가 `Kit.toggle`(쓰는 동작 · 다시 쓰기 없음) → `Self`의 `kit.on`. 화면은 `Hud.setActive`(칸의 테두리) · `Hud.setBuffs`(오른쪽 위 — 버프가 뜨면 `QuestHud.setBuffs`로 알리미가 내려간다) · `Touch.refresh`.
  힘 모으기: 구간에 `charge = true`(대지 강타 1구간 · 삼단 베기 2구간). 그 다음 구간은 서버가 저절로 잇지 않는다 — 화면이 키를 뗄 때(끝까지 모이면 저절로) `Skill` 패킷을 보내고, 서버가 앞 구간이 끝난 뒤 흐른 시간으로 단계를 셈한다(`Kit.charge`). 끝까지 모으는 시간 + 0.4초를 넘겨 온 것은 버린다. 화면은 `stepSkill`(boot.luau)이 그 칸의 키(`sk.action`)를 누르고 있는지 본다 — 스마트폰 단추도 같은 길(`tslot:`), 모을 수 있는 기술은 누르고 있어도 이어 쓰지 않는다.
  `Hits`의 타에 붙는 것: `proc`(echo · star · wisp · shard · ember · flame · reson) · `sx` · `sy`(날아오는 자리) · `crit` · `mark`(초). 패킷 `Crystal`(수정이 서고 사라진다) · `Dodge`(피했다). 화면의 그림은 `effects.luau`의 `SHAPES`(작은 점 그림 — 시험 탭의 고리 · 궤적 같은 이펙트는 게임에 아직 없다).
  아직 없는 것: 2~4차의 사출기 · 장치 · 버프, 캐릭터가 맞아서 밀리는 것(설명의 "밀리지 않는다"는 듣지 않는다).
- 확인용 임시 캐릭터(Studio에서만 — `World.guest`): 편집 모드에서 `workspace:SetAttribute("LuneGuest", "riven")`을 하고 Play를 누르면 저장하지 않는 Lv.22 캐릭터(1차 스킬 전부 마스터 · 사출기는 E 칸)로 들어온다. 내 캐릭터의 저장은 읽지도 쓰지도 지우지도 않는다(테스트 13). **확인이 끝나면 속성을 지운다**(`SetAttribute("LuneGuest", nil)` — 플레이스에 남기지 않는다). 졸개를 오래 치려면 `Debug:FireServer("tough", 60)`(그 방의 졸개 체력 60배).
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
- **가방은 탭마다 진짜 칸이다(사용자 2026-10-08: "품목이 고정되어있고 거기서 수량 1/8 이런식으로 표기하는게 인벤토리가 아닙니다 … 선택하면 장비창 옆에 작은모달이 떠서 아이템 스펙이 나와야합니다 … 기타아이템, 소비아이템 모두 마찬가지").** 메이플스토리의 가방을 따른다.
  - 셈 `sim/bag.luau`: `gear · use · etc` = 길이가 늘 `Bag.size`인 칸들(빈 칸은 `false` — 원격으로 보낼 때도 그대로). 장비 = 한 칸에 하나, 소비 · 기타 = 묶음 `{ item, n }`. `give · take · count · room · move · sort · discard`. 달돈 · 달가루 · 정수는 칸을 차지하지 않는다.
  - 소비 · 기타 아이템은 공방 `items.js`의 `GOODS`(물약 넷 `potion1~4` + 퀘스트의 물건 `etc_*`) → `items.generated.luau`. 새 아이템은 여기에 넣는다(그림은 18도트, 소비 아이템은 퀵슬롯용 24도트도 — 없으면 내보내기가 멈춘다).
  - 퀘스트의 모으는 숫자 = 가방에 든 수(`Quests.sync` — 서버의 `sendBag`이 가방이 바뀔 때마다 맞춘다). 숫자를 따로 세지 않는다. 돌려주면 `Hero.questDone`이 가방에서 뺀다 · 그만두면 `Hero.questDrop`.
  - 퀵슬롯의 칸 = 스킬 · 소비 아이템의 이름표(예전의 `"potion"`은 없다 — `Quick.renew`가 예전 저장을 바꾼다). 숫자는 `Bag.countIn(가방, 이름표)`. 물약을 쓰는 것은 `Potion` 패킷에 이름표를 실어 보낸다.
  - 아이템 상세 판 `ui/itemDetail.luau`: 한 번에 하나, 주인 창 옆(`Windows.beside`). 글은 `shared/lune/ui/itemInfo.luau`(공방 `gearInfo · goodsInfo`와 같은 글 — 본보기로 맞춰 본다). 가방 · 장비 창 · 창고가 쓴다. 단추(장착 · 사용 · 분해 · 버리기 …)는 창이 아니라 이 판에 둔다.
  - 가방의 끌기는 `ui/quickEdit.luau`의 `press(what, from, input, extra)`가 맡는다. **Roblox는 끌기를 놓은 자리의 단추에도 `Activated`를 보낸다** — 끌기 직후의 눌림은 무시한다(`QuickEdit.dragging()` · `dragEnd`).
  - 예전 저장(소비 · 기타 칸이 없던 것)은 `Hero.unpack`이 물약 수 · 퀘스트의 숫자를 아이템으로 옮긴다. 저장의 꼴을 바꿀 때는 이렇게 잃는 것이 없게 옮기고 검사(15번 테스트의 "예전 저장")를 붙인다.
  - **창고 · 팔기 · 나누기(사용자 2026-10-08: "소비, 기타아이템도 창고에 맡길수있어야하고, 상점에 팔기 가능해야하고 묶음나누기 가능해야하고 창고에 드래그앤 드랍으로 맡기기가능해야합니다").**
    창고 = 가방과 같은 짜임(`h.store = { gear, use, etc }` — 탭마다 `Bag.storeSize` 칸). `Bag.storeIn/storeOut(h, 탭, 칸, 수, 놓을 칸)` · 창고 안은 `Bag.move/sort(…, true)` · `Bag.split` · `Bag.sell`(값 = `Items.sellPrice` · `GOODS.sell` — 공방 `items.js`의 `SELL`).
    서버의 일: `storeIn · storeOut · storeMove · storeSort`(창고지기 앞) · `sell`(상점 — 잡화 상인 · 대장장이 앞) · `split`(어디서나). `Item` 패킷은 인자가 넷까지다.
    창끼리 끌어다 놓는 길은 `state.ui`의 `bagDrop · bagHover · bagShow · storeDrop · storeHover · storeShow · shopDrop`(그 창이 열려 있는 동안만 있다 — 닫을 때 지운다). `ui.service` = "store" · "shop" · "forge"에 따라 가방 상세의 단추가 달라진다.
    수를 고르는 줄은 `ItemDetail.ask(kind, …)` 하나를 같이 쓴다(버리기 · 맡기기 · 찾기 · 팔기 · 나누기 — 글은 `WORDS.ask`). 새 "몇 개를" 일을 넣을 때도 이것을 쓴다.
    Studio에서 팔기를 확인하면 달돈이 바뀐다 — `Debug "money"`로 원래 값에 맞춰 놓는다(사용자가 그 사이 직접 플레이했을 수 있으니 Play를 켜자마자 달돈 · 물약 · 경험치를 적어 둔다).
  - Studio에서 확인할 때 사용자 캐릭터의 가방을 건드렸으면 되돌린다(시험용 아이템은 `Debug "potion"`으로 넣고 그만큼 버린다). 마우스 입력의 좌표는 `AbsolutePosition`(위쪽 여백 58을 더하지 않는다). Play를 켠 뒤의 첫 클릭은 창의 초점을 잡는 데 먹힐 수 있다.
- **하단 점프는 ↓ + 점프(사용자 2026-10-08: "아래방향+점프키 여야 하단점프되어야합니다").** ↓ 만으로는 발판에서 내려가지 않는다. `sim/physics.luau`의 `P.step`(↓ 를 누른 채 뛰기 + `P.onPlatform` → 발을 발판 윗면 바로 아래로) — 막힌 땅에서는 보통의 점프. 폰은 조이스틱 아래 + 「점프」. 시험 탭(`luneTab.js`)도 같은 식.
- Studio의 번호(studio_id)는 Studio를 다시 켤 때마다 바뀐다 — `list_roblox_studios`로 「슬래시 RPG」를 찾는다. 사용자가 Play 중이면(내가 시작한 것이 아니면) 멈추거나 입력을 보내지 않는다.
- **플레이어의 이름표는 어두운 판 + 민트의 가는 테두리(사용자 2026-10-08).** `ui.js`의 `UILAYOUT.tag.plate`, 시험 탭 `P.nameTag`, 게임 `Ui.tag(…, true)` — 나와 다른 사람만. 주민 · 졸개 · 문의 이름표는 판이 없다.
- 클라이언트 코드를 고친 뒤에는 자동 검사만 믿지 말고 Studio에서 띄워 콘솔을 본다 — `ui.luau`에 없는 이름(`UI`)을 쓴 것이 검사를 통과하고 Play에서야 드러났다(2026-10-08).
- **맵에 놓는 물건은 캐릭터를 가리지 않는다(사용자 2026-10-08: "z 인덱스 설정 잘못해서 캐릭터를 가려버리는게 몇개 있습니다").** 풀 · 덤불 · 화분 · 통 같은 것을 캐릭터 앞에 그리던 것을 모두 뒤로 보냈다 — 장면 자료의 `front`는 늘 비어 있다(`build_lune_demo.mjs` · `build_lune_maps.mjs` · `build_lune_town.mjs` · `build_lune_town2.mjs`).
- 사냥터 땅 그림의 분홍 줄기(왼쪽 아래)는 원래 그림에 있는 장식이다 — 오류가 아니다.
- 조작: 방향키는 로블록스 기본 조작이 먼저 가져가므로 `InputBegan`의 "처리됨" 표시를 보지 않는다(글자 입력 중만 뺀다). 키는 `input.luau`의 "하는 일 → 키" 표를 거친다(키 설정 · 터치가 이 표와 같은 이름을 쓴다).
- 움직임 수치는 공방 시험판(`js/lune/luneTab.js`)과 같아야 한다 — `config/game.luau`.
- 사용자 결정은 공방 설계 자료의 머리말과 메모리(`lune-world-design`)에 있다: 자동 사냥 없음 · 게임패드 없음 · PC와 스마트폰 · 키를 눌러 줍기 · 경매장으로 전부 거래 · 강화 세 구간 등.
- 지우기 전에는 묻는다(닌자 게임 코드 포함).

## 진행 중 — 이펙트와 2~4차 옮기기 (사용자 2026-10-08)

사용자: "시험탭의 이펙트를 게임으로 옮기세요 / 밀리지 않는다 설명에서 지우세요 / 2~4차 사출기, 설치기, 버프 다 옮겨야합니다."
게임에는 2~4차가 통째로 없다(주력기 · 전직도) — 사출기 강화 · 설치 · 버프를 옮기려면 전직과 2~4차 전부를 옮겨야 한다. 차례대로 한다(끝난 것은 [x]):

- [x] 0. 설명에서 "밀리지 않는다" 지우기(jobs.js — 액시온 일곱 곳).
- [x] A. 이펙트를 그리는 바탕(2026-10-08): 시험 탭의 fx.js는 점을 하나씩 찍는다 → 게임은 `EditableImage`(384x216 점 그림판 둘 — 캐릭터 뒤 · 앞)에 같은 식으로 찍는다.
  `client/lune/canvas.luau`(그림판 · ctx 흉내: `ctx:style(0xRRGGBB)` · `ctx:alpha(a)` · `ctx:rect` · `ctx:blit`(점 자료 그림)) · `shared/lune/fx.luau`(fx.js를 줄마다 옮긴 것 — 이름 · 인자 그대로. `Fx.new()`가 createFx()).
  그림판은 `SceneView`가 맵 틀에 붙인다(`view.fxBack` z25 · `view.fxFront` z56 — 장면이 바뀌어도 다시 쓴다). 화면 흔들림은 `view.shakeX · shakeY`.
- [x] B. 직업 묶음을 그대로 옮겼다(2026-10-08): `dino-workshop/js/lune/kits/<직업>.js` → `shared/lune/kits/<직업>.luau`(다섯 직업 · 1~4차의 쓰는 스킬 전부 + common). 찾아보기는 `shared/lune/kitset.luau`.
  줄마다 옮긴 것이라 고칠 때는 시험 탭의 js를 먼저 고치고 같은 줄을 맞춘다. 바뀐 이름: `end → finish` · `until → till` · `{ ...flame, … } → flameWith` · 색 `'#rrggbb' → 0xRRGGBB` · 목록은 1부터.
  시험판은 4차까지 다 배운 모습이다 — 스킬 레벨로 갈리는 곳만 `g.sk(스킬)`로 덧붙였다(파일 머리말에 적어 둠). 서버만 아는 일(확률 · 몇 번째 타)은 `g.call(이름, …)`(묶음의 `calls`)로 가른다.
  화면에서 돌리는 것은 `client/lune/cast.luau`(시험 탭 luneTab.js의 손잡이 g · 스킬 진행 · 날아가는 것 · 화면 효과 · 그리는 차례를 "보이기만" 옮긴 것): `Cast:actor`(나 · 다른 사람) · `Cast:start(사람, 스킬, 구간, 모은 단계)` · `Cast:hurt`(맞는 순간의 파편) · `Cast:proc`(지금 서버의 따로 나가는 타 → 묶음의 `procs`) · `Cast:chargeUp` · `Cast:toggled`.
  boot.luau: `startSeg`가 `cast:start`를 부르고(이동기는 예전 그대로 `Effects`의 잔상 · 속도선), `Hits`가 `cast:hurt` · `cast:proc`를, `Act`가 다른 사람의 것을 돌린다. 영혼 · 열기는 `syncKit`이 묶음의 `g.s`에 넣고, 달 수정은 `crystalAdd · crystalGone`.
  서버의 1차 판정은 그대로다(`COMBAT.skills` · `sim/kit.luau`) — 묶음의 `g.hit` · `g.hurt`는 화면에서 아무 피해도 주지 않는다.
  확인용: Play 중에 `PlayerGui.LuneStage`의 속성 `FxSpeed = 0.02`로 이펙트를 거의 세워 놓고 화면을 찍는다.
  몸에 입히는 모습(2026-10-08): `Cast:look(사람, 몸 그림, 동작, 장, …)`이 시험 탭이 몸을 그리는 줄들을 그대로 한다 — 크기(`a.scale` 거신의 두 배 · `Sprite:set`의 scale) · 비치는 몸(`a.alpha` — 그림자 숨기 · 연막 · 저승 걸음) · 한 색 실루엣(`a.sil` 그림자 숨기) · 윤곽 빛(묶음의 `heroGlow`) · 얹는 색(`heroTint`). 내 몸과 다른 사람의 몸 모두(boot.luau의 draw). 몸의 실루엣을 덧그리는 `g.sprite`(분신 · 망령 · 굳은 몸의 윤곽)도 된다.
  아직 안 된 것: `mobGlow`(졸개의 윤곽 빛 — 쪼개기의 갈라짐) · 리븐의 hud(월식의 달) · 액시온 버티기의 훑는 반짝임 · 화면 반전은 흰 번쩍임으로 대신 · 이동기의 속도선은 아직 `Effects`의 것.
  알게 된 것: 살라맨더의 발밑 열기 막대는 이름표에 가린다(버프 자리에 값을 같이 적어 둠 — 설계 basics.js는 "직업 게이지는 체력 바 위"라고 적는다. 자리를 정해야 한다).
- [ ] C. 2~4차 — 게임에 통째로 없던 것을 옮긴다. 차례(끝난 것은 [x]):
  - [x] C0. 차수(2026-10-08): `Hero.jobAt(level)` = 레벨로 정한다(30 · 60 · 100 — 설계 basics.js의 JOBQUEST는 2~4지역의 맵(r2a1 …)이 있어야 해서, 그 맵이 생길 때까지는 레벨만 되면 전직한다) ·
        스킬 포인트는 차수마다 따로(`Hero.spLeft(h, job)` — SPRULE: "받은 SP는 그때의 차수 스킬에만 쓴다". `h.sp`는 남은 것의 합) · 먼저 배워야 하는 스킬(`needs`) · 새 차수가 열리면 사냥기 · 보스기가 레벨 1로(`Hero.grantJob`) ·
        내 상태에 `job` · `sps`(차수마다 남은 포인트) · 스킬 창은 보고 있는 탭의 포인트와 「○○부터 배워야 한다」를 적는다 · 확인용 임시 캐릭터에 레벨(`LuneGuest = "riven:120"` — 열린 차수의 스킬을 모두 마스터, 버프는 D · R · F · 1 · 2 칸). 테스트 18.
        아직: 4차 21~30레벨의 「영웅의 비전서」 · 전직할 때의 공짜 초기화 · 전직 퀘스트와 연출("달이 부른다").
  - [x] C1. 서버가 직업 묶음을 돌린다(2026-10-08 — 2~4차의 쓰는 스킬 44개: 사냥기 · 보스기 · 공격기 · 큰 기술 · 바인드 · 달빛 치유. 소생만 빠졌다 — 쓰러지면 3초 뒤 마을이라 되살릴 틈이 없다):
        `shared/lune/sim/caster.luau`(방마다 하나 — `room.caster`). cast.luau(화면 — 보이기만)의 서버 쪽 짝: 손잡이 g가 진짜 판정을 한다(`g.hit · g.hitAt · g.hurt` 피해 · `g.bind` · `g.teleport` · `g.drag` · `g.heal` · `g.s.souls/heat/cr` = 캐릭터 · 방의 것).
        구간은 화면이 잇는다(`Skill(스킬, 구간, …)` — boot.luau의 `startKit · stepKit`: 보통 · loop · hold(키를 떼면) · charge · till(땅에 닿으면) · needPress). 서버는 `Caster:begin`에서 너무 이르지 않은지만 보고(앞 구간의 가장 짧은 시간 − 0.15초), 구간 안의 타는 서버의 시간으로 터뜨린다.
        피해(공방 `design/combat.js`의 `CASTRULE` · `CAST` → `COMBAT.cast` [제안]): 묶음의 값(3 · 6 · 12 …)은 몫. `Caster.profile(스킬, 모은 단계)`가 빈 방(`Caster.makeDry`)에서 열 번 써 보고 "한 번 쓰는 시간 T · 붙어 있는 적 한 마리가 맞는 몫의 합 W"를 잰다 →
        몫 w의 타 = 전투력 x rate(POWER.dps x 쓰임 x 차수 1.3 · 1.6 · 2.1) x (T + 다시 쓰기 x 0.2) x 스킬 레벨의 세기 x w / W. 장치가 얹는 것(표식 터뜨리기 · 달아오름 · 영혼)은 그 위에. 따로 정한 것: 공명 폭발 w 20 · 열 방출 w 23 · 재는 자리(도약 강타 60 · 불덩이 134 · 화염 질주 180).
        맞힌 뒤에 따라붙는 것(사출기 · 표식 · 영혼 · 열기 · 수정)은 묶음의 onHit이 아니라 1차와 같은 `Room:kitAfter`(opts.mark = 표식을 남기는 타만). 졸개에 걸리는 것: `mob.bind · bindImm · stun · rend · cracks`(방이 줄인다 — 묶인 · 넘어진 졸개는 `stepMob`이 건너뛴다. `Snap`의 일곱째 · 여덟째 = 묶인 · 넘어진 시간).
        순간이동: 화면이 먼저 옮기고(cast.control.teleport) 서버도 같은 스킬을 돌려 옮겨 적는다. 스킬을 받은 뒤 1.5초는 280도트까지 멀리 간 자리 보고도 받고, 그 밖의 먼 보고는 받지 않고 `Warp`로 화면을 되돌린다(예전에는 그 뒤로 영영 어긋났다). 새 패킷 `Warp · Healed · Cool`.
        다른 사람의 것: `Act`가 구간마다 온다 → othersView의 동작(kitDef) + cast:start. 테스트 21(790개 — 스킬마다 "열 번 쓴 피해의 합 = 설계의 피해").
        모자란 것: 땅에서 쓰는 기술(ground)을 공중에서 쓰면 내리꽂는 것은 없다(땅에서만 써진다) · 미는 타(kb)는 3도트만 민다 · 띄우기(lift)는 없다 · 서버는 화면이 알려 온 자리(0.1초마다)로 판정한다(돌진 중에는 조금 뒤처진다).
  - [x] C2. 버프(2026-10-08): 수치는 공방 `design/combat.js`의 `BUFFS`(→ `COMBAT.buffs` — 세기는 시험판 kits의 mult · haste 값을 마스터 값으로, 스킬 레벨의 세기를 곱한다 [제안]), 셈은 `sim/buffs.luau`
        (`h.buffs` · `h.cds` — 저장하지 않는다: `cast · give · tick · dmg · haste · cut · guard · ward · full · view`). 서버: `Skill(버프, 1, …)` → `Buffs.cast`(파티 버프는 가까운 파티원에게도) → 방에 `Act`(걸리는 순간) · `Buffs`(걸린 것), 내 상태에 `buffs`(list · cds) · `haste`.
        주는 피해는 `Room:skillHit`의 전투력에 곱하고, 받는 피해 · 생존기 · 죽음의 가호는 `Room:hurtHero`. 공격 속도는 1차 기술의 구간 시간 · 타격 시점을 나눈다(서버 `onSkill` · 화면 `stepSkill` · `cast.luau`). 만월 = 모으지 않아도 끝까지 모은 강타.
        화면: 칸의 키로 건다(`trySkill` → `cast:instant` = 묶음의 `cast(g)` 이펙트) · 오른쪽 위에 그림과 남은 초(`paintBuffs`) · 칸에 다시 쓰기 시간 · 걸려 있는 동안의 모습은 묶음의 `drawBack · draw`(만월의 기운 …). 테스트 20 · 13.
        거신(2026-10-08): `fx.big` — 몸이 두 배(화면) · 기술이 닿는 거리(앞 · 위) +50%(`Buffs.big` → `Room:skillHit`의 상자). 그림자 분신: `fx.echo · after` — 베기에 맞은 적마다 0.25초 뒤에 그 타 피해의 40%를 한 번 더(`Buffs.echo` → `Room:later` → 기록의 `proc = "clone"` → 묶음의 `procs.clone`), 표식도 남긴다. 테스트 20.
        다 옮기지 못한 것(BUFFS의 머리말에 적어 둠): 수정 방벽의 대신 받기와 보호막 · 맞불의 되받아치기 · 달의 성역의 회복 · 사신화의 따라 베기 · 용사의 의지(상태 이상이 게임에 아직 없다 — 수치가 비어 있어 찍히지 않는다).
        모자란 것: 방에 나중에 들어온 사람은 이미 걸려 있던 남의 버프를 다음에 바뀔 때까지 못 본다 · 다시 쓰기는 나갔다 들어오면 풀린다.
  - [x] C3. 사출기 강화 패시브(2026-10-08 — 2~4차, 직업마다 셋): 수치는 공방 `design/combat.js`의 `KITUP`(→ `COMBAT.kitUp[직업] = { two, splash|hop|burn|pierce, fast }` [제안]), 판정은 `Room:kitAfter`의 사출기 부분(1차의 것에 얹었다 — 묶음의 onHit로 갈아타지는 않았다).
        따로 나가는 타의 기록에 `i`(몇째 것) · `n` · `hop`(튕긴 것) · `up`(배운 강화 — 1 하나 더 · 2 셋째 갈래 · 4 넷째 갈래)이 붙고, 화면은 묶음의 `procs`가 그 모습으로 그린다(남의 것은 `up`으로 그 사람의 강화를 안다).
        조금 뒤에 들어가는 타(붙는 불)는 `Room:later` → 방의 한 걸음이 `"kit"` 일로 알린다 → 서버의 `applyResult`(판정의 결과를 방에 푸는 것 — onSkill에서 꺼내 한 함수로 만들었다). 테스트 19.
        화면에 번지는 타 · 꿰뚫는 타 · 붙어 타는 타(splash · pierce · burn)는 숫자만 뜬다(날아가는 그림은 첫 타의 것 하나).
  - [x] C4. 설치 · 소환(2026-10-08 — 연막탄 · 수정 심기 · 화로 · 저승문 · 망령 · 수호령 · 작은 태양): 수치는 공방 `design/combat.js`의 `PLACED`(→ `COMBAT.placed` — kind: field 그 자리에 · follow 따라다닌다 · crystal 달 수정 하나. `mul` = 초당 피해의 배수 [제안]), 쓰는 동작이 있는 셋(연막탄 · 수정 심기 · 저승문)은 `SKILLS`에 판정 없는 동작만 있고 그 장(`at`)에서 놓인다.
        서버: `Room:place` · `Room:stepPlaced`(태우기 `"field"` · 치기 `"summon"` · 끌어당기기 · 화로 곁의 열기) → `"kit"` 일. 저승문 곁에서 쓰러진 적은 영혼을 더 준다(`Room:strike`). 망령은 영혼 3을 태운다. 연막탄 · 작은 태양은 같은 이름의 버프가 같이 걸린다. 화면은 묶음의 그 스킬(`cast` · 날아가는 것)이 그린다. 테스트 20의 5).
        모자란 것: 수호령의 치유 · 망령 군단(셋) · 수호령 각성(둘)은 아직 · 소환이 치는 모습은 화면의 제 박자로 돈다(서버의 타와 꼭 맞지는 않는다) · field · summon 타는 숫자만 뜬다.
  - [x] C4-2. 아직 게임에 없는 스킬은 찍히지 않는다(2026-10-08 — 사용자가 1차 때 짚은 "찍히는데 효과가 없는" 일을 막는다): 공방 내보내기가 `COMBAT.ready`(게임에 있는 스킬 — 기술 · 1차의 사출기/장치/패시브 · 수치가 있는 버프 · 사출기 강화 · 설치/소환)를 만든다. 지금 157개 가운데 74개.
        `Hero.ready(id)` — `skillUp`이 거절한다 · 처음부터 주는 기술(`grants`)로도 주지 않는다 · 먼저 배워야 하는 스킬이 아직 없는 것이면 그 조건은 보지 않는다(만월 ← 깊은 호흡) · 막기 전의 저장에 찍혀 있던 것은 포인트로 돌려준다(`unpack`) · 확인용 임시 캐릭터도 있는 스킬만 마스터한다.
        스킬 창: 이름이 흐리고 + 가 꺼져 있고, 설명 아래에 빨간 글 「아직 준비 중인 스킬 — 포인트를 쓸 수 없다」(`SKILLWORDS.soon`). 테스트 18. 스킬을 옮길 때마다 저절로 풀린다(수치를 넣으면 ready에 들어간다).
  - [x] C5. 패시브 37개(2026-10-08): 수치는 공방 `design/combat.js`의 `PASSIVE`(→ `COMBAT.passive` [제안] — 효과 글은 `passiveText`), 셈은 `sim/passives.luau`(`atk` 공격력에 늘 곱한다 · `vs` 그 적에게만 붙는 것 · `cut · dodge · rekindle` 받는 쪽 · `crit` 표식 치명타 · `reach` 닿는 거리 · `get · count` 그 밖의 값). 캐릭터의 상태 `h.pass`(저장하지 않는다).
        거는 곳: `Room:skillHit` · `Caster:strike`(공격력 · 그 적 · 치명타 · 이어 맞히기 · 넘치는 힘) · `Room:hurtHero`(회피 · 받는 피해 · 재점화) · `Room:kitAfter`(깊은 흡수 · 달빛 칼날) · `Room:mark · marksOf`(깊은 표식 — 기록의 `markN`) · `Room:addCrystal`(수정 군락) · `Room:place`(망령 군단 · 수호령 각성) · `Room:step`(스미는 독 → `"kit"` 일의 proc "venom") · `Room:strike`(폭주가 는다)
        · `sim/kit.luau`(`chargeLevels` 깊은 호흡 · `soulMax` 영혼 주머니 · `hotAt` · 열기 — 끓는 피) · `Buffs.echo`(쌍영) · server world.luau(충격파 = 끝까지 모은 대지 강타 뒤 0.3초에 넓은 한 타 · 넘치는 힘 = 모으지 않아도 2단계(`charged.surged`) · 꺼지지 않는 불 = 폭주가 끝날 때 열기 50). 테스트 22(531개) · 13.
        게임에 없는 것(숙련도 · 방어 무시 · 치명타 · 띄우기 · 등 뒤)은 공격력 + · 최종 피해 + 등으로 합쳤다(PASSIVE의 머리말). 아직 없는 조각: 깊은 호흡의 모으면서 걷기 · 받은 피해가 힘으로 / 수호령 각성의 공명 기준점 / 별빛 가호의 치유할 때 공격력 + / 망령 군단의 망령이 쓰러뜨려도 영혼.
        남은 것: 용사의 의지(상태 이상이 생길 때를 위해 미리 넣어 둔 것 — 그때까지 찍히지 않는다) — 157개 가운데 156개가 게임에 있다.
  - [x] C6. 사용자의 답(2026-10-08)을 받아 넣은 것:
        치명타 — `COMBAT.rules.critChance · critMul`(5% · 1.5배 [제안]). `Passives.crit(캐릭터, 표식이 있는가)` → 확률 · 배수 · 반드시(흘리기). `Room:skillHit` · `Caster:strike`가 굴린다(확률이 0이면 굴리지 않는다 — 테스트 파일은 맨 위에서 0으로 꺼 두고 22번에서만 켠다). 시험 탭 luneTab.js의 hurt에도 같은 확률.
        숙련도 = 최종 피해 — jobs.js의 숙련 · 달인 열 개의 글을 고쳤고, PASSIVE는 `final + atk`(달인은 `critMul`) · 급소는 `markCritMul`.
        몬스터의 체력은 차수에 맞춰 올리지 않는다(더 강한 몬스터를 새로 넣는다).
        쓰러진 뒤 — 저절로 일어나지 않는다. `Hero.tick`은 `revive`(돌아갈 수 있기까지 — `reviveWait` 2초)만 줄이고, 화면이 그 뒤에 묻는 상자(`ui/deathBox.luau` — 치수와 글은 공방 ui.js의 `UILAYOUT.death`)를 띄워 `Return` 패킷을 보내면 `onReturn`이 마을에서 일으킨다.
        비석 = `client/lune/grave.luau`(사냥터 props의 `grave` 그림 — 장면의 `Graves` 층 z35, 캐릭터 · 졸개보다 뒤) — 내 것은 boot의 draw, 남의 것은 othersView.
        소생 — `CASTRULE.heal.mn_revive = { revive, reach }` · `g.revive()`가 `ctx.fallen`(server world.luau의 `fallenIn` — 닿는 거리 안의 쓰러진 파티원)을 `Hero.raise`로 일으킨다(벌칙 `weakWas`를 되돌린다) → `"raised"` 일 → `Raise` 패킷. 레이드의 데스카운트는 아직 없다.
        배운 것: 클라이언트가 보내는 패킷에는 `Args`와 `RateLimit`이 꼭 있어야 한다(없으면 진짜 서버에서 받는 순간 오류 — 테스트 13이 이제 본다).
  - [x] C7. 사용자의 두 번째 답(2026-10-08): 비석 · 묻는 상자 · 마을 귀환 = 승인("비석은 이대로 좋습니다. 죽었을때 이대로 하시죠").
        새 차수의 스킬은 레벨 1부터 앞 차수 마스터보다 세다("이건 기본이에요") — `CASTRULE.start 1.1 · master 1.4 · floor = start ÷ master(0.7857) · tier = 1 · 1.4 · 1.96 · 2.744`. 2~4차의 쓰는 스킬의 레벨의 세기 = `Caster.scale`(floor → 1), 1차 · 버프 · 패시브 · 회복은 `Hero.skillScale`(0.4 → 1) 그대로. 공방 규칙 검사가 "n차 레벨 1 > (n−1)차 마스터"를 본다.
        도약 강타 = `g.hit(-42, 42, …)`(등 뒤 42도트까지 — 시험 탭 kits/axion.js와 게임 kits/axion.luau 같이). `CAST.ax_leap.at`은 지웠다(붙어 있는 적으로 잰다).
        가시 = `RULES.spike`(최대 체력의 5%) · `Physics.onSpike(장면, x, y)`(발이 놓인 칸이 '^') · `Room:step`이 닿아 있는 사람을 `Hero.hurt`로 친다(invuln 0.6초마다 · 버티기 동안에는 안 든다 · 쓰러질 수 있다) → "hurt" 일. 시험 탭 luneTab.js에도 같은 식(쓰러지지 않고 1에서 멈춘다).
  - [x] S1. 이야기를 사용자가 불러 준 것으로 바꿈(2026-10-08 — 6차): 신이 만든 사람의 세상 → 용이 빼앗아 군림 → 블랙드래곤을 다섯 용사가 봉인하며 함께 봉인(5000년 전) → 숨어 살던 가문에 용사를 닮은 예언의 아이들(도끼 액시온 · 창 리븐 · 낫 리퍼 · 대검 무니 · 불 살라맨더) → 흔적을 찾아 진실(수뇌부가 폴리모프한 용)을 알고 저항.
        보스의 차례 = 상관없는 보스 → 하급 드래곤 → 더 큰 드래곤 → 수뇌부 → 왕 → (3년 뒤) 군단장을 석 달에 하나 → (5~6년째) 블랙드래곤. 처음에는 아무 이야기도 들려주지 않는다.
        공방: `js/lune/design/story.js`(STORY.said = 사용자의 말 그대로 · ladder · later · arcs[].lord — 5차는 `story.v5.bak.js`) · `world.js`(REGIONS[].lord/force · BOSSES의 레이드 다섯 = 고개 영주 · 숲 영주 · 광산 영주 · 옛 왕도 총독 · 대영주 · LIFE.roadmap의 stage · MAIN · TRUTHS · CLUES) · `quests.js` · `questplay.js` · 숫자/기초/경제의 이름(용비늘 세트 · 용뿔 세트 · 용사의 비전서 · 흔적의 공명).
        게임: 1지역 퀘스트 글(r1m1 「첫 기술」 · r1m3 「빈 갑옷」 · r1s2 「낡은 달력」 — id는 그대로) · `classes.generated`의 face/hero → old(닮은 옛 용사) · order = axion · riven · reaper · mooni · salamander · `chooser.luau`의 머리글은 무기 이름만.
        내가 채운 것(판정 받을 것 — STORY.open): 네 지역에 이야기를 놓은 것 · 영주 = 하급 드래곤 · 갑옷 병사 = 용이 부리는 것 · 첫 해 레이드의 간격 · 군단장의 수 · 리븐의 무기(창 — 게임은 아직 쌍날) · 가제와 달 이름들.
  - [x] S2. 사용자의 답(2026-10-08): 군단장은 나중 이야기 — 지금은 그 앞의 보스만("일단 군단장은 없어요") · 가제와 달 이름 · 「묵은 용」은 그대로.
        리븐의 무기는 처음부터 창이다("쌍날이라는거 할루에요") — 내가 잘못 적어 온 것을 고쳤다: `jobs.js`의 weapon · `basics.js`의 WEAPON.kinds · 스킬 이름(rv_mastery 「창 숙련」 · rv_expert 「창 달인」 · rv_fan 「창날 부채」 — id는 그대로) · 게임의 `classes.generated` · `items.generated`.
  - [x] S3. 리븐의 아이콘은 바꾸지 않는다 — 사용자 2026-10-08: "아이콘 굳이 안바꿔도 됩니다". 무기 아이콘(w_dagger) · 스킬 아이콘 31개는 지금 것을 그대로 쓴다.
        창으로 다시 뽑아 본 그림(`assetpack/lune/ui/raw_skills_rv.png` · `tools/make_lune_riven_icon_prompt.mjs` · `assetpack/lune/dev/RIVEN_spear_icons.png`)은 쓰지 않은 채 남겨 두었다. 아이콘을 주문하는 글의 리븐 설명만 창으로 고쳐 두었다(`tools/make_lune_skill_icon_prompts.mjs` — 앞으로 새로 뽑을 때를 위해).
  - [x] S4. 사용자 2026-10-08: "리븐 무기 그림 다시 그리면됩니다." → 무기 그림만 창으로 바꿨다(스킬 아이콘은 그대로). `assetpack/lune/ui/raw_w_spear.png`(raw_skills_rv.png의 마지막 칸) · `weapon_sheets.json` → 아이콘 묶음 둘에 `w_spear`로 얹는다:
        18도트 `ICON_MORE=etc_sheets.json,weapon_sheets.json node tools/build_lune_icons.mjs` · 24도트 `ICON_PREFIX=icons24 ICON_SHEETS=raw_icons_a.png,raw_icons_b.png ICON_MORE=skills_sheets.json,weapon_sheets.json node tools/build_lune_icons.mjs 24`(ICON_MORE는 이제 쉼표로 여러 개) → `node tools/build_lune_ui.mjs` → 내보내기 → ui_kit.png 올리기.
        쓰는 곳: 시험 탭 `luneTab.js`의 WEAPON_ICON.riven · 게임 `client/lune/ui/itemCell.luau`의 WEAPON.riven = "w_spear". 예전 그림 w_dagger는 묶음에 남아 있지만 쓰지 않는다.
        같은 날: 옛 용사 다섯의 이름은 없다 — 아무도 모른다("옛용사 이름 없습니다") · "나머지는 알아서 채우세요" — 이야기의 남은 빈칸은 묻지 않고 내가 채운다(STORY.open = 내가 채운 것).
  - [x] U1. 플레이어의 이름표 = 어두운 판 + 민트의 가는 테두리(`UILAYOUT.tag.plate` · `ui/paint.js`의 nameTag · 게임 `Ui.tag(…, plate = true)`) — 그대로 둔다.
        2026-10-08에 "글자 그자체 테두리에 민트 테두리"로 바꿔 봤으나(흰 글씨 + 어두운 테두리 + 민트 — 실루엣 글자판 font_small_r) 사용자가 보고 "생각보다 별로네요 이전방식으로 롤백" → 판으로 되돌리고 그 방식의 코드 · 글자판 · 내보내기를 모두 걷어 냈다. 다시 꺼내지 않는다.
  - [x] M1. 1지역의 맵 둘(2026-10-08): `r1a3` 사냥터 깊은 곳(Lv.6~9 · 검병 6 · 궁병 8) · `r1a4` 버려진 야영지(Lv.8~10 · 궁병 9 · 가시 구덩이). 설계 `js/lune/design/maps.js`(spikes = 가시 · LINKS의 add = 처음부터 있던 장면에 문을 더 세운다 — 사냥터의 오른쪽 끝) · 졸개 레벨 `combat.js`의 FIELD.
        메인 넷째 「발자국을 따라」의 놀이 자료(`questplay.js` — 궁병 열 · 촌장 → 무쇠뿔). 확인용 명령 `Net.FireServer("Debug", "portal", n)`(Studio에서만 — 그 장면의 n째 문 앞으로 옮긴다. 그 뒤 ↑).
        남은 것의 차례: 1지역 끝까지(맵 12 · 퀘스트 13 · 보스) → 전직 퀘스트 → 2지역(새 그림 — 확인 요청부터) → 3 · 4지역 → Lv.150의 놀거리 → 드래곤 레이드.
  - [ ] M2. 맵 배치를 다시 짠다 — 사용자 2026-10-08: "마을에서 출발해서 사냥터만 쭉 계속 이어붙이는게 아니라 작은마을 이 있거나 여행을 하는듯한 구조로 … 여러 다른 rpg 형식 도트게임들 정보를 많이 찾아보시고 맵 설계를 어찌할찌 계획을 세워보세요".
        조사(횡스크롤 온라인 RPG · 도트 RPG · MMORPG의 지역 설계 — 19가지 · 출처)와 계획 = 공방 `js/lune/design/journey.js`(「월드 · 퀘스트」 탭의 맨 위): 규칙 아홉(큰 마을 + 작은 마을 + 쉼터 · 줄기 + 가지 + 지름길 · 갈림목 쉼터 · 쉬는 곳 사이는 네 장까지 · 맵의 갈래 늘리기 · 구간의 표지와 멀리 보이는 목적지 · 퀘스트를 거점마다 · 달빛 문은 마을에만 · 다시 만나는 사람)
        · 1지역 본보기(새로 넣는 곳: 세 갈래 길 · 고갯마루 주막 · 수비대 야영지 — 맵 17 → 19) · 2~4지역의 얼개. **판정을 받기 전에는 맵을 더 짓지 않는다.** 받은 뒤: world.js의 지역 표 → 쉼터 · 달빛 문 기능(시험 탭 먼저) → 새 그림(확인 요청) → 줄기의 차례로 맵.
        → 판정(2026-10-08): "오케이 좋습니다" — 짜임은 승인. 더해진 것: "맵은 맵의 컨셉마다 생긴건 달라져야합니다"(규칙 — 구역마다 새 그림) · 대도시 · 정거장(그리폰 · 하늘을 나는 배) · 바닷길 · 해저 · 대륙 단위의 설계.
  - [ ] M3. 대륙 단위의 설계(계획 — 공방 `js/lune/design/continents.js`, 「월드 · 퀘스트」 탭의 맨 위): 출시 때 대륙 둘(서쪽 = 초승 고개 · 대도시 은달 항구 · 수정 숲 / 동쪽 = 등불 포구 · 땅속 화롯골 · 만월성) · 대도시의 맵 여섯(성문 거리 · 달맞이 광장 · 장터 거리 · 하늘 승강장 · 부두 · 영주의 언덕)
        · 탈것(비행선 · 배 · 그리폰 · 나룻배 — 달빛 문은 같은 대륙 안에서만) · 바닷속 「가라앉은 항구」와 왕도가 있는 대륙은 출시 뒤 · 구역마다의 그림 묶음 스물다섯 벌. **판정을 받기 전에는 world.js를 고치지 않는다.**
        물음 셋: 대륙 둘과 대도시의 자리(Lv.30) · 탈것의 기다림(60초) · 바닷속을 출시 때 넣을지.
        → 판정(2026-10-08): "1. 좋습니다. 2. 좋습니다. 3. 바다마을도 뭐 따로 구현하고 사냥터가 있는게 좋을거같습니다." — 대륙 둘 · 대도시 · 기다림 60초(그렇게 읽었다) 승인, 바다는 출시 때부터: `CONTINENTS.sea`(물마루 마을 + 사냥터 아홉 장 · Lv.45~75 · 배로만).
  - [x] M4. `world.js`의 1지역을 승인받은 짜임으로(맵의 갈래 rest · village · road / 새 맵 r1af 세 갈래 길 · r1bv 고갯마루 주막 · r1cc 수비대 야영지 / r1ah 없앰) · 월드맵의 글과 다니는 법을 대륙 둘로. 2~4지역의 표는 아직 한 줄.
  - [x] M5. 컨셉마다 다른 생김새 — 1지역의 새 생김새 넷(바위 산길 · 고갯마루 주막 · 끊긴 돌다리 · 돌 망루의 안)의 시안: `assetpack/lune/looks/concept_r1_looks.png`(프롬프트 `prompt_r1_looks.txt` · 참고 그림 = 지금의 숲 맵과 게임 화면) → 확인 요청에 올림. **판정을 받은 뒤** 게임의 도트 굵기(16점 칸)와 색으로 다듬어 땅 조각 · 소품 · 배경을 만들고(맵을 짓는 도구가 생김새를 고를 수 있게) 줄기의 차례로 맵을 짓는다.
        → 판정(2026-10-08): "도트 사이즈랑 여러요소가 우리게임이랑 다른데요 분위기 자체는 맘에듭니다." — 분위기는 승인, 그림은 게임의 것으로 다시.
        다시 만드는 법(바위 산길로 해 봄): 게임의 진짜 그림을 키워 참고로 붙이고(`looks/ref_tiles_x6.png` · `ref_props_x3.png`) 게임의 색만 쓰게 한 묶음 프롬프트(`looks/prompt_rock_kit.txt` — 마을 흙 발판의 글투) → `raw_rock_kit.png` → `tools/lune_pixelize.mjs`로 한 점 = 6화소로 줄임(색 14가지, 모두 게임의 색)
        → `tools/build_lune_look.mjs`: 조각을 가르고(바위 덩어리 · 뜬 바위 셋 · 소나무 둘 · 선바위 · 바위 더미 · 돌탑) 바위 덩어리를 무늬로 땅을 깔아(속무늬 이어 붙이기 + 윗면의 서리 띠 + 옆면의 절벽) 시험 맵 「고갯길 초입」을 짓는다 → `looks/rock/preview.png` · `compare.png`(지금의 숲 맵과 나란히). 확인 요청에 올림 — 판정 대기.
        → 판정(2026-10-08): 바위 산길 "좋습니다. 근데 배경도 달라야겠죠?" → 뒷배경도 따로 뽑음(`prompt_rock_bg.txt` → `looks/rock/far.png` · `near.png`) → "오케이 좋습니다 쭉쭉 작업하세요".
        생김새 한 벌 = `looks/<이름>/look.json`(block = 땅의 무늬 · slabs = 뜬 발판의 칸 수 · deck = 돌다리의 조각 치수 · layers = 뒷배경) — `tools/lune_look.mjs`(땅을 까는 법 `makePainter` · 돌다리를 잇는 법 `makeDeckPainter`)가 읽는다.
        소품은 모든 맵이 한 장을 같이 쓴다: `looks/props_all.png` + `props_all.json`(지금의 소품 + 바위 산길 + 주막 + 돌다리 = 256x731 · 자리 48개). 게임에서는 `props_r1a1.png`라는 이름으로 한 번만 올라간다.
        끊긴 돌다리(2026-10-09): `prompt_bridge_kit.txt` → `raw_bridge_kit.png`(한 점 = 6화소) · `prompt_bridge_bg.txt` → `raw_bridge_bg.png`(384점 폭의 격자 — 한 점 ≈ 5.66화소, 주문한 크기와 달리 2172x724로 나왔다).
        뒷배경을 줄일 때 그림 속의 빈 데(깃발 아래 · 아치 속 · 창)를 메우지 않는 방식(`strip(..., holes = true)`)을 넣었다 — 줄이면서 끊긴 깃대는 한 점 굵기로 다시 잇는다. 먼 겹은 옆으로 60점 밀어(roll) 96칸 맵을 끝까지 걸어도 망루가 하나만 보이게 했다.
  - [x] M6. 고갯길을 게임에 이음(2026-10-09): `maps.js`에 r1af 세 갈래 길(쉼터 · 샛별) · r1b1 고갯길 초입(오른쪽 문 추가) · r1b2 굽잇길 · r1bv 고갯마루 주막(작은 마을 · 반달) · r1b3 무너진 다리(look: 'bridge').
        맵 자료에 더한 칸: `decks`(돌다리의 상판 — 얇은 발판 '=' 의 줄 · 끝은 cliff / broken) · `npcs`([이름표, 칸, 그 자리의 대사] — 마을의 주민(town.js)이나 길 위의 사람(`people.js`)) · `rest`(쉬는 곳) · `back`의 셋째 칸 true(다리 위에 놓는다).
        문 곁의 빈 터: `maps.js`의 `gateNeed(see) = see + 16` — 몬스터 구간의 가까운 끝이 모든 문에서 그보다 멀어야 한다. 규칙 검사(`check_lune_design.mjs`의 "지은 맵")가 막고, 처음부터 있던 사냥터는 내보낼 때 구간을 물리거나 뺀다(`export_lune_game.mjs` — "내보내면서 고친 것"으로 알린다). 게임 검사 `12_lune_combat.luau`.
        쉬는 곳: `combat.js`의 `COMBAT.rest = { wait: 2, every: 1, heal: 10 }`([제안]) → 게임 `sim/room.luau`(장면의 `rest` — 맵 자료의 rest + 마을 + 건물의 실내) · 시험 탭 `luneTab.js`. "healed" 일로 알려 민트색 숫자가 뜬다.
        시험 탭: `SCENES`에 지은 맵 여덟 장 · `linkPortals(key, scene)`(maps.js — 사냥터 · 마을의 문을 게임과 같이 잇는다. 내보내기 도구와 같이 쓴다) · 떠나온 장면으로 돌아가는 문 앞에 선다(`arriveFrom`).
        Studio 확인(손님 리븐 Lv.16): 마을 → … → 무너진 다리까지 문으로 넘어감 · 쉬는 곳의 회복 · 문 앞에서 안 맞음 · 반달의 상점 · 다리 위 걷기 · 골짜기에서 다시 올라오기. 시험 탭은 헤드리스 Edge로 화면 두 장을 찍어 봄
        (`msedge --headless=new --screenshot=… --virtual-time-budget=9000 "http://localhost:8090/?lunescene=r1b3#lune"` — PowerShell의 Start-Process로 돌려야 그림이 남는다).
        남은 것: 무너진 다리의 오른쪽 문(망루 아래) · 주모 · 고갯마루 노인 · 수비대원(그림 확인 요청부터) · 달빛 문 · 숨은 문과 멧돼지 굴 · 이 맵들의 퀘스트 · 떠 있는 조각을 디뎌 끝까지 건너 보기.
  - [x] M7. 망루의 문 앞까지(2026-10-09): r1b4 망루 아래(`h: 22` — 오르는 맵 · look `towerfoot`) · r1cc 수비대 야영지(look `camp` · 망루의 밑동 `tower`) · 무너진 다리의 오른쪽 문.
        오르는 맵: 맵 자료의 `h`가 14보다 크면 `scene.tall` — 게임과 시험 탭의 카메라가 발밑을 따라간다(마을과 같은 식). 뒷배경의 y는 빌더가 고쳐 적는다(맨 아래에 섰을 때 보통 맵과 같은 자리: `y - 26 + (맨 아래 땅 - 150) * f * 0.5`).
          처음엔 보통 맵(14칸)으로 지었는데 게임에서 맨 위 고원이 화면 꼭대기에 몰려(보통 맵은 카메라가 세로로 안 따라간다) 다시 지었다 — **땅이 네 칸 넘게 오르내리는 맵은 오르는 맵으로 짓는다.**
        망루 그림: `prompt_tower_kit.txt` → `raw_tower_kit.png`(밑동 139x118 + 목책 · 군기 · 창 걸이 · 수레 · 화로) — 밑동의 창 층(41점)을 두 번 더 쌓아 193점(화면 위로 솟게 · 쌓는 층의 깃발은 지운다) → `looks/tower_kit.png` → 소품 한 장(256x924 — 1024가 한계).
          `prompt_tower_bg.txt` → `raw_tower_bg.png`(안개처럼 흐릿하게 나왔지만 알파를 반으로 가르니 깨끗한 실루엣) → `looks/towerfoot/far.png`(79점 밀어 망루가 하나만 보이게) · `looks/camp/far.png`(망루를 지운 것 — 야영지에는 진짜 망루가 소품으로 선다) · 가까운 겹은 둘이 같이 쓴다.
        새 주민 넷: `people.js`(달래 · 고갯마루 노인 · 차돌 · 여울 — 이름 · 대사는 내가 지음) · 그림 `assetpack/lune/people/`(`prompt_people.txt` → `raw_people.png` → `tools/build_lune_people.mjs` → `people.png` · `compare.png` · `lineup.png`) → `looks/villagers_all.png` + `.json`(마을 여섯 + 넷 — 게임의 `villagers.png`도 이 한 장).
          첫 그림은 키 30점(네모 ≈ 10.3화소)으로 잘게 나와 키 23점에 맞춰 간격을 다시 잡아 줄였다(시작점은 칸마다의 색이 가장 고른 자리). 어두운 색은 2-평균으로 얼굴(#232931)과 몸(#393e46)을 갈랐다. 다시 뽑은 것(`raw_people_v2_outlined.png`)은 테두리 · 음영이 들어가 버림. **확인 요청 — 판정 대기.**
        확인용 명령(Studio 전용): `Net.FireServer("Debug", "goto", n)` — n = 장면 이름표를 ABC 차례로 늘어놓은 번호(확인용 명령은 숫자만 받는다 — packets.luau). 옮긴 뒤 `("Debug", "portal", k)`로 그 맵의 k째 문 앞에 선다.
        남은 것: 옛 망루 1~3층(세로로 오르는 던전 — 안의 그림이 필요) · 망루 꼭대기(지역 보스) · 망루의 문 열기 · 옛 은신처 · 멧돼지 굴 · 사당 지하 · 달빛 문 · 새 주민이 해 주는 일 · 이 맵들의 퀘스트 · 필드 보스.
  - [x] M8. 옛 망루의 안(2026-10-09): r1c1 · r1c2 · r1c3(24칸 x 40칸 · look `towerin`) · 수비대 야영지의 망루 문 → r1c1.
        짜임(`maps.js`의 `towerFloor(side)` · `towerDecor` · `flipMobs`): 바닥 37줄 + 층 31 · 25 · 19 · 13 · 7줄(한 줄 두께의 돌) — 층마다 한쪽 끝 네 칸이 구멍, 구멍에 나무 발판(plank3 — 네 칸) 둘(층의 높이 · 그 세 줄 아래). 'R'은 좌우를 뒤집은 것.
        맵 자료에 더한 칸: back의 셋째 칸에 줄 번호(+ 넷째 칸 = 띄우는 높이) · gates의 넷째 칸에 소품 이름(안쪽 문 `door`) · 여섯째 칸 = 문이 선 줄 · spawn = [칸, 줄] · npcs의 다섯째 칸 = 줄.
        안쪽 벽: `prompt_towerin_wall.txt` → `raw_towerin_wall.png`(한 화면 폭의 한 마디) → 세 번 쌓아 `looks/towerin/wall.png`(384x768) — 겹의 f = 2로 두면 오르는 맵에서 세로로 맵과 똑같이 움직인다(`y - 카메라 * f * 0.5`).
          가로는 2배로 움직이므로 **이 방식의 맵은 꼭 한 화면 폭(24칸)이어야 한다**(게임 검사 10_lune_physics가 막는다). 안의 조각: `prompt_towerin_kit.txt` → `raw_towerin_kit.png`(돌 바닥 · 발판 셋 · 횃불 · 사슬 · 문 · 상자 · 부조).
        소품 한 장이 256x1017 — **1024의 한계에 닿았다.** 다음 그림 묶음부터는 생김새마다 소품 그림을 따로 두게 고쳐야 한다(지금은 장면마다 소품 그림이 한 장).
        정예 병사: `combat.js`의 `MOBS.ewarrior · espearman · earcher`(그림은 `sprite`로 보통 병사의 것을 빌림 · 수치 [제안]) · `FIELD.r1c1~3`.
        문 곁의 빈 터 규칙: 문과 두 줄(`GATE_ROWS`) 넘게 높이가 다른 몬스터는 뺀다(게임의 SEE_Y = 28점) — `maps.js`의 `gridOf` · `gateRow`, 규칙 검사 · 내보내기 · 게임 검사에 같이.
        시험 탭: 몬스터의 그림을 `MOBS[kind].sprite`로 찾게 고침(수습 검병 때문에 「마을 어귀」가 깨져 있었다). 열여섯 장면을 헤드리스 Edge로 찍어 체력 띠가 그려졌는지 세는 검사(scratch `tabs_check.mjs`)로 확인.
        알아 둘 것: 시험 탭은 보통 맵에서도 뒷배경을 `y - 카메라 * f * 0.5`에 그린다(게임은 `y - 26`) — 같은 맵의 뒷배경이 탭에서 20점쯤 낮게 보인다. 전부터 그랬던 차이이고 이번에 건드리지 않았다.
        남은 것: 망루 꼭대기(지역 보스) + 3층의 나가는 문 · 중간 보스 · 정예 병사의 그림 · 옛 은신처 · 멧돼지 굴 · 사당 지하 · 달빛 문 · 퀘스트.
  - [x] M9. 새 맵의 퀘스트 셋(2026-10-09): `questplay.js`의 PLAY — 메인 5 「고갯길」(보름 영감 → 굽잇길 폭탄병 15 → 고갯마루 노인) · 메인 6 「옛 망루」(차돌 → 망루 1층 정예 검병 12 → 차돌) · 부탁 「고갯길의 좌판」(반달 → 폭탄병 12).
        `NPC_ID`에 길 위의 사람들(innkeeper · oldman · guard1 · guard2) · `MOB_NOW`에 정예 병사. 규칙 검사: 퀘스트의 주민은 마을 + people.js에서 찾고, 주는 · 돌려줄 주민이 어느 맵엔가 서 있어야 하며, 할 일의 몬스터가 그 퀘스트의 맵에 있어야 한다(게임 검사 17_lune_quests가 먼저 잡은 것).
        지금 되는 것 9 / 19. 못 하는 열 개의 까닭은 `QPOPEN`에 적음(보스 · 사당 지하 · 물건의 그림 · 줍기/찾기/심부름 놀이 · 도토리 할머니).
  - [ ] M10. 곳마다 다른 몬스터(기본 그림 · 대기까지 됨 — 동작을 기다리는 중) — 사용자 2026-10-09: "너무좋은데 몬스터는 계속 같은몬스터만나오나요". 지금 몬스터 그림은 팩의 졸개 넷뿐(Minions 1 · 2 — 키 11~14점 · 색 셋)이고 맵 13장의 90마리가 모두 그 넷이다.
        계획 `js/lune/design/monsters.js`(MONSTERS.plan — 일곱: shroom 달버섯 · puff 포자 주머니 · piglet 엄니 새끼 · crab 바위 게 · wisp 서리 도깨비불 · bat 골짜기 박쥐 · helm 빈 투구. where = 맵 · like = 빌리는 움직임).
        시안: `assetpack/lune/monsters/prompt_r1_creatures.txt`(참고 = 졸개 넷을 여덟 배로 키운 `ref_minions_x8.png`) → `raw_r1_creatures.png` → `tools/build_lune_creatures.mjs` → `creatures.png`(게임 크기) · `lineup.png`(졸개 넷과 한 줄) · `compare.png`.
          조각은 빈 세로 띠로 가른다(불티 · 집게 · 날개 조각이 몸에서 떨어져 있어 덩어리 찾기로는 열여덟 조각이 됐다). 키는 `TALL` — 처음 값(10~16점)에서는 도깨비불 · 박쥐 · 투구의 눈이 사라져 12~19점으로 키웠다.
→ 사용자 2026-10-09: "각각 어울리은 몬스터 아이디어를 당신이 내고 코덱스로 시안뽑고 도트로 마무리 npc 만드는거랑똑같이 만들면됩니다. 기본이랑 idle 만들고 기본이미지 어디에있는지 말해주고, 필요한 애니메이션 있으면 저한테 요구하세요"
        마무리(도트): 자동으로 줄인 것을 글자 격자로 꺼내(scratch `dump_creatures.mjs`) 점 단위로 다듬어 `monsters.js`의 `MONSTER_ART.rows`에 적음(색 g · k · w + 강조색 하나 · 바위 게만 h · s). `tools/build_lune_monsters.mjs` → `monsters/monsters.png`(칸 32x24 · 대기 두 장) · `monsters.json` · `finish.png`(시안 · 자동 · 다듬은 것) · `monsters_lineup.png`.
          첫 다듬기는 엄니 새끼 · 바위 게 · 빈 투구가 시안에서 멀어져 다시 했다 — **다듬은 뒤에는 꼭 시안과 나란히 놓고 실루엣을 견준다.**
        사용자에게 드린 것(`C:/YJS/Roblox/Assets/character/luna/monsters/`): `<이름>.png`(1024x1024 · 투명 · 도트를 크게) · `<이름>_bg.png`(밤하늘 색 바탕) · `<이름>_idle.png`(대기 두 장) · `anim_prompts.txt`(동작 설명 35개 — 몬스터마다 이동 · 공격 · 맞음 · 쓰러짐 · 나타남).
→ 사용자 2026-10-09(시안과 줄인 것을 나란히 보고): "이게 너무달라지는데 원래 도트를 그대로 따라찍으면 우리게임에 사용할수가없나요?" — **줄이지도 다시 그리지도 않는다.**
          `build_lune_creatures.mjs`를 주민 때의 방식(`town/npc_grid.py`)으로 다시 씀: 몬스터마다 격자 줄을 실제 색 경계에 맞춰 고르고(줄 간격을 한 칸씩 따로 — 생성 그림은 칸이 고르지 않다) 칸마다 가장 많은 색 한 점 → `creature_rows.json` · `compare.png`.
          크기: 달버섯 22x20 · 포자 주머니 24x20 · 엄니 새끼 35x17 · 바위 게 41x21 · 서리 도깨비불 16x23 · 골짜기 박쥐 47x17 · 빈 투구 21x29(주인공 17~20점 · 졸개 11~14점). `MONSTER_ART` = { cell [56, 40], hover, fix }(손으로 그린 작은 그림은 뺐다) · `build_lune_monsters.mjs`가 rows를 읽어 그림판 · 기본 그림 · `monsters_lineup.png`(주인공 + 졸개 + 새 몬스터, 같은 배율)를 짓는다. 드린 기본 그림은 같은 이름으로 덮어씀.
          게임에 넣을 때: 몬스터마다 몸의 크기(맞는 범위 · 이름표의 높이)를 따로 적어야 한다 — 지금 졸개는 크기가 다 비슷해서 한 값으로 쓰고 있다.
        받은 동작 보기(2026-10-09 — 사용자: "어택 라이트 하나만 넣어놨거든 일단? 박쥐로? 이것만 간단하게 모션 공방에 보여줄래?"): 공방에 「몬스터」 탭(`#mon` — `js/lune/monTab.js`)을 만듦.
          `tools/build_lune_monster_anim.mjs`가 `luna/monsters/`의 `<몬스터>/<동작>_right.png`(또는 폴더 바로 아래의 것 — `LOOSE`에 어느 몬스터인지 적는다: attack_right.png = bat)를 `assetpack/lune/monsters/anim/`에 복사하고 칸을 세어 `anim.json`을 쓴다. 탭은 받은 그림 그대로 + 게임의 점 크기로 줄여 본 어림을 돌리고(빠르기 6~24 · 한 장씩 넘기기 · 모든 장의 띠), 아래에 일곱 마리의 기본 그림과 대기를 보여 준다.
          박쥐의 공격: 4480x1800 = 7열 x 5줄(칸 640x360) · 35장. 날개를 접는 자세가 두 번 나온다(7~11째 · 22~25째 장). 몸의 높이는 거의 그대로다(제자리 동작 — 내려꽂는 움직임은 게임이 준다). 박쥐에 없는 흰 점이 장의 절반쯤에서 깜빡인다(귀 곁 — 게임용으로 옮길 때 지운다). 아직 게임용으로 옮기지 않았다.
        다시 받음(2026-10-09 오후 — 사용자: "내가 right , left 라는 이름으로 박쥐 애니메이션다시 가져왔어 이걸로 공방에서 보여줘"): `luna/monsters/right.png` · `left.png`(앞의 attack_right.png는 사용자가 지움). 도구가 동작 이름 없는 right/left도 읽고(`LOOSE`에 [몬스터, 동작, 보는 쪽]), 원본이 없어진 복사본은 공방 쪽에서 지운다. `#mon` 탭에 두 장이 같이 돈다.
          잰 것: 둘 다 4480x1800 = 7 x 5칸 · 35장 · 날갯짓이 두 번 반쯤(날개를 내린 장 4~5 · 17~18 · 31~32째) · 끝 장에서 첫 장으로 자연스럽게 이어진다(35째 ≈ 7째, 1째 ≈ 8째) · 몸의 높이가 ±4점쯤 오르내린다 · 흰 점 없음 · left는 right를 그대로 뒤집은 것(첫 장의 다른 화소 0). 어떤 동작인지는 이름에 없다(날기로 보인다) — 게임용으로 옮기는 것은 아직.
        박쥐의 동작 결정(2026-10-09 — 사용자): "지금 박쥐 이게 run 이고 attack 은 run 애니메이션을 빠르게 재생하면됩니다. death는 필요없어요 hurt 도 필요없습니다. 스폰도 필요없어요 idle 은 run을 느리게 재생하면됩니다. 박쥐는 이렇게 결정할게요"
          → `monsters.js`의 `MONSTER_CLIPS.bat`: run = run 그림 12장/초 · attack = 같은 그림 24장/초 · idle = 같은 그림 6장/초 · hurt · death · spawn = null(효과로: 하얗게 번쩍 · 서서히 보임 · 서서히 사라짐). 빠르기의 숫자와 대신하는 효과는 내가 잡음([제안]).
          게임 크기로 옮기기: `tools/build_lune_monster_game.mjs` — 한 점 ≈ 5.45화소 · 모든 장에 같은 격자 · 칸마다 가장 많은 색 · 기본 그림에 있는 색만 → `monsters/game/bat_run.png`(57x35점 x 35장) · `game.json`. 받은 그림과 나란히 놓고 열두 장을 견줘 봄(자세 · 눈 맞음, 날개 끝의 얇은 막이 거친 장이 있다).
          `#mon` 탭 맨 위 「정해진 동작」에 이동 · 공격 · 대기가 정한 빠르기로 돈다. 박쥐에게 남은 것: 날아다니는 움직임(시험 탭에서 먼저) → 그림판에 넣기 → 무너진 다리에 배치.
        폴더 정리(2026-10-09 — 사용자: "지금 몬스터 몬스터 별로 폴더만들어서 정리하세요"): `luna/monsters/` 아래에 몬스터마다 폴더 하나(shroom · puff · piglet · crab · wisp · bat · helm).
          폴더마다: `<이름>.png` · `<이름>_bg.png` · `<이름>_idle.png`(내가 만든 기본 그림 · 대기 두 장) · `prompts.txt`(그 몬스터의 동작 설명 — 원본은 공방의 `anim_prompts.txt`, `build_lune_monsters.mjs`가 잘라 넣는다) · 사용자가 만든 `<동작>_right.png` · `<동작>_left.png`.
          옮긴 것(옮기기만 — 지운 것 없음): 내 그림 21장 → 제 폴더 · `right.png` · `left.png` → `bat/run_right.png` · `run_left.png` · `idle_right.png` · `idle_left.png` → `crab/`(열어 보니 바위 게의 대기 35장 — 사용자가 새로 넣은 것).
          도구: `build_lune_monsters.mjs`는 `<이름>/`에 쓴다 · `build_lune_monster_anim.mjs`는 몬스터의 폴더에서만 읽는다(`LOOSE`는 비움 — 폴더 바로 아래에 그림이 놓이면 읽지 않고 알린다) · `#mon` 탭에 바위 게의 대기가 같이 돈다(확인: 화면을 찍어 봄).
          바위 게의 대기를 게임 크기로 옮긴 것: `monsters/game/crab_idle.png`(45x25점 x 35장 · 한 점 ≈ 7.39화소) — 앞의 다섯 장만 받은 그림과 견줘 봄. 어느 동작에 어느 빠르기로 쓸지는 아직 정해지지 않았다(`MONSTER_CLIPS`에 없다).
          남은 것: 폴더 바로 아래의 옛 `anim_prompts.txt`(내가 복사해 둔 것 — 머리말이 옛 자리를 가리킨다)는 지우지 못했다(지우기가 막힘) — 사용자에게 물음.
        바위 게의 동작(2026-10-09 — 사용자: "삭제 굳이 안해도 되고, 이제 크랩 애니메이션 확인해보세요"): `crab/`에 run · attack · idle(오른쪽 · 왼쪽) 여섯 장. 모두 4480x1800 = 7 x 5칸 · 35장. 왼쪽은 오른쪽을 뒤집은 것(이동 · 대기 = 화소까지 같음, 공격 = 0.4% 다름) → 게임은 오른쪽만 쓴다.
          받은 그림의 성질: 동작마다 배율이 다르다(한 점 = 대기 7.39 · 이동 7.17 · 공격 6.12화소) · 색이 기본 그림에서 밀려 있다(눈의 흰색 #ffffff → #e0e9ee) · 움직이는 장은 도트가 격자에 맞지 않는다(집게가 돌아가 있다) · 앞뒤에 서 있는 장이 붙어 있다.
            이동: 1~4 · 30~35째 = 서 있는 자세(서로 같다) · 걷는 것은 5~29째(한 걸음 ≈ 여섯 장) → 쓰는 장 6~29. 대기: 1~6째는 반 점 위 · 35째 = 7째 → 쓰는 장 7~34(눈 감기 9~11 · 29~31, 집게 까딱). 공격: 1~5 · 31~35째 = 서 있는 자세 → 쓰는 장 6~30, 벌리기 8~14 · 맞물림 17~22(맞는 장 17).
            공격은 제자리에서 두 집게를 벌렸다가 몸 앞에서 맞물리는 동작이다 → `MONSTERS.plan`의 바위 게를 「집게가 멀리 닿는다(창병)」에서 「벌렸다가 몸 앞에서 맞물린다 · like warrior」로 바꿈.
          변환 도구(`build_lune_monster_game.mjs`)를 고침: ① 색 맞추기 — 첫 장을 기본 그림에 겹쳐 색마다 받은 그림에서의 값을 재고 그 값으로 읽는다(안 하면 눈의 흰 점이 등딱지 색으로 읽힌다) ② 드문 색(기본 그림에 네 점 이하 = 눈의 점)은 덩어리마다 넓이만큼의 점을 찍는다(전: 바위 게의 대기 5 · 19째 장에서 눈이 꺼짐 · 박쥐의 눈이 2~4점으로 오감 → 지금: 게 2점(감는 장 · 집게에 가린 장 빼고) · 박쥐 4점이 모든 장에) ③ 기본 그림의 자리(`ax` · `foot` · `ref` · `match`)를 장에서 찾아 적는다 — 동작이 바뀌어도 기본 자세가 같은 점에 오게.
            확인: 세 동작 105장을 받은 그림과 나란히 놓고 봄(scratch `anim_grid.mjs`) · 서 있는 장이 기본 그림과 점 단위로 같다(기본 그림의 모든 점이 맞음 — 다리 끝이 한두 점 더 길 뿐). 걷는 장의 가는 다리는 장마다 조금 거칠다(받은 그림에서도 흐릿한 데).
          `MONSTER_CLIPS.crab`([제안] — `from` · `to` · `hit` 추가): 이동 6~29째 12장/초 · 공격 6~30째 16장/초(맞는 장 17 = 0.69초) · 대기 7~34째 12장/초 · `open` = 맞음 · 쓰러짐 · 나타남(받지 않음 — 만드실지 물음). `#mon` 탭의 맨 위가 「게임에서 쓰는 동작」으로 바뀌어 박쥐(정해짐)와 바위 게([제안])가 게임 크기로 돈다.
        바위 게의 결정(2026-10-09 — 맞음 · 쓰러짐 · 나타남을 그림 없이 갈지 물은 데 대한 사용자의 답): "박쥐처럼입니다." → `MONSTER_CLIPS.crab`의 hurt · death · spawn = null. 쓰는 장 · 빠르기 · 맞는 장은 내 제안 그대로(다른 말씀 없음).
        새 몬스터 둘을 횡스크롤 시험 탭에(2026-10-09 — 시험 탭에서 먼저 · 게임으로는 아직 안 내보냄): `?lunescene=r1b3#lune`(무너진 다리)에서 창병 셋 → 바위 게 · 폭탄병 둘 → 골짜기 박쥐(`monsters.js`의 `MONSTER_TRIAL` — 시험 탭에서만 바꿔 본다. `maps.js`와 게임은 그대로).
          `tools/build_lune_monster_chars.mjs`(새 도구): `MONSTER_PLAY`에 있는 몬스터의 정해진 동작을 chars 꼴로 묶는다 → `monsters/chars/<id>_<idle|run|atk>.png` · `monsters/chars.json`(칸: 바위 게 46x29 · 박쥐 57x35 · 기본 자세가 모든 동작에서 같은 점에 온다). `chars.json`(게임으로 나가는 것)은 건드리지 않고, 시험 탭이 덧붙여 읽는다.
          `MONSTER_PLAY`([제안]): 바위 게 = 빠르기 14 · 체력 1.6배 · 몸 34x18 · 공격은 좌우 22점 안 모두(벌리기 시작해서 0.69초 뒤에 맞물림) · 다시 치기 2.4초 · 한 방 1.5배. 박쥐 = 빠르기 30 · 체력 0.7배 · 몸 20x16 · 땅에서 40점 위를 떠서 오가다가 주인공이 좌우 64점 안에 들면 0.45초에 내려와 덮치고 0.6초에 올라간다 · 다시 치기 2.6초 · 한 방 1배.
          `luneTab.js`: 새 몬스터만 시험 탭에서 공격한다(지금 졸개는 그대로 걷기만) · 맞는 몸의 크기를 몬스터마다(`body`) · 나는 몬스터(`play.fly` — `gy` = 땅의 높이, `y` = 몸의 아래 끝) · 제 그림이 없는 동작은 효과로(쓰러짐 = 0.6초에 걸쳐 사라짐 · 나타남 = 서서히 보임 · 맞음 = 하얗게 번쩍). 맞았을 때의 피해는 보여 주기용(최대 체력의 6% x 배수).
          확인: 브라우저를 실제 시간으로 돌려 연속으로 찍음(scratch `cdp_mon.mjs`) — 박쥐 둘이 내려와 덮치고(피해 12) 다시 올라가 오간다 · 바위 게가 집게를 맞물려 치고(피해 18) 다시 걷는다 · 오류 없음. 움직임의 느낌(빠르기 · 피할 틈)은 사진으로 알 수 없다 → 사용자에게 해 보시라고 함.
→ 사용자 2026-10-09(해 보고): "박쥐가 너무 높이있는데 그냥 때릴수가없어서" — 박쥐의 높이를 40 ± 3점에서 13 ± 2점으로 낮춤(`MONSTER_PLAY.bat.fly`). **규칙: 나는 몬스터도 제자리에 서서 쓰는 기술로 맞아야 한다** — 가장 낮게 치는 기술이 발에서 16점 위까지 닿으므로 몸의 아래 끝이 16점 아래에 있어야 한다. 다시 찍어 확인(주인공의 머리 높이에서 오가고 덮친다 · 날개 끝이 땅 밑으로 안 내려간다 · 오류 없음).
        빈 투구의 동작(2026-10-09 — 사용자: "이제 helm 애니메이션 가져왔습니다. idle 애니메이션으로 run 도 사용하면됩니다."): `helm/`에 idle · attack(오른쪽 · 왼쪽). 이동 = 대기 그림(정해짐). 맞음 · 쓰러짐 · 나타남은 말씀이 없어 박쥐 · 바위 게처럼 효과로 잡아 둠(알림).
          잰 것: 한 점 = 대기 8.64 · 공격 8.41화소 · 기본 자세가 기본 그림과 98% 맞음. 대기는 31~34째 장 = 1째 장 · 35째 장은 튄다 → 쓰는 장 2~32. 공격은 1~7째 떠 있는 자세 · 8~14째 눈을 치켜뜸 · 15째 오른쪽으로 돌아섬 · 16~21째 빛나는 덩어리를 내뿜음 · 22~28째 잦아듦 → 쓰는 장 8~30.
          **공격 그림에 날아가는 덩어리가 같이 그려져 있고 칸의 끝에서 잘린다**(프롬프트에는 넣지 말라고 적었지만 들어왔다) → 18째 장까지는 그림대로, 19째 장부터는 몸의 그림에서 덩어리와 꼬리를 지우고(`cut`) 18째 장의 덩어리(12x14점)를 따로 떼어(`shot`) 그 자리에서 날려 보낸다. 새로 그린 점은 없다. `build_lune_monster_chars.mjs`가 `helm_shot.png`와 `clips.shot`(w · h · dx · dy)을 짓는다.
          변환 도구: 드문 색 찍기에서 속이 없는 가는 띠(두 색의 경계가 번진 자국)는 뺀다 — 빈 투구의 어두운 회색(기본 그림에 두 점)이 장마다 5~11점 찍히던 것이 2~4점으로.
          `MONSTER_PLAY.helm`([제안]): 땅에서 4점 떠서 빠르기 12로 오가고, 주인공이 좌우 110점 안 · 같은 층에 있으면 돌아서서 쏜다(눈을 치켜뜨기 시작해서 0.69초 뒤) · 덩어리는 1초에 110점으로 150점까지 · 다시 쏘기 3.2초 · 한 방 1.2배 · 체력 1.1배 · 몸 16x24.
          시험 탭: `?lunescene=r1c2#lune`(망루 2층)의 정예 궁병 넷 → 빈 투구(`MONSTER_TRIAL.r1c2`). `luneTab.js`에 새 몬스터가 쏜 것(`mobShots`)을 더함. 확인: 실제 시간으로 돌려 찍음 — 눈을 치켜뜨고, 주인공 쪽으로 돌아서 내뿜고, 덩어리가 날아가 맞는다(피해 14) · 오류 없음 · 옛 병사의 그림은 그대로.
→ 사용자 2026-10-09: "이런식으로 몬스터 훨씬 많이 만들어야합니다. 거의 한사냥터에 한 몬스터라고 생각해야합니다. 코덱스로 초안뽑고 하는방식으로 몬스터 더 많이 만들어보세요"
        **규칙: 사냥터 한 장에 그 곳만의 몬스터 하나**(`MONSTERS.plan[].where`는 한 곳 — 길 맵인 무너진 다리만 박쥐 · 게 둘). 처음의 일곱도 한 곳씩으로 다시 나눔(달버섯 r1a1 · 포자 주머니 r1a3 · 엄니 새끼 r1b1 · 바위 게 r1b3 · 박쥐 r1b3 · 도깨비불 r1b4 · 빈 투구 r1c1).
        새로 열여섯(모두 내가 지음 · 23마리가 됨): 1지역의 나머지 맵 = 달뿔 토끼 hare(r1a2) · 재까마귀 crow(r1a4) · 바위 산양 goat(r1b2) · 낡은 수련 인형 dummy(r1bh) · 굴 두더지 mole(r1bl) · 횃불지기 torch(r1c2) · 망루 올빼미 owl(r1c3) · 돌 지킴이 guardian(사당 지하 r1sh).
          수정 숲(2지역 — 맵을 짓기 전에 먼저) = 수정싹 그루터기 stump · 수정 달팽이 snail · 수정뿔 사슴 fawn · 유리 나방 moth · 수정 고슴도치 quill · 검은 결정 dshard · 결정 골렘 새끼 golem · 종지기 bell(`place` = 둘 곳, 맵을 지을 때 `where`로).
        시안: `monsters.js`의 `MONSTER_SHEETS`(여러 장) — `raw_r1b2_creatures.png` · `raw_r2_creatures.png`(프롬프트 `prompt_r1b2_creatures.txt` · `prompt_r2_creatures.txt`). `build_lune_creatures.mjs`가 있는 장을 모두 옮긴다(처음의 일곱은 한 점도 안 바뀜을 확인).
          **첫 시도(`raw_r1b_creatures.png`)는 도트가 잘았다**(한 점 8화소 → 옮기면 토끼 29x44 · 인형 45x51 — 주인공의 두 배). 줄이지 않기로 했으므로 다시 뽑음: 그 그림을 참고로 붙이고 "같은 생김새를 12 x 12화소의 굵은 도트로, 몬스터마다 몇 점 x 몇 점(화면에서 몇 화소)까지"라고 못박음 → 19x33 ~ 36x21점(처음의 일곱과 같은 급).
          옮기는 도구에 더한 것: `block`(시안에 정해 준 도트 크기 — 재서 구하면 두더지가 세로로 스물세 줄로 늘어났다) · 몸에서 세 칸 넘게 떨어진 어두운 부스러기 지우기(올빼미와 돌 지킴이 사이의 가는 선).
          확인: 두 장 모두 시안과 옮긴 것을 나란히 봄(`compare_r1b.png` · `compare_r2.png`). 돌 지킴이는 시안의 갈기 무늬가 도트보다 잘아서 옮긴 것이 가장 거칠다. 올빼미의 두 눈과 부리는 한 덩어리(U 모양)로 옮겨졌다.
        드린 것: `luna/monsters/<이름>/`에 기본 그림(검정 바탕) · `_bg` · `_idle` · `prompts.txt` — 폴더 스물셋. 새 몬스터의 프롬프트는 대기 · 이동 · 공격만(걷지 않는 수련 인형 = 대기 · 공격, 나는 올빼미 · 나방 = 날기 · 공격). `MONSTER_ART.cell`을 64x48로 키움.
        다음: 사용자의 동작 그림을 기다린다(받으면 지금까지처럼 가져오기 → 확인 → 시험 탭). 수정 숲의 맵 · 물마루 바다 · 그 뒤 지역의 몬스터는 아직.
→ 사용자 2026-10-09(스물셋이 된 뒤): "더 많아야해" — 남은 지역 모두에 여덟 마리씩 일곱 묶음(쉰여섯)을 더 지음 → 계획은 일흔아홉 마리.
        자료: `js/lune/design/monsterBatches.js`(묶음 · 몬스터마다 이름 · 둘 곳 · 레벨 · 빌리는 움직임 · 시안에 청하는 크기 · 영어 설명 · 생김새 · 동작 프롬프트의 문장) — `monsters.js`가 읽어 `MONSTERS.plan` · `MONSTER_SHEETS` · 뜬 높이에 더한다.
          묶음: r2b 수정 숲 추가 · seaa 물마루 바다(섬 · 갯바위) · seab 바닷속 · 가라앉은 항구 · r3a 화롯골(굴 · 광산) · r3b 화롯골(용암 · 화로 · 분화구) · r4a 만월성(옛 왕도 · 성벽) · r4b 만월성(내성 · 봉인의 회랑). 용은 넣지 않음 · 화롯골의 불은 분홍 · 자주.
        도구: `tools/write_lune_monster_prompts.mjs codex | redraw <묶음> | anim`(시안 프롬프트 · 굵은 도트로 다시 그리는 프롬프트 · 동작 프롬프트를 원본에 덧붙이기) · `tools/measure_lune_sheet.mjs <png>`(시안의 도트 한 점이 실제로 몇 화소인가).
          `build_lune_creatures.mjs`: ① 한 점이 10.5화소에 못 미치는 장은 옮기지 않는다(12로 옮기면 줄여 그린 꼴) ② 다시 뽑은 장 `raw_<묶음>2_creatures.png`가 있으면 그것을 옮긴다 ③ 빈 띠로 못 가르는 장은 이어진 덩어리로 가른다(바닷속 — 몬스터마다 제 덩어리의 화소만 읽는다) ④ 멀리 떨어진 어두운 부스러기(다섯 점 이하) 지우기 · `MONSTER_ART.strays`(색에 상관없이 지우는 몬스터 — 두꺼비).
        **Codex는 12 x 12로 못박아도 장마다 다르게 그린다**: seaa 10.5 · seab 11.6 · r3b 10.8(그대로 옮김) / r2b 8.0 · r3a 8.0(다시 뽑아 12.5 · 12.0) / r4a 5.5 · r4b 5.3(한 번 다시 뽑아도 8.0 → 한 번 더). 장이 나올 때마다 재서 잘면 그 장을 붙여 다시 그리게 한다(생김새는 그대로 남는다).
        끝(2026-10-09): **일흔아홉 마리 모두 옮김 — 폴더 일흔아홉**(1지역 15 · 수정 숲 16 · 물마루 바다 16 · 화롯골 16 · 만월성 16). 만월성 두 장은 세 번째에야 굵게 나왔다(r4a 10.5 · r4b 12.5화소). 키 15~40점 · 폭 13~47점. `#mon` 탭에 일흔아홉이 오류 없이 나온다(브라우저로 세어 봄). 처음의 일곱은 한 점도 안 바뀜. 묶음마다 시안과 옮긴 것을 나란히 봄(`compare_<묶음>.png`). 청한 것보다 크게 나온 것이 있다(바닷속 키 27~37점 · 향로 38점) — 줄이지 않음. 성당 석루조는 작은 용처럼 보인다(판단을 여쭘).
          `MONSTER_ART.cell` = 64 x 56. 동작 프롬프트는 모두 대기 · 이동 · 공격(걷지 않는 것 = 대기 · 공격, 나는 것 = 날기 · 공격).
→ 사용자 2026-10-09: "애니메이션을 당신이 만들수는없나요? 엄니 새끼로 만들어보세요" — 내가 직접 만들어 봄(확인 요청).
        `tools/build_lune_monster_made.mjs`(새 도구 · 생성 도구를 쓰지 않는다): 기본 그림의 점을 부위별로 옮겨 장을 짓는다 — 발 넷(맨 아래 두 줄)을 떼어 앞뒤로 옮기거나 한 점 들고, 몸은 한 점 눌리고, 머리는 목에서부터 기울이고, 꼬리 · 등 털은 한 점씩, 눈은 감는다. 공격은 그림을 칸 안에서 뒤로 뺐다가 앞으로 내민다(엄니가 지나간 흰 호 몇 점만 새로 그린 점).
          엄니 새끼: 대기 8장(6장/초) · 달리기 6장(14장/초 — 대각선의 두 발이 번갈아) · 공격 12장(14장/초 · 맞는 장 7째 = 0.43초) → `monsters/made/piglet_<동작>.png` · `made.json` · `made_piglet.png`(모든 장을 크게). `build_lune_monster_game.mjs`가 `made.json`을 `game.json`에 덧붙인다(같은 동작을 사용자가 주면 사용자의 것을 쓴다).
          `MONSTER_CLIPS.piglet` · `MONSTER_PLAY.piglet`(빠르기 34 · 체력 0.9배 · 앞 20점 · 다시 치기 1.8초 · 한 방 1.1배 — 내 제안) · `MONSTER_TRIAL.r1b1`(고갯길 초입의 폭탄병 → 엄니 새끼). 확인: 장을 크게 놓고 봄 · 시험 탭에서 실제 시간으로 달리는 것을 찍어 봄 · 오류 없음. 움직임은 단순하다(발이 2점씩 오가고 몸이 1점 눌리는 정도 — 사용자의 그림 35장보다 훨씬 적다).
→ 사용자 2026-10-09(엄니 새끼를 보고): "꽤 좋은데요 움직임이 클필요가 없어요" → "지금있는몬스터 싹다 애니메이션 만들어보세요 보고 배제할것들 제가 컨펌하겠습니다."
        일흔다섯 마리(사용자가 만든 박쥐 · 바위 게 · 빈 투구와 먼저 만든 엄니 새끼 제외)에 동작을 자동으로 지음: `js/lune/design/monsterMoves.js`(`MOVES` = 몬스터마다 kind · atk · 발의 자리 / `KIND` · `ATK` = 장 수 · 빠르기 · 맞는 장 / `clipsOf`) + `build_lune_monster_made.mjs`의 `renderG` · `framesOf`.
          kind: walk(발을 번갈아 — 맨 아래 줄의 덩어리를 발로 본다) · hop(콩콩) · float(오르내림 + 기울임 + 아래쪽 물결) · fly(날개 끝이 오르내림 — 날갯짓 하나를 6 · 12 · 20장/초로) · root(제자리 흔들림 — 이동 = 대기) · slither(마디 물결) · slide(늘였다 끌기).
          atk: lunge(물러났다 튀어 나감) · chop(젖혔다 내리침 = 몸을 기울임) · slam(뛰어올라 찍음 + 흙먼지) · shoot(젖혔다 튕김 — 날아가는 것은 아직 안 그림) · breath(앞으로 불길) · pulse(움츠렸다 부풂 + 둘레의 빛).
          결과: 동작 204개 + 엄니 새끼 3 → `monsters/made/` · `made.json` · `check_01~10.png`(여덟 마리씩 · 확인용). `game.json`에 덧붙음(213). `MONSTER_CLIPS`에 `auto: true`로 들어감.
          `#mon` 탭에 「제가 만든 동작」: 지역마다 묶어 몬스터마다 대기 · 이동 · 공격이 게임의 빠르기로 돈다(세 배) — 브라우저로 세어 봄: 75마리 · 캔버스 225 · 오류 없음.
          확인한 것: 확인용 그림 열 장 가운데 다섯 장을 보고 깨진 그림(찢어진 몸 · 날아간 조각)이 없음을 봄. 움직임이 어울리는지는 보지 못함 — 사용자가 보고 뺄 것을 정한다. 멀리 쏘는 몬스터의 날아가는 그림 · 시험 탭에 넣기(`MONSTER_PLAY`)는 남길 것이 정해진 뒤에.
→ 사용자 2026-10-09(일흔다섯 마리를 한 번에 자동으로 지은 것을 보고): "하나씩 좀 직접 확인을하고 하나하나 수정을 직접해야겠는데요 양이 많다고 해서 한번에 처리하는방식으로하면 퀄리티가 안나옵니다."
        **한 마리씩 손으로**: `tools/lune_monster_hand.mjs`의 `HAND`(몬스터마다 도트를 보고 부위를 나눠 장마다 적은 것 — ops: move · shearX · shearY · set · swap · grow · clear · lift) → `build_lune_monster_made.mjs`의 `renderH`. 여기에 있는 몬스터는 자동 초안을 쓰지 않는다. 몬스터마다 `made/view_<이름>.png`(모든 장을 여섯 배로)를 보고 고친다. 도트 보기: `node tools/lune_rows.mjs <이름>`.
          손으로 끝낸 것(열다섯 + 엄니 새끼): 달버섯 · 포자 주머니(부풀어 터짐) · 서리 도깨비불 · 달뿔 토끼 · 재까마귀 · 바위 산양 · 낡은 수련 인형 · 굴 두더지 · 횃불지기(불길을 한 번 고침) · 망루 올빼미 · 돌 지킴이 · 수정싹 그루터기 · 수정 달팽이(껍데기의 틈을 고침) · 수정뿔 사슴 · 유리 나방.
          `#mon` 탭의 「제가 만든 동작」: 민트색 테두리 = 손으로 짠 것 · 회색 테두리 = 자동 초안(아직 하나씩 보지 않음). 남은 예순 마리는 같은 방식으로 이어서 한다(수정 숲의 나머지 → 물마루 바다 → 화롯골 → 만월성).
→ 사용자 2026-10-09(일흔아홉 마리의 동작을 다 보고 — 긴 판정): 서른일곱 마리 삭제 · 열일곱 마리는 동작을 말씀대로 · 달버섯 "아주좋음" + 큰 달버섯을 만들 것 · "이거 너무 많아서 피드백 헷갈리면 어디 적어두고 나누어서 꼼꼼히 작업할것".
        **판정 목록 = `js/lune/design/monsterFeedback.js`**(말씀 그대로 + 몬스터마다 판정 · 할 일 · 한 일 — `#mon` 탭 맨 위 「판정과 할 일」). 묶음 A(삭제) → B(1지역) → C(수정 숲) → D(바다) → E(화롯골) → F(만월성) → G(말씀 없던 자동 초안)로 나눠 한 마리씩 했다. **2026-10-09에 모두 끝: 바꿀 것 19가지 가운데 19가지 · 자동 초안 0.**
          A 삭제 서른일곱: 계획 · 도구 · 탭에서 뺌(`MONSTER_OUT`) — 그림 폴더는 지우지 않고 `luna\monsters\_excluded\`로 옮김. 남은 몬스터 마흔셋(큰 달버섯 포함).
          B–F 말씀대로 다시 짠 것: 굴 두더지(가라앉았다 팍 솟음) · 낡은 수련 인형(통통) · 횃불지기(다리 없앰 · 불이 커지며 마법) · 큰 달버섯(Codex 시안 → 39x31) · 수정싹 그루터기(통통) · 수정 달팽이(수정이 커짐) · 수정 고슴도치(몸통이 커짐) · 검은 결정(떠서 마법만) · 등불꼬리 여우(고개만 까딱 · 여우불) · 수정 봉오리(살랑 · 싹이 자라남) · 떠도는 향로(떠서 연기 고리) · 등불 해파리(번개 줄기) · 닻 망령(솟았다 바닥 찍기) · 곡괭이 코볼트(곡괭이를 떼어 직접 그려 휘두름) · 석순 흉내쟁이(통통 뛰어 찍기) · 흑요석 전갈(꼬리를 펴 독침으로 찌름) · 부서진 기사상(이동 = 공격의 몸 동작 · 빛의 검) · 봉인술사의 허물(떠서 봉인 문양).
          G 말씀 없던 자동 초안 열일곱도 손으로: 돌골렘(두 주먹 내리찍기) · 종(울려서 소리 물결) · 이끼 두꺼비(침 뱉기) · 수정 거미(앞다리 쳐들고 덮침) · 진주 조개(열리며 빛살) · 물총 따개비(물줄기) · 굴 곰치 · 굴 지렁이(목을 뻗어 물기) · 굴쥐(뛰어들어 물기) · 폭주 광차(바퀴가 구름 · 들이받기) · 쇳물 방울(통통 · 쇳물 튐) · 성난 모루(뛰어 찍기) · 굴뚝 도깨비(불덩이) · 재 회오리(돌며 불티) · 찢어진 깃발(통통 · 후려치기) · 떠도는 책 · 감시하는 눈(날갯짓 — 공격 동작 없음).
          도구에 더한 것: ops `sink` · `growRect` · `erase` · move/shearX/shearY의 "그 색만"(맨 끝 인자) · fx 도우미 `line` · `poly` · `arc` · `stamp` · `rotCW`(`tools/lune_monster_hand.mjs` 머리말에 설명).
          확인한 것: 마흔 마리 모두 `made/view_<이름>.png`를 열어 장마다 보고 고침(여우 · 봉오리의 싹 · 닻 망령의 눈과 흙먼지 · 코볼트의 곡괭이 높이 · 전갈의 독침 · 두꺼비 뒷다리 · 조개의 빛살 · 쇳물 방울의 혹 · 회오리의 불티 · 깃발의 효과를 한 번씩 고침) · `#mon` 탭이 오류 없이 뜸 · 규칙 검사 통과. **보지 못한 것: 게임 속도로 움직이는 모습(탭에서 사용자가 볼 것) · 시험 탭에서 싸우는 것(`MONSTER_PLAY`가 있는 것은 여전히 박쥐 · 게 · 엄니 새끼 · 빈 투구뿐).**
          남은 것: ① 「마법 형태 공격」의 실제로 맞히는 마법 그림과 멀리 쏘는 몬스터의 날아가는 그림(동작 안의 것은 자리만 잡은 것) ② 삭제로 제 몬스터가 없어진 맵의 배치 다시(r1a2는 큰 달버섯 제안 · r1b4 · r1c3 · 사당 지하 · 2~4지역 여러 곳) ③ 남긴 몬스터의 `MONSTER_PLAY` 숫자와 시험 탭 ④ 게임으로 옮기기.
→ 사용자 2026-10-09(위의 ①을 듣고): "마법 이펙트는 따로 만들어서 연계하면 됩니다"
        **마법 이펙트 = 몸 동작과 따로 그린 그림 + 연결 자료.** 그림 `tools/lune_monster_fx.mjs`(이펙트마다 장을 손으로 적음) → `node tools/build_lune_monster_fx.mjs` → `assetpack/lune/monsters/fx/<이름>.png` · `fx.json` · `view_<이름>.png`(확인용). 연결 `js/lune/design/monsterFx.js`(`MONSTER_FX.list`: 어느 몬스터 `of` · 자리 `place` = feet 발밑 / body 몸 / front 몬스터 앞 / shot 날아감 · 공격 몇째 장에 시작 `at` · 맞는 넓이 `hurt`).
          만든 것 열하나: 달불 기둥(횃불지기) · 결정 가시(검은 결정) · 여우불(여우) · 수정 싹(봉오리) · 연기 고리(향로) · 번개 줄기(해파리 — 몸 앞에 붙음) · 빛의 검(기사상) · 봉인 문양(허물) + 날아가는 것 셋: 침 덩어리(두꺼비) · 물줄기(따개비) · 불덩이(굴뚝 도깨비). 주인공 자리에 뜨는 것은 앞의 넉 장이 예고(0.33초) → 다섯째 장에 맞음 → 흩어짐.
          몸 동작(`lune_monster_hand.mjs`)에서는 자리만 잡아 둔 마법을 뺐다 — 몸의 변화(빛남 · 까딱임 · 쏘는 몸짓)만 남고, 공격의 `hit` = 이펙트가 시작하는 장(`at`과 같아야 한다 — 이펙트 도구가 다르면 경고).
          보는 곳: `#mon` 탭의 「마법 이펙트」(몬스터의 공격과 이펙트가 시간 맞춰 같이 도는 그림 + 이펙트만). 시험 탭: `MONSTER_PLAY.<몬스터>.atk.cast: true` → `build_lune_monster_chars.mjs`가 `clips.cast`로 싣고, `luneTab.js`의 `mobCasts`가 공격의 hit 장에 주인공의 자리에 띄워 맞는 장에 그 안에 있으면 맞힌다(예고 동안 비키면 안 맞는다 · 주인공의 앞에 그린다).
          시험 중: **횃불지기** — `?lunescene=r1c2#lune`(망루 2층의 정예 창병 여섯 → 횃불지기). 숫자(닿는 거리 80 · 다시 쓰기 3.6초 · 1.4배 · 불기둥의 폭 좌우 7점)는 제 제안.
          확인한 것: 이펙트 열하나의 모든 장을 크게 놓고 봄(불기둥의 흩어지는 장 · 결정 가시의 점선 · 연기 고리의 가운데를 고침) · 탭의 「마법 이펙트」를 실제 시간으로 찍어 봄 · 시험 탭에서 횃불지기가 불을 키우고 → 주인공 발밑에 예고 → 불기둥 → 맞는 것을 연속으로 찍어 봄(오류 없음). **보지 못한 것: 손으로 해 보는 느낌(피할 만한가 · 예고가 충분한가) — 사용자가 해 볼 것. 다른 열 가지는 탭에서만 돌고 시험 탭에는 아직 없다(그 몬스터들의 맵이 아직 없거나 전투 숫자가 없음). 날아가는 것 셋은 그림만 있고 시험 탭의 날리기에는 아직 연결하지 않았다(지금 날리기는 한 장짜리 그림만 받는다).**
          다음: 좋다고 하시면 `combat.js`의 `MOBS`에 두 종류를 더하고 `maps.js`의 몬스터를 바꾼 뒤 게임에(그림 올리기 · `mobsView` · `sim/room`의 몸 크기와 나는 몬스터 · 시험).
                **동작을 기다리는 중.** 받을 곳: `luna/monsters/<이름>/<run|attack|hurt|death|spawn>_right.png`. 받으면: 게임 크기로 줄여 그림판(chars)에 넣고 `MOBS`에 종류를 더하고 맵 자료의 몬스터를 바꾼다(움직임은 `MONSTERS.plan[].like`).
→ 사용자 2026-10-09(마법 이펙트를 보고): "좋습니다. 훌륭해요 어느몬스터를 어디에 배치해야하는지 정확하게 파악하고 게임에 적용하세요"
        **배치 = `js/lune/design/monsterPlace.js`**(남은 마흔셋 → 맵 하나씩 · `#mon` 탭의 「배치」 표). 방법: 맵의 레벨 = 몬스터의 레벨 · 그 곳에 있을 법한 것 · 사냥터 한 장에 하나(다리만 둘) · 퀘스트가 잡으라고 하는 병사는 남김. `monsters.js`가 계획의 where · place · lv를 이 표대로 맞춘다(처음 것은 was).
          1지역(지은 맵 — 게임에 적용): 마을 어귀 달버섯 3 · 달그림자 사냥터(hunt) 큰 달버섯 4 · 사냥터 깊은 곳 포자 주머니 4 · 버려진 야영지 재까마귀 4 · 고갯길 초입 엄니 새끼 4 · 굽잇길 바위 산양 5 · 무너진 다리 박쥐 2 + 게 3 · 망루 아래 굴 두더지 5(도깨비불이 빠진 자리 — 멧돼지 굴에서 옮김) · 망루 1층 빈 투구 4 · 2층 횃불지기 4 · 3층 낡은 수련 인형 4(올빼미가 빠진 자리 — 옛 은신처에서 옮기고 레벨 25~27로).
          2~4지역 · 바다(아직 짓지 않은 맵 — 계획): 표에 맵 id로 적음. 제 몬스터가 없는 사냥터 = 해초 숲 · 난파선 무덤 · r3b3 · r3b4 · r3d1 · r3d2 · 만월성의 열 곳(`PLACE.empty`).
        **게임 적용의 차례**(끝낸 것에 ✔):
          W1 전투 숫자: `MONSTER_PLAY`에 1지역 열둘 모두(달버섯 · 큰 달버섯 · 포자 주머니 · 재까마귀 · 바위 산양 · 수련 인형 · 굴 두더지를 더함 — 숫자는 제 제안) ✔
          (2026-10-14: MOB_SWAP · MOB_ZONE은 없어지고 `maps.js`의 `MOB_ONE` — 1지역 사냥터 한 장 = 몬스터 한 종류. 아래는 그 전의 기록)
          W2 맵 자료: `maps.js`의 `MOB_SWAP`(병사의 자리 가운데 새 몬스터가 물려받는 차례) · `build_lune_demo.mjs`(hunt — 큰 달버섯 셋) · `combat.js`의 FIELD(새 종류의 레벨) · `MONSTER_TRIAL` 비움 ✔
          W3 내보내기: `export_lune_game.mjs`가 몬스터의 그림(`monsters/chars.json` + 마법 · 날아가는 그림)과 수치(`js/lune/design/monsterMobs.js` — MONSTER_PLAY → MOBS와 같은 꼴 + body · lift · fly · both · cast · shot의 자리)를 함께 내보냄 · `build_lune_maps.mjs` · 규칙 검사도 새 종류를 앎(+ 배치의 규칙) ✔ — 그림은 판 한 장에 다 들어감(chars_1 · 1024x970쯤 — 거의 찼다)
          W4 시험 탭: 맵에 진짜 종류가 놓이므로 바꿔 보기(trial) 없이 나옴 · 포자 주머니의 터짐(burst) ✔ — 1지역 맵 열 곳이 오류 없이 열림
          G1 서버(`sim/room.luau`): 종류마다 몸 크기(body) · 양쪽 치기(both) · 제자리(speed 0) · 나는 몬스터(fly — 높이는 상태와 시간에서 셈한다, 통신에 y를 더하지 않는다) · 마법(cast — 예고 뒤에 그 자리에 있으면 맞음) · 쏘는 자리(shot의 dx · dy) ✔ — 나는 높이는 `mob.alt`(직업 묶음이 읽는 `m.h`에 얹는다)
          G2 통신(`net/packets.luau` · `server/.../world.luau`): `MobCast` 새로 · Shot에 종류 ✔
          G3 화면(`mobsView` · `effects` · `sprite`): 맞음 · 나타남 · 쓰러짐 그림이 없는 몬스터는 번쩍 · 서서히 보임 · 서서히 사라짐(사용자: "박쥐처럼입니다") · 체력 막대와 숫자의 높이 · 나는 높이 · 날아가는 그림 · 마법 그림(주인공의 앞) ✔ — 동작마다의 기준점(`clip.ox · oy`)
          G4 검사 ✔ — `23_lune_monsters.luau`(배치 · 몸 · 양쪽 · 제자리 · 나는 · 쏘는 · 마법 · 터짐 459개) · `24_lune_mobsview.luau`(화면 쪽 그리기를 가짜 화면 틀로 실제로 돌림 3,045개 — `run.py`가 `client/lune`도 묶는다) · 전체 123,127개 실패 0
          G5 그림 올리기 ✔(chars_1 · chars_mask_1) · `write_lune_ids.mjs` ✔ · **Play 확인 ✔(2026-10-09 밤 · 손님 캐릭터 Lv.30 액시온):** 열한 맵에서 열둘이 모두 나오고 침 — 걸어와 치는 일곱 · 터지는 포자 주머니(burst 뒤 사라짐) · 떠서 덮치는 박쥐 · 제자리의 굴 두더지(x가 바뀌지 않음) · 횃불지기의 마법(`MobCast` 뒤 0.28초에 Hurt · 불기둥이 발밑에 섬) · 빈 투구의 덩어리(`Shot.kind = helm`). 콘솔 오류 없음. 끝난 뒤 `LuneGuest` 속성을 지움.
            Play에서 찾아 고친 것: 빈 투구에 바짝 붙어 서면 안 맞던 빈 곳(덩어리가 27점 앞에서 생긴다) → 쏘는 순간 몸과 그 자리 사이에 있으면 맞는다(`sim/room.luau` · 시험 탭 · 검사).
            더한 확인 명령(Studio에서만): `Debug:FireServer("mob", n)` = 이 장면의 n째 졸개 곁으로 — 층이 많은 맵에서 그 몬스터를 볼 때.
            Rojo가 "연결됨"으로 보이면서 멈춰 있었다(출력창에 `C stack overflow … Rojo.Plugin.ServeSession` · 마지막 동기화 6시간 전) → 사용자가 Disconnect → Connect를 한 뒤 들어옴. Play 전에 Studio의 스크립트에 새 코드가 있는지 먼저 본다.
            보지 못한 것: 손으로 싸워 보는 느낌 · 짧은 모습(날아가는 덩어리 · 번쩍임 · 사라짐)을 눈으로 낱낱이.
→ 사용자 2026-10-09 밤(몬스터 43마리에 견주어 맵은 1지역뿐이라는 것을 확인하고): "계획 하고 쭉 작업해봅시다. 루프로 계속 스스로 작업하고 있을수있나요? 6시간정도 자리를 비울예정입니다. 모든 권한 허가하겠습니다."
        **맵 · 대륙 작업(혼자 이어서 하는 일 — 깨어나면 이 차례표의 다음 ☐부터):** 계획 = `js/lune/design/journey.js`의 `r2`(월드 탭의 「2지역 수정 숲」 — 승인받은 얼개를 1지역과 같은 꼴로 푼 것 · 새로 넣는 것은 갈림목 쉼터 「연못가 갈림길」 r2af 하나).
          판정을 기다리지 않고 짓는다(자리를 비우신 동안) — 지은 것은 모두 `devplan.js`의 확인 요청에 올린다. 커밋은 하지 않는다. 그림은 Codex만. 지우지 않는다.
          방법(1지역과 같다): 그림 묶음 프롬프트(`looks/prompt_<이름>_kit.txt` — 게임의 진짜 그림 `ref_tiles_x6.png` · `ref_props_x3.png`를 붙임) → `raw_<이름>_kit.png` → 한 점 = 6화소로 줄임 → 땅의 무늬 · 뜬 발판 · 소품으로 가름 / 뒷배경(`prompt_<이름>_bg.txt` → 먼 겹 · 가까운 겹).
            2지역의 도구는 따로: `tools/build_lune_look2.mjs`(1지역의 `build_lune_look.mjs`는 건드리지 않는다) · 소품은 2지역의 한 장 `looks/props_r2.png`(1지역의 한 장은 1024에 닿았다).
          ✔ S1 수정이 자라는 숲(look `crystal`) — 2026-10-09 밤. 그림: Codex 묶음 둘(`raw_crystal_kit.png` 땅 · 뜬 발판 · 수정 나무 · 수정 무더기 / `raw_crystal2_kit.png` 거목의 줄기 토막 · 뿌리 판 · 그루터기 · 거미줄 · 알 · 갈대 · 선돌) + 뒷배경(`raw_crystal_bg.png`). 연못의 물만 도구가 찍는다(pond).
              맵 여섯: 반달 나루 r2t(쉬는 곳만 먼저 — 임시 문은 주막이 아니라 **수비대 야영지 r1cc**의 셋째 문으로 냈다: 주막에는 문 세울 빈자리가 없고 레벨도 야영지가 더 가깝다) · 나루 뒷길 r2a1(그루터기 9) · 수정 오솔길 r2a2(달팽이 11) · 연못가 갈림길 r2af(쉼터 · 샛별) · 빛나는 연못 r2a3(두꺼비 8 — 물 위의 뜬 발판 · 갈대) · 쓰러진 거목 r2a4(오르는 맵 72x22 — 줄기 토막 넷을 딛고 뿌리 판이 선 언덕으로 · 거미 9).
              몬스터 넷의 숫자 `MONSTER_PLAY`(제 제안) · 레벨 `FIELD`(31 · 34 · 37 · 39). 두꺼비 = 따로 그린 날아가는 이펙트(침 덩어리 두 장)를 처음 이었다(`build_lune_monster_chars.mjs` · 시험 탭 `mobShots` · 게임은 그대로 됨).
              도구: `build_lune_look2.mjs`(조각을 하나씩 잘라 채우는 2지역의 소품 한 장 256x308 · 통나무 발판의 자리 맞춤 dx · dy) · `build_lune_maps.mjs`(생김새마다 제 소품 한 장) · 배치 표는 맵마다 built · 지역 표의 마을에 id(r2t).
              확인: 규칙 검사 통과 · 게임 검사 124,647개 실패 0 · 그림 15장 올림 · 시험 탭(연못: 두꺼비가 목을 부풀리고 침을 뱉어 맞힘) · Play(손님 Lv.36 — 반달 나루 · 빛나는 연못: Shot + Hurt 3.75초마다 · 쓰러진 거목: 토막 넷 · 거미 아홉 · 맞음. 콘솔 오류 없음). 보지 못한 것: 손으로 걸어 뛰어 본 느낌(토막 사이 두 칸 틈 · 두 칸 높이는 셈으로만 — 뛰는 높이 57점 · 그 높이에서 가로 64점).
              Debug goto 번호가 밀렸다(장면 26개 · 가나다 차례): r2a1 20 · r2a2 21 · r2a3 22 · r2a4 23 · r2af 24 · r2t 25 · town 26.
          ✔ S2 검은 수정 지대(look `dark`) — 2026-10-09 밤. 그림: Codex 묶음 둘(`raw_dark_kit.png` 땅 · 뜬 발판 · 죽은 나무 · 검은 수정 · 수정 문 · 가시덤불 / `raw_dark2_kit.png` 끊긴 돌길 조각 · 무너진 초소 · 망대 · 목책 · 깃발 · 무기 걸이 · 길 등 · 이정석 · 보급 상자) + 뒷배경(`raw_dark_bg.png` — 기운 수정 가시밭 · 가까워진 성당 · 분홍 점). 민트빛 소품은 이 구역에 놓지 않는다.
              맵 다섯: 물든 숲 r2b1(여우 9 — 수정 문) · 끊긴 순찰로 r2b2(봉오리 12 — 끊긴 둑길 · 뜬 돌길 조각 · 가시) · 기사단 초소 r2b3(고슴도치 10 — 목책 · 해자 · 망대 · 초소) · 기사단 본당 r2bs(쉼터만 먼저 — 기사들의 그림 · 가게 · 벽화는 뒤에) · 그림자 능선 r2b4(오르는 맵 64x24 — 결정 9 · 꼭대기에 수정 문). 연못가 갈림길에 줄기 문(물든 숲)을 냈다.
              몬스터 넷의 숫자(제 제안): 여우 · 봉오리 · 검은 결정 = 마법(cast — 주인공의 자리에 따로 뜨고 예고 0.33초) · 봉오리는 제자리 · 결정은 5점 떠 있음 · 고슴도치 = 앞뒤 모두 맞는 근접. 레벨 41 · 44 · 47 · 49.
              도구: 묶음 자르기에 "빈 세로줄에서 가르기(cols)" · "갈린 조각 합치기([이름, 개수])" · 뒷배경에서 한 번만 나와야 하는 것(성당)을 거울 쪽에서 덮기(once) · 빛 점의 색을 맵마다(분홍). 캐릭터 그림판이 두 장이 됐다(chars_2.png).
              확인: 규칙 검사 통과 · 게임 검사 126,177개 실패 0 · 그림 15장 올림 · 시험 탭(끊긴 순찰로: 수정 싹이 발밑에서 자라 맞음) · Play(손님 Lv.48 — 네 맵: 여우 · 봉오리 · 결정 = MobCast 뒤 0.30초에 Hurt / 고슴도치 = Hurt. 콘솔 오류 없음).
              Debug goto 번호(장면 31개): r2b1 25 · r2b2 26 · r2b3 27 · r2b4 28 · r2bs 29 · r2t 30 · town 31.
          ✔ S3 수정 성당 — 2026-10-09 밤. 그림: Codex 묶음 둘(`raw_cathedral_kit.png` 돌 바닥 · 등 달린 발코니 셋 · 큰 창 · 기둥 · 기사상 · 촛대 · 걸상 · 큰 종 / `raw_cathedral2_kit.png` 성당의 정면 · 분수 · 쇠 울타리 · 뜰의 등 · 부러진 기둥 · 항아리) + 안쪽 벽(`raw_cathedral_wall.png` — 눈먼 아치 셋). 생김새 셋: cathedral(앞뜰 — 뒷배경은 검은 수정 지대의 것) · cloister · belfry(안쪽 벽 f 2).
              맵 셋: 성당 앞뜰 r2c1(골렘 10 — 성당 정면의 큰 문 앞에서 ↑) · 수정 회랑 r2c2(향로 9 — 천장이 있는 방 · 가로로 이어 붙는 벽) · 종탑 r2c3(종지기 9 — 망루와 같은 뼈대 24x40 · 꼭대기에 큰 종). 기사단 본당에 줄기 문(성당 앞뜰)을 냈다.
              몬스터 셋의 숫자(제 제안): 골렘 = 느리고 아주 단단함(2.0배) · 앞뒤 내리치기 / 향로 = 떠서 마법(연기 고리) / 종지기 = 빠른 종소리(닿는 거리 30점). 레벨 51 · 54 · 56.
              도구 · 게임: 2지역의 소품이 두 장이 됐다(props_r2 = 수정 숲 · 검은 수정 지대 / props_r2c = 성당 · 나루) · 맵과 똑같이 움직이는 벽(f 2)을 가로로 긴 맵에서도 쓴다(시험 탭 · 게임 sceneView · 검사 10) · 천장이 있는 맵은 놓는 줄을 모두 적는다(안 적으면 천장에 놓인다 — 회랑에서 겪음).
              확인: 규칙 검사 통과 · 게임 검사 127,282개 실패 0 · 그림 11장 올림 · Play(손님 Lv.54 — 세 맵: 골렘 · 종지기 = Hurt / 향로 = MobCast 뒤 0.30초에 Hurt · 회랑의 벽이 바닥 · 문과 맞음. 콘솔 오류 없음).
              Debug goto 번호(장면 34개): r2c1 30 · r2c2 31 · r2c3 32 · r2t 33 · town 34.
          ✔ S4 반달 나루의 제 생김새(look `ferry`) — 2026-10-09 밤. 그림: Codex 묶음(`raw_ferry_kit.png` 널빤지 둑 · 등 달린 나무 발판 셋 · 나룻배 · 뱃사공의 집 · 말뚝 · 그물 걸이 · 바구니 · 나루의 종) + 뒷배경(`raw_ferry_bg.png` 강 건너의 숲 — 첫 그림은 크기가 2172x724로 잘못 나와 `raw_ferry_bg_v1.png`로 두고 다시 뽑았다). 강물 = 연못과 같은 물의 띠.
              맵: 반달 나루 r2t를 다시 지었다(64칸 — 왼쪽 끝이 강 · 나룻배 앞에서 ↑ · 둑 위에 집 둘과 반달의 좌판). 땅 그리는 법에 rise(딛는 줄 위로 솟은 말뚝 머리) · shift 0(세로로 이어지는 말뚝)을 더했다(`lune_look.mjs` — 1지역의 것은 그대로).
          ✔ S5 은달 항구(대도시 — 여섯 장) · 나룻배 — 2026-10-09 밤. 그림: Codex 묶음 넷(`raw_city_kit.png` 흰 돌의 거리 · 발코니 · 차양 · 널빤지 · 가로등 · 분수 · 게시판 · 걸상 · 화분 · 깃발 · 손수레 / `raw_city2_kit.png` 성문 · 여관 · 경매장 · 달무리 회관 · 잡화점 · 대장간 / `raw_city3_kit.png` 돛배 · 비행선 · 승강탑 · 관저 · 그리폰 우리 / `raw_city4_kit.png` 좁은 집 · 나무 집 · 창고 · 마구간 · 어시장 · 항구 사무소) + 뒷배경(`raw_city_bg.png` 등대 · 돛대 · 비행선 탑의 스카이라인).
              맵 여섯(모두 쉬는 곳 · id는 continents.js의 city.maps에 달았다): 성문 거리 ct1 · 달맞이 광장 ct2(문 넷) · 장터 거리 ct3 · 하늘 승강장 ct4(look skyport) · 부두 ct5(look dock — 땅은 나루의 둑) · 영주의 언덕 ct6. 건물은 앞모습의 소품이다(안 · 기능은 없다 — 자리만). 발판은 건물의 앞에 그린다(slabsOver).
              길: 수비대 야영지 r1cc —(임시 문)— 성문 거리 — 달맞이 광장 — 장터 거리 — 부두 —(나룻배)— 반달 나루. 임시 문은 망루 꼭대기와 보스를 지으면 그 뒤의 길로 바꾼다. 비행선 · 돛배는 구경만(표가 없다).
              사람 여덟(그림 = Codex 둘째 · 셋째 묶음 `people/raw_people2.png` · `raw_people3.png` — 캐릭터 그림이라 판정을 받는다. 셋째의 첫 그림은 테두리 · 음영이 들어가 `raw_people3_v1_fine.png`로 두고 다시 뽑았다): 성문지기 마루 · 경매사 금송 · 의뢰 접수원 소담 · 뱃사공 노을(부두 · 나루) · 승강장 일꾼 나래 · 여관 주인 한솔 · 견습 기사 하늬(기사단 본당) · 회관 접수원 이슬. 그림 도구(`build_lune_people.mjs`)가 묶음을 여럿 받는다 — 눈을 지키는 문턱(pri) · 키에 맞춘 간격(fit) · 두 점으로 번진 눈 다듬기.
              소품 장: props_city(거리와 건물) · props_port(부두와 승강장) — 2지역의 것까지 네 장.
              확인: 규칙 검사 통과 · 게임 검사 127,736개 실패 0 · 그림 22장 올림 · 시험 탭(부두) · Play(손님 Lv.30): 수비대 야영지의 임시 문에서 ↑ → 성문 거리 → 달맞이 광장 → 장터 거리 → 부두 → 나룻배 앞에서 ↑ → 반달 나루까지 문을 타고 감(키 입력 도구로 ↑). 주민의 이름표(성문지기 마루 · 잡화 상인 반달 · 뱃사공 노을)가 뜸. 콘솔 오류 없음. 하늘 승강장 · 영주의 언덕은 Play에서 열어 보지 않았다(그림과 검사로만).
              Debug goto 번호(장면 40개 — ct가 맨 앞): ct1~ct6 = 1~6 · hunt 7 · r1cc 25 · r2a1 26 · r2bs 35 · r2c1 36 · r2t 39 · town 40. `Debug portal k`는 문 앞에 세우기만 한다 — 지나가려면 ↑(키 입력 도구 user_keyboard_input).
          ✔ S6 동쪽 대륙의 들머리 — 등불 포구 + 3지역 땅속 화롯골의 첫 구역 「내려가는 굴」 — 2026-10-09 밤. 계획 = `journey.js`의 `r3`(월드 탭의 「3지역 땅속 화롯골」 — 숨은 맵이던 지상 상인의 야영지를 갈림목 쉼터로 꺼냈다 · 들머리 = 등불 포구).
              그림(이 땅의 빛은 분홍): Codex 묶음 셋(`raw_lantern_kit.png` 주상절리 절벽 · 등 달린 나무 길 · 큰 굴 입구 · 기둥 위의 집 · 비행선 매는 기둥 · 등불 줄 · 기중기 · 짐 / `raw_cave_kit.png` 젖은 바위 땅 · 종유석 달린 뜬 바위 · 석순 · 돌기둥 · 빛 버섯 · 굴 문 · 잠자리 · 줄사다리 / `raw_mine_kit.png` 쇠줄을 얹은 땅 · 높은 광차 길의 토막 셋 · 버팀목 · 광차 · 광석 더미 · 연장 걸이 · 광산 등 · 두레박 틀) + 굴의 벽(`raw_cave_wall.png` — 하늘 대신 속이 찬 바위 벽, f 0.3) + 포구의 뒷배경(`raw_lantern_bg.png`). 프롬프트 생성기 = scratch의 mk_prompts_r3.py(프롬프트 파일은 looks/prompt_*.txt에 남아 있다).
              맵 여섯: 등불 포구 `port`(쉬는 곳 — id는 continents.js의 world.nodes의 port) · 굴 입구 r3a1(굴쥐 10) · 젖은 굴 r3a2(석순 흉내쟁이 10 — 물웅덩이) · 지상 상인의 야영지 r3ah(쉼터 · 반달) · 식은 광산 r3a3(곡괭이 코볼트 10) · 광차 길 r3a4(폭주 광차 8 — 96칸 · 높은 광차 길). 레벨 61 · 64 · 67 · 69.
              길: 하늘 승강장 ct4의 승강탑 문 —(임시 비행선)— 등불 포구의 매는 기둥 → 큰 굴 입구 → 굴 입구 → 젖은 굴 → 야영지 → 식은 광산 → 광차 길(막다른 곳). 비행선의 기다림 · 타는 장면 · 표는 아직 없다(문 하나로 바로 간다).
              도구: `build_lune_look2.mjs`에 kitLook(묶음 하나 = 생김새 하나) · 소품 장 props_r3.
              확인: 규칙 검사 통과 · 게임 검사 129,289개 실패 0 · 그림 19장 올림 · Play(손님 Lv.66): 하늘 승강장의 탑 문에서 ↑ → 등불 포구에 닿음 · 네 사냥터의 몬스터가 모두 나오고 침(Hurt). 콘솔 오류 없음. 보지 못한 것: 굴을 걸어서 끝까지 가는 것 · 광차를 뛰어넘는 느낌.
              Debug goto 번호(장면 46개): ct1~6 = 1~6 · hunt 7 · port 13 · r1cc 26 · r2a1 27 · r2t 40 · r3a1 41 · r3a2 42 · r3a3 43 · r3a4 44 · r3ah 45 · town 46.
          ✔ S7 3지역의 용암 굴 · 큰 화로 — 2026-10-09 밤. 그림: Codex 묶음 셋(`raw_lava_kit.png` 분홍 용암이 갈라진 검은 바위 · 용암이 흘러내리는 뜬 바위 · 용암 폭포 · 흑요석 가시 · 불씨 구멍 · 식은 용암 더미 · 불의 돌기둥 · 사슬 다리 / `raw_hearth_kit.png` 쇠판을 얹은 벽돌 바닥 · 사슬에 매달린 쇠 발판 · 화로의 아가리 · 큰 풀무 · 재 더미 · 닫힌 큰 문 · 담금질 물통 · 불의 깃발 / `raw_hearth2_kit.png` 벽화 · 제단 · 쓰러진 기둥 · 화로) + 화로의 벽(`raw_hearth_wall.png`). 용암의 띠만 도구가 찍는다(lava). 프롬프트 생성기 = scratch의 mk_prompts_r3b.py.
              맵 일곱: 뜨거운 굴 r3b1(쇳물 방울 10 — 용암 구덩이 둘) · 불씨 길 r3b2(굴 지렁이 10 — 제자리) · 화롯골 r3t(닫힌 큰 문 앞 — 쉬는 곳만) · 화로 둘레길 r3c1(재 회오리 10) · 식어 가는 불길 r3c2(굴뚝 도깨비 8 — 불덩이를 쏜다) · 벽화의 방 r3cs(이야기의 방 — 벽화: 도끼 · 창 · 낫 · 대검 · 불을 든 다섯 사람과 큰 용 · 달의 다섯 모습) · 화로 깊은 곳 r3c3(성난 모루 8 — 막다른 곳). 레벨 71 · 74 · 81 · 84 · 87.
              식은 광산의 문을 고쳤다: 가운데 둔덕의 문 = 광차 길(가지) · 오른쪽 끝의 문 = 뜨거운 굴(줄기).
              새 것: 용암 구덩이 = 가시(spikes)의 자리에 용암의 띠(`spikeArt: 'lava'` — 닿으면 가시와 같은 약한 피해) · 쏘는 높이를 고쳐 적기(`shot.dy` — 굴뚝 도깨비의 불덩이는 굴뚝 끝(38점)에서 나가면 머리 위로 지나가 12점으로 낮췄다).
              확인: 규칙 검사 통과 · 게임 검사 131,160개 실패 0 · 그림 18장 올림 · Play(손님 Lv.84): 다섯 사냥터의 몬스터가 모두 나오고 침(쇳물 방울 · 지렁이 · 회오리 · 모루 = Hurt / 굴뚝 도깨비 = Shot + Hurt 3.8초마다) · 벽화의 방이 나옴. 콘솔 오류 없음. 보지 못한 것: 용암 구덩이에 빠져 보는 것 · 뜬 바위로 건너는 것.
              Debug goto 번호(장면 53개): ct1~6 = 1~6 · hunt 7 · port 13 · r1cc 26 · r2t 40 · r3a1 41 · r3a2 42 · r3a3 43 · r3a4 44 · r3ah 45 · r3b1 46 · r3b2 47 · r3c1 48 · r3c2 49 · r3c3 50 · r3cs 51 · r3t 52 · town 53.
              3지역에서 아직 없는 것: 버려진 제단 · 쫓겨난 아이의 방 · 불씨 도둑의 소굴 · 화약 창고 · 용암 못 · 분화구 넷(화산 기슭 · 갈라진 비탈 · 가장자리(흑요석 전갈) · 분화구) · 화롯골의 안 · 보스 · 퀘스트.
          ✔ S8 4지역 만월성의 첫 구역 「무너진 외성」 — 2026-10-09 밤. 계획 = `journey.js`의 `r4`(월드 탭의 「4지역 만월성」). 그림(하얗게 바랜 돌 — 민트 · 분홍이 모두 옅다): Codex 묶음 `raw_ruin_kit.png`(바랜 돌의 길 · 떠 있는 성벽 조각 셋 · 무너진 성벽 · 불탄 집 · 쓰러진 왕의 석상 · 부러진 기둥들 · 점령군의 깃발 · 말뚝 방책 · 하얗게 마른 나무) + 뒷배경 `raw_ruin_bg.png`(무너진 성과 달의 고리 — 한 번만 나오는 큰 성은 도구가 가린다, `once`). 소품 장 props_r4. 프롬프트 생성기 = scratch의 mk_prompts_r4.py.
              맵 넷: 외성 밖 들판 r4a1(정예 창병 9 — 왼쪽 끝이 외성 밖 야영지) · 무너진 성벽 r4a2(64칸 x 24칸 · 오르는 맵 — 정예 창병 5 + 정예 검병 5) · 불탄 거리 r4a3(찢어진 깃발 6 + 정예 검병 5) · 아랫마을 광장 r4a4(부서진 기사상 5 + 정예 창병 3 + 정예 궁병 2 — 막다른 곳 · 필드 보스 자리). 레벨 101 · 104~105 · 107 · 109~110.
              이 지역의 주인은 병사다(배치표 monsterPlace.js: 4지역은 새 몬스터 다섯만 남았다) — 정예 창병 · 검병 · 궁병을 레벨만 올려 쓰고, 제 몬스터는 깃발과 기사상 둘. 한 맵에 병사와 제 몬스터가 같이 있다.
              길: 등불 포구의 오른쪽 문 —(임시)— 외성 밖 들판 → 무너진 성벽 → 불탄 거리 → 아랫마을 광장. 임시 문은 3지역의 보스 뒤의 굴과 그리폰이 생기면 바꾼다.
              도구: 묶음에서 붙어 버린 두 조각을 가장 성긴 세로줄에서 가르기(`split`) · 뒷배경 두 겹 만들기(`bgLayers` — 폭이 2172인 그림도 받는다).
              확인: 규칙 검사 통과 · 게임 검사 132,895개 실패 0 · 그림을 모두 올림(남은 것 0장) · Play(손님 Lv.108): 불탄 거리(깃발 6 · 검병 5 — Hurt) · 아랫마을 광장(기사상 5 · 창병 3 · 궁병 2 — MobCast 뒤 Hurt). 콘솔 오류 없음. 보지 못한 것: 외성 밖 들판 · 무너진 성벽을 Play에서 여는 것 · 성벽을 걸어서 오르는 것.
          ✔ S9 물마루 바다의 뭍 — 2026-10-09 밤. 계획 = `continents.js`의 sea(월드 탭 맨 위). 그림: Codex 묶음 `raw_shore_kit.png`(젖은 모래와 갯바위 · 해초가 늘어진 뜬 바위 셋 · 무너진 등대 · 뭍에 올린 배 · 바위기둥 · 물웅덩이 바위 · 떠밀려 온 나무 · 생선 말리는 틀 · 등 달린 돌말뚝) + 뒷배경 `raw_shore_bg.png`(먼 섬과 바다). 물마루 마을(isle)의 땅 · 나무 발판 · 집 · 돛배는 반달 나루 · 은달 항구의 것을 다시 쓴다. 소품 장 props_sea.
              맵 셋: 물마루 마을 seat(쉬는 곳 — 잔교의 돛배 · 반달의 좌판) · 갯바위 해변 sea1(진주 조개 10 — 제자리 · 물웅덩이 둘) · 등대 곶 sea2(56칸 x 26칸 · 오르는 맵 — 물총 따개비 9 · 꼭대기에 무너진 등대 = 필드 보스 자리). 레벨 47 · 52.
              길: 은달 항구의 부두 ct5의 잔교 —(임시 배)— 물마루 마을 → 갯바위 해변 → 등대 곶. 배의 기다림 · 타는 장면 · 표는 아직 없다.
              따개비의 물덩이는 주둥이 끝(24점)이 아니라 발에서 12점 높이로 날아온다(`shot.dy` — 굴뚝 도깨비와 같은 까닭).
              확인: Play(손님 Lv.108): 부두의 잔교에서 ↑ → 물마루 마을에 닿음 · 갯바위 해변(조개 10 — Hurt) · 등대 곶(따개비 9 — Shot + Hurt 3.5초마다). 콘솔 오류 없음. 보지 못한 것: 등대 곶을 걸어서 오르는 것 · 물웅덩이.
              Debug goto 번호(장면 60개): ct1~6 = 1~6 · hunt 7 · port 13 · r1cc 26 · r2t 40 · r3a1 41 · r3cs 51 · r3t 52 · r4a1 53 · r4a2 54 · r4a3 55 · r4a4 56 · sea1 57 · sea2 58 · seat 59 · town 60.
              바다에서 아직 없는 것: 바닷속 맵 여섯(해파리 · 뱀장어 · 닻 — 물속 움직임과 「앞에 놓는 주문」이 먼저 있어야 한다. 시험 탭에서 먼저) · 낚시터 · 마을의 주민과 가게. 4지역에서 아직 없는 것: 구역 b~e(책 r4c2 · 눈 r4d1 · 마법사 r4d2) · 성 아랫마을 · 보스.
          ✔ S10 3지역의 분화구(굴 밖 — 화산의 비탈) — 2026-10-09 밤. 계획 = `journey.js`의 `r3`의 r3d. 그림(분홍): Codex 묶음 `raw_crater_kit.png`(재가 앉은 검은 용암의 땅 · 뜬 용암 껍질 셋 · 분기공 · 화산탄 · 탄 나무 · 흑요석 · 갈라진 바위 · 화약통 · 옛 승강기의 탑) + 뒷배경 `raw_crater_bg.png`(연기를 뿜는 큰 화산 — 한 번만 나오게 가린다). 소품 장 props_r3d(용암의 띠도 싣는다). 프롬프트 생성기 = scratch의 mk_prompts_r5.py.
              맵 셋: 화산 기슭 r3d1(폭탄병 6 + 정예 창병 4) · 갈라진 비탈 r3d2(64칸 x 24칸 · 오르는 맵 — 턱 셋에 용암이 든 틈 · 폭탄병 7 + 정예 궁병 3) · 분화구 가장자리 r3d3(흑요석 전갈 10 — 용암 구덩이 둘 · 옛 승강기의 탑 = 분화구(보스)로 내려갈 자리). 레벨 91~92 · 94 · 96.
              화산 기슭 · 갈라진 비탈은 제 몬스터(불꼬리 도마뱀 · 불티 도깨비)가 삭제되어 주인이 없다 → 지역 표의 「갑옷 폭파병」과 메인 퀘스트 「터지는 산」(누가 화산을 터뜨렸다)에 맞춰 폭탄병 부대로 채웠다. 새 몬스터 둘을 만들지는 사용자에게 여쭌다.
              길: 벽화의 방 r3cs에 굴 문을 냈다(가운데 오른쪽) → 화산 기슭 → 갈라진 비탈 → 분화구 가장자리(막다른 곳 — 분화구 r3d4는 보스를 지을 때).
              도구: 뒷배경의 먼 겹이 그림의 가운데 줄을 넘어 내려왔을 때 읽을 줄 수(`farH`) — 처음에는 먼 겹에 세로 막대 흠이 생겼다.
          ✔ S11 4지역의 성벽 구역 — 2026-10-09 밤. 계획 = `journey.js`의 `r4`의 r4b · r4bh. 그림: Codex 묶음 `raw_rampart_kit.png`(돌출 받침이 달린 성벽의 윗길 · 나무 비계 셋 · 성벽의 탑 · 성가퀴 · 공성 사다리 · 투석기 · 화톳불 · 창걸이 · 내림문) + 성벽의 벽면 `raw_rampart_wall.png`(맵과 같이 움직이는 벽 f 2). 생김새 둘: rampart(성벽 아래 · 망대 · 통로) · wallwalk(성벽 위 — 뒤는 폐허의 하늘과 먼 성). 소품 장 props_r4.
              맵 넷: 성벽 아래 r4b1(정예 궁병 5 + 정예 창병 5) · 성벽 위 r4b2(88칸 — 정예 궁병 3 + 폭탄병 7 · 문 셋) · 망대 r4b3(24칸 x 40칸 — 옛 망루 · 종탑과 같은 뼈대 · 폭탄병 7 + 정예 궁병 2 · 막다른 가지) · 성벽 속 통로 r4bh(쉼터 — 지역 표의 숨은 맵을 계획대로 쉼터로 꺼냈다). 레벨 111~112 · 114~115 · 117.
              아랫마을 광장 r4a4를 오른쪽으로 여덟 칸 늘려 내성 성벽의 내림문을 냈다(→ 성벽 아래). 이 구역은 제 몬스터가 없다(배치표의 「병사가 주인인 곳」).
          ✔ S12 4지역의 내성 — 2026-10-09 밤. 그림: Codex 묶음 `raw_court_kit.png`(달의 다섯 모습을 새긴 축대 · 회랑의 윗길 조각 셋 · 내성의 정면 · 마른 분수 · 회랑 한 토막 · 기사상 · 죽은 산울타리 · 초소 · 수련 말뚝) · `raw_hall_kit.png`(바둑판 바닥 · 책이 매달린 선반 셋 · 큰 책장 · 갑옷 · 회랑의 문 · 초상화 · 독서대 · 책 더미 · 기둥) + 회랑의 벽 `raw_hall_wall.png`. 두 묶음은 처음 것이 너무 잘게 나와 줄였을 때 뭉개져서(`raw_court_kit_v1.png` · `raw_hall_kit_v1.png`로 남겼다) 성벽 묶음을 굵기 기준으로 붙여 다시 뽑았다.
              뜰의 뒷배경은 도구가 만든다: 성벽의 벽면 한 마디에 성가퀴를 파서 화면의 88점부터 건다(그 위는 하늘과 달). 소품 장 = 뜰 props_r4 · 회랑 props_r4c.
              맵 셋: 내성 뜰 r4c1(정예 창병 5 + 정예 검병 5) · 기사의 회랑 r4c2(96칸 — 떠도는 책 6 + 정예 검병 4) · 옛 근위대 숙소 r4ch(쉼터 — 숨은 맵을 계획대로 쉼터로). 레벨 121~122 · 126.
          ✔ S13 4지역의 봉인의 회랑 — 2026-10-09 밤. 그림: Codex 묶음 `raw_seal_kit.png`(봉인의 문양이 새겨진 검은 돌 바닥 · 사슬에 매인 돌판 셋 · 봉인의 문 · 쐐기 · 부러진 쐐기 · 문양 기둥 · 사슬 고리 · 파수꾼의 등 · 내려가는 계단의 문) + 봉인의 벽 `raw_seal_wall.png`(큰 사슬 · 문양의 띠 · 달의 다섯 모습의 고리). 봉인의 빛은 민트, 새는 곳만 분홍 금. 소품 장 props_r4c.
              맵 둘: 내려가는 계단 r4d1(64칸 x 24칸 · 맨 위 오른쪽에서 들어와 내려간다 — 감시하는 눈 10) · 봉인의 회랑 r4d2(88칸 — 봉인술사의 허물 9). 레벨 134 · 138. 깨진 쐐기의 방(중간 보스) · 성문(보스) · 봉인의 문 앞은 아직 없다.
              몬스터 넷을 넣었다(숫자는 제 제안): 흑요석 전갈 = 제자리에 서서 꼬리로 찌름(0.42초 뒤 · 24점 · 1.7배 단단함) · 떠도는 책 · 감시하는 눈 = 박쥐의 방식(13점 위를 날다가 내려와 덮침 — 책 70점 · 0.45초 / 눈 80점 · 0.4초) · 봉인술사의 허물 = 5점 떠서 90점 안의 주인공 몸 자리에 봉인 문양(예고 0.33초). 이로써 뭍의 제 몬스터 40종이 모두 게임에 있다(남은 것 = 바닷속의 해파리 · 뱀장어 · 닻).
              도구 · 검사: 뒷벽 한 장을 만드는 도우미(`wallOf` — 거는 높이 y) · 같은 묶음으로 뒷배경만 다른 생김새(`alsoLook`) · 묶음 가르기의 자리 지정(`split.at`) · 미리보기 그림이 벽의 높이(y)를 따르게 · 게임 검사 10의 규칙을 고쳤다(오르는 맵의 맵과 같이 움직이는 벽: 한 화면 폭이 아니어도, 벽 그림이 맵의 높이를 다 덮으면 된다 — 내려가는 계단).
              확인(S10~S13 한꺼번에): 규칙 검사 통과 · 게임 검사 135,099개 실패 0 · 그림 34장 올림 · Play(손님 Lv.138): 사냥터 열 장의 몬스터가 모두 표대로 나오고 침(전갈 10 · 책 6 · 눈 10 = Hurt / 허물 9 = MobCast 뒤 0.3초에 Hurt / 병사 = Hurt · Shot · Burst) · 문 셋을 실제로 지남(벽화의 방 → 화산 기슭 · 아랫마을 광장 → 성벽 아래 · 옛 근위대 숙소 → 내려가는 계단). 콘솔 오류 없음. 보지 못한 것: 나머지 문을 손으로 지나는 것(게임 검사 13이 길이 이어지는지만 본다) · 용암 틈 · 걸어서 끝까지 가는 것 · 손으로 싸워 본 느낌.
              Debug goto 번호(장면 72개): ct1~6 = 1~6 · hunt 7 · port 13 · r1cc 26 · r2t 40 · r3a1 41 · r3cs 51 · r3d1 52 · r3d2 53 · r3d3 54 · r3t 55 · r4a1 56 · r4a4 59 · r4b1 60 · r4b2 61 · r4b3 62 · r4bh 63 · r4c1 64 · r4c2 65 · r4ch 66 · r4d1 67 · r4d2 68 · sea1 69 · sea2 70 · seat 71 · town 72(탐침에서는 scenes.generated의 열쇠를 정렬해 번호를 셈한다).
          ✔ S14 물마루 바다의 바닷속 — **시험 탭에서만**(게임에는 넣지 않았다) — 2026-10-09 밤. 까닭: 물속 움직임은 느낌의 문제라 「시험 탭 먼저 → 사용자가 느껴 봄 → 게임」의 차례를 지킨다.
              물속 움직임(`luneTab.js`의 SEA · 장면의 `sea: true`): 걷기 0.85배(78점) · 뛰는 힘 0.74배 · 끌어내리는 힘 0.34배 → 뛰는 높이 약 92점(땅의 1.6배 — 다섯 칸 위에 닿는다) · 오르는 데 0.92초 · 내려오는 빠르기는 1초에 90점까지. 승인받은 대륙 계획의 규칙(「바닥을 걷는다. 뛰면 느리게 높이 뜨고 천천히 내려온다. 숨 제한은 없다」)을 숫자로 옮긴 것이고 숫자는 제 제안.
              그림: Codex 묶음 `raw_seabed_kit.png`(모래와 암초의 땅 · 산호 선반 셋 · 키 큰 해초 · 부채 산호 · 뇌 산호 · 큰 소라 · 대롱 산호 · 가라앉은 나룻배 · 암초 문) · `raw_sunken_kit.png`(따개비가 붙은 옛 선창 · 난파선의 갑판 조각 셋 · 물에 잠긴 창고 · 부러진 돛대 · 항구의 등 · 쓰러진 석상 · 항아리 · 큰 닻 · 옛 항구의 문 — 처음 것은 잘고 해초가 초록이라 `_v1`로 남기고 다시 뽑았다) + 깊은 물의 뒷벽 `raw_deep_wall.png`(달빛 줄기 · 먼 바다 밑의 윤곽 · f 0.3). 공기 방울은 도구가 찍는다. 소품 장 props_sea. 프롬프트 생성기 = scratch의 mk_prompts_sea.py.
              맵 넷(`tabOnly: true` · `sea: true`): 얕은 여울 sea3(등불 해파리 10) · 공기 방울 쉼터 seaf(쉼터 · 반달) · 산호밭 sea4(굴 곰치 10 — 제자리) · 가라앉은 항구 sea7(닻 망령 9). 레벨 52 · 58 · 71. 갯바위 해변 sea1의 가운데 둔덕에 바다로 들어가는 자리(돌말뚝)를 냈다 — 게임에서는 이 문이 빠진다. 산호밭 → 가라앉은 항구는 임시 문(사이의 난파선 무덤 · 해초 숲은 제 몬스터가 삭제되어 주인이 없어 아직 짓지 않았다).
              몬스터 셋(`tabOnly: true` — 숫자는 제 제안): 등불 해파리 = 8점 떠서 44점 안의 주인공 쪽으로 번개 줄기를 뻗음(「앞으로 뻗는 주문」 — 탭에는 그 코드가 있었고 게임에는 아직 없다) · 굴 곰치 = 제자리에서 28점 안이면 뭄 · 닻 망령 = 5점 떠서 다가와 솟았다가 찍음. 이로써 삭제되지 않은 제 몬스터 43종이 모두 어딘가에 놓였다(게임 40 · 시험 탭 3).
              게임에서 빼는 장치: 내보내기(`export_lune_game.mjs`)가 tabOnly인 맵 · 그 맵으로 가는 문 · tabOnly인 몬스터를 건너뛴다(`monsterMobs.js`). 게임은 그대로 장면 72개 · 졸개 48종.
              확인: 규칙 검사 통과(배치 43마리 모두 지은 맵에) · 게임 검사 135,100개 실패 0 · 올릴 그림 0장(소품 장 props_seat 한 장 다시 올림) · 시험 탭을 머리 없는 브라우저로 열어 네 맵이 모두 그려지는 것(해파리 · 곰치 · 닻 망령 · 공기 방울과 반달). 보지 못한 것: **뛰어 보는 느낌 · 해파리의 번개가 실제로 맞는 것 · 싸우는 것 전부**(멈춘 화면만 봤다) — 사용자가 탭에서 해 보셔야 한다.
              게임에 옮길 때 할 일: sim/physics.luau에 물속 움직임 · 몬스터의 「앞으로 뻗는 주문」(cast place front) · tabOnly를 떼기 · 검사 23의 표.
          ✔ S15 4지역의 막다른 사냥터 둘 + 지은 것을 게임에서 다시 돌아봄 — 2026-10-10 00:10. 새 그림 없이 지금 있는 생김새로 지었다.
              맵 둘: 성문 앞 r4b4(성벽 아래의 가운데 문에서 — 정예 창병 4 · 폭탄병 3 · 정예 궁병 3 · 닫힌 성문 · 필드 보스 「파성추 부대」의 자리 · Lv.119~120) · 무기고 r4c3(옛 근위대 숙소의 가운데 문에서 — 정예 검병 10 · 빈 갑옷이 줄지어 선 방 · Lv.130). 성벽 아래 r4b1은 가운데 문 곁을 비우느라 병사의 자리를 고쳤다(마릿수는 그대로 10).
              게임에서 보고 고친 것: 망대의 맨 아래층에 벽의 깃발이 바닥에 걸려 분홍 토막으로 보였다 → 깃발을 지운 벽(생김새 `rampin`)을 망대 r4b3 · 성벽 속 통로 r4bh가 쓴다(통로는 점령군이 모르는 곳이기도 하다).
              확인: 규칙 검사 통과 · 게임 검사 135,212개 실패 0 · 올릴 그림 0장 · Play(손님 Lv.140)에서 **새 문을 모두 ↑로 지나 봄**(장면의 이름으로 확인): 화산 기슭 → 갈라진 비탈 → 분화구 가장자리 · 성벽 아래 → 성문 앞 · 성벽 아래 → 성벽 위 → 망대 · 성벽 위 → 성벽 속 통로 → 내성 뜰 → 기사의 회랑 → 옛 근위대 숙소 → 무기고 · 내려가는 계단 → 봉인의 회랑. 무기고(검병 10) · 성문 앞(창병 4 · 폭탄병 3 · 궁병 3)의 몬스터가 나오고 침. 갯바위 해변의 바다 문은 게임에서 빠져 있음(문 둘 · 장면 sea3 없음). 화면으로 본 맵: 갈라진 비탈 · 성벽 위 · 망대 · 성벽 속 통로 · 옛 근위대 숙소 · 외성 밖 들판 · 무너진 성벽 · 갯바위 해변 · 성문 앞 · 무기고. 콘솔 오류 없음.
              Debug goto 번호(장면 74개): r3d1 52 · r3d2 53 · r3d3 54 · r3t 55 · r4a1 56 · r4a4 59 · r4b1 60 · r4b2 61 · r4b3 62 · r4b4 63 · r4bh 64 · r4c1 65 · r4c2 66 · r4c3 67 · r4ch 68 · r4d1 69 · r4d2 70 · sea1 71 · sea2 72 · seat 73 · town 74. 지금 장면의 이름 = `PlayerGui.LuneStage:GetAttribute("Scene")`.
              남은 맵 24장(지역 표): 보스 넷 · 옛 주인의 굴 여덟 · 용사의 흔적 같은 숨은 방 여섯(이야기 그림이 필요하다) · 불씨 도둑의 소굴과 화약 창고(사람 꼴의 적 「불씨 도둑」의 그림이 없다) · 깨진 쐐기의 방 · 봉인의 문 앞 · 틈새 회랑 · 바다의 해초 숲 · 난파선 무덤 · 가라앉은 등대 — 모두 사용자의 판단(보스 · 새 몬스터 · 이야기 그림)이 먼저다.
          ✔ S16 가로 사냥터 줄이기 — 2026-10-10. 사용자(돌아와서): "공방 켜고, 지금 사냥터들이 전반적으로 가로 맵인경우 가로로 너무 깁니다. 조금 줄일필요가있습니다. 나머지는 잘만들어져있습니다. 그리고 나머지 진행하지못한 작업들 쭉 작업하면 됩니다."
              줄인 것: 가로 사냥터 40장(maps.js의 39장 + 달그림자 사냥터) — 72 → 56칸 · 80 → 64칸 · 88 → 72칸 · 96 → 76칸(스무 칸 안팎 = 20%쯤). 화면 한 장이 24칸이니 세 장 반이던 맵이 두 장 반 남짓이 됐다. 마을 어귀(64칸) · 오르는 맵 · 쉼터 · 도시는 그대로.
              방법: 맵마다 평평한 단에서 두세 칸씩 덜어냈다(턱 · 문 · 발판 · 구덩이의 짜임은 그대로) — 덜어낼 칸은 손으로 정했다(scratch의 cuts.mjs · cut_maps.mjs — 한 번 쓰고 마는 도구라 tools에는 넣지 않았다). **몬스터의 수는 줄이지 않았다**(같은 수가 더 좁은 데에 — 화면 한 장에 3마리쯤 → 3.7마리쯤). 덜어낸 칸에 있던 나무 · 풀 같은 소품은 뺐다.
              달그림자 사냥터는 만드는 도구가 달라(`build_lune_demo.mjs`) 따로 줄였다: 기술을 써 보는 시작 평지와 나무 다리는 그대로, 그 뒤만 96 → 76칸. 세 갈래 길로 가는 문은 72.5칸.
              확인: 규칙 검사 통과 · 게임 검사 135,395개 실패 0(줄이다가 사냥터 깊은 곳의 보초 궁병이 턱에 끼는 것을 검사가 잡아 고쳤다) · 바닥 그림 48장 다시 올림 · Play(손님): 줄인 36장이 모두 새 폭으로 뜨고 몬스터의 수가 그대로 · 가운데 문 둘(식은 광산 → 광차 길 · 성벽 아래 → 성문 앞)과 끝 문 둘을 ↑로 지남 · 달그림자 사냥터 14마리 · 세 갈래 길로 가는 문. 콘솔 오류 없음. 미리보기 40장을 한 장씩 봤다.
              앞으로: 새 가로 사냥터는 56~72칸으로 짓는다.
          ✔ S17 숨은 방(용사의 흔적) 여섯 곳 — 2026-10-10. 지역 표의 숨은 맵 여섯을 지었다: 옛 은신처 r1bh(굽잇길) · 반달네 옛집 r2ah(빛나는 연못) · 금서고 r2bh(기사단 초소) · 쫓겨난 아이의 방 r3bh(불씨 길) · 도끼가 꽂힌 언덕 r4ah(불탄 거리) · 쐐기지기의 방 r4dh(봉인의 회랑).
              방: 한 화면 남짓(32칸 · 도끼 언덕만 40칸), 몬스터 없음(쉬는 곳), 이야기 소품 하나씩 — Codex 한 장(`looks/raw_traces_kit.png`)에서 여섯을 잘라 쓴다(땅에 꽂힌 창 · 수정에 덮인 집 · 사슬로 잠근 책장 · 아이의 잠자리 · 돌무지의 도끼 · 침상과 연장걸이). 옛 은신처만 새 모습 hideout(바위 틈), 나머지는 그 지역의 모습 그대로.
              숨은 문: 사냥터의 높이 뜬 발판 위에 낸, 그림이 없는 문 — 가까이 가야 이름표(↑ 바위 틈으로 …)가 뜬다. 발판 위의 작은 표시(빛나는 풀 · 빛 버섯 · 파수꾼의 등)가 실마리. 높은 발판에 두면 「문 곁의 빈 터」 규칙이 층이 세 줄 넘게 다른 몬스터를 보지 않아 사냥터 한가운데에도 낼 수 있다.
              이름표의 높이: 넷째 줄의 문 24 · 다섯째 줄 30 · 그 아래 40(화면의 맨 위가 맵의 18px쯤 — 40을 주면 화면 밖으로 나간다. Play에서 보고 고쳤다).
              새 검사 `tools/test/tests/25_lune_reach.luau`: 장면 80개의 문 153개가 시작 자리에서, 그리고 다른 문으로 들어온 자리에서 걷기 · 뛰기 · 하단 점프만으로 닿는지 게임의 움직임 식으로 따진다(616개 실패 0 — 「네 줄 위에는 닿지 않는다」 같은 제 따지는 법의 확인 포함). 숨은 문을 순간이동으로만 서 봤기 때문에 만들었다. 앞으로 맵을 지을 때마다 돈다.
              확인: 규칙 검사 통과 · 게임 검사 136,310개 실패 0 · 그림 올림(새 바닥 6장 + 소품 판) · Play(손님): 숨은 문 여섯에서 ↑ → 여섯 방 모두 들어가짐 · 옛 은신처에서 굽잇길로 돌아옴 · 이름표가 보임(굽잇길 · 빛나는 연못 · 봉인의 회랑에서 봤다) · 콘솔 오류 없음.
              안 한 것: 소품을 읽는 장면 · 대사(용사의 흔적 퀘스트를 만들 때 붙인다). 소품의 생김새는 제가 채웠다(지역 표의 한 줄에서).
          ✔ S18 옛 주인의 굴 여덟 곳(자리만) — 2026-10-10. 멧돼지 굴 r1bl(굽잇길) · 뿌리 굴 r2bl(물든 숲) · 성당 뒤 못 r2cl(성당 앞뜰) · 버려진 제단 r3al(식은 광산) · 용암 못 r3cl(식어 가는 불길) · 옛 수로 r4bl(성벽 아래) · 멈춘 종탑 r4cl(기사의 회랑) · 용의 둥지 r4dl(무기고).
              굴: 두 화면(48칸)의 싸움터 + 뜬 발판 둘 + 가운데 소품(옛 주인이 사는 자리 — 쓰러진 거목 · 뿌리에 싸인 수정 심장 · 볕바위와 떡 접시 · 식은 돌 화로 · 알둥지 · 쌍둥이 수문 · 금 간 종과 멈춘 톱니바퀴 · 뼈와 창으로 엮은 둥지). `lair: true`(쉬는 곳이 아니다).
              **옛 주인(보스) 여덟은 아직 없다** — 그림은 사용자의 작업 순서(Codex 컨셉 → 1:1로 옮김 → 서 있는 그림 → 사용자가 고른 동작)로, 싸우는 방식은 뒤로 미룬 대로. 지금은 들어가서 볼 수만 있다. 성당 뒤 못의 나룻배(지름길)도 보스를 꺾은 뒤의 것이라 아직 문이 아니다.
              그림: Codex 두 장(`looks/raw_lairsa_kit.png` · `raw_lairsb_kit.png` — 아홉 조각, 굴 입구 denmouth 포함). 둘째 장의 첫 그림은 검은 외곽선이 둘러져 `_v1`로 남기고, 첫 장을 견본으로 붙여 다시 그리게 했다.
              들어가는 문: 그림이 있는 문(굴 입구 · 권양기 · 쇠 울타리 문 · 성벽의 문 · 계단 문 · 뒷문). 여섯은 몬스터의 줄에서 세 줄 넘게 떨어진 높은 발판 위(여우 · 궁병처럼 멀리 보는 몬스터의 맵에서는 땅에 문을 낼 빈 터가 없다 — 양쪽 7~10칸), 둘(성당 뒤 못 · 용암 못)은 몬스터가 없는 끝자리. 문 곁을 비우느라 고친 것: 물든 숲의 높은 바위에 있던 여우를 땅으로 · 식은 광산의 코볼트 둘 · 식어 가는 불길의 굴뚝 도깨비 하나 · 무기고의 검병 둘의 구간을 줄임(마릿수는 그대로).
              굽잇길은 굴 입구 그림을 쓰느라 소품 장을 바위 산길의 둘째 장(hideout — 이름을 「바위 산길(둘째 소품 장)」으로 바꿈)으로 옮겼다. 땅 · 발판 · 뒷배경은 그대로다.
              확인: 규칙 검사 통과(맵 85장 · 문 169개) · 게임 검사 136,704개 실패 0(문에 닿는지 따지는 검사 포함) · 그림 14장 올림 · Play(손님): 여덟 문에서 ↑ → 여덟 굴 모두 들어가짐 · 이름표가 보임 · 용의 둥지에서 무기고로 돌아옴 · 콘솔 오류 없음.
          ✔ S19 보스 방 넷 + 봉인의 문 앞(자리만) — 2026-10-10. 망루 꼭대기 r1c4(망루 3층 맨 위의 문) · 성당 제단 앞 r2c4(종탑 맨 위의 문) · 분화구 r3d4(분화구 가장자리의 끝) · 성문 r4d4(봉인의 회랑의 끝 — 임시로 곧장) · 이야기 맵 봉인의 문 앞 r4es(성문의 오른쪽 문).
              방: 두 화면(48칸) 평지 + 발판 둘(`boss: true` — 쉬는 곳이 아니다). 봉인의 문 앞은 32칸(쉬는 곳). **지역 보스 넷은 아직 없다.** 지름길 셋(도르래 줄 → 마을 · 옛 승강기 → 포구 · 성문 → 아랫마을)은 보스를 꺾은 뒤의 것이라 소품으로만 서 있다.
              새 모습 towertop(망루 꼭대기): 망루 안의 돌바닥 · 나무 발판 + 바위 산길의 하늘(산줄기를 아래로 내려 내려다보는 느낌). 1지역의 둘째 소품 장(r1x)에 망루의 소품(발판 · 화로 · 깃발 · 창걸이 · 궤짝 · 말뚝 울타리)을 옮겨 실었다.
              그림: Codex 두 장 — `raw_bossrooms_kit.png`(도르래 pulley · 제단과 책 더미 altarpyre) · `raw_greatgate_kit.png`(큰 성문 greatgate 154x161). 첫 묶음의 성문은 키 72점이라 성벽 앞에서 작은 모형처럼 보여, 화면 높이를 채우는 크기로 문과 문틀만 다시 그렸다(8점 내려 놓아 맨 위의 초승달이 화면에 든다).
              문 곁을 비우느라 고친 것: 분화구 가장자리의 맨 위 단 전갈을 아래로 · 봉인의 회랑 끝의 허물 하나를 뜬 돌판 위로(마릿수는 그대로). 분화구 가장자리의 옛 승강기는 분화구 안으로 옮겼다.
              확인: 규칙 검사 통과(맵 90장) · 게임 검사 137,035개 실패 0 · 그림 8장 올림 · Play(손님): 망루 3층 → 망루 꼭대기 · 종탑 → 성당 제단 앞 · 분화구 가장자리 → 분화구 · 봉인의 회랑 → 성문 → 봉인의 문 앞 모두 ↑로 들어가짐 · 성문 앞까지 걸어가 봄 · 콘솔 오류 없음.
              안 지은 것: 사당 지하 r1cs(마을 사당의 실내와 이어야 한다 — 마을 도구가 다르다) · 던전 둘(불씨 도둑의 소굴 r3b3 · 깨진 쐐기의 방 r4d3 — 몬스터가 없다) · 화약 창고 r3b4 · 틈새 회랑 r4e1 · 바다의 남은 맵.
          ✔ S20 옛 주인 여덟의 그림(기본 + 대기 두 장 + 동작 설명) — 2026-10-10. 사용자의 작업 순서대로: 제가 생각함(생김새는 world.js의 옛 주인 표 그대로) → Codex 시안 → 시안의 도트를 1:1로 옮김 → 기본 그림 + 대기 두 장 → **어느 동작을 만드실지 여쭘(답을 기다린다)**.
              크기(점): 검은엄니 87x66 · 천년 수정목 60x84 · 달자라 86x50 · 화로지기 64x58 · 불도롱뇽 어미 118x57 · 쌍둥이 수문장 59x99 · 종지기 67x83 · 묵은 용 138x84. 주인공(키 20점쯤)의 2.5~4배.
              사용자의 폴더: `C:\YJS\Roblox\Assets\character\luna\bosses\<id>\` — `<id>.png`(기본 · 검정 바탕) · `<id>_bg.png` · `<id>_idle.png`(대기 두 장) · `prompts.txt`(대기 · 이동 · 기본 공격의 설명). id = blacktusk · crystaltree · moonturtle · hearthkeeper · firenewt · sluicekeeper · bellringer · olddragon. 쌍둥이 수문장은 하나만 그렸다(둘이 똑같다).
              새 설계 파일 `js/lune/design/bosses.js`(시안 목록 · 동작 설명 · 정해지지 않은 것) · 새 도구 `tools/build_lune_bosses.mjs`(기본 그림 · 대기 · 덩치 견주기 `bosses_lineup.png`) · `tools/build_lune_creatures.mjs --bosses`(옮기기 — 졸개의 것은 그대로다: creature_rows.json이 한 글자도 바뀌지 않는 것을 확인) · 규칙 검사에 보스의 그림 계획을 넣었다.
              겪은 일: ① 처음에 옛 주인 표를 읽지 않고 다섯을 다르게 청했다가(달자라 · 화로지기 · 쌍둥이 수문장 · 종지기 · 묵은 용) 멈추고 표대로 다시 청했다. ② Codex는 8화소로 청한 도트를 10화소쯤으로 그렸다 — 8로 못박아 옮기니 줄이 더 들어가 화로지기가 일그러져서, 보스마다 도트 크기를 재서(가로 · 세로를 함께) 옮기게 고쳤다. ③ 셋째 · 넷째 장은 6.6~6.9화소로 잘게 그려져, 줄이지 않고 한 마리씩 굵은 도트로 다시 그리게 했다(raw_<id>_creatures.png).
              확인: 여덟 모두 시안과 옮긴 것을 나란히 놓고 봤다(`compare_*.png`) · 규칙 검사 통과. **게임에는 아직 없다**(그림만 — 동작 · 싸우는 방식 · 수치가 없다).
          ✔ S21 가로 사냥터를 한 번 더 줄임 — 2026-10-10. 사용자: "사냥터 길이 더 줄이고 몬스터 수는 유지합니다. 허가받지말고 쭉 계속 작업하세요"
              줄인 것: 가로 사냥터 40장 — 56 → 44칸 · 64 → 48칸(화면 두 장) · 72 → 56칸 · 76 → 60칸 · 달그림자 사냥터 76 → 62칸(처음의 96칸에서 보면 35~40% 줄었다). **몬스터 수는 그대로**(maps.js의 39장에 370마리 · 달그림자 사냥터 15마리 — 창병이 문 곁에서 빠지지 않아 게임에서는 14 → 15).
              규칙을 바꿨다[제가 정함]: 맵이 화면 두 장이 되면 「문 곁을 몬스터가 보는 거리 + 한 칸만큼 비운다」(궁병은 문마다 양쪽 10칸)로는 몬스터를 둘 자리가 없다. → ① 문 곁의 빈 터는 어느 몬스터든 3.5칸(maps.js `gateNeed` — 보는 거리를 40점까지만 친다) ② 맵에 들어선 뒤 2.5초는 피해를 받지 않는다(combat.js `arrive` · 게임 `Hero.arrive` — world.luau의 place가 부른다 · 시험 탭도 같다).
              방법: 평평한 단에서 고르게 덜어내고(scratch의 suggest_cuts2.mjs · cuts2.mjs · cut_maps2.mjs), 몬스터는 단(평평한 땅 · 뜬 발판 · 다리의 널)마다 다시 세웠다 — 제 단이 문 곁이거나 꽉 찼으면 가장 가까운 다른 단으로(23마리가 단을 옮겼다). 덜어낸 칸에 있던 소품은 뺐다. 숨은 문 · 굴 입구 · 가운데 문은 그대로다.
              확인: 규칙 검사 통과 · 게임 검사 138,427개 실패 0(문에 닿는지 · 몬스터가 벽에 끼지 않는지 포함) · 미리보기 40장을 한 장씩 봄 · 바닥 그림 37장 올림 · Play(손님): 열 장이 새 폭으로 뜨고 몬스터 수 그대로 · 물든 숲 → 끊긴 순찰로 · 달그림자 사냥터 → 세 갈래 길을 ↑로 지남 · 봉인의 회랑에서 허물 곁에 선 뒤 첫 피해가 4.9초 뒤 · 콘솔 오류 없음.
              고친 검사: 문 곁의 거리(12) · 쓰러뜨리는 검사에 보호 걷기(13) · 연막 순보의 자리(21 — 옛 자리가 턱 속이 됐다).
              안 한 것: 오르는 맵(망루 · 종탑 · 망대 · 갈라진 비탈 · 내려가는 계단)과 쉼터 · 마을 · 굴 · 보스 방은 그대로다.
          ✔ S22 바닷속을 게임으로 옮김 — 2026-10-10(사용자: "허가받지말고 쭉 계속 작업하세요" — 시험 탭에만 두고 느낌을 여쭙던 것을 게임에도 넣었다. 숫자는 그대로 제 제안이다).
              옮긴 것: 맵 넷(얕은 여울 sea3 · 공기 방울 쉼터 seaf · 산호밭 sea4 · 가라앉은 항구 sea7 — 갯바위 해변의 바닷가 표석에서 걸어 들어간다) · 몬스터 셋(등불 해파리 · 굴 곰치 · 닻 망령) = 게임의 맵 97장 · 몬스터 43종.
              물속 움직임: `scene.sea`인 맵에서 걷기 0.85배 · 뛰는 힘 0.74배 · 떨어지는 힘 0.34배 · 가라앉는 빠르기 90점/초까지. 숫자는 combat.js의 `sea` 한 곳에 있고 시험 탭(luneTab.js)과 게임(sim/physics.luau)이 같이 읽는다. 서버는 자리의 거리만 따지므로 따로 고칠 것이 없었다.
              앞으로 뻗는 마법(front — 해파리의 번개 줄기): 몬스터의 앞에 붙어 뜨고(쓴 몬스터를 따라간다 · 쓰러지면 사라진다), 앞에 있는 사람만 맞는다. room.luau의 마법 · MobCast에 dir · 화면의 Effects.addMobCast(뒤집어 그린다).
              확인: 규칙 검사 통과 · 게임 검사 139,591개 실패 0(새 검사: 해파리의 번개가 앞에서 맞고 뒤에서는 안 맞는다 · 바닷속에서 더 높이 · 오래 · 멀리 뜬다 · 걷기 85%) · 그림 9장 올림 · Play(손님 Lv.60): 갯바위 해변 → ↑ → 얕은 여울 · 네 맵이 모두 뜸 · 뛰기 높이 90점 / 2.07초(땅은 52점 / 0.77초) · 해파리 곁에서 9초 동안 번개 두 번(dir · 자리 맞음)에 두 번 맞음 · 콘솔 오류 없음.
              안 한 것: 스마트폰에서의 느낌 · 기술의 움직임(공중에서 쓰는 기술은 땅의 중력 그대로다 — caster.luau) · 바닷속의 남은 맵(해초 숲 · 난파선 무덤 · 가라앉은 등대 — 새 몬스터가 필요하다).
          ✔ S23 남은 사냥터 여섯 + 새 몬스터 여섯 — 2026-10-10(사용자: "허가받지말고 쭉 계속 작업하세요").
              새 몬스터(묶음 last · 한 장에 여섯): 불씨 도둑 thief · 빛 먹는 것 gloom · 봉인의 그림자 pool(셋은 지역 표의 이름) · 해초 덩굴 tangle · 가시 성게 urchin · 입 벌린 궤짝 mimic(셋은 제가 지었다). 덩굴과 궤짝은 걷지 않는다(제자리).
              새 맵: 불씨 도둑의 소굴 r3b3(56칸 · 도둑 10) · 화약 창고 r3b4(44칸 · 폭탄병 9) · 깨진 쐐기의 방 r4d3(56칸 · 빛 먹는 것 9) · 틈새 회랑 r4e1(48칸 · 그림자 9) · 해초 숲 sea5(48칸 · 덩굴 5 + 성게 5) · 난파선 무덤 sea6(56칸 · 궤짝 9) = 게임의 맵 103장 · 새 몬스터 49종.
              길: 불씨 길 r3b2의 뜬 발판 위 굴 입구 → 소굴 → 화약 창고(막다른 길) · 봉인의 회랑 r4d2 → 깨진 쐐기의 방 → 봉인의 문 앞 r4d4 → 이야기 방 r4es의 봉인 문 → 틈새 회랑 · 공기 방울 쉼터 seaf의 동쪽 → 해초 숲 → 난파선 무덤 ← 산호밭 sea4 · 난파선 무덤 → 가라앉은 항구 sea7(산호밭 → 항구로 바로 가던 길은 난파선 무덤을 지나게 바꿨다).
              겪은 일: ① **첫 시안에 해마 · 먹물 문어 · 키 크고 마른 그림자가 있었다 — 셋 다 사용자가 2026-10-09에 지우신 것**(monsterFeedback.js). 그 장은 `raw_last_v1_creatures.png`로 남기고, 낮게 깔린 그림자 · 해초 덩굴 · 가시 성게로 바꿔 다시 청했다. **새 몬스터를 생각하기 전에 지운 목록을 먼저 읽는다.** ② 시안이 7.8화소로 잘게 그려져 굵은 도트로 다시 그리게 했다(`raw_last2_creatures.png`). ③ 성게와 궤짝의 눈이 한 점씩 어긋나 `MONSTER_ART.fix`로 고쳤다 — made 도구가 fix를 안 읽던 것도 같이 고쳤다. ④ 동작 그림은 `build_lune_monster_game.mjs`를 먼저 돌려야 `build_lune_monster_chars.mjs`가 찾는다.
              동작: 여섯 모두 제가 손으로 지었다(대기 · 이동 · 공격 — `tools/lune_monster_hand.mjs`). 사용자가 직접 만드실 수 있게 기본 그림 · 대기 두 장 · 동작 설명은 `C:\YJS\Roblox\Assets\character\luna\monsters\<id>\`에 두었다.
              확인: 시안과 옮긴 것을 나란히 봄(`compare_last.png`) · 동작 장을 한 마리씩 봄(`made/view_<id>.png`) · 규칙 검사 통과 · 게임 검사 141,808개 실패 0 · 올릴 그림 0장 남음 · Play(손님 Lv.150): 여섯 맵이 모두 뜨고 여섯 몬스터가 모두 때림(도둑 3 · 폭탄병 1 · 빛 먹는 것 4 · 그림자 2 · 덩굴과 성게 2 · 궤짝 2번) · 문 여섯 곳을 ↑로 지남(불씨 길 → 소굴 · 이야기 방 → 틈새 회랑 · 쉼터 → 해초 숲 → 난파선 무덤 · 봉인의 회랑 → 깨진 쐐기의 방 → 봉인의 문 앞) · 콘솔 오류 없음.
              약한 곳: 봉인의 그림자는 어두운 봉인 바닥 위에서 몸이 잘 안 보인다(분홍 눈과 피어오르는 연기로 알아본다) — 「바닥의 그림자」라는 뜻에는 맞지만 놓치기 쉽다. 사용자께 여쭘.
              안 한 것: 수치는 모두 제 제안 · 스마트폰 확인 · 가라앉은 등대(보스 방) · 사당 지하.
          ✔ S24 가라앉은 등대 sea8(바다의 보스 방 — 자리만) — 2026-10-10. 게임의 맵 104장.
              그림: 등대는 따로 한 장(`prompt_lighthouse_kit.txt` → `raw_lighthouse_kit.png` → 소품 이름 `sunklight` 121x162점 · 바다 소품 장). 화면 높이를 거의 채운다(지붕 끝 3점쯤이 화면 위로 나간다 — 뛰면 보인다).
              맵: 48칸 · 양 끝이 한 단 높은 평지 + 뜬 갑판 조각 둘 · 몬스터 없음(`boss: true`). 가라앉은 항구 sea7의 오른쪽 선창 위에 문을 세우고, 선창 위에 있던 닻 망령 하나를 아래 땅으로 내렸다(문 곁 3.5칸 — 몬스터 수 9는 그대로).
              확인: 규칙 검사 통과 · 게임 검사 실패 0 · 그림 2장 올림 · Play(손님 Lv.75): 가라앉은 항구의 문에서 ↑ → 등대 맵 → 걸어서 등대 앞까지 → 문에서 ↑ → 항구의 선창 위로 돌아옴 · 콘솔 오류 없음.
              **보스는 없다.** 대륙 계획(10-08 승인)의 보스는 「등대를 감고 사는 큰 문어」인데 10-09에 「먹물 문어」를 지우셨다 → 보스를 문어로 둘지 여쭘(devplan). 같은 까닭으로 필드 보스 「뿔 큰 수정 사슴」(수정뿔사슴 삭제) · 「재투성이 왕도마뱀」(불꼬리 도마뱀 삭제)도 여쭌다 — **이 셋은 답이 올 때까지 그리지 않는다.**
              알아낸 것: 바닷속에서 기술로 뛰어오르는 움직임은 이미 물속 규칙을 따른다(몸은 `sim/physics.luau`가 움직인다 — caster.luau의 중력은 수치를 잴 때만 쓴다). 따로 고칠 것이 없고, 느낌만 사용자가 보면 된다.
          ✔ S25 지역 보스 넷의 그림(기본 + 대기 두 장 + 동작 설명) — 2026-10-10. 옛 주인과 같은 순서 · 같은 도구(`bosses.js`에 `REGION` · `BOSS_LIST`의 kind가 lair / region).
              생김새는 제가 잡았다(설계 표에는 이름 · 레벨 · 이야기만 있다): 정찰대장 = 팩의 병사를 키운 꼴 + 망토 · 큰 굽은 칼 · 분홍 도장의 두루마리(영주의 명령서) / 타락한 부단장 = 투구 쓴 기사 + 어깨와 등의 검은 수정 · 분홍 횃불 · 열쇠 고리(스무 해 금서고의 열쇠지기) / 용암 거인 = 분홍 금이 간 바위 거인 / 공성 거인 = 팩의 병사를 키운 꼴 + 파성추 · 화살 꽂힌 방패 · 분홍 깃발.
              크기(점): 정찰대장 120x86 · 타락한 부단장 116x84 · 용암 거인 114x92 · 공성 거인 132x105. **청한 것(62~104 x 62~88)보다 크게 나왔다** — Codex가 한 점 10화소는 지켰는데 그림을 화면 가득 그렸다. 줄이지 않았다(사용자의 규칙: 시안의 도트를 그대로). 옛 주인의 큰 것(쌍둥이 수문장 99 · 묵은 용 138x84)과 같은 급이다. 작게 바라시면 굵은 도트로 다시 청한다(묵은 용 때의 방법).
              고친 것: 용암 거인의 얼굴 — 시안이 웃는 얼굴로 나왔고 옮기면서 점이 흩어졌다 → 눈구멍 둘 + 삐죽빼죽한 입 금으로 다시 찍었다(`BOSS_ART.fix.lavagiant`). 부단장의 눈은 옮긴 그대로(투구 틈의 흰 줄 · 분홍 줄).
              사용자의 폴더: `C:\YJS\Roblox\Assets\character\luna\bosses\` 아래 scoutcaptain · fallenknight · lavagiant · siegegiant(기본 그림 · 밤하늘 바탕 · 대기 두 장 · prompts.txt).
              확인: 넷 모두 시안과 옮긴 것을 나란히 봄(`compare_<id>.png`) · 한 줄에 세워 봄(`bosses_lineup.png` — 열둘) · 규칙 검사 통과(지역 보스 넷이 빠짐없이 · 방이 boss인지). **게임에는 없다**(그림만).
              약한 곳: 부단장은 다른 보스보다 그림이 잘다(갑옷에 음영 세 단) — 그림체가 튀면 다시 청한다.
          ✔ S26 2지역(수정 숲)의 퀘스트 — 메인 여섯 · 부탁 다섯 — 2026-10-10. 새 그림 없이 지금 있는 주민으로: 견습 기사 하늬 · 뱃사공 노을 · 반달.
              자료: `questplay.js`를 지역마다 짓게 고쳤다(`PLAY`(1지역) · `PLAY2` · `PLAYS` · `QUEST_REGIONS` · `HUB` — 설계의 map 'town' = 그 지역의 마을). 이름표 = 지역 + m / s + 차례(r2m1 … · r2s1 …).
              메인: 반달 나루(노을 → 하늬 · 말 걸기) → 숲의 마물(수정싹 그루터기 12) → 사라진 순찰대(순찰대 표식 8 · 이끼 두꺼비 50%) → 검은 수정(수정 봉오리 15) → 기사단 초소(수정 고슴도치 15) → 본당의 벽화(하늬에게 받고 다시 말 걸기). 그 뒤(그림자 능선 = 보스)는 못 한다.
              부탁: 새는 나룻배(노을 · 끈끈한 수정 진 8) · 연못가의 빛 이끼(하늬 · 빛 이끼 10 — 옛 이름 「연못가의 뿔 조각」) · 초소에 남은 이름표(하늬 · 기사의 이름표 10) · 능선 너머 장삿길(반달 · 검은 결정 30) · 삼백 년 치 장부(하늬 · 장부의 낱장 8 · 40%).
              제가 정한 것[판정 대기]: ① 하늬를 반달 나루 · 연못가 갈림길 · 기사단 본당 세 곳에 세움(어느 하늬에게나 받고 돌려준다) ② 기사단 본당에 반달을 세움 ③ **2지역의 첫 메인은 Lv.30이면 1지역의 메인을 다 끝내지 않아도 받는다**(1지역의 끝 셋이 보스가 없어 막혀 있다 — 보스가 생기면 잇는다) ④ 줄거리의 몬스터를 지금 맵에 있는 것으로 바꿔 적음(world.js · quests.js의 글도): 수정 벌레 → 수정싹 그루터기 · 수정 사슴의 뿔 → 이끼 두꺼비의 빛 이끼 · 물든 견습 기사 → 수정 고슴도치 / 결정 골렘 새끼 · 갑옷 저격병 → 검은 결정 ⑤ 보상의 「창고 칸 · 흔적의 빛 · 칭호 · 달가루」는 기능이 없어 달돈(또는 물약 10) ⑥ 마릿수 · 확률 · 대사.
              그림: 모으는 물건 다섯(`raw_etc_2.png` — 순찰대 표식 etc_badge · 끈끈한 수정 진 etc_resin · 빛 이끼 etc_moss · 기사의 이름표 etc_tag · 장부의 낱장 etc_page). 차례: `etc_sheets.json`에 적음 → `ICON_MORE=etc_sheets.json,weapon_sheets.json node tools/build_lune_icons.mjs` → **`node tools/build_lune_ui.mjs`(부품 한 장에 싣는다 — 빼먹으면 게임 검사가 "그림이 없다"로 막는다)** → 내보내기 → `ui_kit.png` 올림.
              검사: 규칙 검사를 지역마다 따지게 고침(수 · 메인이 앞에서부터 이어지는가 · 이름표) · 게임 검사 17에 2지역의 첫 메인(레벨만으로 열림 · 노을 → 하늬 · 보스 메인은 잠김)을 더함 → 142,357개 실패 0.
              Play(손님 Lv.60): 반달 나루에서 노을 「!」 → 받기 → 둑 위의 하늬 「?」 → 돌려줌(경험치) → 「숲의 마물」 받기 → 나루 뒷길에서 그루터기 셋을 잡아 알리미 「수정싹 그루터기 3/12」 · 끈끈한 수정 진이 그림으로 떨어지고 Z로 주워 1개 · 물건 여덟의 그림을 바닥에서 봄 · 기사단 본당의 반달 「!」 · 콘솔 오류 없음. 받기 · 돌려주기는 화면의 단추가 아니라 같은 신호(R.Quest)를 직접 보내서 했다 — **대화 상자로 받고 돌려주는 것 · 열한 개를 끝까지 하는 것은 하지 않았다.**
          ✔ S27 3지역(땅속 화롯골)의 퀘스트 — 메인 여덟 · 부탁 여섯 + 새 주민 넷 — 2026-10-10.
              새 주민(넷째 묶음 `raw_people4.png`): 소금 장수 바우 `saltman` · 광부의 손자 한돌 `minerkid` · 불의 아이 아리 `firechild` · 족장 아궁 할멈 `granny`. 이름 바우 · 한돌 · 아리와 **불의 종족의 생김새(머리 위의 분홍 불꽃)**는 제가 정했다[판정 대기].
              그림은 세 번 청했다: 첫 장은 잘고 음영이 들어감(`raw_people4_v1_fine.png` — 43점 키) → 둘째 장은 굵고 납작했지만 눈이 하나씩(`_v2_oneeye`) → 셋째 장(두 눈 · 한 점 13.4화소)을 썼다. 옮기면서 셋의 눈이 두 줄에 걸쳐 한 점씩으로 고침(`build_lune_people.mjs`의 묶음 `fix` — 새로 넣은 기능).
              자리: 등불 포구에 샛별(굴 입구 옆) · 지상 상인의 야영지에 바우 · 한돌 · 아리 · 화롯골 문 앞에 아리 · 아궁 할멈 · 벽화의 방에 아궁 할멈.
              메인: 땅속으로(샛별 · 굴쥐 12) → 닫힌 문(샛별 → 바우 · 말 걸기) → 광산의 흔적(바우 · 그을린 수레 못 8) → 불씨 길(바우 → 아리 · 굴 지렁이 15) → 불씨 도둑의 소굴(아리 → 할멈 · 불씨 도둑 20) → 큰 화로(할멈 · 재 회오리 18) → 벽화의 방(할멈 · 말 걸기) → 터지는 산(할멈 · 폭탄병 12). 아홉째 「용암 거인」은 보스.
              부탁: 야영지의 횃불(샛별 · 굴쥐 수염 10) · 불 꺼진 등잔(한돌 · 등잔 조각 10) · 상인들의 수레(바우 · 폭주 광차 20) · 빈 불씨 단지(아리 · 8) · 되찾은 불씨(아리 · 불씨 단지 6) · 식은 알껍데기(아리 · 알껍데기 조각 8).
              제가 정한 것[판정 대기]: 「닫힌 문」을 화롯골이 아니라 야영지에서(HUB.r3 = r3ah) · 할멈을 처음부터 닫힌 문 앞에 · 소굴은 두목 없이 도둑 스물 · 「옛 주인이 열린다」는 부탁 둘은 지금은 달돈 · 줄거리의 몬스터를 지금 맵의 것으로(굴 박쥐 → 굴쥐 · 돌 두더지 → 곡괭이 코볼트 · 폭탄병(광차 길) → 폭주 광차 · 불 도마뱀 → 굴뚝 도깨비 · 재 정령 → 재 회오리).
              그림: 모으는 물건 여섯(`raw_etc_3.png` — etc_nail · etc_whisker · etc_lamp · etc_jar · etc_ember · etc_shell).
              확인: 규칙 검사 통과(3지역 19개 가운데 14개) · 게임 검사 142,951개 실패 0 · 그림 2장 올림(villagers.png · ui_kit.png) · Play(손님 Lv.95): 등불 포구의 샛별에게서 「땅속으로」 받음 → 굴 입구에서 굴쥐 하나를 잡아 「굴쥐 1/12」 · 야영지의 바우 「!」 · 반달 · 화롯골 문 앞의 아리 「!」와 할멈 · 콘솔 오류 없음. **열네 개를 끝까지 해 보지는 않았다 · 대화 상자로 받지 않고 신호를 직접 보냈다.**
              알아낸 흠: 여러 맵에 서는 주민(샛별 · 반달 · 하늬 · 아리 · 할멈)은 **다른 지역의 부탁도 그 자리에서 준다** — 등불 포구의 샛별이 1지역의 「등불 심지」(Lv.2)를 주려고 「!」를 띄운다. 퀘스트를 그 지역의 맵에 선 주민만 주게 하려면 게임의 퀘스트 자료에 지역을 싣고 주민의 맵과 견줘야 한다(아직 안 함).
          ✔ S28 주민은 제 지역의 퀘스트만 준다 — 2026-10-10(S27에서 찾은 흠을 고침).
              내보내기: 장면마다 `region`(마을 · 실내 · 달그림자 사냥터 = r1 · r1~r4 맵 = 그 지역 · 등불 포구 = r3 · 은달 항구와 바다 = false) · 퀘스트마다 `region`.
              게임: `Quests.atNpc(book, level, npc, region)` · `Quests.mark(…, region)` — 받을 것과 「!」는 지역이 같을 때만(돌려주기는 어느 지역의 그 주민에게나) · 서버의 받기도 같은 것을 따진다("여기서는 받을 수 없는 퀘스트다") · 화면(boot.luau)은 지금 장면의 region을 넘긴다.
              확인: 게임 검사 143,122개 실패 0(새 검사: 1지역의 샛별은 등불 심지를 · 3지역의 샛별은 땅속으로를 준다 · 서로 바꿔서는 주지 않는다 · 돌려주기는 어디서든) · Play(손님 Lv.95): 등불 포구에서 「등불 심지」 받기가 거절됨 · 「야영지의 횃불」은 받음 · 연못가 갈림길(2지역)에서 하늬는 「!」, 샛별은 표시 없음 · 콘솔 오류 없음.
          ✔ S29 4지역(만월성)의 퀘스트 — 메인 일곱 · 부탁 여덟 + 새 주민 넷 + 3지역의 「화약통 치우기」 — 2026-10-10.
              새 주민(다섯째 묶음 `raw_people5.png` — 한 번에 굵게 나왔다): 석공 도담 `mason` · 시계공의 딸 새봄 `clockgirl` · 산지기 솔뫼 `ranger` · 화롯골 대장장이 숯돌 `firesmith`. 이름은 제가 지었다. 옮기면서 눈 둘(새봄 · 솔뫼)과 숯돌의 불꽃 속을 고쳤다(묶음의 fix).
              자리: 외성 밖 야영지(r4a1 왼쪽 끝)에 샛별 · 하늬 · 아궁 할멈 · 반달 / 성벽 속 통로 r4bh에 무쇠뿔 · 하늬 · 도담 / 옛 근위대 숙소 r4ch에 새봄 · 그믐 사제 · 하늬 · 솔뫼 / 화롯골 문 앞 r3t에 숯돌. 무쇠뿔 앞에서는 강화 창, 사제 앞에서는 전직 창이 그대로 열린다(마을 밖에서도).
              메인: 외성 밖의 사람들(샛별 → 할멈 · 말 걸기) → 무너진 외성(정예 검병 12) → 아랫마을 탈환(부서진 기사상 10) → 성벽을 넘어라(폭탄병 15) → 내성(정예 창병 15) → 봉인의 회랑(감시하는 눈 20) → 전날 밤(하늬 → 그믐 사제 · 말 걸기). 그 뒤(공성 거인 = 보스 · 봉인의 문)는 못 한다.
              부탁: 야영지의 울타리(샛별) · 되찾은 곳간(반달) · 수문 열쇠(도담) · 저항군 대장간(무쇠뿔) · 멈춘 태엽(새봄) · 회랑의 방패(하늬) · 용 비늘 피리(솔뫼) · 깨진 쐐기 조각(그믐 사제). 3지역: 화약통 치우기(숯돌).
              제가 정한 것[판정 대기]: **보스가 없어 대신한 것 셋** — 3지역 「불씨 도둑의 소굴」(두목 → 도둑 20) · 4지역 「아랫마을 탈환」(점령군 대장 → 부서진 기사상 10) · 「봉인의 회랑」(창기병 대장 → 감시하는 눈 20). world.js의 글에서도 두목 · 대장을 빼고 지금 하는 일로 적었다(보스가 생기면 되돌린다). / 「전날 밤」은 마을 대신 옛 근위대 숙소(HUB.r4 = r4ch) / 「옛 주인이 열린다」는 부탁 셋은 달돈 / 줄거리의 근위 창병 · 근위 검병 · 공성병은 그 맵의 정예 창병 · 정예 검병 · 떠도는 책 · 부서진 기사상으로.
              그림: 모으는 물건 아홉(`raw_etc_4.png` 3 x 3 — etc_shaft · etc_crate · etc_keypiece · etc_ironplate · etc_gear · etc_shield · etc_scale · etc_wedge · etc_keg).
              확인: 규칙 검사 통과(r3 15 · r4 15) · 게임 검사 143,855개 실패 0 · 그림 2장 올림 · Play(손님 Lv.150): 야영지에서 「외성 밖의 사람들」을 샛별에게 받아 할멈에게 돌려줌(완료 알림) → 「무너진 외성」 받음(알리미 「정예 검병 0/12」) · 야영지에서 병사에게 맞지 않음 · 옛 근위대 숙소에 넷이 서 있고 표시가 뜸 · 콘솔 오류 없음. **열다섯 개를 끝까지 해 보지 않았다 · 대화 상자로 받지 않았다.**
              약한 곳: 야영지의 넷이 6칸 안에 모여 있어 이름표가 겹친다(주인공의 이름표에 가려진다).
          ★ 사용자 2026-10-10(S23~S29의 보고를 보고): "보스 크기 좋습니다. 대형에 무섭고 보스전느낌나고" → **보스의 덩치는 이대로(주인공의 4~5배). 줄이거나 작게 다시 그리지 않는다.**
              같은 날 두 가지를 되물으셨다: "찾기, 심부름은 무슨말인지?" · "사당 지하는 마을그림을 건드리게된다는게 무슨말인지" — 제가 지어낸 낱말과 뭉뚱그린 말이었다. 풀어서 답했다:
              ① 지금 게임은 잡기 · 물건 줍기 · 말 걸기만 할 줄 안다. quests.js의 부탁 열 개(find 여섯 · errand 넷 — 예: 「할멈의 옛말」은 불씨를 꺼진 등 다섯 군데에 옮겨 붙인다)는 **「맵에 놓인 것 앞에서 ↑를 누르면 숫자가 오르는」 기능**이 있어야 한다. 시험 탭에 먼저 만든다.
              ② 사당 지하(1지역의 끝 메인 「불타는 마을」의 맵)는 달의 사당 안에서 내려가야 하는데, 사당 안은 승인받은 방 그림 한 장이라 **그 그림에 내려가는 계단 하나를 그려 넣어야** 한다. 계단 하나만 더하는 방식으로 짓겠다고 말씀드렸다(손대지 말라고 하시면 사당 밖에 입구를 둔다).
          ✔ S30 중간 보스 넷의 그림(영주의 부관 — 기본 + 대기 두 장 + 동작 설명) — 2026-10-10. `bosses.js`의 `MID` · `BOSS_LIST`의 kind = mid.
              크기(점): 망루의 부관 `towerlieutenant` 67x68(망루의 층 높이 96점 — 망치를 치켜들 자리) · 그림자 사수 `shadowarcher` 140x93 · 불씨 도둑 두목 `thiefboss` 90x71 · 창기병 대장 `lancercaptain` 135x77.
              생김새는 제가 잡았다(설계 표의 「무엇을 가르치는 보스인가」 한 줄에서): 큰 두손 망치 / 사슴뿔 · 큰 활 · 명령서 두루마리 / 불씨 단지가 달린 자루 · 폭탄 / 판금 · 큰 방패와 긴 창(탈것 없음). 화살 · 폭탄은 몸의 동작에 그리지 않는다(따로 만든다).
              다시 그리게 한 것: 그림자 사수(첫 장이 아홉 등신의 사람 꼴 → 병사의 비율로) · 불씨 도둑 두목(첫 장이 한 점 8화소 → 굵은 도트로). 프롬프트의 기준 그림은 정찰대장의 시안(크기 · 그림체).
              확인: 넷 모두 시안과 옮긴 것을 나란히 봄 · 열여섯을 한 줄에 세워 봄 · 창기병 대장의 눈 하나를 고침(fix) · 규칙 검사 통과. **게임에는 없다**(그림만).
          ★ 사용자 2026-10-10(보스가 왜 이렇게 많은지 물으신 뒤 — 쓰임새를 설명드리자): "이게 보스도 난이도 나눠서 돌려쓰면 되거든요 노말보스 하드 보스 이렇게 같은보스여도 난이도별로 보상 다르게하고 이런식으로 메이플이나, 로스트아크 확인해보면됩니다."
              → **보스를 따로따로 늘리지 않는다. 같은 보스를 난이도(스토리 · 노말 · 하드)로 돌려 쓰고, 난이도마다 보상을 다르게 한다.**
          ✔ S31 보스 표를 난이도로 돌려 쓰는 구조로 고침 — 2026-10-10. 보스 서른다섯 → 스물하나 · 계단 서른여덟.
              확인한 것(웹): 메이플스토리 — 같은 보스가 이지 · 노말 · 하드 · 카오스, 낮은 난이도는 일일 · 높은 난이도는 주간, 루타비스는 카오스에서만 파프니르 세트 / 로스트아크 — 발탄 노말 1415 · 하드 1445(비아키스 1430 · 1460), 보상의 종류는 같고 하드가 더 많이, 한 주에 한 난이도만.
              뺀 것(모두 아직 그리지 않았던 것): 필드 보스 여덟 · 잊힌 뜰의 네 수호자 · 바다의 보스 둘(가라앉은 등대의 방은 자리만 둔다). 남은 것: 옛 주인 여덟 · 지역 보스 넷 · 부관 넷(이 열여섯은 그림이 있다) + 드래곤 다섯.
              빠진 보스의 몫: 수호자가 주던 Lv.150의 첫 세트 → 지역 보스의 노말(보스마다 방어구 한 부위: 정찰대장 모자 · 부단장 옷 · 용암 거인 장갑 · 공성 거인 신발 + 무기 조각) · 하드(윗무기 조각) — 이름은 「네 장수 세트」 / 필드 보스 → 부관이 메인 퀘스트 뒤에 제 맵에 20분마다 다시 나온다(`field: true`).
              난이도: 쉬움 · 보통 · 파티 판 · 혼돈 · 어려움 · 이야기 판 여섯 → **스토리 · 노말 · 하드** 셋. 옛 주인 = 노말(일일) · 하드(주간 · Lv.150) / 지역 보스 = 스토리 · 노말 · 하드(주간 — 둘 가운데 하나) / 드래곤 = 노말 · 하드.
              고친 파일: 설계 world.js(BOSSES · REGIONGEAR · modesOfBoss · MODES · TIERS · LADDER · SETS · BOSSRULES · 지역 표와 월드맵의 글) · numbers.js(FIGHT를 갈래 x 난이도로 · EASE · DROPS · 장비 이름 · 공명의 문턱) · economy.js(한 주의 결정 — 같은 보스는 비싼 난이도 하나만) · basics.js · story.js · quests.js · journey.js · maps.js · continents.js / 탭 atlasTab(새 표 「난이도별 보상」) · specTab · coinTab · questTab / 규칙 검사(난이도는 셋 · 필드 보스를 따로 두지 않는다 · 지역 보스의 방어구 네 부위).
              확인: 규칙 검사 통과(보스 21 · 계단 38) · 게임 검사 143,845개 실패 0 · 탭 넷이 그려진 화면의 글을 뽑아 봄(새 표가 있고 옛 난이도 이름 · undefined · NaN이 없다). 게임 코드는 바뀐 것이 없다(보스는 아직 게임에 없다).
              제가 정한 것[판정 대기]: 어느 보스를 빼고 남길지 · 「네 장수 세트」라는 이름과 부위 나눔 · 지역 보스와 드래곤은 한 주에 노말과 하드 가운데 하나만 · 옛 주인의 쉬움을 없앤 것 · 정수의 수(노말 · 하드 모두 2).
          ★★ 사용자 2026-10-10 — **방향을 바꾸셨다**: "일단 보스를 전부 구현하는것보다 처음부터 일정부분까지 게임이 완벽하게 돌아가는게 중요합니다. 메이플과 비교해서 … 우리가 맨 처음 게임을 시작하는 시점부터 정확하게 만들어가기로 할게요"
              → **넓히는 일(뒤 지역 · 보스 그림)을 멈춘다. 게임을 켠 순간부터 차례대로, 새 캐릭터로 해 보며 빈 데를 메운다.** 기준 자료 = 공방 `js/lune/design/startplan.js`(「개발 진행」 탭 맨 위 「처음부터 다시」).
          ✔ S32 조사와 점검 — 2026-10-10. 메이플스토리의 처음~Lv.100(전직 10 · 30 · 60 · 100 · 튜토리얼 · 길라잡이 · Lv.30대 테마던전 · 레벨마다 열리는 것)을 조사했고, 우리 게임을 **새 캐릭터로 처음부터** 켜 봤다.
              새 캐릭터로 보는 법(새로 넣음): Workspace 속성 `LuneGuest = "new"` → Play → 직업 고르기부터 Lv.1(저장을 읽지도 쓰지도 않는다). 끝나면 속성을 지운다.
              오늘 본 것: 켜면 바로 직업 고르기(제목 화면 없음 · 맨 위의 글이 옛 이야기의 말) → 마을 왼쪽 끝의 문 앞에서 시작(사제는 세 층 위 사당 안) → 조작 안내가 하나도 없음 · 기술 셋과 물약 열 개가 처음부터 칸에 있음 → 사제에게 말을 걸면 「첫 기술」 완료 · Lv.2 · 창 단추가 생김(여기는 잘 된다) → 다음 퀘스트(샛별)가 어디 있는지는 알려 주지 않음.
              코드로 본 것: 소리가 하나도 없다 · 전직은 Lv.30 · 60 · 100에 저절로(퀘스트 · 알림 없음) · 1지역의 메인은 Lv.20 「옛 망루」 뒤로 끊긴다(Lv.25 부관) · 부탁은 열 가운데 셋.
              만드는 차례(startplan.js `order`): ① 켠 순간 ~ 캐릭터 만들기 ② 첫 5분(사당 안에서 시작 · 키 안내 · 기술을 받는다 · 첫 레벨업 안내) ③ Lv.1~10 ④ Lv.10~20(첫 보스 검은엄니) ⑤ Lv.20~29(부관 · 정찰대장 · 사당 지하) ⑥ Lv.30 2차 전직 ⑦ 소리. 여쭌 것: 어디까지를 「일정 부분」으로 볼지(제 안 = 1지역 끝 · Lv.30) · 이름 · 외형 · 소리.
          ✔ S33 계정 · 처음 화면 — 2026-10-10. 사용자의 답(범위 = 1지역 Lv.30까지 · 제목 「달의 계승자」 · 외형은 정해져 있다 · 소리는 `luna/music` · 캐릭터 고르기 · 포탈 · 계정 창고 · 지은 이름)을 받아 차례 ①을 만들었다.
              서버: 저장을 **계정 하나**로(`LuneAccount_v1` / `acct_<번호>` = 캐릭터들 + 같이 쓰는 창고 — `sim/account.luau` · `store.luau`). 예전 저장(`LuneHero_v1`)은 읽기만 하고 첫 캐릭터로 옮긴다(이름이 비어 있어 들어가기 전에 짓는다. 예전 저장은 지우지 않는다).
                    이름 장부 `LuneNames_v1`(UpdateAsync로 먼저 적은 사람이 갖는다) + Roblox 글 거르기. 이름의 꼴 = 한글 2~6자 · 영문/숫자 4~12자(메이플과 같은 셈 — 내 제안). 캐릭터는 계정에 6명까지(내 제안). 지운 캐릭터의 이름은 다시 지을 수 있다(내 제안).
                    패킷 `Ready` → `{ select }`, `Chars`(check · create · name · delete · enter · leave). `Choose`는 없앴다. 이름표 · 파티 · 채팅의 이름 = 지은 이름(사람의 속성 `LuneName`).
              화면: `client/lune/title.luau` — 로딩 화면(큰 달 · 구름 · 달가루 · 다섯 영웅의 실루엣 · 제목 · 불러오는 띠 → START) → 캐릭터 고르기(← → · 게임 시작 · 캐릭터 만들기 · 캐릭터 삭제 · 이름 짓기) → 만들기(직업 다섯 + 이름 + 중복 확인).
                    그림 = 공방 `tools/build_lune_title.mjs`(하늘 · 구름 · 언덕 · 제목 — 새로 지어낸 그림 없이 사냥터의 하늘 그리기와 소품 실루엣) · 자리와 글 = `design/title.js` → `data/title.generated.luau`.
                    게임 안 메뉴 → 「캐릭터 선택」으로 고르기 화면에 돌아간다(스마트폰 메뉴에도). `chooser.luau`는 이제 아무도 부르지 않는다(지워도 되는지 여쭐 것).
              확인: 자동 검사 144,057개 통과(계정 · 이름 · 삭제 · 같이 쓰는 창고 · 예전 저장 옮기기 · 임시 계정). Studio Play — `LuneGuest = "new"`로 로딩 → START → 만들기(「달」 = 너무 짧다 · 「달빛낫」 = 쓸 수 있다) → 마을, `LuneGuest = "select"`(캐릭터 셋 있는 임시 계정)로 이름 짓기 · 삭제 · 들어가기 · 메뉴 → 캐릭터 선택 · **밤의창이 창고에 넣은 물약 3개를 달빛도끼가 꺼냄(10 → 13)**.
              아직 못 본 것: 진짜 저장소(DataStore)에 쓰고 다시 읽는 것(자동 검사는 가짜 저장소) · 사용자 본인의 예전 캐릭터가 옮겨지는 것(임시 계정으로만 봤다) · 한글 입력기(IME)로 직접 치는 것 · 스마트폰 화면.
          ✔ S34 포탈 — 2026-10-10. 모든 문 · 건물 입구에 같은 움직이는 그림 하나(세로로 선 민트 빛의 타원 안에서 소용돌이가 돈다 · 22x34 · 8장 · 초당 10장). 「↑ 어디로」 글은 그 앞(가로 30 · 세로 40도트 안)에 섰을 때만 보인다(내 제안 — 포탈인 것은 그림이, 가는 곳은 글이 알려 준다).
              공방: `tools/build_lune_portal.mjs` → `assetpack/lune/fx/portal.png` · 값 `design/portal.js` · 시험 탭(luneTab.js)도 같은 그림을 그린다. 게임: `data/portal.generated.luau` · `sceneView.luau`(Portals 층 = 땅 위 · 주민과 캐릭터 뒤 — 캐릭터를 가리지 않는다).
              확인: 시험 탭의 마을 화면(헤드리스 캡처) · Studio Play의 마을(성문 · 촌장의 집 · 사당에 같은 포탈, 성문 앞에 서면 「↑ 마을 어귀로」). 문 위의 퀘스트 표시(! · ?)는 그대로 뜬다. 104개 장면을 하나하나 보지는 않았다(문의 자리는 예전 그대로라 그림만 그 자리에 놓인다).
          ✔ S35 음악 배치(곡은 아직 올리지 못함) — 2026-10-10. 팩(AlkaKrab Fantasy RPG Music Pack 1 · 2 · 3 — 음악과 징글뿐, 효과음 없음)의 곡 100개를 재서(길이 · 평균 크기 · 밝기 · 박 · 처음과 끝의 크기) 12개를 골랐다. **나는 소리를 들을 수 없다 — 팩의 이름과 잰 숫자로만 골랐다(모두 제안).**
              배치(`design/music.js`): 처음 화면 = Vol.3 Ambient 3 Loop · 마을과 쉬어 가는 곳 = Vol.2 Light Ambient 2 · 달그림자 사냥터(r1a) = Night Ambient 2 · 고갯길(r1b) = Night Ambient 4 · 옛 망루(망루 아래 · 1~3층) = Night Ambient 5 · 숨은 방과 굴 = Vol.1 Dark Ambient 1 · 옛 주인의 방 = Vol.3 Action 5 Loop · 지역 보스의 방 = Vol.3 Action 1 Loop.
                    징글: 퀘스트 완료 = Complete · 레벨 업 = Victory(6.4초 — 길 수 있다) · 쓰러짐 = Death · 숨은 방 = Strange. 2~4지역 · 바다 · 큰 도시는 1지역의 곡을 빌려 쓴다(그 지역을 만들 때 제 곡을 정한다).
              게임: `client/lune/music.luau`(장면이 바뀌면 1.2초에 걸쳐 넘어간다 · 같은 곡이면 이어 튼다 · 징글 동안 배경을 줄인다 · 곡마다 크기를 맞춘다) · `data/music.generated.luau` · 메뉴에 「소리 끄기 / 켜기」(저장은 아직 안 함).
              **올리는 일은 사용자가 해야 한다**(Studio 연결에는 그림 올리기만 있다): `luna/music/_게임에 올릴 곡/lune_*.mp3` 12개(`node tools/build_lune_music.mjs`가 모은 것)를 로블록스에 올리고, 번호를 `node tools/build_lune_music.mjs '{"title":"번호", …}'`로 적는다. 번호가 없는 곡은 게임이 건너뛴다(지금은 모두 조용하다).
              확인: 로블록스 기본 소리를 임시로 끼워 Play — 마을의 곡이 돌고, 사냥터로 가면 0.5초 뒤 두 곡이 섞이다 2초 뒤 사냥터의 곡만 남고, 창고 안 · 마을에서는 같은 곡이 끊기지 않고, 번호 없는 곡의 장면에서는 조용해지는 것. 그 뒤 임시 번호는 지웠다. 진짜 곡으로는 들어 보지 못했다(징글도).
              같이 고친 것: 포탈을 넣으며 생긴 오류(이름표가 없는 문이 있는 맵에 들어서면 화면이 멈춤) — 104개 장면에 모두 들어가 보고 확인. 자동 검사에 문 · 음악 자료의 꼴을 보는 검사를 넣었다(144,995개 통과).
          ✔ S36 사용자의 말 둘 — 2026-10-10. ① "캐릭터 만들기에서 캐릭터 선택으로 눌렀을때 한번씩 액션 애니메이션 나오는데 자연스럽지가 않고 우는 부분이 생기는데?" ② "닉네임에서 영어, 한글 모두 욕이나, 몇자 제한이라던가 예외처리 다 한거지?"
              ① 본 것: 동작 그림 한 장 한 장은 정상(장마다 늘어놓아 봄) · 화면에서 그림이 빠지는 장도 없음(60분의 1초마다 기록). 어색한 까닭 둘을 찾아 고쳤다 —
                 (가) 살라맨더가 사냥기 「화염 광선」의 몸 동작만 틀었다: 게임 안에서는 광선을 따로 그리는데 이 화면에는 없어, 몸을 움츠렸다 펴는 것만 보였다(「우는 부분」을 이것으로 읽었다 — 내 해석. 다르면 어느 캐릭터의 어느 대목인지 여쭐 것). → 몸 동작만으로 보이는 「불주먹 연타」로 바꿨다(`design/title.js`의 `show.skill`).
                 (나) 서 있는 동작이 중간 장에서 끊기고 기술이 끝나면 또 중간 장으로 건너뛰었다. → 고른 순간과 기술이 끝난 순간에 서 있는 동작을 첫 장부터 튼다. 고르고 0.5초 뒤 기술 → 2.4초 서 있기 → 다시(전에는 0.8초 · 3초 주기). 기술은 게임 안의 0.8배 빠르기로 보여 준다(내 제안).
              ② 원래 돼 있던 것: 길이(한글 2~6자 · 영문/숫자 4~12자 · 섞으면 칸으로 셈) · 띄어쓰기/기호/낱자/한자/이모지 거절 · 중복(영문 대소문자 무시 · 내 다른 캐릭터 포함 · 동시에 지으면 먼저 적은 사람) · 운영자인 척하는 이름 몇 개 · Roblox 글 거르기 · 서버가 모든 것을 다시 본다(화면을 속여도 안 된다).
                 빠져 있던 것을 넣었다: **우리 금칙어 목록**(한글 · 영문 욕설 · 성적인 말 · 혐오 표현 약 100개 — Roblox의 글 거르기는 Studio에서 걸러 주지 않아 욕설 이름이 Studio에서는 지어졌다) · 숫자를 끼우거나(시1발) 숫자로 바꿔 적은 것(sh1t) · 숫자만으로 된 이름 · 아주 긴 글(따져 보기 전에 거절) · 이름 칸에서 빈칸이 저절로 빠지게 ·
                 **들어갈 때 다시 보기**(지은 뒤 금칙어가 늘었거나 Studio에서 지은 이름이 실제 서버의 글 거르기에 걸리면 이름을 비우고 다시 짓게 한다 — 캐릭터의 레벨 · 물건은 그대로).
                 규칙과 목록을 공방으로 옮겼다: `js/lune/design/names.js` → `data/names.generated.luau`(목록은 거기서 더하고 뺀다).
                 못 하는 것 · 안 한 것: Roblox 글 거르기가 실제로 무엇을 거르는지는 Studio에서 볼 수 없다(실제 서버에서만 동작) · 대문자 I와 소문자 l처럼 모양이 닮은 글자로 남을 흉내 내는 것은 막지 않는다 · 한글 욕의 변형(자음을 바꾼 것 등)은 목록에 있는 것만 잡는다.
              확인: 자동 검사 145,125개 통과(이름의 경우 60여 개 · 들어갈 때 다시 보기). Play — 살라맨더의 새 동작이 0.5초 뒤 시작해 1초쯤 돌고 서 있는 첫 장으로 돌아오는 것, 「달 빛 검」이 「달빛검」으로 적히는 것, 「시1발」에 「쓸 수 없는 이름입니다」가 뜨는 것.
          ✔ S37 캐릭터 만들기의 튕김 — 2026-10-10. 사용자가 영상(`Assets/character/talchar/three/bug.mp4`)을 찍어 줬다: "애니메이션 종료시점이랑 돌아오는게 연결이 안되서 엄청나게 이상하게 튕기는 현상".
              **S36에서 내가 읽은 것(살라맨더가 움츠리는 대목)은 틀렸다.** 영상을 장마다 보니: 동작의 모든 장이 「바로 앞 장의 크기」로 그려진다(그림은 새 장 · 틀의 크기는 앞 장). 크기가 비슷한 장 사이에서는 티가 덜 나고, 크게 다른 장 사이(64x36 → 62x21 → 24x20 — 기술이 끝나 서는 자세로 돌아올 때)에서 세로로, 이어서 가로로 크게 늘어난다.
              원인: `title.luau`가 화면을 `RunService.RenderStepped` **이벤트**에서 고쳤다. 그 이벤트는 Roblox가 그 장의 틀 크기를 셈한 뒤에 불려서, 그림의 자리(ImageRect)는 이번 장에 · 틀의 크기(Size)는 다음 장에 적용된다. 게임 화면(boot.luau)은 `BindToRenderStep`이라 괜찮았다. 예전 직업 고르기(chooser.luau)에도 같은 잘못이 있었다.
              시험: 한 화면에 그림 둘을 두고 장마다 두 장을 번갈아 넣었다 — BindToRenderStep으로 넣은 쪽은 그림과 틀이 맞고, RenderStepped 이벤트로 넣은 쪽은 눌린 채 찍혔다(`dev/BUG_2_before_after.jpg`). 영상의 화면이 초당 10~15장으로 느리게 돌아(녹화 중) 한 장의 어긋남이 0.1초씩 보였다.
              고친 것: `title.luau`의 돌리기를 `BindToRenderStep("LuneTitle", Camera - 1)`로(끝나면 푼다). 자동 검사에 「화면 코드가 RenderStepped 이벤트에서 화면을 고치지 않는가」를 넣었다(`run.py`의 lint_render_step). chooser.luau는 머리말에 적어 두었다.
              확인: Play — 처음 화면 위에 두 방식을 나란히 두고 찍어 지금 방식이 맞는 것 · 메뉴 → 캐릭터 선택으로 돌아와도 화면이 도는 것(다시 묶인다) · 콘솔 오류 없음. 고친 뒤의 진짜 동작을 영상으로 찍어 보지는 못했다(내게 화면을 녹화하는 도구가 없다).
              S36에서 바꾼 것 가운데 남긴 것: 서 있는 동작을 첫 장부터 트는 것 · 살라맨더의 보여 주는 기술(불주먹 연타) · 0.8배 빠르기 — 틀린 해석에서 나온 것이라 사용자에게 되돌릴지 여쭸다.
          ✔ S38 이름의 금칙어 — 2026-10-10. 사용자가 「성관계장인」이 「쓸 수 있는 이름입니다」로 뜨는 사진을 줬다: "조금만 우회해도 문제되는 닉네임이 통과됩니다." S36의 목록(내가 적은 100개 남짓)은 턱없이 모자랐다.
              조사: 공개된 금칙어 목록 넷을 받아 합쳤다 — doublems/korean-bad-words(MIT · 3,577) · yoonheyjung/badwords-ko(MIT · 574) · LDNOOBW ko(CC BY 4.0 · 72) · LDNOOBW en(CC BY 4.0 · 403). 원본과 라이선스는 공방 `assetpack/lune/badwords/`, 출처는 `data/names.generated.luau`의 머리말에 적었다.
                    로블록스의 글 거르기는 Studio에서 걸러 주지 않는다는 것도 확인했다(DevForum의 여러 글 — 올린 게임에서만 동작). 그래서 Studio에서 보이는 것은 우리 목록뿐이다.
              지은 것: `tools/build_lune_names.mjs`(합치기 + 견주는 셈 + 맞춰 보기) → `merged.json` → 게임 `Account.nameBanned`(같은 셈). 금칙어 한글 2,276 · 섞인 말 56 · 영문 347 · 영문(덩어리 전체일 때만) 85.
                    변형을 잡는 셈: 한글만 뽑아 견줌(시1발 · 시a발) · 모음 늘인 것 줄임(씨이발) · 소리의 뼈대(쎅쓰 = 섹스 · 성관께 = 성관계 — loose의 여덟 말만) · 영문만 뽑아 견줌(fu달ck) · 숫자로 바꾼 것(sh1t · a55) · 글자를 늘인 것(fuuck — 글자의 덩이로 견줘서 nigeria는 막지 않는다) · 영문 덩어리가 gm이면 운영자인 척(GM달빛).
                    멀쩡한 이름을 풀어 주는 것: 가져온 목록에서 흔한 말 250개쯤을 뺐다(아가 · 카드 · 세끼 · 광년 · 존귀 …) · 가려 놓는 말 60개(성기사 · 시발점 · 졸라맨 · 보지마 · essex …) · 짧은 영문(ass · tit · cum · rape …)은 덩어리 전체일 때만.
              확인: 공방과 게임이 같은 답을 내는지 이름 288개(막혀야 88 · 통과해야 200)로 맞춰 봄 — 자동 검사 145,498개 통과. Play의 진짜 서버에 물어봄: 성관계장인 · 성관께 · 섹쓰왕 · 씨이발 · fu달ck · fuuck · b00bs · GM달빛 = 막힘 / 달빛도끼 · 성기사 · 무지개색 · 미니미 · Classic · Nigeria · xXxMoonxXx = 통과.
              한계(사용자에게 말함): 목록은 끝이 없다 — 새로 지어낸 말 · 뜻으로만 통하는 조합 · 글자 사이에 다른 한글을 끼운 것은 못 잡는다. 실제 서버에서는 로블록스의 글 거르기가 한 겹 더 있고(Studio에서는 볼 수 없다), 빠져나간 말을 extra에 더하면 그 이름의 캐릭터는 다음에 들어올 때 다시 지어야 한다.
              일부러 막힌 채 둔 멀쩡한 말도 있다(성욕 · 「자지 · 보지」가 든 말 가운데 가려 놓지 않은 것 · Titsworth 같은 드문 이름).
          ▶ 2026-10-10 밤, 사용자가 자리를 비우며 준 일(1시간 · 모든 권한): "두번째 캐릭터로 창고지기에게 대화해도 창고가 안열립니다. 그리고 처음에 성장이 너무 어렵습니다. 성장밸런스 확인하고, 직업별 밸런스도 확인해봐야합니다.
             어떤직업은 시작부터 쉽게 사냥하는데 어떤직업은 그것도 어려운경우가 있고 또, 대형 마을마다 명예의 전당 건물 을 만들어서 최대 로벅스 결제자, 전투력 랭킹, 레벨 랭킹 이렇게 캐릭터 닉네임 보여주는 명예의 전당을 만듭니다.
             이 버그들 이랑 제가말한 제안사항 처리하고 다시 게임 시작부터 ~ lv30 찍고 2차전직하는 루트까지 정확하게 메이플식으로 아직 구현되지않은것 구현하고, 버그 있는거 검증하고 해서 계속 작업 하세요"
             차례: ① 창고(S39 ✔) ② 성장 · 직업 균형(S40 ✔ 1차) ③ 명예의 전당(S41) ④ 시작 ~ Lv.30 · 2차 전직의 길에서 빠진 것(startplan.js의 차례 ② ~ ⑥).
          ✔ S39 창고 — 새 캐릭터(Lv.1~3)는 창고가 Lv.4부터라 창고지기에게 말을 걸어도 아무 일도 없었다. 계정의 창고는 처음부터 열리게 했다(`items.js`의 OPEN.store 4 → 1), 창고를 열 때 가방 창은 레벨과 상관없이 같이 뜬다(`Windows.open(id, arg, force)`). 설계의 글(basics.js · items.js · questplay.js)도 고쳤다. Play 확인: 임시 계정의 둘째 캐릭터(Lv.1 리퍼 「창고둘째」)로 창고지기 앞에서 ↑ → 창고 창 + 가방 창이 같이 열림(`dev/STORE_lv1.jpg`).
          ✔ S40 초반 성장 · 직업 균형(1차) — `tools/test/tests/26_lune_balance.luau`를 만들어 진짜 서버의 셈으로 직업 다섯 x 여섯 자리(Lv.1 수습 검병 · Lv.2 버섯 · Lv.3 검병 · Lv.5 창병 · Lv.6 검병 · Lv.9 까마귀)를 쟀다.
              고치기 전: Lv.1에 수습 검병 한 마리 = 사냥기 6~8번(3.5~5.2초) · Lv.1 → 2에 43마리(설계는 2번 · 26마리). 까닭 = 새 캐릭터의 기술은 1레벨이라 설계 피해의 40%만 들어갔다. 가까이 붙는 직업은 한 마리에 체력을 10~26% 잃었다(멀리서 치는 리븐은 0~9%). 직업 사이의 잡는 시간은 최대 1.87배.
              고친 것(모두 내 제안): ① 레벨에 드는 시간의 바닥 T0 2분 → 0.5분(Lv.1 → 2가 26마리 → 8마리 분량. Lv.29까지 6시간 → 5시간) ② Lv.1~14 몬스터의 체력을 덜어 줌(Lv.1에 절반 → Lv.15에 제값 — `CURVE.ease`, `N.easeAt`) ③ 1차 스킬의 1레벨 세기 40% → 70%(`SKILLRULE.floor`).
              고친 뒤: Lv.1 수습 검병 = 사냥기 2번(1.3~1.7초) · Lv.1 → 2에 13마리 · Lv.3 검병 2.0~3.0초 · Lv.9 까마귀 2.8~3.4초. 직업 사이의 잡는 시간 최대 1.51배 · 한 마리에 잃는 체력 최대 14%. 자동 검사 전부 통과.
              아직 안 본 것: 여러 마리를 한꺼번에 잡는 효율(넓은 기술의 직업이 유리 — 살라맨더의 광선 194도트 · 리퍼의 낫 48도트) · Lv.10~30 · 장비를 갖췄을 때 · 실제 손맛(Play).
          ✔ S41 명예의 전당 — 2026-10-10 밤. 초승달 마을의 「살림집의 섬」(들어갈 수 없던 살림집이 서 있던 흙섬)에 명예의 전당 건물을 세웠다(자리는 내 제안). 안에 비석 셋: 후원(쓴 로벅스) · 전투력 · 레벨. 비석 앞에서 ↑ → 「명예의 전당」 창(탭 셋 · 판마다 위 열 줄 · 캐릭터의 이름 · 직업 · 값).
              그림: Codex 두 장 — `town/raw_hall.png`(건물 · 10화소 = 1점으로 줄여 131점 폭) · `town/indoor/raw_hall.png`(실내). 프롬프트는 같은 폴더의 prompt_hall.txt. 비석은 방 그림에 그려져 있고, 게임에서는 「그림 없는 주민」(stone)으로 이름표와 ↑만 있다.
              서버: `sim/rank.luau` · `store.luau`(OrderedDataStore 셋 `LuneRankLevel_v1` · `LuneRankPower_v1` · `LuneRankRobux_v1` + 이름 `LuneRankInfo_v1`) · `world.luau`(들어올 때 · 저장할 때 올리고, 1분마다 한 번 읽어 둔 것을 준다 · 캐릭터를 지우면 뺀다) · 패킷 `Rank`.
              후원 판: 계정에 `spent`(쓴 로벅스)를 두고 `World.addSpent(player, robux)`가 판에 올린다 — **게임 안 상점(로벅스 상품)이 아직 없어서 부르는 곳이 없다. 지금은 늘 「아직 기록이 없습니다」다.** 상품을 만들 때 영수증 처리에서 부르면 된다.
              확인: 자동 검사(레벨이 높은 쪽이 위 · 지우면 빠짐 · 쓴 로벅스가 쌓임) 151,521개 통과. Play — 마을에 건물과 포탈, 들어가서 전투력의 비석 앞에서 ↑ → 창에 「1 밤의창 리틀 리븐 30」.
              아직: 다른 큰 마을(은달 항구 · 2~4지역의 마을)에는 세우지 않았다(범위가 1지역이라) · 진짜 저장소의 순위판은 보지 못했다(임시 계정은 메모리에만) · 내 순위(열 줄 밖일 때 내 줄) 표시 없음.
          ✔ S42 첫 5분(startplan 차례 ②) — 2026-10-10 밤. ① 새 캐릭터는 **사당 안(문 앞)에서 시작**한다(첫 퀘스트 「첫 기술」을 끝내기 전까지 — 끝낸 뒤에 다시 들어오면 마을의 시작 자리. 공방 `questplay.js`의 `FIRST` → `Quests.firstScene`).
              ② **스킬 칸은 사제에게 말을 건 뒤에 생긴다**: 그 전에는 칸이 보이지 않고 기술도 나가지 않는다(화면만 — 서버의 캐릭터는 처음부터 기술을 갖고 있다. 스마트폰의 단추는 보이지만 듣지 않는다). 끝내면 화면 가운데에 「기술을 배웠다 — 화면 아래에 스킬 칸이 생겼다」.
              ③ **조작 안내 한 줄**(화면 위 가운데 · 민트 글씨 — `shared/lune/ui/guideText.luau`가 고르고 `client/lune/guide.luau`가 그린다): 걷기 → 사제에게 ↑ → 받은 점수 찍기(능력치 창 → 스킬 창) → 사당 밖으로 → 뛰기 · 아래 발판 · 샛별의 자리 → 마을 어귀로 나가는 문 → 사냥기 · 이동기의 키 → 떨어진 것 줍기 → 체력이 절반 아래면 물약.
                 무엇을 봤는지 저장하지 않는다 — 지금 상태에서 그때그때 고르고, 할 일을 하면 사라지며, Lv.5가 지나면 뜨지 않는다. 키 이름은 지금 설정된 키를 적는다. 스마트폰에서는 단추의 이름(「말 걸기」 · 「들어가기」 · 「줍기」 · 「점프」)으로 적는다.
              설계(START)의 「능력치 창과 스킬 창이 차례로 저절로 열린다」는 하지 않았다 — 열라는 안내 글과 단추의 노란 점으로 대신했다(내 제안: 싸우는 중에 창이 저절로 뜨면 방해가 된다).
              확인: 자동 검사 `27_lune_start`(안내 글 스무 가지 남짓이 때에 맞게 뜨고 칸에 다 들어간다). Play(`LuneGuest = "new"`): 사당 안 문 앞에서 시작 · 「← → 키로 걷는다 — 그믐 사제에게 간다」 → 사제 앞 「↑ 키: 그믐 사제에게 말을 건다」 → ↑ 세 번 → 스킬 칸 + 알림 + Lv.2 → 「P 키: 능력치 창 …」 → 사당 밖 마을(`dev/START_1~3`).
              **시험 탭에는 넣지 않았다**(글 안내라 손맛과 무관하다고 봤다 — 내 판단). 실제 스마트폰 화면은 보지 못했다.
          ✔ S43 다음 퀘스트로 이끄는 것(차례 ③의 앞부분) — 퀘스트 알리미(오른쪽 위)가 하는 중인 퀘스트 아래에 **길잡이**를 적는다(`Quests.guide`): 지금 받을 수 있는 메인 「! 마을 밖의 그림자 / 샛별에게 받는다 · 초승달 마을」(노랑 + 민트) ·
              레벨이 모자란 다음 메인 「빈 갑옷 / Lv.4부터 받는다」(흐리게) · 받을 수 있는 부탁 둘까지. 주는 주민이 여러 맵에 서 있으면 그 퀘스트를 하는 맵에서 문으로 가장 가까운 곳을 적는다. 알리미의 높이에 남는 데까지만.
          ✔ S44 1지역의 퀘스트를 끝까지 이음(차례 ③ ④ ⑤의 퀘스트 부분) — 메인 6 → **9**, 부탁 3 → **7**. Lv.20에서 끊기던 메인이 Lv.28까지 이어져 사당의 사제에게서 끝난다(전직하는 곳).
              **보스의 싸움이 아직 없어 대신한 셋(내 제안 — 2~4지역에서 한 방식)**: 「망루의 부관」 = 망루 3층의 낡은 수련 인형 열다섯 · 「정찰대장」 = 망루 3층의 정예 검병에게서 찢어진 명령서 여섯 장 · 「불타는 마을」 = 수비대원 차돌에게 받아 사당의 그믐 사제에게 가기만(싸움 없음).
              부탁 넷: 「창고의 빈 선반」(검병 · 보따리 6) · 「이름 없는 비석」(재까마귀 · 달맞이꽃 5 — 맵에서 꺾는 대신) · 「모루에 올릴 것」(굽잇길 폭탄병 · 폭탄 껍데기 10) · 「마을 문 고치기」(망루 2층 정예 궁병 · 쇠 경첩 12). 보상은 달돈.
              그림: 물건 여섯(Codex `ui/raw_etc_5.png` · `prompt_etc_5.txt` — 보따리 etc_bundle · 달맞이꽃 etc_primrose · 폭탄 껍데기 etc_bombshell · 쇠 경첩 etc_hinge · 찢어진 명령서 etc_order · 달빛 서린 조각 etc_moonshard). 18점으로 옮긴 것을 원본과 견줘 봤다. ui_kit.png 올림.
              아직 못 하는 부탁 셋: 「할아버지의 옛이야기」 · 「수비대의 깃발」(맵에 놓인 것 앞에서 ↑를 누르는 기능이 없다) · 「묵은 도토리」(도토리 할머니의 그림 · 검은엄니의 싸움이 없다).
          ✔ S45 2차 전직(차례 ⑥) — **레벨만 되면 저절로 열리던 것을 전직 퀘스트로 바꿨다.** Lv.30이 되는 순간 「2차 전직」 퀘스트를 저절로 받는다(화면 가운데 「달이 부른다」 · 알리미 맨 위) → 망루 3층의 낡은 수련 인형에게서 달빛 서린 조각 열 개(둘에 하나꼴)
              → 초승달 마을 사당의 그믐 사제에게 돌려주면 2차(화면 가운데 「2차 전직」 · 스킬 창의 II 탭이 열림 · 2차의 사냥기와 보스기가 1차의 것이 놓여 있던 칸에 들어옴 · Lv.30부터 받은 스킬 포인트를 그때부터 쓴다).
              셈: 캐릭터가 차수를 갖는다(`h.job` — 저장한다). `Hero.advance` · `Hero.advanceAll`(확인용) · `Quests.jobQuest` · 퀘스트의 보상 `job`. 전직 퀘스트는 그만둘 수 없다. **3 · 4차는 전직 퀘스트가 아직 없어 예전처럼 레벨만 되면 오른다**(그 지역을 다듬을 때 만든다).
              예전에 저장된 캐릭터(차수가 적혀 있지 않다)는 그 레벨의 차수 그대로 읽는다 — 사용자의 캐릭터가 2차 스킬을 잃지 않는다. 확인용 캐릭터(`LuneGuest = "riven:120"`)도 그 레벨의 차수로 들어온다.
              설계와 달라진 것(내 제안): 전직 퀘스트의 맵을 2지역의 첫 맵(나루 뒷길)에서 1지역의 마지막 사냥터(망루 3층)로 — 사제가 초승달 마을에만 있어서다. 퀘스트를 사제에게 먼저 받으러 가지 않아도 되게 저절로 받게 했다(한 번만 걸어가면 된다).
              확인: 자동 검사(13의 끝 「시작과 전직 퀘스트의 흐름」 · 18 · 21 · 27) — 전체 151,633개 통과. Play: 새 캐릭터를 확인용 명령으로 Lv.30까지 올림 → 「달이 부른다」 → 확인용 명령 `qitem`으로 조각 10개 → 사제 앞 ↑ 세 번 → 「2차 전직」 · 칸의 Q · A가 초승달 가르기 · 쪼개기로 · 스킬 창 II 탭(`dev/JOB_1~3`). 콘솔 오류 없음.
              **Play에서 못 본 것**: 망루 3층에서 인형을 실제로 잡아 조각이 떨어지고 줍는 것(떨어지고 줍는 길은 다른 모으기 퀘스트와 같다 — 자동 검사만) · Lv.30 캐릭터로 사당까지 걸어 돌아가는 길(맵 열둘).
              같이 넣은 것: 확인용 명령 `Debug("qitem", n)`(하는 중인 모으기 퀘스트의 물건을 n개씩 가방에) · 서버의 `World.jump(player, 장면)`(확인용 goto가 쓰는 것을 함수로 뺌 — 자동 검사도 쓴다) · 균형 검사의 문턱(두 번에 잡는 Lv.1에서는 차이가 1초 안이면 통과 — 리븐 1.1초 · 살라맨더 2.0초).
          ✔ S46 뒷손질 — ① 스킬 칸의 잠금과 사당 안 시작은 **Lv.1 새 캐릭터에게만**(`Quests.isNew`): 첫 퀘스트를 건너뛰고 자란 예전 캐릭터 · 확인용 캐릭터(`LuneGuest = "직업:레벨"` — 첫 퀘스트를 끝낸 것으로 만든다)는 마을에서 시작하고 기술도 그대로 쓴다. Play: `axion:9`가 마을에서 시작 · 스킬 칸이 보임.
              ② 「불타는 마을」을 돌려줄 때 사제가 2지역으로 가는 길을 한마디 더 한다(「야영지 너머 은달 항구의 부두에서 배를 타라.」 — 월드맵이 없어서). ③ 전직의 알림은 캐릭터 머리 위의 「완료」 글과 겹치지 않게 위로 올리고, 전직 때는 「완료」 글을 띄우지 않는다. 알리미의 전직 퀘스트 이름은 노랑.
              Play(부탁 하나): Lv.9 확인용 캐릭터로 창고지기 초롱에게 ↑ → 「창고의 빈 선반」을 받음 → `qitem`으로 보따리 6 → 가방의 기타 탭에 새 그림과 수 6 → 초롱에게 ↑ → 「완료」 · 경험치. 바닥에 떨어뜨려 본 새 물건 여섯의 그림도 봄.
              **보고 알게 된 것**: 창고지기 · 상인처럼 창을 여는 주민이 줄 퀘스트를 갖고 있으면 ↑를 눌렀을 때 퀘스트의 말이 먼저 나오고(마지막 ↑에서 받는다), 그다음 ↑부터 창이 열린다 — 받고 싶지 않아도 받아야 창이 열린다(상인 반달은 전부터 그랬다. 창고지기는 이번에 부탁이 생겨 Lv.7부터 그렇게 된다). 사용자에게 여쭐 것.
          ▶ 2026-10-11 사용자의 답(휴대폰 Remote Control로): 「조작안내 좋습니다」(승인) · "어떤 역할이 부여된 npc 들의 경우 퀘스트 부여하면안됩니다. 그 역할만 해야해요 퀘스트 npc 는 퀘스트 npc 들이 하는 역할입니다." · "전직은 전직관의 역할" · (뱃사공 노을 · 화롯골 대장장이 숯돌도) "마찬가지로 역할npc로봅니다" · "도르래 놓을필요없음"
             · "보스가 있으면 안됩니다. 자연스러운 약한 스토리 보스는 나와도되는데 리워드를 드롭하는 레이드보스가 있으면안됩니다. 메이플 파악해보세요"
          ✔ S47 역할 주민은 퀘스트를 주지도 돌려받지도 않는다 — 2026-10-11. 목록 = `questplay.js`의 `ROLE_NPC`(반달 · 무쇠뿔 · 초롱 · 그믐 사제 · 달래 · 노을 · 숯돌 · 금송 · 소담 · 이슬 · 나래 · 한솔 · 마루). 그믐 사제에게 남은 것은 「첫 기술」(1차의 기술을 가르친다 — 전직으로 본 것은 내 해석)과 전직 퀘스트뿐.
              옮긴 것(옮길 주민 · 대사는 내가 잡음): 1지역 「창고의 빈 선반」 초롱 → 샛별 · 「이름 없는 비석」 사제 → 보름 영감 · 「모루에 올릴 것」 무쇠뿔 → 보름 영감 · 「고갯길의 좌판」 반달 → 고갯마루 노인 · 메인 「발자국을 따라」는 준 사람(보름 영감)에게 돌려줌 · 메인 「불타는 마을」 사제 → 보름 영감
                    / 2지역 메인 「반달 나루」 · 부탁 「새는 나룻배」 노을 → 하늬 · 「능선 너머 장삿길」 반달 → 하늬 · (아직 못 하는) 「반달의 고향 집」 반달 → 하늬 / 3지역 「화약통 치우기」 숯돌 → 아궁 할멈
                    / 4지역 「되찾은 곳간」 반달 → 샛별 · 「저항군 대장간」 무쇠뿔 → 하늬 · 「깨진 쐐기 조각」과 메인 「전날 밤」 사제 → 보름 영감(옛 근위대 숙소에 촌장을 세움 — 털어놓는 사람이 사제에서 촌장으로 바뀜).
              규칙 검사에 넣음(역할 주민이 주거나 돌려받는 퀘스트 · 설계의 부탁에서 주는 사람이 역할 주민이면 오류) · 자동 검사 27에도. 전체 151,801개 통과. Play: Lv.9 확인용 캐릭터로 창고지기 앞 ↑ 한 번 → 말풍선 없이 창고 + 가방이 바로 열림.
          ▶ 2026-10-11 사용자가 방향을 바로잡음(내 보스 정리안 — 검은엄니를 Lv.50으로 옮기는 것 — 에 대해): "이거 계획이 잘못된겁니다. 메이플은 그냥 일반 아이템들이 드롭되는 구조에요 그리고 그냥 일반몬스터들이 확률에 따라서 레벨 10 몬스터 잡다가 적은확률로 10렙제 아이템, 방어구를 드롭하는겁니다.
             안뜨면 재료를 모아서 대장장이에서 만들수도 있구요. 메이플을 보면 힐라부터 120제 네크로 아이템, 그후에 시그너스 140 제 아이템 그후에 루타비스 150 제 아이템 그 후에 스우, 데미안 160 제 아이템 이런식으로 이어지는겁니다. 하지만 우리는 완전히 초반구역을 기획하고있는데
             그냥 몬스터에 간단하게 일반아이템 드롭되고, 낮은확률로 이것저것 리워드 드롭되게해서 반복사냥 mmorpg 개념으로 가야하는겁니다. 지금 완전히 초반구획에서 리워드 보스를 설계하고 이런게 방향성이 잘못된겁니다. 그냥 스토리 보스는 넣을수있는데"
          ✔ S48 반복 사냥의 드롭과 제작 — 2026-10-11. 조사: 초창기 메이플(인벤의 회고 글) — 장비는 대부분 드롭("2시간에 1개 장비를 먹으면 다행") · 제작 NPC(페리온의 선더 · 스미스 …)에게 "엄청나게 많은 재료를 주고" 만든다 · 제작은 무기 60제까지.
              설계(`items.js` 4-0절 — 모두 내 제안): 재료 여섯(`MATS` — 레벨대마다 광석 · 가죽: 청동 · 강철 · 미스릴 / 얇은 · 질긴 · 두꺼운) · 한 마리에 12%씩(`MATDROP`) · 제작법 열다섯(`RECIPES` — Lv.1 · 10 · 20 x 무기 + 방어구 넷. 예: Lv.10 무기 = 광석 20 + 가죽 5 + 달돈 210) · 만든 것의 성능은 보통 이상(`CRAFTQ`) ·
                    낮은 확률의 귀한 드롭(`RARE` — 그 레벨의 물약 2% · 귀환 주문서 0.3%) · 귀환 주문서(`RETURNSCROLL` — 쓰면 마을로 · 잡화 상인이 100달돈에). 한 벌에 평균 Lv.1 108 · Lv.10 442 · Lv.20 667마리.
              그림: 재료 여섯(Codex `ui/raw_etc_6.png` · `prompt_etc_6.txt` — mat_ore1~3 · mat_hide1~3). 18점으로 옮긴 것을 원본과 견줘 봄. 귀환 주문서는 있던 그림(scroll). ui_kit.png 올림.
              게임: `Items.matsAt · rollMats · rollRare · recipe · rollCraftQuality` · `Room:lootFor`(떨어지는 것의 갈래 "goods" — 가방의 아이템이 제 그림으로 떨어진다. 재료 · 귀한 드롭은 방의 다른 난수 `lootRng`로 굴린다 — 졸개의 움직임이 달라지지 않게) · `Bag.craft` · 서버 `Item("craft", 제작법)`(대장장이 앞에서만) ·
                    귀환 주문서(`Potion` 패킷이 주문서도 받는다 → `World.jump`) · 화면: 상점 창의 제작 보기(`shopWindow.luau`의 buildCraft — 단계의 탭 · 줄마다 재료 가진 수/드는 수 · 삯 · 「제작」) · 대장장이 상점의 단추 둘(「제작하러 가기」 · 「강화하러 가기」) · Lv.8 전의 대장장이는 상점부터 연다. 확인용 `Debug("mats", n)`.
              확인: 자동 검사 178,607개 통과(재료의 확률 · 제작의 조건과 성능 · 주문서 · 줍기). Play(`axion:12`): 고갯길 초입에서 멧돼지 새끼 몇 마리 → 달돈 3 · 달가루 2 · 질긴 가죽 1이 떨어짐 / 대장장이 → 상점 → 제작 창 → Lv.10 큰 도끼 제작(광석 30 → 10 · 달돈 5,000 → 4,790) / 사냥터에서 주문서 → 마을(`dev/LOOT_1 · CRAFT_1~3`).
              못 본 것: 수백 마리를 실제로 잡으며 모이는 속도 · 스마트폰의 제작 창 · 2지역부터의 재료(없다).
          ▶ 2026-10-11 사용자: "그러니까 무기나 방어구를 얻는건 쉬운겁니다. 강화가 벽으로 작용해야해요"
          ✔ S50 장비는 쉽게 · 강화의 벽은 그대로 — 장비 드롭 0.8% → 5%(내 무기 1 · 다른 직업의 무기 1 · 방어구 3 — `basics.js` WEAPON.drop) · 재료 12% → 15% · 제작 재료를 3분의 1 아래로(Lv.10 무기: 광석 20 · 가죽 5 → 6 · 2. 한 벌에 평균 Lv.1 60 · Lv.10 120 · Lv.20 153마리) · 삯 0.5 → 0.3배.
              강화의 벽을 지키는 것: 장비가 여섯 배쯤 흔해졌으므로 분해의 달가루를 1 → 0.16배(`economy.js` DUST.dismantle · Lv.10부터 적어도 1), 상점에 파는 값의 몫을 30 · 15 → 4.8 · 2.4(`items.js` SELL)로 내림 — 한 마리를 잡아 버는 달가루 · 달돈이 전과 같다. 규칙 검사에 「떨어진 장비를 분해한 달가루가 사냥으로 줍는 달가루를 넘지 않는다」 · 「장비는 한 마리에 3% 넘게」 · 「제작 한 벌은 그 레벨대 사냥의 25% 안」을 넣음.
              같이: 떨어지는 것을 모두 방의 드롭 난수(`lootRng`)로 굴린다(드롭 확률을 고쳐도 싸움의 흐름이 안 바뀐다) · 균형 검사가 자리마다 세 마리 → 아홉 마리를 잰다(세 마리로는 값이 1.2~2.3배로 흔들렸다). 아홉 마리로 잰 직업 사이의 잡는 시간: 1.08~1.32배 · 잃는 체력 최대 18.7%(살라맨더 Lv.5).
              사용자에게 말한 사실: 1지역의 장비는 5성까지라(Lv.10 장비 5성 = 달가루 평균 11개 · 212달돈) 지금은 초반의 강화도 벽이 아니다 — 벽은 11성부터(전에 정한 10 · 17 · 22성). 초반에도 벽이 되어야 하는지 여쭘. 자동 검사 193,503개 통과. Play로는 다시 보지 않았다(숫자만 바뀜).
          ▶ 2026-10-11 사용자의 답: "10까지는 쉬운게 맞습니다. 초반육성은 쉬워도 되요 2차 이후로 점차 어려워지면됩니다." → 1지역의 강화(5성 상한 · 싼 달가루)는 그대로 둔다. 어려워지는 것은 2차(Lv.30) 뒤부터 점차 — 지금 설계의 구간 길이는 1지역 5시간 · 2지역 24시간 · 3지역 76시간 · 4지역 191시간.
          ✔ S51 첫 강화는 공짜로 반드시 붙는다 — 설계(basics.js FORGE.first · START의 Lv.8 줄)에 있었는데 게임에 없던 것. `h.forged`(저장) · `Items.enhanceInfo(it, guard, first)` · `Bag.enhance`(별이 없는 장비에 첫 별을 붙일 때 한 번 — 예전 캐릭터가 높은 별에서 공짜로 넘어가지 못하게) · 강화 창의 글 「첫 강화 — 달가루 없이 반드시 붙는다」.
              자동 검사 193,629개 통과(첫 강화 50번이 모두 붙음 · 달가루 0 · 한 번뿐 · 저장). Play에서는 보지 않았다.
          ▶ 2026-10-11 사용자: "메이플스토리 참고해서 작업해야하는것들 작업하세요 현재 덜 구현된것들" → S52~S55(메이플에 있는데 우리 게임에 없거나 반쯤이던 것)
          ✔ S52 퀘스트 창의 탭 셋(메이플의 「시작 가능 · 진행 중 · 완료」) — `ui/questWindow.luau`를 새로 씀: 탭 「진행 중 · 시작 가능 · 완료」 · 한 쪽에 다섯 줄(▲▼) · 줄마다 Lv · 보상의 글(`QuestWindow.rewardText` — 전직 퀘스트는 「2차 전직」 · 「Lv.30 무기」) · 「받는 곳: 샛별 · 초승달 마을」(`giverText`) · 레벨이 모자란 다음 메인은 흐리게 「Lv.N가 되면 받는다」.
              셈: `Quests.listOpen(book, level)` · `listDone(book)` · `giverScene(def)` / `giverPlace(def)`(그 퀘스트의 맵에서 문으로 가장 가까운, 주는 주민이 있는 장면).
          ✔ S53 월드맵(M) — 메이플의 월드맵처럼 그 지역의 맵들이 길로 이어진 그림. 자료는 공방의 길 그림(`design/journey.js`) 그대로: `export_lune_game.mjs` 2-00절 → `data/worldmap.generated.luau`(지역 넷 · 마디 · 길 · 장면 → 마디. 숨은 방 · 옛 주인의 굴은 뺌).
              셈 `shared/lune/ui/worldmap.luau`(`nodeOf` — 그림에 없는 장면(건물 안)은 문을 따라 가장 가까운 마디 · `levels` · `marks`(받을 곳 「!」 · 돌려줄 곳 「?」) · `recommend`(내 레벨에 맞는 사냥터) · `info`) · 화면 `ui/mapWindow.luau`(넓은 창 620 · 지역 탭 · 내가 있는 맵은 민트 테두리 · 이름 아래 몬스터의 레벨 · 내 레벨의 사냥터는 풀빛 · 맵을 누르면 아래에 갈래 · 레벨 · 몬스터 · 주민). 이동하는 기능은 없다(보기만).
              이름 글이 길을 가리지 않게 글 뒤에 받침을 깔고, 여러 장을 묶은 마디는 짧은 이름(`label`)을 적는다(88점 안 — 검사 28).
          ✔ S54 2차 전직의 보상에 Lv.30 무기(보통) — 메이플은 전직하면 그 차수의 무기를 준다. `questplay.js` JOBPLAY[2].give.gear → `reward.gear` → `Hero.questDone`(가방의 장비 칸이 가득 차면 돌려주지 못한다 — 전직도 하지 않는다. 까닭 `Bag.FULL`).
              S52~S54 확인: 자동 검사 `28_lune_worldmap.luau`(새로) · 전체 194,372개 통과. Play(손님): 퀘스트 창의 「시작 가능」 탭 · 월드맵 1 · 2지역(내 자리 · 레벨 · 「!」 · 풀빛 사냥터) — `dev/QUEST_1_tabs.jpg` · `MAP_1_region1.jpg` · `MAP_2_region2.jpg`. 전직의 무기는 Play에서 보지 않았다(자동 검사만).
          ✔ S55 맵에 놓인 것 앞에서 ↑를 누르는 퀘스트(메이플의 「살펴보기」 퀘스트) — 1지역의 부탁 둘이 열렸다(부탁 9/10): 「할아버지의 옛이야기」(Lv.18 · 고갯마루 노인 → 무너진 다리 r1b3의 돌무더기 밑의 샘 → 노인) · 「수비대의 깃발」(Lv.22 · 보름 영감 → 망루 1층 r1c1의 상자 → 보름 영감).
              설계: `questplay.js` `SPOTS`(scene · x · y · up(「!」의 높이) · name · act) · 할 일 `{ use: 이름, n, spot }` → 게임의 `{ type = "use", spot, place, act, x, y, up }`. 자리는 그 맵에 이미 그려져 있는 돌무더기 · 상자다(샘 · 깃발의 그림은 따로 없다 — 내 제안). 규칙 검사: 자리가 그 퀘스트의 맵 안 · 글의 길이 · 높이.
              셈: `Quests.spotsIn(book, scene)` · `Quests.use(book, id, scene, x, y)`(가로 30 · 세로 24점 안 — `USE_REACH`) · 길잡이 「무너진 다리 — 돌무더기 밑의 샘 앞에서 ↑」. 서버: `Quest("use", id)`. 화면(`boot.luau`): 그 자리 위에 주민의 것과 같은 「!」가 까딱이고, 가까이 서면 「↑ 물을 뜬다」 · ↑를 누르면 글이 떠오르고 표시가 사라진다 · 알리미는 「고갯마루 노인에게 간다」. 스마트폰: 상호작용 단추의 글 「살펴보기」(`touch.luau`).
              ↑의 차례: 문 → 퀘스트의 자리 → 주민(자리는 문 · 주민에게서 60점 넘게 떨어져 있어야 한다 — 검사 28). 확인용 `Debug("npc", n)`(이 장면의 n째 주민 앞) · `Debug("spot", n)`(n째 자리 앞).
              확인: 자동 검사 194,517개 통과(셈 28 · 그 자리에 걸어서 닿는지 25 · 서버 13). Play(`axion:22`): 노인에게 말을 걸어 받기 → 샘 앞의 「!」와 「↑ 물을 뜬다」 → ↑ → 「물을 뜬다」 · 알리미 「고갯마루 노인에게 간다」 → 노인에게 돌려줌 / 깃발도 같은 흐름(받기는 패킷으로). 「!」가 상자 더미의 통과 벽 횃불에 겹쳐 자리를 왼쪽 상자 위로 옮김(x 248 → 236 · 높이 34) — `dev/SPOT_1_spring.jpg` · `SPOT_2_spring_done.jpg` · `SPOT_3_flag.jpg`. 콘솔 오류 없음.
              못 본 것: 스마트폰의 「살펴보기」 단추(코드만) · 깃발을 보름 영감에게 돌려주는 것(자동 검사는 같은 길을 노인의 퀘스트로 봄) · 시험 탭에는 넣지 않았다(게임에만 — 조작의 느낌이 아니라 「!」와 글 한 줄이라 그렇게 판단).
          ✔ S56 월드맵에 은달 항구 · 물마루 바다, 다른 지역으로 이어지는 곳, 가는 길 — S53의 지도에는 지역 넷만 있어, 2차 전직 뒤 2지역으로 가는 길(수비대 야영지 → 성문 거리 → 달맞이 광장 → 장터 거리 → 부두 → 반달 나루)이 지도에 없었다.
              자리: `continents.js` `WORLDMAP_MORE`(city 여섯 장 · sea 열 장 — x · y는 journey.js와 같은 자, links는 게임의 문과 같아야 한다 — 규칙 검사 · 검사 28) → `worldmap.generated.luau`의 order = r1 · city · r2 · r3 · r4 · sea.
              셈(`shared/lune/ui/worldmap.luau`): `exits(rid)` · `exitsOf` · `rows`(마디 아래의 줄: 이름 · 레벨 · 「→ 은달 항구」 — 세 줄까지 `ROWS_MAX`) · `path(from, to)`(문을 가장 적게 지나는 길) · `route`(그 길의 마디들) · `routeText`(다섯 곳을 넘으면 앞의 둘 · … · 뒤의 둘) · `goalText` / `goalLine` · `recommendLine`(그 지역의 사냥터가 모두 내 레벨보다 높으면 권하지 않고 「이 지역의 사냥터는 Lv.47부터(갯바위 해변)」).
              퀘스트(`sim/quests.luau`): `npcScene(def, npcId)` · `endScene(def)` · `goal(book, level)` = 지금 가야 할 곳 — 하는 중인 전직 · 메인의 맵("do") / 다 했으면 돌려받는 주민이 선 곳("back") / 없으면 받을 수 있는 다음 메인을 주는 주민이 선 곳("take") / 레벨이 모자라면 nil.
              화면(`ui/mapWindow.luau`): 탭 여섯 · 이어지는 맵 아래의 「→ 은달 항구」(민트 — 누르면 그 지역의 그림으로 넘어가 닿는 맵을 고른다) · 가는 길의 선은 금빛 · 닿는 맵의 이름도 금빛 · 아래 글 넷째 줄 「「마을 밖의 그림자」 받으러 가는 길: 고갯마루 주막 → 굽잇길 → … → 마을 어귀 → 초승달 마을」(그 맵에 있으면 「지금 있는 맵에서 받는다」). 오른쪽 위의 「지금 있는 곳」 글은 뺐다(탭이 여섯이라 — 내 자리는 민트 테두리로 본다).
              확인: 자동 검사 195,173개 통과(탭의 폭 · 줄의 폭 · 이어지는 곳과 돌아오는 길 · 길의 걸음마다 문 · 가는 길의 글을 메인 · 전직 퀘스트마다 지도의 모든 맵에서 재서 창의 폭 안). Play(`axion:30`): 1지역의 「→ 은달 항구」를 눌러 도시의 그림으로 / 도시 · 바다의 탭 / 무너진 다리에서 연 지도의 금빛 길과 넷째 줄 — `dev/MAP_3_route.jpg` · `MAP_4_city.jpg` · `MAP_5_sea.jpg`. 콘솔 오류 없음.
              못 본 것: 1지역을 다 끝낸 캐릭터로 도시를 지나 2지역으로 가는 금빛 길(자동 검사는 그 길이 은달 항구를 지나 수정 숲에 닿는 것을 본다) · 스마트폰의 지도 창.
          ▶ 2026-10-11 사용자: "스스로 검증해보세요 게임을 시작해서 30까지 찍는걸 유저가 자연스럽게 플레이할수있는지"
          ✔ S57 처음부터 2차 전직까지 해 봄 — 두 가지로.
              ① 진짜 플레이(Studio · `LuneGuest = "new"` · 확인용 명령 없이 키와 마우스만): 제목 → 캐릭터 만들기(리틀 액시온 · 이름 MoonAxe · 중복 확인) → 사당 → 사제 → 능력치 「자동으로 찍기」 · 스킬 「추천대로 찍기」 → 샛별(메인 + 부탁) → 마을 어귀에서 사냥 · 줍기 · 물약 → Lv.3 → 돌려주기 → Lv.4 → 촌장의 집에서 「빈 갑옷」 → 달그림자 사냥터. 약 25분.
                 막힌 곳 없음: 안내 글이 그때그때 맞게 바뀌고(걷기 → 능력치 → 스킬 → 문 → 뛰기 → 공격 → 줍기 → 물약), 알리미가 다음 퀘스트와 받는 곳을 알려 준다. 쓰러졌을 때의 상자 → 「마을로 돌아간다」도 됨(경험치는 안 깎임).
                 Lv.4에 달그림자 사냥터 입구에서 한 번 쓰러짐 — 내 입력 사이의 빈 시간(화면을 보고 다음 키를 보내는 수십 초)에 캐릭터가 서서 맞은 것. 손으로 하는 플레이는 위험을 재는 데 쓸 수 없다 → ②를 만듦.
                 본 것(고치지 않음 — 여쭘): 달그림자 사냥터의 입구 앞(x 160~208)에 검병 Lv.3 · 궁병 Lv.4 · 폭탄병 Lv.5 · 창병 Lv.5 넷이 한자리에 뭉쳐 나온다 / 문을 지나쳐 맵 끝(문에서 27점)에 서면 ↑가 듣지 않는다.
              ② 가상의 플레이(`tools/test/tests/29_lune_playthrough.luau` — 진짜 서버의 셈 위에서 한 순간도 쉬지 않는 플레이어: 길잡이대로 퀘스트를 받고 돌려주고 · 그 맵에서 사냥기만 쓰고 · 줍고 · 더 좋은 장비를 끼고 · 체력 절반에 물약 · 물약이 다섯 병 아래면 상점 · 레벨업마다 자동 찍기 · 정해진 레벨에 대장장이(제작 → 상점 → 강화) · 쓰러지면 마을로).
                 늘 도는 것은 액시온 Lv.8까지(몇 초). 끝까지: `LUNE_PLAY=axion,riven,reaper,mooni,salamander python tools/test/run.py 29_lune_playthrough`(20초쯤 · `axion0` = 대장장이에 안 들름 · `LUNE_PLAY_XP=2` = Lv.10부터 경험치 두 배로 쳐 보는 만약에).
                 결과(쉬지 않고 · 2차 전직까지): 살라맨더 3:17 · 리퍼 3:47 · 리븐 4:15 · 액시온 4:34 · 무니 4:38 — 다섯 직업 모두 퀘스트 19개(메인 9 · 부탁 9 · 전직)를 끝내고 막히지 않는다.
                 구간(액시온): Lv.10까지 13분(잡은 수 130 · 물약 18) / Lv.20까지 1:42 / Lv.30까지 4:28. Lv.20~30이 2시간 46분 — 한 레벨에 20~43분 · 150~300마리.
                 퀘스트가 없는 구간(액시온): Lv.14 → 18에 35분 · Lv.18 → 20에 24분 · Lv.22 → 25에 1시간 반 · Lv.26 → 28에 한 시간(그 사이는 사냥뿐).
                 물약: 액시온 625 · 무니 669 · 리븐 585 · 살라맨더 259 · 리퍼 65병. 위험한 곳 = 굽잇길(10분에 26~34병 · 다섯 직업 가운데 넷이 한 번씩 쓰러짐)과 망루 1~3층(근접 셋은 10분에 21~49병 · 쓰러짐 3~5번). 무너진 다리는 10분에 0.3~2병. 달돈은 남는다(끝에 85,000~92,000).
                 장비: 대장장이에 아홉 번 들러 제작 · 상점 · 별 75개를 붙여도 4:34(떨어진 장비만 끼면 5:01) — 1지역의 장비와 강화는 빠르기에 10%쯤만 보탠다.
                 설계와 견줌: 설계(`numbers.js` minutesAt)는 1지역 5시간 — 잰 것과 같은 크기다. 즉 고장이 아니라 설계가 그 길이다.
                 만약에(설계는 안 고침): Lv.10부터 경험치 x2 → 1:40~1:58 · 잡은 수 700 · 물약 100~200 / x3 → 1:13~1:18.
              고치지 않은 것(정해 주실 것 — devplan 맨 위): Lv.30까지의 길이(지금 3~5시간) · 굽잇길과 망루의 피해 · 달그림자 사냥터 입구의 몬스터 뭉침.
          ▶ 2026-10-11 사용자의 답(S57을 보고): "지금 우측 상단에 있는 퀘스트 퀘스트라는 인식이 되지가 않아요 ui 만들어서 퀘스트처럼 보이게하세요, 월드맵 똑바로 그리세요 다른 게임 월드맵 참고라도 하던가 퀄리티가 이게 뭡니까 없는게 나은수준인데
             그리고 레벨업 했을때 능력치, 스킬 찍으라고 계속 글씨뜨는거 이거 빼세요 맨처음 튜토리얼때 가르쳐주는거지 계속적인 알림을 보내는게 아닙니다. 그리고 초반 퀘스트 아이템 드롭률 낮아서 퀘스트 깨는데 너무 오래걸립니다.
             그리고 lv 30 까지는 쉽게 찍을수있게하세요 지금보다 난이도가 조금더 낮게 검병,궁병,폭탄병, 창병 나누는게 맞습니다. 그리고 폭탄병 지혼자 터져서 없어지는거 없어야합니다. 공격하고 사냥당하는 일반 몬스터여야하는거에요"
          ✔ S58 그 일곱 가운데 여섯(월드맵은 S59):
              ① 퀘스트 알리미 = 판이 있는 UI — `shared/lune/ui/questPanel.luau`(줄의 차례 · 높이 · 폭의 셈) + `client/lune/questHud.luau`(그리기): 창과 같은 어두운 판 · 머리줄(「!」 + 「퀘스트」 + 진행 N) · 갈래의 표(메인 노랑 · 전직 민트 · 부탁 회색)와 이름 · 할 일의 글과 「3/8」과 진행 띠 · 다 했으면 「?」 + 돌려줄 사람(풀빛) · 「받을 수 있는 퀘스트」.
                 칸의 높이 98 → 150(`basics.js` HUD 4번 · 스마트폰은 손가락 단추에 닿지 않게 98 그대로 — HUDTOUCH의 h). 자동 검사 27이 모든 퀘스트의 글이 판 안에 들어가는지 본다.
              ② 조작 안내는 맨 처음에만(`shared/lune/ui/guideText.luau`): 첫 사냥 퀘스트 「마을 밖의 그림자」를 돌려주면 그 뒤로는 아무 안내도 뜨지 않는다. 능력치 · 스킬을 찍으라는 글은 처음 점수를 받은 Lv.2에서만.
              ③ 1지역의 모으는 퀘스트는 잡을 때마다 하나(`questplay.js` — 아홉 개의 pct 40~60 → 100: 갑옷 조각 · 찢어진 명령서 · 기름 천 · 젖지 않은 종이 · 보따리 · 달맞이꽃 · 폭탄 껍데기 · 쇠 경첩 · 달빛 서린 조각).
              ④ Lv.30까지 쉽게(`numbers.js` CURVE — 수치는 내 제안 · `config/numbers.luau`도 같은 식): ease.upto 15 → 30(몬스터의 체력을 덜어 주는 구간) · soft.time(한 레벨에 드는 시간의 배수: Lv.6까지 1 → Lv.14에 0.5 → Lv.29까지 0.5 → Lv.45에 다시 1) · soft.hit(일반 몬스터의 한 방: Lv.29까지 0.7 → Lv.45에 1).
                 필요 경험치가 앞 레벨보다 줄면 안 되어(규칙 검사) 천천히 내린다. 지역의 시간 5 · 24 → 3 · 22시간(`world.js` GROWTH).
                 다시 잰 것(가상의 플레이 · 쉬지 않고 2차 전직까지): 살라맨더 1:54 · 리퍼 2:09 · 리븐 2:12 · 무니 2:15 · 액시온 2:21(전 3:17~4:38) · 잡은 수 1,030~1,070(전 1,900~2,200) · 쓰러짐 0~1(전 0~6) · 물약 4~154병(전 65~669). 액시온: Lv.10 0:11 · Lv.20 0:55 · Lv.30 2:16.
              ⑤ 몬스터를 종류마다 나눔: 달그림자 사냥터(`tools/build_lune_demo.mjs`) = 시작 평지와 위층 검병 넷 / 가운데 둔덕 궁병 셋 / 가시 구덩이 너머 폭탄병 둘 / 그 옆 큰 달버섯 셋 / 맨 오른쪽 창병 셋(15마리 그대로 · 평지의 검병은 문에서 4.6칸 밖부터).
                 (2026-10-14부터는 MOB_ZONE 대신 `MOB_ONE` — 한 맵에 한 종류라 나눌 것이 없다)
                 다른 맵(`maps.js` MOB_ZONE — 자리는 그대로, 들어서는 쪽부터 종류를 모아 준다): 마을 어귀 · 사냥터 깊은 곳 · 버려진 야영지 · 고갯길 초입 · 굽잇길 · 망루 아래 · 망루 1층 · 3층. 망루 2층은 궁병의 자리가 벽의 난간이라 그대로.
              ⑥ 폭탄병 · 포자 주머니는 터뜨려도 사라지지 않는다: `combat.js` bomber(cd 0 → 2.4 · 한 방 1.6 → 1.2) · `monsters.js` puff(cd 2.4 · 1.5 → 1.1) · `sim/room.luau`(둘레가 맞고 끝 — 죽지 않는다 · 맞으면 멈칫 · 잡히면 경험치와 물건) · `mobsView.luau`(터지는 그림에는 몸이 없어, 터진 장부터는 서 있는 몸을 밑에 그린다 — `under`) · 시험 탭 `luneTab.js`도 같게. 「Burst」 패킷은 없앰.
              확인: 규칙 검사 통과 · 자동 검사 195,455개 통과. Play(`axion:5`): 알리미의 판(메인 2/5 · 부탁 2/5 · 진행 띠) · 마을 어귀의 수습 검병 셋이 왼쪽에 · 기름 천이 잡을 때마다 · 달그림자 사냥터의 시작 평지에 검병만 · 폭탄병 둘이 8초 동안 되풀이해 터뜨리고 그대로 서 있음(터지는 62장 모두 밑에 몸이 있음) — `dev/QUESTHUD_1_panel.jpg` · `HUNT_1_zones.jpg`.
              못 본 것: 스마트폰의 알리미 판 · 포자 주머니의 터지는 모습(게임에서) · 시험 탭의 포자 주머니 · 다시 나눈 다른 맵들을 걸어 보는 것.
          ✔ S59 월드맵을 그림으로 — S53 · S56의 도표(네모를 선으로 이은 것)를 버림("없는게 나은수준").
              참고: 메이플스토리의 월드맵(그림으로 된 지역 지도 위에 장소의 표시 · 길 · 내 위치 · 고르면 그 맵의 몬스터와 주민). 웹 검색으로는 쓸 만한 설명을 찾지 못했다(검색 셋 — 기록은 대화에).
              그림: `assetpack/lune/worldmap/prompt_r1.txt` → Codex → `raw_r1.png`(1536x1024) → `node tools/build_lune_worldmap.mjs` → `r1.png`(384x256 — 4x4화소의 평균 밝기를 게임의 청회색 열여섯 단으로 · 민트 · 분홍 불빛은 그대로 · 외톨이 점을 지움) · `r1_view.png`(세 배).
                 한 장의 파노라마: 왼쪽 아래 초승달 마을 → 문 → 죽은 숲 → 세 갈래 길 → (아래) 깊은 숲 → 버려진 야영지 / (오른쪽 위로) 고갯길 초입 → 굽잇길 → 고갯마루 주막 → (능선을 따라 왼쪽으로) 무너진 다리 → 망루 아래 → 수비대 야영지 → 옛 망루. 왼쪽 위에 달, 그 아래 멀리 은달 항구.
              자리: `journey.js` `WORLDART`(size · r1.at = 장소 14곳의 [x, y] — 그림을 보고 손으로 적음 · out = 나가는 곳의 이름표) → `worldmap.generated.luau`의 regions.r1.art · artSize. 올린 그림 `worldmap_r1.png` = rbxassetid://102843140318075.
              창(`ui/mapWindow.luau` — 새로 씀): 왼쪽 그림 위에 동그란 표시(갈래의 색) · 내가 있는 곳(민트 고리 + 화살표 + 이름표) · 퀘스트 「!」「?」 · 내 레벨의 사냥터(풀빛 고리 + 이름표) · 가야 할 곳까지 금빛 점줄 · 마을과 쉼터의 이름은 늘, 나머지는 마우스를 올리거나 눌렀을 때 · 「← 은달 항구」.
                 오른쪽 글 칸(190점): 지역 이름 · 레벨 / 고른 장소의 이름 · 갈래 · 레벨 · 몬스터 · 주민 / 내 레벨의 사냥터 / 가는 길(「「마을 밖의 그림자」 받으러」 + 「고갯길 초입 → … → 마을 어귀 → 초승달 마을」).
                 그림이 있는 지역만 보여 준다(`WM.arted()` — 지금은 초승 고개 하나 · 탭 없음). 은달 항구 · 2~4지역 · 바다는 그림을 그리면 탭이 생긴다(자리 자료와 길의 셈은 그대로 있다).
              셈(`shared/lune/ui/worldmap.luau`): `arted` · `card` · `regionLevels` · `recommendShort` · `goalCard` / `goalCardOf` · `ROUTE_MAX` 5 → 4(앞의 하나 · … · 뒤의 둘 — 글 칸의 두 줄에 들어가게).
              확인: 규칙 검사 통과(자리가 그림 안 · 표시끼리 12점 넘게) · 자동 검사 195,573개 통과(글 칸의 줄 수 · 가는 길을 지도의 모든 맵에서). Play(`axion:12` · 굽잇길에서 M): 그림 · 표시 14 · 내 자리 · 금빛 점줄 · 풀빛 사냥터 · 마우스를 올리면 이름 · 누르면 오른쪽 글이 바뀜 — `dev/WMAP_1_region1.jpg` · `WMAP_2_pick.jpg`. 콘솔 오류 없음.
              못 본 것: 스마트폰의 지도 창 · 퀘스트 「!」「?」가 그림 위에 뜬 모습(손님 캐릭터의 받을 퀘스트는 마을이라 금빛 이름표와 겹쳐 봄) · 다른 지역의 그림(아직 없다).
          ▶ 2026-10-11 사용자(S59의 창을 직접 열어 보고 · 사진): "바위틈 같은 사냥터 표시안되고, 은달항구의 경우 지금 수비대 야영지에서 포탈로 갈수있는데 맵에서는 그냥 좌측 은달항구라고 나와버리면 어떻게 하라는건지?"
          ✔ S60 월드맵 고침:
              ① 곁맵도 싣는다 — 「바위 틈」 = 굽잇길의 문 「바위 틈으로」로 들어가는 옛 은신처(r1bh). 멧돼지 굴(r1bl)도. 전에는 몬스터도 주민도 없는 막다른 곳이라 지도에서 뺐다(그 안에 있으면 내 자리가 굽잇길로 나왔다).
                 `WORLDART.r1.at`에 자리를 적은 곁맵은 내보낸다(`export_lune_game.mjs` — 그림이 없는 지역의 숨은 방은 여전히 빠진다). 1지역의 마디 14 → 16.
              ② 은달 항구 = 그림 위의 표시 — 왼쪽의 글 「← 은달 항구」를 없애고, 도시가 그려진 자리에 민트 표시와 이름표를 놓고, 그리로 가는 포탈이 있는 수비대 야영지에서 민트 점줄로 잇는다(`WORLDART.r1.out.city = [50, 126]` · `WM.exits`).
                 수비대 야영지를 고르면 오른쪽에 「은달 항구로 가는 포탈이 있다」(`WM.linkText`), 은달 항구를 고르면 「수비대 야영지의 포탈로 간다」(`WM.outCard`). 가는 길(금빛 점줄)이 다른 지역으로 넘어가면 그 표시까지 잇는다.
              ③ 모든 장소에 이름표 — 전에는 마을 · 쉼터 · 내 자리 · 가야 할 곳 · 내 레벨의 사냥터만 이름이 보였다(사냥터는 흰 점뿐). 이제 열일곱 개가 모두 보인다: `WM.placeLabels`(내 자리 → 가야 할 곳 → 내 레벨의 사냥터 → 고른 곳 → 마을 · 쉼터 → 나머지의 차례로, 아래 · 위 · 옆 스물두 자리를 대 보고 서로도 표시와도 겹치지 않는 첫 자리에). 이름표를 눌러도 고른다. 마우스를 올렸을 때의 이름표는 없앰.
              확인: 규칙 검사 통과 · 자동 검사 287,554개 통과 — 이름표 열일곱 개가 어느 장소에 있든 다 놓이고 겹치지 않는지 · 지도 창을 화면 없이(가짜 UI 부품) 모든 맵 x 퀘스트 세 가지에서 그려 보고 모든 표시와 은달 항구를 눌러 오른쪽 글을 봄(28).
              **게임 화면으로는 못 봤다**: 그때 사용자가 Studio에서 직접 Play 중이라 건드리지 않았다. 대신 그림 위에 표시와 이름표의 자리를 얹은 미리 보기(`dev/WMAP_3_preview.png` — 글꼴은 게임의 것이 아니다)를 봄. 다음에 Play로 확인할 것.
                 → S61의 Play에서 화면으로 봄(`dev/WMAP_4_button.jpg` · `WMAP_5_route.jpg`): 장소 열여섯 + 은달 항구의 표시와 민트 점줄 · 옛 은신처 · 멧돼지 굴 · 모든 이름표 · 마을 어귀 → 옛 망루의 금빛 길과 오른쪽의 「달그림자 사냥터 → … → 수비대 야영지 → 옛 망루 1~3층」.
          ▶ 2026-10-11 사용자(오른쪽 아래의 단추 사진과 함께): "이 기본 버튼에 월드맵도 있어야합니다. 메뉴를 누르고 월드맵누르는게 아니라 / 정예검병 이런 그냥 검병이랑 같은 몬스터 디자인을 돌려쓰는 경우에 그냥 돌려쓰는게 아니라 주위에 화려한 이펙트라던가 좀 구분되어지게 몬스터를 작업해야합니다. / 저만 쓸수있는 어드민용 탭 만들어주세요 다른 유저들에게는 보이지않고, 어드민만 보이는 어드민관리탭 만들어주시고, 경험치 배율증가, 레벨 조정, 아이템발급 등등 여러 테스트용 편의 기능 넣어서 만들어주세요 누군가 해킹같은거해서 사용도 못해야하고 오직 어드민만 사용할수있어야합니다."
          ✔ S61 기본 단추의 월드맵 · 그림을 빌려 쓰는 몬스터의 겉모습 · 관리 창:
              ① 월드맵 단추 — 오른쪽 아래의 그림 단추 여섯 → 일곱(가방 · 장비 · 능력치 · 스킬 · 퀘스트 · 월드맵 · 메뉴). `basics.js` HUD 8번(x 686 · w 258) · `ui.js` menu.max 7 · 그림 `menu_map`(Codex — `assetpack/lune/ui/prompt_menu_map.txt` → `raw_menu_map.png` → `menu_sheets.json`) · `hud.luau` MENU_PIC.map · `boot.luau` MAIN에 map. 「메뉴」 안에는 파티 · 키 설정 · (관리) · 캐릭터 선택 · 소리. `ui_kit.png`을 다시 올림 = rbxassetid://82709939441916.
              ② 그림을 빌려 쓰는 몬스터의 겉모습(`combat.js`의 `look`) — 규칙: `sprite`가 제 이름과 다른 몬스터는 `look`이 있어야 한다(`check_lune_design.mjs`가 막는다 · 테스트 24도).
                 정예 검병 · 정예 창병 · 정예 궁병 = `{ tint: '#ff8fc0', aura: '#ff3e9f', embers: '#ff7ea2' }` — 몸의 그림에 색을 곱하고(어두운 몸은 그대로, 흰 눈 · 뿔 · 날이 분홍) · 윤곽의 빛(한 점씩 비낀 실루엣 넷이 숨 쉬듯 밝아졌다 어두워진다) · 불티 다섯(피어오를 때 두 점, 길의 45%를 넘으면 한 점, 1.3초에 스무 점 떠오르며 사라진다). 수습 검병 = `{ tint: '#9fb0c4' }`(빛 없이 바랜 색만).
                 게임: `mobsView.luau`의 `glowOf` · `embersOf` · `drawLook`(쓰러지면 꺼진다) · 내보내기는 색을 [r, g, b]로. 시험 탭: `luneTab.js`의 `multiplied` + 같은 셈.
                 불티는 처음에 한 점짜리 셋이었다 — Play에서 거의 보이지 않아 다섯(두 점 → 한 점)으로 늘림. 색 · 세기 · 수는 내 제안. 정예의 공격 동작은 아직 본디 몬스터와 같다(팩의 안 쓰는 동작을 주는 일은 남음).
              ③ 관리 창(어드민) — 지키는 법은 `server/lune/modules/admin.luau`의 머리말에.
                 누가 관리자인가: `Admin.IDS = { [10311679477] = "dolupa95" }` 또는 게임의 주인(`game.CreatorType == User and game.CreatorId == UserId`). 서버만 가린다(파일이 ServerScriptService에 있다). 관리자를 더하려면 IDS에 계정 번호를 적는다.
                 명령: 패킷 `Admin`(RemoteFunction · 1초에 6번 · 한꺼번에 10번) → `world.luau`의 `onAdmin(player, what, a, b, c)` — 올 때마다 `Admin.is(player)`를 다시 보고 아니면 nil. 값은 서버가 범위를 다시 본다.
                    `xp`(1 · 2 · 5 · 10 · 50 · 100) · `dmg`(1 · 5 · 20 · 100) · `god`(true/false) · `heal` · `level`(1~MAX) · `job`(그 레벨에 열린 차수까지) · `skills`("max"/"reset") · `stats`("reset") · `money`(1~1억) · `dust`(1~100만) · `gear`(단계 · 성능 1~5 · 별 — 장비 칸 다섯이 비어야) · `goods`(이름표 · 1~999) · `quests`("fill") · `goto`(장면의 이름).
                    배율과 무적(`h.xpBoost` · `h.dmgBoost` · `h.god`)은 `Hero.pack`에 없어 저장되지 않는다. 레벨 · 달돈 · 장비는 그 캐릭터에 저장된다. `Hero.setLevel(h, level, job?)` · `maxSkills` · `resetSkills` · `resetStats`를 새로 만듦.
                 창(`client/lune/ui/adminWindow.luau` — 356x300 · 탭 넷 성장 · 아이템 · 이동 · 전투 · 단추의 이름 `Do_<id>` · 탭의 이름 `Tab_<grow|item|move|fight>`): 서버가 내 상태에 `admin = { xp, dmg, god }`을 실어 준 사람에게만 「메뉴 → 관리」가 보인다(`boot.luau`의 `isAdmin`). 창의 코드는 누구에게나 내려가지만 관리자가 아니면 눌러도 서버가 듣지 않는다(아래 줄에 「서버가 듣지 않았다(관리자가 아니다)」).
                 Play에서 내가 쓸 때: `R.Admin:InvokeServer("goto", "r1c1")` · `("level", 30)` · `("god", true)` — Studio의 계정이 dolupa95라 손님 캐릭터로도 된다(옛 `Debug` 명령은 Studio에서만 듣는다 — `inStudio()`).
              ④ 같이: 오른쪽 창이 열린 동안 퀘스트 알리미를 감춘다(`Windows.sideOpen("right")` → `QuestHud.setCovered`) — 창의 바탕이 살짝 비쳐서(panelAlpha 238) 알리미의 글이 창의 글 뒤로 겹쳐 보였다.
              확인: 규칙 검사 통과 · 자동 검사 288,467개 통과 — `30_lune_admin`(관리자가 아닌 사람의 명령 17가지에 nil이고 아무것도 안 바뀜 · 관리자의 명령과 값의 범위 · 배율이 저장되지 않음 · 관리 창을 화면 없이 띄워 네 탭의 단추를 관리자와 관리자가 아닌 사람으로 모두 누름) · `24`(겉모습).
                 Play(`axion:22` · dolupa95): 단추 일곱 · 월드맵 단추 → 지도 · 메뉴의 「관리」 · 레벨로 바로 30 · 경험치 x10 · 달돈 +100만 · Lv.20 장비 한 벌(가방에 다섯 점) · 달빛 물약 +50 · 이동 탭 → 망루 1층 · 무적 켜기 · 피해 x20 · 정예 검병의 분홍빛과 불티 · 창을 열면 알리미가 사라지고 닫으면 돌아옴. 콘솔 오류 없음. 그림: `dev/ADMIN_1_grow.jpg` ~ `ADMIN_4_fight.jpg` · `ELITE_1_look.jpg` · `WMAP_4_button.jpg` · `WMAP_5_route.jpg`. 시험 탭(`?lunescene=r1c1#lune`)의 정예 검병도 머리 없는 브라우저의 사진으로 봄.
              못 본 것: 관리자가 아닌 계정으로 실제로 들어와 보는 것(자동 검사로만) · 배율을 켠 채의 사냥 · 정예 창병 · 정예 궁병의 화면 · 수습 검병의 바랜 색(차이가 작다) · 스마트폰.
              물어 둔 것: 정예의 겉모습이 이만하면 되는지 · 관리 명령으로 올린 캐릭터가 명예의 전당에 오르는 것 · 관리자를 더 둘지.
          ▶ 2026-10-11 사용자: "점프하고 바로 점프 즉 2단점프가 가능하게해주세요 전 직업입니다. / 스킬마다 예를들면 샐러맨더 열기 이런거 캐릭터 아래에 게이지 보여주는 스킬들이있는데 이게 닉네임이랑 겹쳐서 가려버리는 문제가있습니다. / 망루에서 하단점프가 안되는 영역이있습니다. / 퀘스트가 퀘스트를 부여해주는 npc 랑 말을하고 퀘스트를 수락해야 퀘스트가 수락되고 완료도 다 깨고 npc랑 대화해야 깨지고 이렇게 정석적으로 되어야합니다 / 어드민 기능으로 이동후에 포탈이용 불가능합니다. 똑바로 만드세요 / 게임 시작시, 포탈 이용시 페이드 아웃 로딩 걸고 그 사이에 이미지 정확히 다 로드 해야합니다. 지금 그냥 포탈로 넘어간다음에 이미지들 로드 안되서 바로 안뜹니다."
          ✔ S62 여섯 가지:
              ① 2단 점프(전 직업) — 공중에서 뛰기를 한 번 더 누르면 다시 뛰어오른다. 발판에서 걸어 떨어진 뒤에도 한 번, 땅에 닿으면 다시 센다. 두 번째는 첫 번째의 85%(내 제안 — 한 번 57점 → 꼭대기에서 한 번 더 98점쯤).
                 `config/game.luau` AIR_JUMPS 1 · JUMP2 0.85 · `sim/physics.luau`(body.air) · 화면의 효과 `Effects:hop`(발밑에서 흩어지는 점 여섯) · 시험 탭 `luneTab.js`(같은 숫자). 뛰는 힘의 배수(패시브)는 두 번째에도 든다. 바닷속에서도 된다.
              ② 열기 막대(살라맨더) — 발밑 3점 → 발밑 10점(`kits/common.luau` · `common.js`의 GAUGE_DOWN): 이름표(발밑 2~9점)의 바로 아래. 이름표는 움직이지 않는다. 캐릭터 아래에 그리는 막대는 열기 하나뿐이었다(다른 직업의 장치는 몸 둘레 · 머리 위).
              ③ 망루의 하단 점프 — 원인: 층 바닥이 통째로 막힌 칸(#)이라 구멍의 나무 발판 네 칸에서만 내려갈 수 있었다. `maps.js` towerFloor가 `thin`(층 바닥의 줄)을 주고 `build_lune_maps.mjs`가 내보낼 때만 얇은 발판(=)으로 바꾼다 — 그림과 놓는 자리는 돌바닥 그대로(올려야 하는 그림 0장).
                 망루 1~3층 · 종탑(r2c3) · 망대(r4b3). 맨 아래층은 땅이라 그대로. 얇은 발판이 됐으니 아래에서 뛰어 올라탈 수도 있다(층 사이가 96점이라 2단 점프를 꼭대기에서 눌러야 닿는다).
              ④ 퀘스트는 주민에게 말을 걸어 받는다 — 저절로 받던 둘을 없앴다: 「첫 기술」(새 캐릭터) · 전직 퀘스트(Lv.30). 둘 다 그믐 사제가 준다(받을 때의 말은 내가 채움).
                 `questplay.js`의 auto를 뺐고 검사가 auto를 막는다. `sim/quests.luau`: `Q.start`는 빈 표 · `isNew`(받기 전에도 새 캐릭터) · `openJobs` · `guide`(길잡이 맨 위에 「! 2차 전직 — 그믐 사제에게 받는다 · 달의 사당」) · `listOpen` · `goal`(월드맵의 가는 길) · 전직 퀘스트는 사제가 어느 지역에서든 준다.
                 화면: 「달이 부른다」는 받을 수 있게 된 때 뜬다(「그믐 사제에게 가서 「2차 전직」 퀘스트를 받는다」) · 받으면 머리 위에 「○○ 수락」 · 조작 안내 「↑ 키: 그믐 사제에게 말을 걸어 「첫 기술」을 받는다」 → 「한 번 더 말을 걸어 「첫 기술」을 끝낸다」.
                 「첫 기술」은 할 일이 없어 받자마자 돌려줄 수 있다(말을 두 번 건다). 끝내는 것은 전에도 주민 앞에서만 됐다(서버가 자리를 본다).
              ⑤ 관리 이동 뒤의 문 — **같은 증상을 재현하지 못했다**(Play에서 관리 이동 뒤 문을 열 번 넘게 지나 봄 · 장면 98곳으로 옮겨 봄). 대신 어긋날 수 있는 자리를 모두 막았다:
                 (가) 관리 이동 · 마을로 돌아가기도 문과 같은 길(아래 ⑥의 goScene)로 화면을 바꾼다. 장면을 그리다 오류가 나도 `state.busy`가 풀린다(전에는 켜진 채 남아 그 뒤로 아무것도 못 했다).
                 (나) 서버가 먼저 옮긴 직후 2초 동안, 옮겨 놓은 자리에서 먼 자리 보고는 받지 않는다(`s.stale` — 화면이 알기 전에 보낸 옛 장면의 자리).
                 (다) 관리의 「체력 채우기」가 쓰러진 캐릭터를 일으킬 때 화면에 알리지 않던 것(화면은 쓰러진 채 남아 움직이지도 문을 지나지도 못했다)을 고침 — `Raise`를 보낸다.
                 (라) 자동 검사: 모든 장면의 모든 문을 관리 이동 → 걸어가기 → 지나기(30의 7).
              ⑥ 막(페이드)과 그림 불러오기 — `client/lune/curtain.luau`(새로) + `boot.luau`의 `goScene`: 막을 치고(0.16초) → 막 뒤에서 새 장면을 그리고 → 그 장면이 쓰는 그림마다 4점짜리 조각을 막 뒤에 실제로 그려 「불러옴」(IsLoaded)이 다 설 때까지 기다리고 → 막을 걷는다(0.26초).
                 게임에 들어올 때 · 캐릭터를 바꿔 들어올 때 · 문 · 마을로 돌아가기 · 관리 이동 모두. 0.5초가 넘으면 오른쪽 아래에 점 셋. 가장 길게 8초(끝내 안 오는 그림은 다음부터 기다리지 않는다).
                 원인: 로블록스는 숨겨져 있거나 화면 밖에 놓인 그림을 미리 올려 두지 않는다 — 처음에 번호만 한꺼번에 불러 둔 것으로는 모자랐다. 잰 것: 처음 가는 맵 0.45~0.5초 기다림(누른 뒤 1초쯤에 다 열림) · 다시 가는 맵 0.06초(0.6초쯤).
                 서버: 옮긴 뒤 화면이 열릴 때까지(첫 자리 보고 · 첫 기술 — `arrived`) 피해를 받지 않는다(가장 길게 12초 — LOAD_GUARD). 거기서부터 보통의 들어선 뒤 보호 2.5초.
              확인: 규칙 검사 통과 · 자동 검사 290,963개 통과(10: 2단 점프 · 오르는 맵의 층 바닥 다섯 맵 모든 칸 / 13 · 17 · 18 · 27 · 28 · 30: 퀘스트를 새 규칙으로 / 30: 관리 이동과 문).
                 Play(dolupa95): 새 캐릭터(`new` — 살라맨더)로 제목 → 만들기 → 막 → 사당 · 사제에게 말을 걸어 「첫 기술」을 받고(수락) 다시 말을 걸어 끝냄 · 2단 점프(한 번 50점 → 두 번 94점 · 세 번째는 안 됨 · 점 흩어짐) · 관리 이동 → 문(키) → 망루 1층 꼭대기 → 돌바닥에서 ↓ + 점프로 아래층 · Lv.30에 길잡이 「! 2차 전직」 → 사제에게 받음(수락) · 열기 막대가 이름표 아래 · 처음 가는 맵 일곱 곳에서 막이 걷힌 뒤 늦게 뜬 그림 0개. 콘솔 오류 없음.
                 그림: `dev/QACCEPT_1_start.jpg` ~ `QACCEPT_6_job_accepted.jpg` · `TOWER_1_dropdown.jpg` · `GAUGE_1_below_tag.jpg`.
              못 본 것: ⑤의 원래 증상(어느 맵의 어느 문이었는지 모른다) · 실제 서버(느린 회선)에서의 불러오는 시간 · 스마트폰 · 시험 탭에서 손으로 2단 점프(탭이 뜨는 것만 봄) · 종탑과 망대의 하단 점프(자동 검사로만).
          ▶ 2026-10-11 사용자(스킬 창 사진과 함께): "드랍되는 아이템들 크기가 너무 큽니다. 다들 평균적으로 / 스킬 전부 마스터했는데 왜 1차에 남는 스킬포인트가 12 가있는건지? / 달돈 생긴거 너무 못생겼음 / 타격감이 너무 없음 어느정도는 구현해야할듯"
          ✔ S63 넷:
              ① 스킬 포인트 — 원인: 레벨업마다 3점씩 1차(Lv.2~29) 동안 84점을 받는데, 1차 스킬 여섯을 다 마스터하는 데는 72점이 든다(2차 +2 · 3차 +22~27 · 4차 +4~14점도 남게 돼 있었다).
                 고침: 그 차수의 스킬을 다 마스터하는 데 드는 만큼만 받는다(`sim/hero.luau`의 `spNeed` · `spEarnedIn(level, job, class)` · `spGain`) — 1차는 Lv.25에 72점을 다 받고 Lv.26~29에는 받지 않는다. 다 찍으면 남는 포인트 0. 저장된 캐릭터도 들어올 때 다시 셈한다. 설계의 글 `basics.js` SPRULE.
              ② 떨어진 것의 크기 — 장비 · 물건: 가방의 그림(18점)을 0.6배로(`Effects.DROP_SCALE` — 10.8점. 캐릭터의 키는 17점). 달돈 · 달가루: 12점 → 8점(아래 ③의 새 그림 그대로 — 줄이지 않는다).
              ③ 달돈 · 달가루의 그림 — 12점짜리는 Codex의 큰 그림을 줄인 것이라 뭉개져 있었다. Codex에 작은 시안을 다시 받아(`assetpack/lune/ui/prompt_drop8.txt` → `raw_drop8.png`: 금화 넷 · 수정 넷) 민무늬 금화와 곧게 선 수정을 보고 8x8에 옮겨 찍었다(`build_lune_ui.mjs`의 dropCoin · dropDust — 밝은 금 · 흰 빛 · 짙은 금).
                 Codex의 그림 자체는 8x8이 아니었다(11점쯤 · 빛 번짐) — 그대로 쓰지 못해 손으로 옮겼다. `ui_kit.png`을 다시 올림 = rbxassetid://93840173814932. 가방과 화면 위의 달돈 그림(18점)은 그대로다.
              ④ 타격감(`combat.js`의 `hit` — 숫자는 내 제안) — 맞는 순간마다: 몬스터가 하얗게 번쩍(0.08초 — 전에는 제 맞는 그림이 없는 몬스터만 번쩍였다. 시험 탭에는 원래 다 있었다) · 때린 쪽의 반대로 3점 밀렸다가 0.14초에 돌아옴(그림만) ·
                 맞은 자리에 퍼지는 불꽃(`fx.pop`)과 반대쪽으로 튀는 파편(2 → 3개 · 센 타격 5 → 6개) · 내가 때린 순간 내 캐릭터와 몬스터의 그림이 0.035초(센 타격 · 치명타 · 쓰러뜨린 타 0.06초) 멈칫 — 0.22초에 한 번만. 화면 흔들림은 넣지 않았다(연타하는 주력기에 흔들림 금지).
                 게임: `mobsView.luau`(`MobsView.hit` · 모든 몬스터에 흰 실루엣) · `cast.luau`(`Cast:hurt`) · `boot.luau`(Hits의 land · draw의 held). 시험 탭 `luneTab.js`의 hurt도 같은 숫자로.
                 소리: 타격감의 큰 몫인데 게임에 효과음이 없다(음악도 아직 올리지 못했다). CC0인 Ninja Adventure 팩의 소리에서 여덟 개를 골라(`music.js`의 `sfx` — 타격 셋 · 센 타격 · 쓰러뜨림 · 내가 맞음 · 달돈 줍기 · 물건 줍기) 배선해 두었다(`Music.sfx` · `Music.hit`).
                    파일은 `C:/YJS/Roblox/Assets/character/luna/music/_게임에 올릴 곡/lune_sfx_*.wav`에 모아 둠. 올리는 것은 사용자만 할 수 있다 → `node tools/build_lune_music.mjs '{"sfx_hit1":"번호", …}'`. 번호가 없으면 조용하다. 나는 소리를 못 듣는다 — 이름과 길이만 보고 골랐다.
              확인: 규칙 검사 통과 · 자동 검사 293,294개 통과(18: 다섯 직업 x 네 차수의 받는 포인트 = 드는 포인트 · 처음부터 키워 Lv.25에 1차 마스터 / 24: 모든 몬스터의 번쩍임과 밀림).
                 Play(`salamander:29` · 모두 마스터): 스킬 창 「스킬 포인트 0」 · 때리는 동안 흰 번쩍임(세 번에 11프레임)과 파편 · 달돈 8x8(24화면점) · 물건 10.8점(0.6배). 콘솔 오류 없음. 그림: `dev/SP_1_zero.jpg` · `DROP_1_coins.jpg` · `DROP_2_item.jpg` · `DROP_3_coin_art.png` · `HIT_1_shards.jpg`.
              못 본 것: 멈칫과 밀림의 손맛(사진으로는 알 수 없다 — 숫자만 맞는지 봄) · 효과음(올린 것이 없다) · 장비가 떨어진 모습(물건 하나만 봄) · 스마트폰 · 시험 탭에서 손으로 치는 것.
          ▶ 2026-10-11 사용자(S63의 달돈을 보고): "달돈 전혀 돈 같지 않고 그냥 노랑 동그란 과자같은데"
          ✔ S64 달돈 = 도는 주화 — 원인: S63에서 Codex의 시안 넷 가운데 민무늬 금화를 골라 내가 8x8로 줄여 찍었다(테두리도 각인도 없는 노란 원반).
              고침: Codex에 「테두리(림) · 초승달 각인 · 빛 · 네 장으로 도는 주화」를 다시 받아(`assetpack/lune/ui/prompt_coin_spin.txt` → `raw_coin_spin.png`) **손대지 않고 칸 그대로** 옮겼다 —
                 `tools/build_lune_coin.mjs`(새로): 그림의 도트 한 칸의 크기를 재고(24.85점) 칸마다 가운데의 색을 옮긴다 → `coin_spin.png`(앞 19x20 · 비스듬히 14x21 · 옆 6x21 · 비스듬히 14x21 — 칸 19x21) · `coin_spin_check.png`(원본과 나란히).
                 Codex는 10x10을 부탁해도 20칸쯤으로 그려 온다 — 그래서 그림은 그 칸 수대로 두고, 땅에는 0.45배로 놓는다(세로 9.5점쯤. 화면의 점이 세계의 도트보다 곱절 넘게 잘아서 칸이 빠지지 않는다).
                 `build_lune_ui.mjs`: 부품 dropCoin1~4 · 게임 `effects.luau`: `Effects.COIN = { frames 4 · fps 7 · scale 0.45 }` — 떨어진 달돈이 1초에 일곱 장씩 빙글 돈다. `ui_kit.png` = rbxassetid://81236740288806. 달가루(8x8 수정)는 그대로.
              확인: 자동 검사 293,190개 통과 · Play: 달돈 8.5x9.4점 · 1.2초 동안 네 장이 다 돎 · 두 번 찍은 사진에서 서로 다른 장(`dev/COIN_1_spin_a.jpg` · `COIN_2_spin_b.jpg`) · 그림 `dev/COIN_3_art.png`. 콘솔 오류 없음.
              규칙으로: 달돈은 내가 손으로 그리지 않는다(세 번 퇴짜 — 똥 · 못생김 · 과자). 작은 그림도 Codex의 것을 칸 그대로 옮긴다.
          ▶ 2026-10-11 사용자(S64를 보고): "너무 좋습니다. 이제 다음 작업해야할것들 파악해서 개발이어서하세요" — 달돈(도는 주화) 승인. 다음 일은 내가 정해 이어 간다.
             정한 차례(범위 = 1지역 · Lv.30): ① 달빛 문(S65 — 끝) ② 전직할 때 스킬 포인트 초기화 한 번 무료 ③ 같은 계정이 두 서버에 동시에 들어왔을 때의 잠금 ④ 사당 지하 「불타는 마을」(그림이 든다) ⑤ 되풀이하는 것(일일 의뢰).
             기다리는 것(사용자): 스토리 보스(망루의 부관 · 정찰대장)의 답과 동작 그림 · 효과음 8 + 음악 12 올리기 · 실제 스마트폰.
          ✔ S65 달빛 문(가 본 마을 사이를 바로 오간다) — 설계는 전부터 있었다(journey.js rules · world.js · economy.js). 자료 `journey.js`의 `GATES`(from 28 · price 20 · lands 서쪽 = town · r1bv · ct2 · r2t · r2bs / 동쪽 = port · r3t).
              규칙(`sim/gates.luau` — 새로): 큰 마을 · 작은 마을에만(쉼터에는 없다) · 걸어서 한 번 들러야 열린다 · 같은 대륙끼리만 · Lv.28부터 · 내 레벨 x 20달돈 · 마을 안에 서 있을 때 쓴다.
              쓰는 법: 마을에서 월드맵(M) → 가 본 마을을 고르면 오른쪽 칸(몬스터의 줄 자리)에 「달빛 문으로 간다 · 600달돈」. 못 가면 그 자리에 까닭 한 줄(「걸어서 한 번 들러야 열린다」 · 「Lv.28부터 쓴다」 · 「마을이나 작은 마을에서 쓴다」 …).
              서버: 패킷 `Gate` → `world.luau`의 `onGate`(값을 내고 그 마을의 시작 자리로 — 문을 지날 때와 같은 대답) · `place`가 마을에 들를 때마다 `h.towns`(들른 마을)와 `h.home`(마지막으로 들른 마을)을 적는다(저장한다).
              쓰러졌을 때 돌아가는 곳 = 마지막으로 들른 마을(`onReturn` — 전에는 늘 초승달 마을). 화면: `boot.luau`의 ctx.gate(막 → 그리기 → 그림 불러오기) · 새 마을에 들르면 「달빛 문이 열렸다 — ○○」 · Lv.28이 되면 안내.
              [내 결정] 마을 안에 세운 문(물건)은 아직 없다 — 월드맵에서 쓴다. 4지역의 아랫마을 광장(r4a4)은 몬스터가 차지한 맵이라 뺐다.
              확인: 규칙 검사 통과 · 자동 검사 293,276개 통과(`31_lune_gates` 68개 — 규칙 · 서버 명령 · 값 · 대륙 · 쓰러졌을 때 · 저장). Play(`axion:30`): 주막에서 월드맵 → 초승달 마을을 고르니 단추 → 누르니 마을의 시작 자리 · 달돈 10000 → 9400 · 창이 닫힘. 콘솔 오류 없음. 그림 `dev/GATE_1_locked.jpg` · `GATE_2_button.jpg`.
              못 본 것: 걸어서 처음 들렀을 때의 「달빛 문이 열렸다」 알림 · Lv.28이 됐을 때의 안내 · 쓰러진 뒤 주막에서 일어나는 화면(자동 검사로만) · 스마트폰.
          ✔ S66 전직하면 스킬 포인트 초기화 한 번이 공짜(설계 `basics.js` SPRULE · JOBFLOW에 적혀 있던 것): `h.resets`(전직할 때 1 — 쌓이지 않는다 · 저장한다) · `Hero.freeReset` · 패킷 `SkillReset` → `onSkillReset`.
              스킬 창: 탭의 오른쪽에 「초기화(무료 1회)」 — 남아 있을 때만 보인다. 누르면 「정말 초기화?」로 바뀌고 3초 안에 한 번 더 눌러야 된다. 찍은 스킬이 모두 되돌아가고(처음부터 주는 레벨 1만 남는다) 포인트를 다시 쓴다.
              이것이 생기기 전에 전직한 캐릭터는 들어올 때 한 번 받는다. 같이: 남은 포인트가 음수로 보이지 않게(관리 명령 「모두 마스터」는 포인트를 쓰지 않고 채운다 — 화면에는 0으로).
              확인: 자동 검사 통과(18의 끝 — 전직하면 1 · 쓰면 0 · 포인트가 모두 돌아옴 · 저장). Play(`axion:30` → 관리 명령으로 2차): 단추가 보이고, 두 번 누르니 2차 스킬이 1 / 0으로 돌아가고 「스킬 포인트 3」 · 단추가 사라짐. 그림 `dev/RESET_1_button.jpg` · `RESET_2_done.jpg`.
              남은 것: 돈을 내고 되돌리는 「초기화 물약」(상점 · 탐사 수첩)은 아직 없다.
          ✔ S67 계정의 잠금 — 같은 계정이 두 서버에 동시에 들어오면 두 서버가 제가 아는 가방을 번갈아 저장해 물건이 복사되거나 사라진다(startplan의 「저장」 줄에 남겨 둔 것).
              `modules/store.luau`: `Store.lock(userId)`(같은 저장소의 "lock_<번호>" = { job = 서버 번호, at = 잡은 때 } — UpdateAsync) · `Store.unlock` · LOCK_TTL 150초(새로 고쳐지지 않은 잠금은 죽은 서버의 것으로 보고 넘겨받는다).
              `world.luau`: 계정을 읽기 전에 잡는다(다른 서버의 것이면 1.5초 간격으로 여섯 번 다시 물어 보고 — 서버를 옮겨 올 때 앞 서버가 저장을 끝내고 푼다 — 끝내 안 풀리면 「이 계정은 다른 서버에서 하는 중입니다. 잠시 뒤에 다시 들어와 주세요.」로 내보낸다. 읽지도 저장하지도 않는다) ·
                 저장할 때마다(60초) 새로 고치고, 잠금을 잃었으면 저장하지 않고 내보낸다 · 나갈 때와 서버가 닫힐 때 저장한 뒤에 푼다. 저장소를 못 쓰면(Studio — 메모리 저장) 잠그지 않고, 저장소가 잠깐 말을 안 들으면 막지 않는다.
              확인: 자동 검사 293,342개 통과(`32_lune_lock` 32개 — 두 서버인 척해서 잡기 · 못 잡기 · 넘겨받기 · 풀기 / 잠긴 계정은 내보내고 저장하지 않음 · 잠금을 잃으면 저장하지 않음 · 나갈 때 풂). Studio: 손님 표시 없이 켜서 제목 화면이 뜨는 것까지(캐릭터로는 들어가지 않음) — 콘솔 오류 없음.
              못 본 것: 실제 서버 둘로 동시에 들어와 보는 것(Studio 하나로는 할 수 없다).
          ✔ S68 가상 플레이 다시(오늘 바뀐 것을 다 넣고 — `LUNE_PLAY=axion,riven,reaper,mooni,salamander python tools/test/run.py 29_lune_playthrough`): 처음에는 다섯 직업 모두 전직을 못 했다 — 검사 속 플레이어가 전직 퀘스트를 사제에게 가서 받는 새 규칙을 몰랐다(게임의 고장은 아니다). `Quests.openJobs`를 보고 받으러 가게 고침.
              결과(쉬지 않는 가상의 플레이어 · 2차 전직까지): 살라맨더 1:54 · 리븐 2:07 · 리퍼 2:09 · 액시온 2:21 · 무니 2:27 — 「첫 기술」을 받고 끝내고, Lv.30에 「2차 전직」을 받아 5분쯤 뒤에 끝낸다. 자동 검사 293,440개 통과.
              다음(정한 차례의 남은 것): ④ 사당 지하 「불타는 마을」은 스토리 보스(망루의 부관 · 정찰대장)와 한 줄기라 그 답을 기다린다 · ⑤ 일일 의뢰는 내용(어떤 의뢰 · 보상 · 흔적의 공명)을 정해야 한다 — 둘 다 사용자에게 물어 둠.
          ▶ 2026-10-11 사용자(답): "리워드 없는 스토리보스로넘기고 스토리가 끝나면 재도전 하거나 재격파없이 그냥 이야기에서 지나치는 스토리보스로, 동작그림은 필요한거 저한테 말하면 제가 가져다드리겠습니다. 패턴, 스킬 이펙트는 따로 만드셔야해요 / 일일의뢰는 추후에 설계하겠습니다. / 달빛문이 무엇인지?"
          ✔ S69 스토리 보스 둘의 설계와 동작 그림 청하기 — `design/bosses.js`의 `STORYBOSS`(규칙: 보상 없음 · 그 메인을 하는 중에만 나타난다 · 끝내면 다시 안 나온다).
              망루의 부관(r1m7 · Lv.25): 내려찍기 · 휩쓸기 · 땅 울림(체력 절반 아래) — 동작 idle · run · attack · sweep · death. 정찰대장(r1m8 · Lv.28): 내리베기 · 호령(검병 둘을 부른다) · 내달리기(절반 아래) — 동작 idle · run · attack · shout · death.
              둘 다 망루 꼭대기(r1c4)에서 싸운다[내 결정 — 설계의 글에는 부관이 망루 3층]. 숫자는 모두 내 제안. 동작 설명 열 개는 `Assets/character/luna/bosses/<id>/prompts.txt`(`node tools/build_lune_bosses.mjs` — 아직 못 받은 것도 적는다).
              **싸움은 아직 만들지 않았다** — 다음: 시험 탭에서 대기 그림을 대신 세워 패턴 · 예고 · 이펙트부터 → 게임(서버의 보스 · 체력 칸 · 퀘스트와 잇기) → 동작 그림이 오면 바꿔 끼운다.
              일일 의뢰는 사용자가 뒤에 설계한다(만들지 않는다). 달빛 문은 사용자가 무엇인지 물음 — 설명함(가 본 마을 사이의 빠른 이동). 이름 · 유무는 사용자의 답을 기다린다.
          ▶ 2026-10-11 사용자(답): "달빛문같은걸 넣지는 않습니다. 추후에 메이플스토리 텔레포트 아이템같은걸 bm 으로 잡을거에요 지금은 걸어다닌다고 보면됩니다. 일단 작업 진행하세요 애니메이션 완성하면 다시 말씀드릴게요 일단 없는채로만드세요"
          ✔ S70 달빛 문(S65)을 걷어냄 — 마을 사이를 바로 오가는 기능은 없다(걸어서 다닌다). 뒤에 메이플스토리의 텔레포트 아이템 같은 것을 유료(BM) 아이템으로 — 사용자가 설계한다(먼저 만들지 않는다).
              걷어낸 것: 월드맵의 「달빛 문으로 간다」 단추와 줄(`ui/mapWindow.luau`) · `boot.luau`의 ctx.gate와 「달빛 문이 열렸다」 알림 · 패킷 `Gate`와 서버의 `onGate` · `sim/gates.luau` · `data/gates.generated.luau` · 캐릭터의 `towns`(저장 · 화면) · 검사 `31_lune_gates`.
                 (파일 셋은 지우지 않고 이 세션의 임시 폴더로 옮겼다 — 저장소에는 없다.) 설계: `journey.js`의 `GATES` → `HOMES`(돌아가는 마을의 목록) · 내보내기 · 규칙 검사 · 글(basics · world · continents · economy · numbers · maps · journey · startplan)에서 달빛 문을 뺌.
              남긴 것[내 결정]: 쓰러졌을 때 마지막으로 들른 마을 · 작은 마을에서 일어난다(`h.home` — 메이플의 "가까운 마을". 목록 = `scenes.generated`의 `homes`). 마을이 아닌 곳 · 없는 장면이 적혀 있으면 시작 마을.
                 옛 저장(달빛 문이 있던 하루 동안의 것)의 `towns`는 읽지 않고 버린다. 귀환 주문서는 그대로다.
              확인: 규칙 검사 통과 · 자동 검사 293,290개 통과(`31_lune_home` 34개 — 명령 Gate가 없다 · 돌아가는 곳 · 저장 · 깨진 저장). Studio(리븐 Lv.30): 리모트 Gate 없음 · 주막에서 월드맵을 열어 초승달 마을을 골라도 단추가 없다 · 콘솔 오류 없음.
          ✔ S71 스토리 보스 둘의 싸움(망루의 부관 · 정찰대장) — 동작 그림 없이(사용자: "일단 없는채로만드세요") 대기 그림으로 먼저 만들었다. 시험 탭 → 게임.
              설계 `design/bosses.js` `STORYBOSS`(패턴의 넓이 · 시간 · 세기 — 숫자는 모두 내 제안) · `storyBoss()` · `STORYROOM` → 내보내기: `combat.generated`의 mobs[보스](boss · story) · `scenes.generated`의 r1c4.bosses · 그림판 `monsters/bosschars.json`(`build_lune_bosses.mjs` — 대기 두 장).
              퀘스트 `questplay.js`: r1m7 「망루의 부관」 = 망루 꼭대기에서 부관 1 · r1m8 「정찰대장」 = 대장 1(전에는 수련 인형 15 · 찢어진 명령서 6으로 대신해 두었다). 말은 내가 채웠다.
              서버 `sim/room.luau`: 보스는 졸개의 목록 끝에 자리만 잡아 두고(away), **그 퀘스트를 하는 중인 사람이 방에 있을 때만 선다**(`stepPresence` — `Quests.wantsKill`). 이야기의 차례로 한 번에 하나.
                 `stepBoss`: spawn → idle · run(쉬며 다가옴) → tell(예고) → act(침) / dash(내달림) → idle(굳음). 쓸 수 있는 패턴 가운데 가장 오래 안 쓴 것을 고른다. 맞아도 멈칫 · 밀림 없음. 묶이면(바인드) 그만둔다.
                 부관: 내려찍기(앞 8~64 · 높이 56 · 4.5배) · 휩쓸기(앞 -8~96 · 높이 14 — 뛰어넘는다 · 3.5배) · 땅 울림(체력 절반 아래 · 9초에 한 번 — 내려찍은 자리에서 물결 둘이 양쪽으로 250점 · 3배).
                 대장: 내리베기(앞 6~86 · 높이 52 · 4.5배) · 호령(16초에 한 번 — 검병 둘이 방의 양 끝에서 · 넷까지) · 내달리기(체력 절반 아래 · 10초에 한 번 — 보는 쪽 벽까지 · 발이 34점보다 높으면 넘긴다 · 4배).
                 보상 없음: 보스 · 불려 나온 검병은 경험치 · 달돈 · 물건을 주지 않는다. 보스를 쓰러뜨리면 방에 있는 모두의 퀘스트가 찬다. 퀘스트를 끝내면 다시 서지 않는다.
                 방이 비면(`world.luau` — `room:idle()`) 보스가 사라지고, 다시 들어오면 체력이 가득한 채 선다. 스냅숏의 아홉째 = 패턴의 차례.
              화면: `shared/lune/bossfx.luau`(= 시험 탭 `js/lune/bossfx.js`를 옮긴 것 — 예고의 자리 · 치는 이펙트 · 물결 · 속도선 · 대기 그림을 움직이는 pose) · `client/lune/bossView.luau`(상태가 바뀌는 때에 건다 + 화면 위 가운데의 체력 바 — `UILAYOUT.boss`) ·
                 `mobsView.luau`(보스의 몸: 그 동작의 그림이 있으면 그것을, 없으면 대기 그림을 움직인다 · 예고하는 동안 분홍 윤곽 · 머리 위의 띠와 이름표는 없다).
                 **동작 그림이 오면**: `<동작>_right.png`를 그림판에 싣기만 하면 된다 — 화면은 clips에 그 이름(attack · sweep · shout · run)이 있으면 그것을 튼다(death는 아직 쓰는 곳이 없다 — 지금은 서서히 사라진다. 그림이 올 때 잇는다).
              관리: `Admin("quests", "to", "r1m7")` — 그 메인을 받은 것으로(앞의 메인은 끝낸 것으로 · 레벨이 모자라면 올린다). 관리 창 「성장」 탭에 「보스 퀘스트: 망루의 부관 · 정찰대장」 단추. 확인용 속성 `Hud.Boss`의 State · Pattern.
              시험 탭: `?lunescene=r1c4#lune`(망루 꼭대기) — 부관 → 대장 → 부관 …으로 되풀이해 선다. `&lunepre=초`(미리 돌린 뒤 멈춘 그림) · `&lunehp=비율` · `&luneboss=차례`. 이 탭의 검병은 치지 않는다.
              확인: 규칙 검사 통과(스토리 보스의 규칙을 더함) · 자동 검사 293,918개 통과(`33_lune_boss` 151 · `24`에 보스의 몸과 bossView · `29`의 봇이 보스를 잡는다) · 새 그림판 4장 올림.
                 Studio(리븐 Lv.25 · 28): 퀘스트를 받은 채 망루 꼭대기에 가면 부관이 서고 체력 바 · 예고의 자리 · 분홍 윤곽 · 치는 이펙트가 나온다 / 무적 없이 서 있으면 맞는다 / 쓰러뜨리니 「차돌에게 간다」 · 경험치 0 · 떨어진 것 0 /
                 「정찰대장」으로 넘기니 대장이 서고, 호령으로 검병 둘이 걸어 나와 친다(11씩) / 땅 울림의 물결(이펙트를 느리게 돌려서 봄) / 콘솔 오류 없음.
                 가상의 플레이어(새 캐릭터 → 2차 전직): 리븐 2:07 — 「망루의 부관」 1:34 → 1:37 · 「정찰대장」 2:02 → 2:05(봇은 예고를 다 피한다고 친다 — 얼마나 맞는지는 재지 못한다).
              못 본 것: 손으로 피해 보는 느낌(예고 0.8~1.2초가 넉넉한지) · 게임 화면의 휩쓸기 · 내달리기 장면(시험 탭의 멈춘 그림과 검사로만) · 물결이 서버의 판정과 같은 자리를 지나는지 · 두 사람이 같이 싸우는 것 · 스마트폰.
              내 결정: 세기(처음 6배 → 서 있으면 9초에 71%가 깎여 4.5배로) · 발판 위(48점)도 내려찍기 · 내리베기에는 맞는다(안전한 자리가 없게) · 보스 방에서 한 번에 한 보스 · 부관을 3층이 아니라 꼭대기에서.
          ▶ 2026-10-11 사용자: "망루의 부관이랑, 정찰대장 퀄리티가 너무 낮아서 원본 코덱스로 다시받고 다듬는것도 다시 다듬어서 원본캐릭터 다시 똑바로 만드세요 그리고 만든뒤에 상하좌우 공백이 너무 빡빡하면 안됩니다.
               지금 망루의 부관으로 예시를 들면 이미지 사이즈를 통일시켜야하는데 망치를 들고 휘두르는 모션을 만들면 위에 망치가 잘려버리기때문에 애초에 가만히 있는 자세 이미지에서도 공백을 멀쩡하게 잡아두어야합니다."
          ✔ S72 보스 둘의 그림을 다시 받아 다시 만듦 + 기본 그림의 여백.
              까닭(처음 것): 내가 "납작한 실루엣 · 안쪽 그림은 거의 없이"라고 청해 뭉개진 덩어리로 나왔고, 부관은 발이 그림 밖으로 잘렸다. 기본 그림은 1024에 몸이 900을 채웠다(여백 7%).
              다시 받기(Codex — `assetpack/lune/monsters/prompt_<id>_v*_creatures.txt`): 품질의 기준으로 사용자가 승인한 새 주인공 그림(`luna/riven.png`)과 팩 병사를 붙이고, 또렷한 윤곽 한 점 · 재질마다 서너 단의 명암 · 온몸이 그림 안 · 한 점 8화소로 청함.
                 부관 = v2 한 번에 됨(8화소 · 90x96점). 대장 = 일곱 번: v2~v4는 도트가 잘게(5.3~6.8화소 → 160~174점 — 화면을 다 채운다) 나와 버림 → 부관의 v2를 "쌍둥이 그림"의 기준으로 붙이고(v5) 눈 · 머리 · 뿔 · 허리띠의 크기를 칸 수로 못박아(v6 · v7) v7을 씀(102x116점).
                 대장의 생김새가 조금 바뀜: 칼을 몸 앞에 세워 땅에 짚고 두 손으로 쥠(전에는 한 손으로 낮게) · 뿔이 전보다 작음 · 쇠 정강이받이. `bosses.js`의 생김새 · 대기 동작의 글을 맞춤. Codex는 대장을 투명 바탕으로 줌(초록을 청해도) — 둘레의 빛무리는 반투명이라 옮길 때 빠진다.
              다듬기(옮기는 도구 `build_lune_creatures.mjs` — 장의 smooth · key): ① 초록 바탕 읽기(key) ② 색 고르기를 칸의 평균 색 + 이웃과 맞추기로(화소마다 고르면 시안의 한 색이 팔레트의 두 색 사이에 걸려 얼굴 · 망토 · 깃발이 얼룩졌다).
                 `build_lune_bosses.mjs`(BOSS_ART.outline · despeckle · fix): ③ 끊긴 윤곽 잇기(바깥에 닿은 점을 윤곽의 색으로 — 분홍은 그대로) ④ 어두운 면에 홀로 박힌 점 지우기(리베트의 그림자는 지킨다) ⑤ 눈을 반듯한 흰 네모로(부관 3x3 · 2x3 / 대장 3x4 둘). 색은 게임의 열세 색 그대로.
              기본 그림의 여백(모든 보스 열여섯 — `build_lune_bosses.mjs`의 CANVAS · FILL_W · FILL_H · FOOT · SHIFT): 1536x1536(새 주인공의 기본 그림과 같은 크기) · 몸은 가로 44% · 세로 38%를 넘지 않게 · 발밑은 위에서 80% · 왼쪽으로 3% 비낌.
                 부관: 한 점 6화소 · 위 652 · 아래 308 · 왼쪽 451 · 오른쪽 545화소가 빈다(머리 위로 제 키보다 넓다). 대장: 한 점 5화소 · 위 648 · 좌 466 · 우 560. 여백이 모자라면 도구가 멈춘다. prompts.txt 맨 위에 여백과 "이 크기 그대로 만들어 달라"를 적음.
                 처음의 기본 그림(1024 · 낮은 품질)은 `assetpack/lune/monsters/old_bosses_1011/`에 남김(사용자의 폴더에서는 새것으로 바뀜).
              게임 · 시험 탭: 새 그림(대기 두 장)으로 바꾸고 판 4장을 올림 · 몸과 맞는 자리를 다시 잼(부관: 몸 50x84 · 가운데 34 · 내려찍기 앞 14~86 · 휩쓸기 -10~110 / 대장: 몸 52x98 · 가운데 48 · 내리베기 앞 6~96 · 높이 60) · 치는 이펙트가 맞는 자리의 크기를 따라가게 함(bossfx).
              확인: 시안과 나란히 확대해 봄(얼굴 · 깃발의 얼룩이 사라짐 · 눈 · 윤곽) · 규칙 검사 통과 · 자동 검사 293,918개 통과 · 시험 탭(예고 · 타격)과 Studio(두 보스가 서는 모습 · 콘솔 오류 없음)에서 봄.
              못 본 것 · 내 결정: 대장이 부관보다 20% 크다(116 대 96점 — 더 줄이려면 다시 받아야 한다) · 대장의 뿔이 전보다 작다 · 사용자의 애니메이션 도구가 1536 그림을 받는지(주인공의 기본 그림이 1536이라 그렇게 봤다) · 다른 보스 열넷은 여백만 바뀌고 그림(품질)은 그대로다.
          ▶ 2026-10-11 사용자(해 보고): "뭐 보스 패턴도 없고 이펙트도없고 체력 몇인지도 숫자로안보이고 난이도는 2차수준이 깰수가 없는 수준인데요?"
          ✔ S73 보스전 고침 — 난이도 · 체력 숫자 · 패턴의 이름 · 큰 예고와 이펙트.
              재 본 것(Studio — 확인용 리븐 Lv.32 · 2차 · 스킬 마스터 · 무적 없이 보스 앞에 서서 1차 보스기만): **16초에 쓰러졌고 그동안 보스의 체력은 2%도 줄지 않았다**(한 방 37~47 = 체력의 10~13% · 2초마다 한 번).
                 내 숫자가 틀렸다: 체력 40 · 55배 · 한 방 4.5배 · 예고 0.8~0.9초 · 친 뒤 0.9초만 굳음. 기술을 쓰는 동안에는 못 움직여 0.9초의 예고는 사실상 못 피한다. (S71의 "가상의 플레이어가 지나간다"는 봇이 다 피한다고 친 것이라 이것을 못 잡았다.)
              난이도(bosses.js STORYBOSS — 내 제안): 체력 12 · 14배 / 한 방 = 일반 몬스터의 1.5~2배(맨몸 체력의 5~7%) / 예고 1.2~1.5초 / 친 뒤 1.6~2.2초 굳음(한 패턴 3.3초쯤) / 걷는 빠르기 34 · 38 / 서는 자리 560 → 400(문에서 가깝게) / 땅 울림 12초 · 호령 20초 · 내달리기 14초에 한 번.
                 검사의 규칙도 바꿈: 한 방 3~10% · 예고 1.2~1.8초 · 굳음 1.2초 이상 · 체력 8~20배(check_lune_design.mjs).
                 `33_lune_boss` 4): **피하지 않는 사람**(보스 앞에 붙어 서서 1차 보스기만 · 본보기 장비)도 깬다 — 부관 28초 · 받은 피해 = 내 체력의 52% / 대장 34초 · 68%. 가상의 플레이어도 피하지 않게 돌려 봄(`LUNE_PLAY_NODODGE=1`): 리븐 · 무니 둘 다 꼭대기에서 쓰러지지 않고 지나간다.
              체력 숫자: 보스의 체력 바(화면 위 가운데)를 16으로 키우고 안에 「지금/최대」(예: 53640/53640 — 칸에 안 들어가면 짧게). `UILAYOUT.boss`(h · patY · pad) · `bossView.luau` · 시험 탭 `P.bossBar`.
              패턴과 이펙트(`js/lune/bossfx.js` → `shared/lune/bossfx.luau`를 새로 씀 — 처음 것은 옅은 네모와 작은 고리뿐이라 싸우는 동안 눈에 들어오지 않았다):
                 예고 = 맞을 자리를 짙게 칠하고(차오르는 앞머리에 흰 줄 · 두 점 테두리) 보스의 머리 위에 분홍 마름모의 느낌표 · 체력 바 아래에 그 패턴의 이름(「내려찍기」 …).
                 치는 순간 = 맞는 자리 전체를 채우는 번쩍임 + 겹 고리 + 솟는 가시 일곱 + 파편 + 피어오르는 먼지 + 화면 흔들림(보스의 한 방에만) / 휩쓸기 = 바닥의 굵은 띠 / 내리베기 = 큰 초승달 둘 /
                 호령 = 세 겹 고리 + 졸개가 나오는 자리의 빛기둥 / 내달리기 = 분홍 잔상 + 속도선, 벽에 닿으면 터진다 / 물결 = 더 큰 마루. 대기 그림을 움직이는 폭도 키움(들어 올림 7점 · 내리꽂음 10점).
              확인: 규칙 검사 통과 · 자동 검사 293,837개 통과. 시험 탭의 멈춘 그림(예고 · 타격 넷). Studio: 체력 숫자 · 패턴 이름 · 예고의 자리와 느낌표가 찍힘 / 타격은 이펙트를 느리게 돌려 찍음 / 그림판의 점을 읽어 예고 · 타격 때 분홍 점이 3,600~4,200개 찍히는 것을 셈. 콘솔 오류 없음.
              못 본 것: 손으로 싸워 본 느낌(이제 너무 쉬운지) · 사용자가 "패턴도 없고 이펙트도 없고"라 한 것이 처음 것이 너무 옅어서였는지, 화면에 아예 안 나왔는지(내 Studio에서는 처음 것도 찍혔다) · 스마트폰 · 휩쓸기 밖의 타격 장면(내려찍기 · 내리베기 · 내달리기)은 게임에서 따로 찍지 못함(시험 탭에서 봄).
              배운 것: 내 봇이 "다 피한다"고 치는 검사만으로 난이도를 말하지 않는다 — 피하지 않는 사람으로 재 본다. 사용자의 「Lv.30까지 쉽게」에 맞춰 처음부터 약하게 잡는다.
          ▶ 2026-10-11 사용자: "scoutcaptain은 왜 칼이 이상하게 휘어있는거에요? 메이플이나 다른 도트 rpg 들 횡스크롤 게임에서 여러 보스들을 좀 공부하세요"
          ✔ S74 보스 조사 + 정찰대장의 칼을 다시 받음(v8) — 곧은 양날 긴 칼을 가까운 손으로 앞으로 낮게 뻗어 든다.
              칼이 휜 까닭(내 탓): Codex에 「굽은 칼(시미터)」을 청해 놓고, 도트 크기를 맞추느라 다시 「몸 앞에 세워 땅에 짚은 자세」로 청했다 — 굽은 날이 세로로 서서 바나나처럼 보였다. 조사 없이 정했다.
              조사(기록 = `design/bosses.js`의 `BOSS_STUDY` — 규칙 열 줄, 찾은 것 what → 우리에게 쓰는 법 apply):
                 본 것 = 메이플스토리의 무기 든 보스 · 큰 몬스터 아홉의 대기와 공격 동작(오다 사무라이 대장 · 매그너스 · 타우로마시스 · 타우로스피어 · 창병 스켈레나이트 · 발록 둘 · 골렘 · 캡틴 다크구 — maplestory.io의 그림을 스크래치에 받아 장마다 늘어놓고 봄. 보기만: 저장소 · 공방에 두지 않는다)
                 읽은 것 = Dead Cells의 첫 보스(수위)의 공격과 예고 · Skul의 위그드라실 · 메이플스토리 매그너스 · 파풀라투스 · 자쿰의 패턴. 던그리드의 보스는 글을 찾지 못했다.
                 찾은 것: ① 무기는 몸의 윤곽 밖으로, 앞으로 뻗어 든다(몸 앞에 세로로 겹쳐 든 보스는 없다) ② 칼은 곧거나 아주 완만하게만 굽는다 ③ 무기는 몸과 다른 가장 밝은 색 ④ 실루엣은 비대칭(무기 앞 · 망토 뒤 · 뿔 위)
                    ⑤ 큰 상체 · 짧은 다리 · 포인트 색 하나 ⑥ 서 있을 때도 숨을 쉰다 ⑦ 공격은 세 마디(크게 준비 · 치기 · 박힌 채 멈춤) ⑧ 예고는 몸과 무기가 먼저 알린다(윤곽 빛 · 무기가 빛남)
                    ⑨ 타격 이펙트는 몸보다 크고 밝은 색을 겹친다(흰 심 → 밝은 색 → 가장자리) ⑩ 첫 보스의 패턴은 서너 가지 · 뚜렷이 다른 모양. 체력 구간에서 포효로 단계가 바뀌는 것은 우리에게 아직 없다(사용자에게 여쭘).
              그림: `prompt_scoutcaptain_v8_creatures.txt` — v7을 붙여 「몸 · 갑옷 · 뿔 · 망토 · 깃발 · 두루마리는 그대로, 칼과 팔만」 다시 청함 → `raw_scoutcaptain_v8_creatures.png` 한 번에 옴(곧은 칼 · 앞으로 낮게 · 칼끝이 앞쪽 땅에 닿음 · 먼 손은 주먹을 쥐고 옆에).
                 재 보니 몸의 도트는 v7과 같고(몸만 잘라 재면 둘 다 7.1화소 · 머리와 뿔만 옮기면 둘 다 47줄) 칼만 잘게(6.4화소) 그려져 왔다 — 넓게 찾으면 칼에 끌려 176x130점(몸이 12% 커짐)이 된다.
                 → `build_lune_creatures.mjs`에 sheet의 `pin`(칸의 기준을 block ±3%에 못박음 · 잘게 그려진 장 거르기도 건너뜀)을 넣고 v7을 옮길 때 잡혔던 기준 8.0에 못박음: **152x117점**(몸은 v7의 102x116과 같은 크기 · 늘어난 폭은 칼).
                 다듬기: 윤곽 61점 잇기 · 어두운 잡티 15점 · 눈 셋(`BOSS_ART.fix.scoutcaptain` — 둘 다 3x4 흰 네모). 시안과 나란히 · 머리 · 손 · 칼날을 따로 확대해 봄: 날이 곧고, 위쪽의 흰 줄 · 가운데 홈 · 윤곽이 끊기지 않는다.
              글과 숫자: 생김새 · 대기 · 걷기(칼을 앞으로 든 그대로 — 전에는 어깨에 걸침) · 내리베기 · 호령의 설명을 새 자세로(→ 보스 폴더의 prompts.txt). `STORYBOSS.scoutcaptain`: art 48 → 50 · 내리베기 reach 88 → 100 · 맞는 자리 6~96 → **6~112**(든 칼끝 101점 + 내딛는 12점 — 보이는 칼보다 맞는 자리가 짧으면 안 된다). 체력 · 세기 · 예고는 그대로.
              드리는 그림: `C:/YJS/Roblox/Assets/character/luna/bosses/scoutcaptain/`의 기본 그림 · 대기 두 장 · prompts.txt가 새 것으로 바뀜(1536x1536 · 한 점 4화소 · 위 760 · 좌 417 · 우 511의 여백). 앞의 것은 `assetpack/lune/monsters/old_bosses_1011b/scoutcaptain/`에 둠.
              올린 그림: chars_1.png = rbxassetid://137719764018585 · chars_mask_1.png = rbxassetid://92209231549602.
              확인: 규칙 검사 통과 · 자동 검사 293,935개 통과(피하지 않는 사람: 대장 34초 · 68% — 그대로) · 시험 탭의 멈춘 그림 셋(서 있음 · 예고 · 타격) · Studio Play(확인용 리븐 Lv.32 → 관리 「보스 퀘스트」 → 망루 꼭대기): 새 그림 · 내리베기의 예고가 든 칼을 다 덮는 것을 찍음. 콘솔 오류 없음. 확인용 속성 지움(attrs 0).
              못 본 것 · 내 결정: 칼이 제 키만큼 길다(청한 것은 50점쯤, 온 것은 날만 70점쯤 — 메이플의 사무라이 대장 · 매그너스도 그만하다. 길면 다시 받는다) · 서 있을 때 칼이 가까이 온 플레이어와 겹쳐 보인다(닿아도 피해는 없다) ·
                 대기 두 장째(기계적으로 한 점 내림)에서 칼끝 가까이가 한 점 어긋난다(사용자의 대기 동작이 오면 바뀐다) · 손으로 싸워 본 느낌 · 스마트폰 · 부관은 그대로 둠(망치 머리를 앞의 땅에 내려놓은 자세 — 규칙 ①에 맞는다고 봄).
              배운 것: 무기 · 자세처럼 눈에 가장 먼저 띄는 것은 주문을 쓰기 전에 같은 장르의 보스 몇을 먼저 본다(`BOSS_STUDY`). 생성 그림에 「굽은」을 청하면 부풀려 온다 — 곧은 것을 청한다. 도트 크기를 맞추려고 자세를 바꾸지 않는다.
          ▶ 2026-10-11 사용자(v8의 기본 그림을 보고): "확인 한거 맞아요? 이번엔 칼이 아래로 휘어있잖아요 축늘어져서 이게 뭐하는짓인지"
          ✔ S75 정찰대장의 칼을 다시 받음(v9) — 곧은 칼을 두 손으로 허리 높이에서 **수평으로** 겨눈 자세 + 곧은지를 재는 검사.
              내 잘못 둘: ① S74에서 "날이 곧고"라고 알렸는데 확대한 그림만 눈으로 봤다. 재 보니 옮긴 그림의 날 위 가장자리 기울기가 앞 절반 0.50 → 뒤 절반 0.60(끝으로 갈수록 처짐 · 줄에서 1.2~1.6점 벗어남).
                 Codex의 시안은 곧다(0.47 → 0.48) — 옮기는 격자의 줄 간격이 몸 쪽(7화소)과 칼만 있는 쪽(6.4화소)에서 달라 얕은 대각선이 휘었다. 확대하면 계단만 보이고 전체의 휨은 안 보인다.
                 ② 자세: 내가 청한 「앞으로 낮게 뻗어 칼끝을 땅에 댄」 자세 자체가 힘없이 늘어져 보였다(가늘고 긴 칼의 끝이 손보다 낮다).
              검사를 넣음: `BOSS_ART.straight`(bosses.js) = 곧아야 하는 날의 자리 → `build_lune_bosses.mjs`가 그 상자에서 날의 위 · 아래 가장자리를 열마다 읽어 곧은 줄에 맞추고,
                 앞 · 뒤 절반의 기울기 차이 > 0.03 또는 벗어남 > 0.75점이면 그림을 만들지 않고 멈춘다(v8을 넣어 보니 멈춤: "칼날이 곧지 않다 — 기울기 0.547(앞 0.496 · 뒤 0.596) · 벗어남 1.19점"). `slope`를 적으면 그 기울기인지도 본다.
              그림: `prompt_scoutcaptain_v9_creatures.txt`(v7을 붙여 몸은 그대로 · 칼과 두 팔만) — 「날은 정확히 수평 · 위 가장자리도 아래 가장자리도 도트 한 줄 · 두 손으로 허리 높이에서 · 늘어뜨리지 않는다 · 땅에 닿지 않는다」.
                 → `raw_scoutcaptain_v9_creatures.png`: 시안의 날 기울기 0.000 · 두께 73~74화소로 고르다. pin 8.0으로 옮김: **164x108점**(몸이 v7보다 7% 작게 그려져 왔다: 116 → 108줄. 부관 96보다는 크다).
                 옮긴 날: 위 · 아래 가장자리 기울기 0.000 · 벗어남 0.00점(도구가 잼). 다듬기: 윤곽 17점 · 잡티 6점 · 눈(왼쪽 3x4 · 오른쪽 2x4 흰 네모).
                 이번에는 사용자가 여는 기본 그림(1536x1536 전체)을 그대로도 보고, 몸만 두 배로 키운 것도 봤다.
                 같이 받아 둔 다른 자세: `raw_scoutcaptain_v9b_creatures.png`(두 손으로 앞 위 45도로 치켜든 자세 — 쓰지 않음. 사용자가 고르면 옮긴다. 초록 바탕 · 몸이 더 작게 왔다).
              글과 숫자: 생김새 · 대기 · 걷기 · 내리베기 · 호령의 설명을 수평으로 겨눈 자세로(→ prompts.txt). `STORYBOSS.scoutcaptain`: art 50 → 48 · body 98 → 92 · 내리베기 reach 100 → 112 · 맞는 자리 6~112 → **6~128**(칼끝 115점 + 내딛는 12점).
                 수평의 칼은 바닥에서 39~52점 높이라 서 있는 캐릭터의 머리 위를 지난다(v8처럼 캐릭터와 겹쳐 보이지 않는다). `BOSS_STUDY`의 첫 두 줄(apply)에 「칼끝이 손보다 낮으면 힘없어 보인다 — 수평이나 치켜든 자세 · 곧은 날은 수평이나 45도로 청한다 · 곧은지는 잰다」를 적음.
              드리는 그림: `…/luna/bosses/scoutcaptain/`의 기본 그림 · 대기 두 장 · prompts.txt를 다시 바꿈(한 점 4화소 · 그림 164x108점). v7의 것은 `old_bosses_1011b/`에 있다(v8의 기본 그림은 따로 두지 않았다 — 시안 raw_…v8…png는 있다).
              올린 그림: chars_1.png = rbxassetid://130526965623827 · chars_mask_1.png = rbxassetid://95816416204302.
              확인: 규칙 검사 통과 · 자동 검사 293,935개 통과 · 시험 탭의 멈춘 그림 셋 · Studio Play(확인용 리븐 Lv.32 → 망루 꼭대기): 수평의 칼 · 체력 바를 찍음. 콘솔 오류 없음. 확인용 속성 지움(attrs 0).
                 빌드 도중 한 번 `UNKNOWN: unknown error, open …scoutcaptain.png`(파일이 잠깐 잠김 — 보는 프로그램이 열고 있었던 듯) → 다시 돌려 씀.
              못 본 것: 손으로 싸워 본 느낌(맞는 자리가 여덟 칸으로 늘었다) · 스마트폰 · 칼의 길이(77점 — 청한 것은 55점)와 자세에 대한 사용자의 판단.
              배운 것: 곧다 · 수평이다 같은 것은 재서 말한다(도구가 멈추게). 확대 그림과 함께 사용자가 여는 그림 전체를 그대로 본다. 날은 수평이나 45도처럼 옮겨도 변하지 않는 각도로 청한다. 무기 끝을 땅에 늘어뜨리지 않는다.
          ▶ 2026-10-11 사용자: "두 보스 애니메이션 어택,아이들, 워크 이렇게 넣었습니다." — `…/luna/bosses/towerlieutenant/` · `…/scoutcaptain/`에 idle.png · walk.png · attack.png(저마다 4480x1800 = 640x360칸 7x5 · 35장 · 바탕 투명)
          ✔ S76 받은 보스 동작 여섯 장을 게임의 점으로 옮겨 시험 탭과 게임에 넣음 — 대기 · 걷기 · 공격(내려찍기 · 땅 울림 / 내리베기)이 받은 그림으로 움직인다.
              받은 그림의 크기(가장 큰 제약): 사용자의 도구는 기본 그림(1536x1536)을 칸의 높이 360에 맞춰 줄여 낸다 → 게임의 한 점이 **정찰대장 0.97화소 · 부관 1.45화소**(졸개 때는 5~8화소). 여백을 넉넉히 둔 탓에 기본 그림 안에서 몸이 작다.
                 한 점이 한두 화소뿐이라 졸개처럼 "칸마다 가장 많은 색"으로 옮길 수 없다. 대장은 눈 · 리베트 · 두루마리가 받은 그림에서 이미 뭉개져 있다(제 대기 그림보다 거칠다) — 부관은 제 그림과 거의 같게 나온다.
              옮기는 도구(새로): `tools/build_lune_boss_clips.mjs` → `monsters/chars/<보스>_<동작>.png` · `monsters/bossclips.json`. 이름은 <동작>.png · <동작>_right.png 둘 다 읽고 walk = run.
                 배율 = 대기 첫 장 ÷ 기본 그림. 1에 가까우면(대장) 받은 화소를 그대로 한 점으로(그림이 3% 작아진다: 164x108 → 158x105 — 다시 늘이면 더 뭉개진다), 아니면(부관) 넓이 평균으로 줄인다(90x96 그대로).
                 가장자리 밖을 둘레의 색으로 채우고 날을 세운 뒤(sharp 1 — 0이면 눈이 회색으로 묻히고 2면 잡티가 는다: 세 가지를 나란히 놓고 고름) 그 보스의 색으로만 옮긴다. 외톨이 점은 지운다.
                 기준점 = 대기 첫 장의 발밑 · 몸의 가운데를 그 보스의 모든 동작에 같은 칸 자리로. 동작마다 칸(fw · fh)과 기준점(ox · oy)이 따로: 부관 idle 95x96 · run 96x105 · attack 213x171 / 대장 idle 191x131 · run 167x112 · attack 257x126.
                 걷기 · 공격의 몇 장은 발끝 · 망치가 발밑 줄보다 2~5점 내려간다(받은 그림 그대로 — 자르지 않았다).
              시간 맞추기(`design/bosses.js`의 `BOSS_ANIM` — 장을 늘어놓고 읽음): 공격 그림의 hit(닿는 장) = 부관 15 · 대장 8, to(쓰는 끝 장) = 27 · 28(그 뒤는 서 있는 장이라 싣지 않음), 초당 12장.
                 예고하는 동안 0~hit-1째 장(치켜듦)을 제 빠르기로 틀고 다 틀면 그 자세로 멈춘다 → 치는 순간에 hit째 장 → 그 뒤는 제 빠르기로. 셈은 `bossfx.js`의 `body`(게임 `bossfx.luau`의 `BossFx.body`).
                 친 뒤 무기가 박혀 있다가 돌아오는 동안 보스가 걷거나 돌아서지 않게: 패턴의 act(굳어 있는 시간)를 0.25 → 부관 0.9 · 대장 1.1초로 늘리고 그만큼 rest를 줄임(친 뒤 다음 패턴까지는 그대로 — 2.05 · 2.45 · 1.85초).
                 내딛는 걸음(step)은 처음 0.25초 안에 다 간다(`room.luau` STEP_TIME). act가 끝난 뒤에도 서 있으면 남은 장을 끝까지 튼다(`mobsView.luau`의 m.tail). 규칙 · 검사: rest ≥ 1.2 → act + rest ≥ 1.4.
                 그림이 없는 동작(부관의 휩쓸기 sweep · 대장의 호령 shout · 둘의 쓰러짐 death)은 전처럼 대기 그림을 움직여 대신한다. 내달리기는 걷는 그림을 두 배 빠르게.
              그림판: `build_lune_bosses.mjs`가 bossclips.json의 동작을 bosschars.json에 싣는다(제가 만든 대기 두 장은 `<보스>_still.png`로 남김). export가 동작마다의 칸 · 기준점과 `story.anim`을 넘긴다. 시험 탭 `frameOf`가 동작마다의 칸을 읽는다.
                 캐릭터 그림판이 2장 → **5장**으로 늘었다(보스의 장 197개). 올린 그림: chars_1~5 = rbxassetid://76395307397832 · 87616262657336 · 110758951174514 · 78094149791506 · 118530575192058 /
                 chars_mask_1~5 = 117273460398499 · 111893964655440 · 133697473932884 · 81646251845981 · 75446383700530.
              확인: 규칙 검사 통과 · 자동 검사 294,470개 통과(검사 24에 받은 동작의 장 고르기 · 남은 장 이어 틀기를 넣음. 피하지 않는 사람: 부관 28초 · 52% / 대장 34초 · 68% — 그대로) ·
                 옮긴 공격 그림 57장을 장마다 늘어놓고 봄 · 시험 탭의 멈춘 그림 열 장(두 보스 × 서 있음 · 치켜듦 · 멈춤 · 닿음 · 돌아옴).
              Studio Play(처음에는 사용자가 직접 Play 중이라 — dolupa95 · 망루 꼭대기 · 동작을 넣기 전의 버전 — 건드리지 않고 기다렸다가, 끝난 뒤에 확인용 리븐 Lv.32로): 부관의 대기 · 휩쓸기(그림 없는 패턴 — 대기 그림을 움직임) ·
                 내려찍기의 치켜든 자세 · 친 뒤 들어 올림 / 대장의 내리베기 예고 · 베는 순간을 찍음. 그림판 다섯 장이 다 떴고 콘솔 오류 없음.
                 찍어 보고 고친 것: 예고에서 멈추는 장 — 처음에는 치기 바로 앞의 장(hit-1)에서 멈췄는데, 대장의 그 장은 휘두르는 도중이라 칼끝에 번진 줄이 그려져 있어 세워 두니 칼이 부서져 보였다
                    → 그 앞 장(hit-2 — 다 치켜든 자세)에서 멈추고 hit-1째 장은 예고의 마지막 12분의 1초에만 보이게(`body`). 다시 찍어 확인.
                 **내 실수(Studio)**: 두 번째 확인을 켜면서 Edit 확인 명령과 Play 시작 명령을 한꺼번에 보냈더니 시작이 먼저 돌아 Edit 확인이 "Play 중이라 안 된다"로 실패했다 → 사용자가 Play를 누른 줄 알고
                    "직접 켜신 Play가 확인용 캐릭터로 들어갔다"고 잘못 알렸다. 게임 시간(25초) · 3분 가까이 입력이 전혀 없는 것 · 캐릭터가 처음 자리에서 움직이지 않은 것으로 내가 켠 Play임을 확인하고 바로잡음.
                    그 사이 확인용 속성이 켜진 채였던 것은 사실이다(첫 Play를 끄고 지우지 않았다) → 이제 Play를 끌 때마다 바로 지운다 · 시작/끄기 명령은 다른 Studio 명령과 같이 보내지 않는다. 끝에 지움(attrs 0).
              못 본 것: 손으로 싸워 본 느낌 · 걷는 발이 미끄러지는지(멈춘 그림으로는 알 수 없다) · 보스 방에 처음 들어갈 때 그림이 늦게 뜨는지 · 스마트폰(그림판이 5장으로 늘었다).
          ▶ 2026-10-11 사용자: "에테르 ai 쓰고있는데 크게 뽑는법은 모르겠네요 정보 찾아볼래요?"
          ✔ S77 에테르 AI 조사 + 가로형 기본 그림.
              찾은 것: 사용자의 도구 = 에테르 AI(AetherAI · https://www.aetherforgeai.com/ko — 튜토리얼 /ko/tutorial · 스프라이트 화면 /ko/generate/sprite-pulsar은 로그인해야 보여 내가 볼 수 없다).
                 공식 튜토리얼: 스프라이트 생성 V1(이미지 한 장 · 25~169장 · 픽셀아트 ON/OFF) · V2(시작 장 + 끝 장 · 49~121장 · 더 자연스럽다). 결과 = GIF + 스프라이트 시트.
                 **결과의 크기를 고르는 설정은 적혀 있지 않다(고르는 것은 장 수뿐).** 넣는 그림의 권장: 단색 바탕(흰 바탕이 가장 좋다) · 오른쪽을 봄 · 한 캐릭터 · 잘리지 않게 여백 · 1024px 이상(「품질 높이기」 1K · 2K · 4K는 넣는 그림용).
              내가 잰 것: 받은 그림 한 칸은 640x360(16:9). 정사각형 기본 그림은 높이 360에 맞춰 줄어 양옆 280화소가 빈다 → 그림을 16:9로 하고 몸을 크게 놓으면 같은 칸에서 더 크게 나온다(확인은 사용자가 한 번 뽑아 봐야 한다).
              만든 것: `build_lune_bosses.mjs`가 받은 동작이 있는 보스에게 `<id>_wide.png`(1920x1080 · 검정) · `<id>_wide_white.png`(흰 바탕)를 더 쓴다 — 받은 동작에서 잰 움직임의 범위(왼쪽 · 오른쪽 · 위)에 10%만 더 남기고 몸을 가장 크게.
                 정찰대장 한 점 6화소 → 받을 그림에서 2.0화소(지금 0.97의 두 배) / 부관 5화소 → 1.67화소(망치를 치켜들어 세로가 모자란다 — 지금 1.45와 큰 차이 없음). 앞의 정사각형 기본 그림은 그대로 둠. prompts.txt에 안내 한 줄.
                 `build_lune_boss_clips.mjs`: 배율과 기준점을 동작마다 그 첫 장에서 잰다(기본 그림이 다른 동작이 섞여도 되게) → 부관 공격의 칸이 213x171 → 212x170으로 한 점 달라져 그림판 여섯 장을 다시 올림:
                 chars_1 · 3 · 4 = rbxassetid://125432213419078 · 102527500445272 · 123098599230370 / chars_mask_1 · 3 · 4 = 133507017028387 · 125004677780324 · 137658500816763.
              확인: 규칙 검사 통과 · 자동 검사 294,568개 통과 · 가로형 그림을 열어 봄 · Studio Play에서 다시 올린 그림판이 뜨는 것(부관)을 찍음 · 확인용 속성 지움(attrs 0 — 이번에는 상태 확인 → 속성 → 시작 → 끄기 → 지우기를 하나씩).
              못 본 것: 16:9 그림을 넣으면 에테르 AI가 정말 640x360 칸을 가득 채워 내는지(사용자가 동작 하나를 뽑아 봐야 안다) · 그 도구의 생성 화면에 크기 설정이 있는지(로그인해야 보인다).
          ▶ 2026-10-11 사용자: "지금 화질 너무 구지게 나옵니다ㅏ . 보스 크기 좀 줄여도 되니까 최대화질로 보일수있는 방법이없는지 고안해보세요"
          ✔ S78 화질 — 원인을 재고, 보스 크기를 그대로 둔 채 한 점에 드는 화소를 2~3배로 받는 방법을 만듦(사용자가 다시 뽑아야 게임에 반영된다 — 지금 게임의 그림은 그대로다).
              잰 것: 받은 그림의 번짐은 작다(서 있는 그림을 같은 크기로 줄여 흐린 것과 견줘 표준편차 0.5화소쯤). 거친 까닭은 거의 다 **한 점에 든 화소의 수**다.
                 서 있는 그림을 그만큼 줄이고 흐려 다시 옮겨 본 셈(다른 점의 비율): 0.97화소/점 48% · 1.45 → 40% · 2.0 → 15% · 3.1 → 4% · 4.1 → 0.5%. 받은 부관의 대기 첫 장(1.45)으로 직접 재도 36~41% — 셈과 맞는다.
              방법 ① 동작별 가로형 기본 그림(`build_lune_bosses.mjs` — 보스 폴더에 넷씩): `<id>_big.png`(서 있기 · 걷기용 — 걷는 그림이 닿는 데만 남기고 몸을 가득) · `<id>_wide.png`(공격처럼 크게 움직이는 동작용) + 흰 바탕 판.
                 그림의 95.5% 안에 움직임이 들도록 가장 큰 배율: 부관 big 한 점 9화소(받을 그림에서 3.0) · wide 6(2.0) / 정찰대장 big 8(2.7) · wide 6(2.0). 지금은 1.45 · 0.97.
              방법 ② 격자에 맞춰 읽기(`build_lune_boss_clips.mjs` — 한 점이 1.8화소 이상인 동작에만): 그 동작의 첫 장에서 격자의 간격과 시작점을 찾고(칸 안의 색이 가장 고른 자리), 점마다 가운데에 무게를 둔 평균 색을 읽는다.
                 가짜 입력으로 끝까지 시험(`LUNE_BOSS_TEST=<폴더>` — 새 기본 그림을 656x368로 줄여 640x360을 자르고 흐림 0.5 · 잡음 · 장마다 조금씩 옮김): 서 있는 그림과 다른 점이 3.06화소/점 1.6% · 2.73 → 2.7% · 2.05 → 6.7~7.5%. 크기는 정확히 90x96 · 164x108.
                 1.8화소 아래(지금 받은 그림)는 전의 방식 그대로다 — 격자로 읽으면 부관의 눈이 묻힌다(견줘 봄). 그래서 지금 게임의 그림은 바뀌지 않았다(올릴 것 0장).
              보스 크기: 줄이지 않았다. 줄이면 더 오른다 — 75%로 줄이면 big 4화소 · wide 2.7~3화소(다른 점 1% 아래 · 3% 안팎). 그러나 줄이려면 서 있는 그림부터 새로 받아야 한다(도트를 줄여 다시 그리는 것은 안 됨) → 새 그림으로 뽑아 본 뒤에 정하시게 여쭘.
              확인: 규칙 검사 통과 · 내보내기 올릴 것 0장 · 새 기본 그림을 열어 봄. 못 본 것: 에테르 AI가 16:9 그림을 칸에 그대로 채워 내는지 · 진짜 도구의 결과가 가짜 입력만큼 깨끗한지(도구는 번짐 말고도 그림을 조금씩 고쳐 그린다).
          ▶ 2026-10-11 사용자(S78의 답을 보고): "아니 게임에서 표현되어지는 크기를 줄이라는거에요 스프라이트를 건드리라는게아니라"
              — 내가 잘못 읽었다: 「보스 크기 좀 줄여도 되니까」는 **게임 화면에서 그리는 크기**를 줄이라는 말이었다. 기본 그림을 바꿔 다시 뽑자는 것도, 받은 그림을 점으로 다시 옮기는 것도 아니다.
          ✔ S79 받은 동작 그림을 손대지 않고 화소 그대로 싣고, 게임과 시험 탭이 작게 · 부드럽게 줄여 그린다.
              싣기(`build_lune_boss_clips.mjs` — `BOSS_ANIM.read = 'asis'`): 색 맞추기 · 줄이기 · 날 세우기를 하지 않는다. 하는 일은 칸을 장으로 자르기 · 기준점 재기 · 투명한 화소의 숨은 색 채우기(보이지 않는 값 — 줄여 그릴 때 가장자리가 검게 물들지 않게)뿐.
                 부관 idle 139x140 · run 139x153 · attack 309x247화소 / 대장 idle 191x131 · run 167x112 · attack 257x126화소(받은 그대로). 점으로 옮기는 앞의 방식('dots' — 격자 읽기 포함)은 도구에 남겨 두었다(쓰지 않는다).
              그리는 크기(`design/bosses.js`의 `BOSS_SHOW = 0.75` — 내 제안): 제 서 있는 그림의 한 점 = 세계의 한 점을 1로 볼 때의 배율. 부관 68x72 · 대장 123x81(전에는 90x96 · 164x108).
                 동작마다 k(그림 한 화소 = 세계의 몇 점) = BOSS_SHOW ÷ 그 동작의 화소/점 → 부관 0.517 · 대장 0.775(화면 배율 3에서 받은 화소 하나가 1.6 · 2.3화소. 전에는 3화소 + 열세 색으로 맞춤).
                 싸움의 가로 길이도 같이 줄인다(`storyBoss` — 몸 · keep · reach · 맞는 자리 from/to · step · wave.at). 높이(up)와 물결은 그대로. 피하지 않는 사람: 부관 28초 · 52% / 대장 35초 · 71%(거의 그대로).
              게임: `sprite.luau` — 동작에 k가 있으면 그 배율로 그리고 `ResampleMode.Default`(부드럽게), 자리 · 크기는 소수 자리까지. 흰 번쩍임 · 분홍 윤곽 · 잔상도 같은 길로 간다. 캐릭터 그림판 5 → 6장(PAD 1 → 2).
                 올린 그림: chars_1~6 = rbxassetid://110967347107645 · 133756900660171 · 127467860720962 · 72220676550978 · 103546471071907 · 83722297992648 /
                 chars_mask_1~6 = 122113085270330 · 134234941519765 · 77305340358001 · 82483647685216 · 125667668412843 · 115949151462526.
              시험 탭: `frameOf`가 k만큼 줄여 부드럽게 그린다(탭의 그림판은 화면 해상도라 고운 그림이 그대로 보인다).
              크기 고르기: 관리 창 「전투 → 보스 크기」 100 · 75 · 60 · 50 · 40% — 그림만 바꿔 본다(`Sprite.preview` · 맞는 자리는 설계값 그대로). 고른 값을 알려 주면 BOSS_SHOW로 굳힌다.
              확인: 규칙 검사 통과 · 자동 검사 294,497개 통과(검사 24: 그리는 크기 = 그림의 화소 x k · 부드럽게 · 미리보기 배율 / 검사 30: 「보스 크기」 단추) · 시험 탭의 멈춘 그림 여섯 · 화면 크기 그대로 자른 것 ·
                 Studio Play(확인용 리븐 Lv.32 → 망루 꼭대기): 대장이 75%로 곱게 그려지고 예고의 윤곽 · 맞는 자리가 줄어든 몸에 맞는 것을 찍음. 콘솔 오류 없음. 확인용 속성 지움(attrs 0 — 상태 확인 → 속성 → 시작 → 끄기 → 지우기를 하나씩).
              못 본 것: 관리 창의 「보스 크기」 단추를 Play에서 눌러 보지는 못했다(화면 없는 검사로만) · 부관을 Play에서 · 스마트폰(그림판 6장) · 1080p 전체 화면(배율 5 — 받은 화소가 2.6 · 3.9화소로 커진다).
              배운 것: 「크기를 줄여도 된다」를 내 해법(다시 뽑기 · 다시 그리기)에 끼워 읽지 않는다 — 말 그대로 화면에 그리는 크기다. 사용자가 만든 그림은 손대지 않는 것이 기본이다.
          ▶ 2026-10-12 사용자: "지금 이방식은 별로인거같습니다. 제가 애니메이션를 만드는게아니라 지금 기반 보스 만드는것처럼 코덱스로 생성하고 그걸 당신이 수정해서 최종 도트디자인 캐릭터로 가져오는것처럼 스프라이트 시트도 그런 방향으로 만들어야 할거같아요"
          ✔ S80 보스의 동작을 Codex로 만든다 — 장 하나하나를 기본 보스 그림과 같은 길로(Codex가 그린다 → 내가 점으로 옮기고 다듬는다 → 차례대로 엮는다). 두 보스의 공격 동작을 만들어 게임 · 시험 탭에 넣음.
              청하는 법: 내가 다듬은 서 있는 그림을 정확한 K화소 격자로 키워 판 위에 놓은 그림(`assetpack/lune/monsters/ref_<보스>_k*.png` — scratch의 make_ref.py)을 붙이고 "같은 블록 크기 · 같은 크기 · 같은 자리에서 자세만 바꿔 다시 그려라". 한 번에 한 자세(`prompt_mk_<보스>_attack_<장>.txt` → `mk_<보스>_attack_<장>.png`).
                 재 본 것: 블록은 6.0~7.6화소로 온다(정확한 격자는 지키지 않는다). 눈의 높이 · 눈 사이의 점 수가 서 있는 그림과 같다(부관: 발밑에서 71점 ↔ 70~72점) → 그 장의 블록 크기로 옮기면 같은 크기의 몸이 된다.
                 바탕은 투명 · 초록 어느 쪽이든 된다("초록으로"만 적으면 Codex가 바탕을 고치느라 한 번 더 그린다 → "어느 쪽이든 좋다 · 바탕 때문에 다시 그리지 마라").
              옮기기: 기본 그림과 같은 도구(`build_lune_creatures.mjs --bosses` — `BOSS_SHEETS` 끝에 `BOSS_MADE`의 장들이 「보스~장」으로 붙는다). 장에는 `tight`(줄 간격을 기준 ±1화소로) —
                 느슨하면(±4화소) 무늬가 많은 장에서 줄이 늘어 그 장만 몸이 15% 커졌다(부관 swing 163x133 → 146x123).
              다듬고 엮기(새 도구 `build_lune_boss_made.mjs`): 제 색이 아닌 점 고치기 · 윤곽 잇기 · 잡티 · fix / 기준점 = 발밑 + 뒷발(서 있는 그림의 뒷발과 같은 자리) / `drop` = 무기의 길이 맞추기(단면이 고른 날의 가운데를 빼고 당겨 붙인다 — 대장의 45도 장 8걸음) /
                 `clips`의 seq(장의 차례 — 'still' = 내 서 있는 그림)로 한 칸에 놓아 `chars/<보스>_attack.png` · `bossclips.json`. 시간 맞추기는 그대로(`BossFx.body` — anim은 이제 `BOSS_MADE`의 clips에서 온다).
              만든 것: 부관 lift · top · swing · hit(공격 14장: still lift×2 top×2 swing hit×5 lift×2 still · 초당 10장 · 닿는 차례 6) / 대장 lift · hit(공격 15장: still×2 lift×4 hit×8 still).
                 대장의 머리 위로 치켜든 장은 세 번 받았으나 못 썼다(① 정면 + 칼이 짧음 — 판에 자리가 모자랐다 ② 곧게 세운 자세는 잘 나왔지만 키 220점 > 화면(바닥 위 176점) ③ 어깨 뒤로 넘긴 자세는 칼이 두 배) → 예고의 멈춘 장을 lift(앞 위 45도 · 키 136점)로.
              같이 바꾼 것: `BOSS_SHOW` 0.75 → 1(도트 그림은 점 그대로 · k 없음 → Pixelated) · `BOSS_ANIM.read = 'made'`(에테르 AI의 동작은 읽지 않는다 — 넣어 주신 idle · walk · attack.png는 보스 폴더에 그대로) ·
                 관리 창의 「보스 크기」 줄은 고운 그림이 있을 때만 뜬다(지금은 안 뜬다) · 캐릭터 그림판 6 → 2장. 규칙 검사에 동작의 규칙(차례의 장 · 닿는 차례 · 예고보다 긴 치켜들기).
                 올린 그림: chars_1 · 2 = rbxassetid://76847239677032 · 84854610765755 / chars_mask_1 · 2 = 122887528856133 · 104122857504801.
              확인: 장마다 시안과 나란히(compare_mk_*.png) · 두 보스의 장을 한 줄에 놓고 봄 · 규칙 검사 통과 · 자동 검사 293,994개 통과 · 시험 탭의 멈춘 그림(두 보스 × 예고 · 닿는 순간 · 그 뒤) ·
                 Studio Play(확인용 리븐 Lv.32): 대장이 서 있는 모습과 내리베기의 예고(칼을 든 장 · 윤곽 · 맞는 자리)를 찍음. 콘솔 오류 없음. 확인용 속성 지움(attrs 0).
              못 본 것 · 남은 것: 게임에서 닿는 순간의 장(시험 탭으로만) · 걷기(지금은 서 있는 그림이 미끄러진다) · 부관의 휩쓸기 · 대장의 호령 · 쓰러짐 · 대기(지금은 내 두 장) — 같은 방식으로 이어서 만든다.
                 대장의 45도 장은 칼의 두께가 11점(서 있는 그림 14점) · 장마다 갑옷의 잔무늬가 조금씩 다르다(Codex가 장마다 새로 그린다). Codex 한 장에 3~9분.
              내 결정 · 여쭌 것: 대장의 공격 그림에 그려져 있는 흰 칼자국과 제 분홍 초승달 이펙트가 겹친다(둘 다 둠) · 대기 동작에서 대장이 칼을 치켜들었다 내린다(받은 그대로) ·
                 받은 그림의 해상도를 올릴 수 있는지(도구가 칸을 더 크게 낼 수 있는지 / 몸을 더 크게 놓은 기본 그림을 드릴지)를 여쭘.
          ▶ 2026-10-12 사용자: "공방 키고, 지금 보스 디자인부터 구려서 보스디자인부터 다시 뽑아보세요"
          ✔ S81 보스의 디자인을 다시 받았다(망루의 부관 · 정찰대장) — 보스마다 방향 셋을 받아 하나씩을 게임의 도트로 옮김. **디자인의 판정 대기**(고른 것은 내 판단).
              나빴던 것(내 판단 — 승인된 주인공 시안 `concept/raw_heroes_C4.png`과 나란히): 회색 한 색 · 점 눈의 둥근 머리 · 소재 없음 · 밋밋한 무기. 까닭 = 내 주문("병사와 같은 생김새 · 이 색만 · 망토도 깃발도 없이").
              받은 것(`assetpack/lune/bossdesign/` — 주문 `prompt_*.txt`): 망루의 부관 A 성루 기사 · **B 봉화지기(옮김)** · C 철갑 황소 / 정찰대장 **A 매 투구의 대장(옮김)** · B 늑대 가죽의 대장 · C 철가면의 장교. 자료 = `bosses.js`의 `BOSS_REDESIGN`.
                 `raw_bd_*` = 시안(주인공 시안을 그림체의 기준으로 붙임 — 한 점 3화소쯤의 일러스트로 온다) · `raw_bs_*` · `raw_bg_*` · `raw_bh_*` · `raw_bi_*` = 게임의 굵기로 다시 받은 것.
              굵게 받는 법: 「옛 보스를 한 점 10화소로 판에 가득 채운 그림」을 붙여 "절반의 해상도로 · 판을 가득 채워" → 한 점 8~10화소. 한 번 깨끗하게 나온 보스를 옮긴 점 그림(`ref_new_tl_k8.png` — `tools/make_lune_boss_ref2.py`)을 굵기의 기준으로 붙이면 더 잘 온다.
                 검은 갑옷의 가는 금줄은 한 점보다 가늘게 그려져 옮기면 뭉개진다 → "금은 몇 군데의 굵은 덩어리로만 · 갑옷 판은 민짜"로 다시 청함(그 주문 글은 S82에서 안과 함께 지웠다).
                 **Codex는 한 번에 하나씩만**: 동시에 돌리면 서로의 그림을 집어 간다(가장 새 PNG를 복사) — 두 보스가 섞인 그림이 한 번 나왔다. 한 명령에 `;`로 이어 돌린다. 잘못 받았을 때 제 그림은 `~/.codex/generated_images/<세션>/`에 있다.
                 도트 크기 재기: 색 경계의 주기(blk.py)와 런 길이(`tools/measure_lune_block.py` — 쓰지 말 것)는 틀린다. 윤곽선의 두께(scratch `olw.py`)가 맞았다(아는 그림 셋으로 확인). 그래도 생성 그림은 고른 격자가 아니다 — 옮긴 것을 확대해 견줘 본다.
              옮기기(`build_lune_creatures.mjs --bosses`): 보스마다 제 색(`BOSS_PALS` — `tools/make_lune_boss_palette.py <시안> 24`가 뽑는다 · 장의 `palette`) → `boss_rows.json`의 `pals`(짓는 도구 · 동작 도구가 읽는다). 팩의 열세 색에 묶지 않는다(내 판단).
                 `tight`(간격 ±1화소 — 느슨하면 161x123 → 164x132점으로 부푼다) · `smooth` 없이(가장 많은 색 고르기가 윤곽을 지킨다) · 새 옵션 `grid`(격자 줄의 느슨함) · `ink`(가는 선 지키기 — 대장의 눈) · 「칸의 맞음」 출력 · 시험 `LUNE_ONLY=<id> LUNE_GRID=span,cost` → `boss_rows_test.json`.
                 새 그림: 부관 161x123점 · 대장 187x128점(옛 90x96 · 164x108). 대장의 칼날 = 기울기 0.000(`BOSS_ART.straight` — `colors`로 날의 색을 적는다). 옛 그림의 fix · outline · despeckle은 뺌.
              싸움(`STORYBOSS`): 몸 · 맞는 자리를 새 그림에서 다시 잼 — 부관 body 76x92 · art 60 · keep 72 · 내려찍기 26~118 · 휩쓸기 -14~134 · 물결 72 / 대장 body 56x106 · art 94 · keep 62 · 내리베기 6~118. 체력 · 세기 · 예고는 그대로(검사 33: 28초 · 34초 그대로).
                 글: 생김새 · 동작 설명을 새 그림에 맞춤. 대장의 「호령」 = 허리의 뿔나팔을 분다(새로 생긴 것) · 부관은 「망루의 봉화를 지킨다」(내가 채움).
              동작: 옛 디자인의 장은 `BOSS_MADE_1012`로 접고 `BOSS_MADE = {}` → 공격은 서 있는 그림을 움직여 대신한다(`BossFx.pose`). 디자인의 판정 뒤에 S80의 방식으로 새로 만든다.
              옛 그림의 보관: `assetpack/lune/monsters/old_bosses_1012/`(서 있는 그림 · 동작 · 기본 그림 · boss_rows.json). 사용자 폴더의 `<id>_big · _wide.png`는 에테르 AI용이던 것 — 새 그림으로 한 번 덮였고 이제 쓰지 않는다.
              올린 그림: chars_1 · 2 = rbxassetid://111821676939756 · 109764676262818 / chars_mask_1 · 2 = 97152547129846 · 124822456297186. **Studio의 id가 바뀌었다**(a7a7d498-a906-46cf-bd7e-427a94d99013 — 사용자가 Studio를 다시 켬. `list_roblox_studios`로 본다).
              확인: 두 보스를 Codex의 그림과 전체 · 확대로 견줌 · 규칙 검사 통과 · 자동 검사 293,866개 통과 · 시험 탭의 멈춘 그림 · Studio Play(확인용 리븐 Lv.32): 부관 · 대장이 서 있는 모습과 대장의 호령(검병이 나옴). 확인용 속성 지움(attrs 0).
              못 본 것 · 남은 것: Play에서 공격을 맞아 보기(맞는 자리가 새 몸과 눈으로 맞는지) · 스마트폰 · 옮긴 도트가 Codex의 그림보다 선이 조금 거칠다 · 새 디자인의 동작 전부 · 나머지 보스 열넷(아직 회색). 기록 = 공방 「개발 진행」 맨 위(그림은 S82에서 `dev/BOSS11_*`로 바뀜).
          ▶ 2026-10-12 사용자(게임에서 새 부관과 싸워 보고): "망루의 부관은 세 디자인 전부 맘에듬 다 각각 보스로 살려도될듯 / 정찰대장 디자인 3종은 매 투구의대장 , 철가면의 장교 최악임 기각 삭제 / 늑대가죽의 대장 합격임 / 근데 조금 이질감이 있음 게임에서 플레이로보면 보스랑 배경, 플레이어 캐릭터와 조금 차이가있어서 이질감이있음"
          ✔ S82 판정을 반영 — 정찰대장 = 늑대 가죽의 대장 · 기각된 두 안을 지움 · 보스의 색을 게임의 색에 맞춤(`BOSS_TONE`). **색 맞추기의 판정 대기** — 동작은 그 뒤에.
              정찰대장: `raw_scoutcaptain_v11_creatures.png`(= `bossdesign/raw_bg_sc_B.png`) · 한 점 8화소로 옮김(170x124점 · `tight` · 제 색 24) · 두건 속 얼굴의 점 27개를 고침(`BOSS_ART.fix` — 눈과 줄무늬가 뭉쳤다). 이 빠진 칼이라 `straight` 검사에는 넣지 않고 시안과 확대해 봄.
                 `STORYBOSS`: body 60x100 · art 84 · keep 64 · 내리베기 reach 110 · zone 6~126. 글(생김새 · 동작)을 새 그림에 맞춤. 검사 33은 그대로(34초).
              지운 것(사용자 "기각 삭제"): `bossdesign/*_sc_A.*` · `*_sc_C.*` · 섞여 나온 그림 · `monsters/raw_scoutcaptain_v10_creatures.png` · `dev/BOSS10_*` · 사용자 폴더 `bosses/scoutcaptain/scoutcaptain_big · _wide(_white).png`(매 투구의 그림 — 폴더에서 옮겨 낸 뒤 지움). 기록은 `BOSS_REDESIGN.verdict.rejected` 한 줄.
              부관: 봉화지기가 그대로 부관. 성루 기사 · 철갑 황소 = `verdict.spare`(다른 보스로 살릴 디자인 — 아직 어디에도 안 넣음. 내 제안: 철갑 황소 = 공성 거인 · 성루 기사 = 창기병 대장).
              이질감 — 잰 것: ① 팩의 가장 어두운 색은 #232931(검정 없음)인데 새 보스는 거의 검정의 윤곽이 몸의 3분의 1 ② 팩은 채도 15~25%의 푸른 잿빛 · 보스는 50~75%.
                 고친 것 = 색만(`bosses.js`의 `BOSS_TONE` · `bossTone(id, pal)` — `build_lune_bosses.mjs` · `build_lune_boss_made.mjs`가 칠할 때 쓴다. `boss_rows.json`의 `pals`는 시안의 색 그대로): ink #232931 · sat 0.62 · tint [#7c8ea2, 0.2] · keep(부관의 불 → 팩의 분홍 · 눈).
                 견줘 보기: `LUNE_TONE=off`(시안의 색) · `LUNE_TONE=채도,몫`으로 `build_lune_bosses.mjs`를 돌린다(시험용 — 끝나면 값 없이 다시 돌린다). 네 세기의 화면 = `dev/BOSS11_4 · 5`.
                 색으로 못 고치는 것(사용자에게 알림): 그리는 방식(팩은 납작한 두세 단 · 보스는 네댓 단 + 잔 장식) · 크기(주인공 19점의 여섯 배) · 새 주인공 그림이 아직 게임에 없다.
              올린 그림: chars_1 = rbxassetid://124258609731835 · chars_mask_1 = 118077778997356(두 보스가 한 판에 들어갔다).
              확인: 규칙 검사 통과 · 자동 검사 293,866개 통과 · 시험 탭 · Studio Play(대장의 호령 예고 · 부관의 휩쓸기 예고 — 색을 맞춘 것). 확인용 속성 지움(attrs 0). 기록 = 공방 「개발 진행」의 첫 확인 요청(그림 `dev/BOSS11_*`).
              남은 것: 색 맞추기의 세기 · 깃발을 분홍으로 할지 · 남은 두 디자인을 어느 보스로 — 답을 기다림. 그 뒤 두 보스의 동작(S80의 방식 — 장의 `BOSS_SHEETS` 줄에 `palette`를 붙여야 한다) · 나머지 보스 열넷.
          ▶ 2026-10-12 사용자: "우리 캐릭터 엑시온만 지금 보스 도트스타일로 코덱스 통해서 만들어볼래요?"
          ✔ S83 액시온을 보스의 도트 방식으로(시험 — 서 있는 그림 한 장). 시험 탭 `?luneherodots=1`로만 보인다. 게임 · 평소의 탭은 그대로. **판정 대기**(방향 · 크기 · 동작을 만들지).
              자료 `js/lune/design/heroart.js`(HERO_SHEETS · HERO_PALS · HERO_TONE · HERO_FIX · HERO_AT) · 그림 `assetpack/lune/herodots/`(시안 raw_axion_a~e · 주문 prompt_axion_*.txt · hero_rows.json · axion_still.png · chars.json).
                 도구: `node tools/build_lune_creatures.mjs --heroes`(옮기기 — 보스와 같은 도구) → `node tools/build_lune_herodots.mjs`(그림 · 시험 탭용 그림판: 모든 동작 = 서 있는 그림 한 장).
              디자인 = 승인된 새 액시온(`Assets/character/luna/axion.png`). 결과 32x42점(투구 꼭대기 27 · 뿔 끝 31 · 도끼 끝 42 — 지금의 액시온은 24x20). 색은 `bossTone` + 청록은 팩의 민트로. 고친 점 = 걸쇠 두 점.
              **Codex를 작은 크기로 그리게 하는 법(찾은 것)**: "더 굵게 · 3분의 1의 해상도로"는 듣지 않는다(105점 → 62점 → 62점). Codex가 스스로 그리는 가장 잔 무늬는 10화소쯤이다 →
                 제 손으로 거칠게 줄인 그림(크기와 격자만 맞는 것)을 **한 점 10화소로 판 한가운데에 작게** 놓고 "같은 크기 · 같은 자리 그대로, 안쪽을 한 칸짜리로 고쳐 그려라(EDIT)"고 청한다 → 고른 격자의 깨끗한 도트로 온다(칸의 맞음 94%).
                 같은 그림을 판에 가득(한 점 25화소) 놓으면 바깥 윤곽만 격자에 맞고 안쪽은 반 칸으로 그려 온다(옮기면 얼굴 · 무늬가 깨진다).
                 옮기는 도구에 `uniform`(고른 격자 — 간격과 시작점을 하나씩만 고른다)을 넣음. 판은 1024를 청해도 1254로 온다(한 점 10 → 12.2~13.4화소).
              확인: 시안과 확대해 견줌 · 시험 탭의 사냥터 · 망루 꼭대기(두 보스 옆) · 규칙 검사 통과. 못 본 것: 움직임(동작 없음) · 게임 · 스마트폰. 기록 = 공방 「개발 진행」 맨 위(그림 `dev/HERO3_*`).
              알린 것: 보스 옆에서는 같은 그림으로 보이지만 사냥터에서는 주인공과 졸개(팩의 그림)의 결이 달라진다. 동작은 열 가지 · Codex로 40~60장쯤.
          ▶ 2026-10-12 사용자(그 액시온을 보고): "도트 퀄리티가 보스랑 너무 다르게 느껴집니다."
          ✔ S84 액시온을 다시 받고, 크기 · 굵기의 세 가지를 시험 탭에 나란히 둠(`?luneherodots=1 | big | fine`). **어느 쪽인지의 판정 대기** — 동작은 그 뒤.
              잰 것: 부관 10,868점 · 윤곽 36% · 명암 서너 단 ↔ 처음의 액시온 775점 · 윤곽 47% · 한두 단. 뿌리 = 크기(보스 123점 ↔ 액시온 30점 → 점이 14분의 1).
              ① 32x42점(다시 받음 — `raw_axion_f.png`): 보스의 윗몸을 한 점 10화소로 키운 그림(`ref_boss_quality_k10.png`)을 「그리는 방식」의 본보기로 붙이고 같은 크기 · 같은 자리에서 다시. 790점 · 고친 점 없음(칸의 맞음 90%).
              ② 48x63점(`raw_axion_g.png` — 같은 주문 · 뿔 끝까지 52점): 1,737점 · 칸의 맞음 97%. 보스 옆에서 가장 같은 그림. 키가 지금 액시온의 2.6배(발판 사이 48점보다 크다).
              ③ ②의 그림을 3분의 2로 그린 것(화면에서 32x42점 — 시험 탭의 clip에 `k` + `crisp`): 맵은 그대로 · 주인공의 도트가 보스 · 배경보다 잘다 · 화면 배율에 따라 고르지 않을 수 있다(게임에서 확인해야 함).
                 자료 `heroart.js`의 HERO_VIEWS(꼴 → 그림 · k) → `build_lune_herodots.mjs`가 `herodots/chars.json · chars_big.json · chars_fine.json`을 쓴다. 시험 탭의 `frameOf`에 `crisp`(줄여 그려도 번지지 않게).
              내 의견(사용자에게 적음): 같은 도트로 보이는 것은 ②뿐이나 맵을 다시 맞춰야 한다 · 맵을 두려면 ③(보스도 3분의 2로 줄이면 굵기가 같아진다 — 보스 82점) · ①은 구조에 맞지만 그림이 못하다.
              확인: 세 가지를 시험 탭의 망루 꼭대기 · 사냥터에서 찍음 · 규칙 검사 통과. 못 본 것: 동작 · 게임 · 스마트폰 · ③의 다른 화면 배율. 그림 `dev/HERO3_*`(갈아 끼움).
          ▶ 2026-10-12 사용자: "3. 화면의 크기는 1과 같고 도트를 곱게 가 맞습니다. 근데 이걸 모자, 상하의, 무기를 분리하고 기본 형태만 만들어서 장비를 바꿔끼면 외형도 바뀌는 방식으로 설계할수있나요?"
          ✔ S85 ③(fine)으로 정함(`heroart.js`의 HERO_PICK). 장비로 겉모습이 바뀌는 설계 = **된다고 답함 — 세 겹을 제안, 판정 대기**(`HERO_GEAR` · 공방 「개발 진행」 맨 위 · 그림 `dev/HERO4_1_layers.png`).
              시험(Codex에 `herodots/ref_axion_big_k10.png`을 주고 한 가지만 바꾸게 — `prompt_test_*.txt` · scratch의 regtest.py로 바탕과 점마다 견줌):
                 도끼만 빼기(`raw_test_noaxe.png`) = 몸의 점 96% 그대로 → 차이가 곧 무기의 층 / 투구만 바꾸기(`raw_test_hat.png`) = 모양은 그대로 · 몸이 반 점쯤 어긋남(55%) / 옷만 바꾸기(`raw_test_suit.png`) = 온몸을 다시 그림(투구 40% · 도끼 42%).
              제안: 몸(기본 형태 + 옷 한 벌 — 장마다 · 무기 없이 · 맨머리) / 모자(한두 장 — 머리의 자리에 얹음) / 무기(한 장 — 손의 자리와 기울기에 붙임 · 쥔 손은 앞에 다시). 값: 무기 1장 · 모자 1~2장 · 옷 한 벌 40~50장.
                 옷의 벌 수: 차수마다 한 벌(직업마다 네 벌) + 그 사이는 색만 — 내 제안. 장갑 · 신발은 색만 · 장신구는 겉모습에 없음. 조각을 움직이는 방식(리그)은 권하지 않음.
              정해지면 할 것: 기본 형태(맨머리)의 디자인 다섯 · `basics.js`의 「겉모습은 그대로다」 · `startplan.js`의 「외형은 정해져 있다」를 고친다 · 장마다 머리 · 손의 기준점 자료 · 시험 탭 · 게임의 겹쳐 그리기.
          ▶ 2026-10-12 사용자: "다 취소하고 보스를 현재 우리 에셋사용하는 본래의 엑시온,리븐 이런 캐릭터 의 디자인에 맞춰서다시만듭시다. 현재 모습은 도트라던가 원래 우리게임과 어울리지가 않아요 색깔은 다양하게 써도 되는데 도트사이즈나 이런게 캐릭터,배경과 다른게임이라는 느낌이 듭니다."
          ✔ S86 **S81~S85를 취소**하고 두 보스를 팩의 캐릭터의 그림에 맞춰 다시 만듦. **지금의 기준 = `bosses.js`의 `BOSS_PACKSTYLE`**. 판정 대기 — 동작은 그 뒤.
              취소한 것: 색이 풍부한 보스 그림(`bossdesign/` — 쓰지 않음 · 파일은 남김) · 색 맞추기(`BOSS_TONE = null`) · 주인공의 시험(`heroart.js` 맨 위에 취소를 적음 · 시험 탭의 `?luneherodots`와 `crisp`를 뺌 · `herodots/`는 남김) · 장비의 겹. 주인공은 팩의 그림 그대로.
                 공방 「개발 진행」에서 S82~S85의 확인 요청 셋을 빼고 그림(`dev/BOSS11_* · HERO3_* · HERO4_*`)을 지움.
              팩의 그림(잰 것 — `BOSS_PACKSTYLE.look`): 윤곽 없는 한 색의 실루엣(#393e46 · 그늘 #232931) · 명암의 단 없음 · 흰 뿔 · 흰 점 눈(2x2) · 포인트는 한 가지 밝은 색의 납작한 면 · 색 서너 가지 · 점 130~290개.
              받은 법: 기준 = 팩의 캐릭터 아홉을 키운 그림(`monsters/ref_pack_chars_x11.png`) + 팩의 그림으로 만든 보스 둘(공성 거인 · 그림자 사수). 주문 `prompt_towerlieutenant_v4 · v5 · prompt_scoutcaptain_v12 · v13_creatures.txt`.
                 처음 것(v4 · v12)은 한 점 8화소로 잘게 옴 → 그 그림 + 팩의 보스를 정확한 10화소 격자로 키운 그림(`ref_pack_boss_k10.png` — `make_lune_boss_ref2.py shadowarcher 10 …`)을 붙여 "더 굵은 도트로" → 부관 v5 = 고른 격자 16화소(78x63점 · `uniform`) · 대장 v13 = 13.8화소(108x74점 · 초록 바탕 `key`).
                 색: 팩의 열세 색의 글자 그대로 + 부관 갈색 둘(b · d) · 대장 늑대 털(f) — `BOSS_PALS`. 고친 점 없음(칸의 맞음 93% · 96%).
              소재는 그대로: 부관 = 봉화를 등에 멘 뿔 달린 거인 · 돌망치 / 대장 = 늑대 가죽을 뒤집어쓴 대장 · 이 빠진 칼 · 분홍 깃발 · 명령서 · 뿔나팔. 글(what · feat)을 팩의 그림에 맞춤.
              싸움(`STORYBOSS`): 부관 body 42x46 · art 30 · keep 46 · 내려찍기 reach 70 zone 12~78 up 52 · 휩쓸기 reach 92 zone -8~100 · 물결 46 / 대장 body 44x60 · art 51 · keep 52 · 내리베기 reach 80 zone 6~92 up 60. 체력 · 세기 · 예고 그대로(검사 33: 28초 · 34초).
              올린 그림: chars_1 · 2 = rbxassetid://127375458274030 · 132809294782535 / chars_mask_1 · 2 = 121818309652806 · 139978498802674.
              확인: 규칙 검사 통과 · 자동 검사 293,866개 통과 · 시험 탭 · Studio Play(부관이 다가오는 모습 · 대장의 호령 예고). 확인용 속성 지움(attrs 0). 기록 = 공방 「개발 진행」 맨 위(그림 `dev/BOSS12_*`). 색이 풍부했던 서 있는 그림의 보관 = `monsters/old_bosses_1012b/`.
              남은 것: 판정 → 두 보스의 동작(S80의 방식 — 동작의 장에도 `palette`를 붙인다) · 나머지 보스 열넷은 이미 팩의 그림이다(다시 받을 까닭이 없어졌다).
          ▶ 2026-10-12 사용자: "방향성은 맞는데 얼굴은 왜 뭉게버리는거야?"
          ✔ S87 두 보스의 머리와 얼굴만 다시 받음(부관 v6 · 대장 v14) — 크고 둥근 민짜 머리 · 흰 네모 눈 둘 · 눈에 닿는 것 없음. 규칙 = `BOSS_PACKSTYLE.face`.
              까닭(내 잘못 둘): 작은 머리 둘레에 흰 것을 몰아넣은 주문 · 옮기면서 눈이 한 점 / 가는 줄로 줄었는데 「조금 복잡하다」고만 적고 넘김.
              방법: 옮긴 점 그림을 정확한 격자로 키운 것(`ref_tl_v5_k14.png` · `ref_sc_v13_k12.png` — `make_lune_boss_ref2.py`) + 팩의 캐릭터 그림을 붙이고 "EDIT — 같은 격자 · 같은 크기 · 같은 자리, 머리와 얼굴만"(`prompt_towerlieutenant_v6 · prompt_scoutcaptain_v14_creatures.txt`).
                 **정확한 격자의 그림을 붙여 EDIT를 청하면 Codex가 그 격자 그대로 그려 온다**(간격 14.00 · 12.00화소 · 몸의 크기도 화소까지 같다) → `uniform` + `pin`으로 옮기면 칸의 맞음 99%(고칠 점 없음). 크기 · 발의 자리가 그대로라 `STORYBOSS`는 손대지 않음.
                 (`pin`이 없으면 14화소의 격자를 7화소로 잘못 재서 "잘게 그려졌다"고 옮기지 않는다)
              올린 그림: chars_1 = rbxassetid://114355219398357 · chars_mask_1 = 75094790553730. 자동 검사 293,970개 통과 · 시험 탭 · Studio Play(부관 · 대장의 호령 예고) · attrs 0. 그림 `dev/BOSS12_*`(얼굴 견줌 = `BOSS12_8_faces.png`).
          ▶ 2026-10-12 사용자: "아니아니 제가 한말은 뭐냐면 그림체랑 도트사이즈를 통일해야지 왜 캐릭터디자인을 다 검은얼굴에 흰눈깔을 억지로 붙이냐는 이야기입니다. 그건 우리 주인공캐릭터들의 고유 디자인인데"
          ✔ S88 **S86 · S87을 바로잡음** — 맞추는 것은 그림체와 도트 크기뿐, 생김새는 캐릭터마다 제 것(`BOSS_PACKSTYLE.style` · `.design`). 두 보스에 합격한 디자인을 돌려놓음(부관 v7 · 대장 v15). 판정 대기.
              내 두 가지 오독: 「캐릭터의 디자인에 맞춰서」 = 생김새까지 베끼기로 · 「얼굴은 왜 뭉게버리는거야」 = 눈이 작다로. 뜻은 「보스의 제 얼굴을 왜 지웠느냐」였다.
              방법: (A) 지금의 납작한 그림을 정확한 격자로 키운 것(`ref_tl_v6_k14.png` · `ref_sc_v14_k12.png` — 그리는 방식 · 격자 · 크기 · 자세) + (B) 합격한 디자인의 그림(`monsters/design_towerlieutenant.png` · `design_scoutcaptain.png` = bossdesign의 raw_bg_tl_B · sc_B) →
                 "EDIT — (A)의 격자 · 크기 · 자세 · 납작한 방식 그대로, 생김새(머리와 얼굴 먼저 · 살빛 · 차림 · 색)는 (B)의 것" + 그리는 방식의 규칙(한 색 + 그늘 한 단 · 잔 무늬 두 점 · 가장자리 #232931). 주문 `prompt_towerlieutenant_v7 · prompt_scoutcaptain_v15_creatures.txt`.
                 같은 격자로 왔다(14 · 12화소) → `uniform` + `pin` · 칸의 맞음 93% · 96%. 색 = 그 그림에서 뽑은 열대여섯(`BOSS_PALS` — k는 #232931). 고친 점 = 대장의 뺨의 붉은 줄 아홉 점(`BOSS_ART.fix`).
              크기 · 발의 자리 그대로(부관 80x64 · 대장 108x74) → `STORYBOSS`는 손대지 않음. 글(what · feat)도 지금의 그림에 맞춤(부관: 푸른 잿빛 살 · 창살 투구 · 분홍 눈 / 대장: 붉은 줄의 얼굴 · 붉은 눈).
              올린 그림: chars_1 = rbxassetid://119281242647728 · chars_mask_1 = 117328873004457. 규칙 검사 통과 · 자동 검사 293,866개 통과 · 시험 탭 · Studio Play(부관 · 대장의 호령 예고) · attrs 0.
              여쭌 것: 이것이 맞는지 · 다른 보스 다섯(공성 거인 · 그림자 사수 · 불씨 도둑 두목 · 창기병 대장 · 타락한 부단장 — 내가 「병사와 같은 생김새」로 잡은 것)도 제 얼굴로 다시 받을지 · 성루 기사 / 철갑 황소를 어느 보스에.
                 (heredoc 안에 작은따옴표가 든 긴 명령을 background로 돌리면 깨진다 — 주문 글은 Write로 만든 파이썬 파일로 쓴다)
          ▶ 2026-10-12 사용자(v15의 정찰대장을 보고): "부관은 잘 수정했는데 정찰대장 이건 진짜 아니잖아요 얼굴이 이게 뭡니까진짜로" — **부관(v7)은 합격**
          ✔ S89 정찰대장의 머리만 다시 받음(v16) — 옆을 보는 늑대 머리(귀 · 늑대의 붉은 눈 · 주둥이와 코 · 윗턱의 송곳니) 아래로 사람의 얼굴(붉은 두 눈 · 뺨의 줄무늬). 판정 대기.
              틀렸던 것: 두건이 꼴 없는 흰 덩어리 + 얼굴이 붉은 점이 박힌 갈색 공. 주문에 머리의 「구조」를 보여 주지 않았다(낱말로만 적었다).
              방법: 합격한 디자인의 머리를 잘라 두 배로 키운 그림(`monsters/design_scoutcaptain_head.png`)을 따로 붙이고 구조를 조목조목 적음 + 합격한 부관의 그림을 「얼굴이 읽히는 본보기」로 붙임 + 지금의 점 그림(정확한 격자)의 EDIT. 주문 `prompt_scoutcaptain_v16a · v16b_creatures.txt`(a = 같은 크기의 머리 · b = 머리를 조금 키움 — **b를 씀** = `raw_scoutcaptain_v16_creatures.png`).
                 같은 격자 12.00 · 몸의 크기 그대로 → 칸의 맞음 98.7%. 색 다시 뽑음(`BOSS_PALS.scoutcaptain`). 발의 자리 그대로 → `STORYBOSS` 그대로.
                 **눈이 또 줄었다**: 시안의 눈(가로 1.8 · 1.4점)이 격자에서 반 칸 비켜 있어 1x2로 옮겨짐 → 시안에서 눈의 자리를 재서 2x2로 네 점을 고침(`BOSS_ART.fix`). 눈 · 입처럼 한두 점짜리 생김새는 옮긴 뒤 시안에서 크기를 재서 견준다.
              올린 그림: chars_1 = rbxassetid://87534950938323 · chars_mask_1 = 83132876941489. 규칙 검사 통과 · 자동 검사 293,970개 통과 · 시험 탭 · Studio Play(대장의 호령 예고) · attrs 0. 그림 `dev/BOSS12_9_captain_head.png` 등.
          ▶ 2026-10-12 사용자(v16을 보고): "늑대전사스타일말고 아예 새로뽑으세요" — 늑대 가죽의 대장은 기각
          ✔ S90 정찰대장을 새로 뽑음 — 세 안(`bosses.js`의 `BOSS_CAPTAIN2`): **A 외눈 감시자(게임에 옮김 — 내 판단)** · B 깃발지기 · C 고블린 두목. 판정 대기.
              받은 법: 합격한 부관의 그림을 정확한 12화소 격자로 키운 것(`monsters/ref_tl_v7_k12.png`) 한 장만 붙이고 "이 그리는 방식 · 격자 · 굵기로 새 보스를" — 주문 `prompt_sc2_A · B · C.txt`. 바로 게임의 그림체로 왔다(색이 풍부한 시안 단계를 거치지 않는다).
                 도트 크기는 안마다 달랐다: A 12.4화소(그대로 씀) · B 9화소 · C 11화소 → B · C는 미리 읽은 점 그림을 거칠게 줄여 정확한 12화소 격자로 키운 것(`ref_sc2_<안>_rough_k12.png`)을 붙여 "같은 격자 · 같은 크기로 깨끗하게" 다시 받음(`raw_sc2_B2 · C2.png` — 13화소쯤으로 왔다. 고르면 정식으로 옮긴다).
                 Codex가 "Selected model is at capacity"로 한 번 실패 → 20초 쉬고 다시 청함(되풀이 고리로).
              A를 옮김: `raw_scoutcaptain_v17_creatures.png`(= raw_sc2_A.png) · block 12.4 · pin · tight · 제 색 15 → 111x76점 · 칸의 맞음 95% · 고친 점 없음. `STORYBOSS`: body 50x58 · art 40 · keep 54 · 내리베기 reach 84 zone 6~98 up 62. 글(생김새 · 동작 — 언월도 · 신호 등불)을 새로 씀.
              올린 그림: chars_1 = rbxassetid://121878662907808 · chars_mask_1 = 92205626405399. 규칙 검사 통과 · 자동 검사 293,970개 통과 · 시험 탭 · Studio Play(호령의 예고) · attrs 0. 그림 `dev/BOSS13_*` · 미리 읽은 점 그림 `monsters/preview_sc2_B · C.png`.
              쓰지 않게 된 것(파일은 남김): 늑대 가죽의 대장(raw_scoutcaptain_v11~v16 · design_scoutcaptain*.png · bossdesign/raw_*_sc_B).
          ▶ 2026-10-12 사용자(S81의 봉화지기 화면을 붙이고): "지금 첨부한 이미지쯤 버전 이미지뽑고 도트를 바로 변환했던버전 자료 가지고있나요? 대답만해보세요" → "그때 버전 보스들 공방에 띄워주세요"
          ✔ S91 그때 버전(색이 풍부한 그림을 도트로 바로 변환한 것)의 보스 넷을 다시 지어 공방 「개발 진행」 맨 위에 띄움. **게임 · 시험 탭의 보스는 바꾸지 않았다** — 사용자가 보고 무엇을 할지는 아직 말하지 않았다.
              자료 `bosses.js`의 `BOSS_RICH_SHEETS · BOSS_RICH_PALS · BOSS_RICH_FIX` → `node tools/build_lune_creatures.mjs --rich`(→ `monsters/rich_rows.json` · `compare_rich_*.png`) → `python tools/build_lune_boss_rich.py`(→ `monsters/rich/<id>.png`).
              봉화지기 161x123(10,868점) · 늑대 가죽의 대장 170x124(10,374점 · 얼굴의 고친 점 27) = 그때와 같다 / 성루 기사 162x109 · 철갑 황소 163x108 = 그때는 옮기지 않았던 안(같은 방식 · 칸의 맞음 81% · 83%). 그림 `dev/RICH_*`.
          ▶ 2026-10-12 사용자: "오케이 이버전으로 픽스하고 , 애니메이션 만들어봅시다. 봉화지기부터"
          ✔ S92 **보스의 그림 확정 = 그때 버전(Codex의 그림을 도트로 바로 변환 · 색 그대로 — `bosses.js`의 `BOSS_FIXED`)** + 봉화지기(망루의 부관)의 동작 넷(걷기 · 내려찍기 · 휩쓸기 · 쓰러짐)을 게임에 넣음.
              되돌린 것: `BOSS_SHEETS`(부관 raw_towerlieutenant_v3 · 대장 raw_scoutcaptain_v11) · `BOSS_PALS` · `BOSS_TONE = null` · `STORYBOSS`의 몸 · 서는 거리(S81 · S82의 값). 그 뒤의 길(색 가라앉히기 · 납작한 그림 · 검은 얼굴 · 새 정찰대장들)은 쓰지 않는다.
              동작(`BOSS_MADE.towerlieutenant` — Codex에 한 장씩, 본 = `monsters/ref_tl_rich_k6*.png`(서 있는 그림을 한 점 6화소로)): run 4장(초당 5) · attack 14장 · sweep 9장(초당 10) · death 7장(초당 8). 받은 17장 가운데 13장을 씀.
              ★ 화면에서 바닥 위로 보이는 높이는 **150점**(장면의 땅 176 → 화면의 150 — `ui.js` GROUND. 그동안 176으로 잘못 알고 있었다). 치켜든 장 셋(230 · 190 · 177점)은 위가 잘려 버리고 낮은 자세(raise 150 · back 131)로 다시 받음 — 높이의 숫자만 적으면 지키지 않는다: 손의 높이 · 자루의 각도를 적고, 가로형 그림(바닥 위 164점)에서 청한다. 검사에 「동작의 키 ≤ 150」 추가.
              걷는 장: 윗몸은 서 있는 그림의 점을 그대로(`match` 윗몸으로 자리 맞춤 + `keep` 이음매) — Codex가 장마다 윗몸의 명암을 달리 그려 와(같은 점 86~91%) 그대로 틀면 끓는다. 처음 받은 걷는 장은 다리를 펴 키가 19점 솟았다 → 「몸을 낮춘 채 · 다리는 그대로 짧게」로 다시.
              기준점(`tools/build_lune_boss_made.mjs`): 뒷발 = 맨 아래 넉 줄의 폭 10점 넘는 덩어리(가시 · 내려놓은 돌망치는 발이 아니다) · 발이 맨 아랫줄보다 위면 그만큼 무기가 땅에 박힘 · 내딛는 장은 Codex가 뒷발을 뒤로 빼 그려 와(swing 27 · hit 7 · sweepend 16점) `dx`로 맞춤 · 무릎 꿇은 장 · 누운 장은 `anchor`(화소로 재서 적음).
              맞는 자리를 그림에 맞춤(제 제안): 내려찍기 · 땅 울림 26~118 → 26~150(reach 136 · 물결 118) · 휩쓸기 -14~134 → -14~154(reach 140). 세기 · 예고 · 체력 그대로.
              쓰러짐: `BOSS_FALL { hold 0.8, fade 0.6 }` · `bossfx.js`/`bossfx.luau`의 `fall` · 서버 `stepBoss`가 `story.fall`(2.28초) 동안 치우지 않음(death가 없는 보스는 전처럼 0.9초 · 선 채로 사라짐) · `storyBoss`의 anim.fps = 패턴 동작(hit가 있는 것)의 빠르기(걷기의 5가 섞여 들어가던 것 고침). 시험 탭 `&lunekill=초`(화면 확인용).
              확인: 규칙 검사 통과 · 테스트 294,022개 실패 0(보스 테스트 둘은 옛 숫자를 가정하던 것을 고침 — 물결의 시간 · 친 뒤의 상태) · Play(리븐 Lv.32 확인용): 걷기 · 두 예고 · 내리친 순간 · 쓰러짐 화면 확인, 오류 0. 휴대폰 미확인. 올린 판 chars_1 · chars_2 + mask.
              남은 것: 정찰대장의 동작(같은 방법 — 서 있는 그림만 있다) · 성루 기사 / 철갑 황소를 쓸 보스 · 나머지 보스 14(옛 회색 그림).
          ✔ S93 정찰대장(늑대 가죽의 대장)의 동작 넷도 같은 방법으로 게임에 넣음(사용자가 따로 시킨 것이 아니라 「봉화지기부터」에 이어 한 것 — 정찰대장 = 늑대 가죽의 대장은 내 읽기, 확인을 청해 두었다).
              `BOSS_MADE.scoutcaptain`(본 `monsters/ref_sc_rich_k6.png` · `_right.png`): run 4장(초당 6 — 내달리기는 두 배) · attack 14장(still → back x3 → still → end x8 → still · hit 5) · shout 7장(horn · hit 3) · death 7장(초당 8). 받은 9장을 다 씀.
              자세: 내리베기의 예고 = 칼을 머리 곁에 들어 날을 뒤로 눕힘(124점) · 벤 끝 = 깊이 내디딘 채 날을 무릎 높이로(128점) · 호령 = 칼끝을 땅에 짚고 뿔나팔을 분다 · 쓰러짐 = 젖혀짐 → 꽂은 칼에 매달림 → 엎어짐(기준점은 화소로 재서 `anchor`).
              맞는 자리(제 제안): 내리베기 6~126 → 6~156(칼끝 144 + 내딛는 12) · reach 110 → 136. 쓰러져 사라지기까지 2.28초(부관과 같다).
              확인: 규칙 검사 통과 · 테스트 294,259개 실패 0 · Play(리븐 Lv.32 확인용 · 「정찰대장」을 받은 것으로): 내리베기의 예고 · 벤 끝 · 호령 · 쓰러짐 화면 확인, 오류 0. 내달리기는 화면으로 못 찍음. 휴대폰 미확인. 올린 판 chars_1~3 + mask(판이 2 → 3장).
              남은 것: 사용자의 판정(두 보스의 동작 · 정찰대장의 디자인) · 성루 기사 / 철갑 황소를 쓸 보스 · 나머지 보스 14(옛 회색 그림).
          ▶ 2026-10-12 밤 사용자(두 보스의 동작을 보고): "근데 지금 패턴이 너무적습니다. 뻔하고 보스 크기좀 줄이고 패턴좀 멋있게 만드세요 다른게임들 보스 어떻게 만드는지도 좀 공부해서"
          ✔ S94 ① 공부(`bosses.js` `BOSS_PATTERN_STUDY` — Dead Cells 수위 · Hollow Knight 거짓 기사 / 사마귀 군주 · 메이플 반 레온 / 매그너스 · Skul 위그드라실) ② 보스 크기 4분의 3(게임까지) ③ 새 패턴(**시험 탭에만** — `STORYBOSS_NEXT`).
              크기: `BOSS_SIZE = 0.75` — 같은 Codex 그림을 굵은 칸으로 다시 옮김(`build_lune_creatures.mjs`의 `shrink`: 그 그림의 진짜 칸을 찾은 뒤 ÷0.75 간격으로 줄을 긋는다 — 장마다 같은 비율). 부관 120x91 · 대장 127x93점. 장의 자리 숫자(dx · anchor · match · keep)는 본래 크기의 값에 비율을 곱해 쓴다. `STORYBOSS`의 몸 · 서는 거리 · 맞는 자리를 다시 잼.
              덕에 쓰게 된 장: `lift`(돌망치를 곧게 세움 141점) · `back45`(어깨 뒤 45도 130점) → 내려찍기의 예고 = back45. 새 동작(받은 장으로 엮음): toss · beacon · leap · roar(부관) · roar(대장).
              새 패턴(시험 탭 `luneTab.js` stepStory · `bossfx.js`): 부관 = 내려찍기 · 휩쓸기 · 불씨 뿌리기(spots aim hero · far 70) · 도약 찍기(leap · far 90) → 60%에서 「봉화를 올린다」(phase) → 땅 울림 · 연속 찍기(chain) · 봉화 불기둥(spots grid 두 번). 대장 = 내리베기 · 검기(wave front blade · far 80) · 호령 · 내달리기(far 110) → 50%에서 「늑대의 포효」 → 연속 검기(wave n 3) · 몰아치기(chain).
              고르기: 「가장 오래 안 쓴 것」 → 거리(reach · far)로 추린 뒤 몫(w)대로 뽑기 · 방금 쓴 것은 피함 · 포효 뒤 쉬는 틈 x0.8. 화면 확인용 `&lunepat=패턴`.
              게임: 크기만 줄었다(패턴은 `STORYBOSS`의 셋 그대로 — `storyBoss(id)`. 시험 탭은 `storyBoss(id, true)`). 테스트 294,338개 실패 0 · Play로 줄인 부관 확인. 올린 판 chars_1 · 2 + mask.
              남은 것: 사용자가 시험 탭에서 해 본 뒤 → 게임으로 옮기기(서버 `stepBoss` · `bossfx.luau` · 화면 · 테스트 · 난이도 재기) · 새 패턴의 제 몸 동작(Codex) · 크기 0.75의 판정.
          ▶ 2026-10-12 밤 사용자: "지금 보스 정면 이미지는 어디에있는지?"(→ 정면 그림은 없다고 답하고 기본 그림의 자리를 알림) → "지금 두 몬스터 모두 걷기모션이 개판입니다. 전혀 걷는것처럼 보이지않고 우스꽝스럽게 보입니다."
          ✔ S95 두 보스의 걷는 동작을 다시 만듦(여덟 장 · 초당 4장) — 게임까지.
              그 앞의 잘못: 싸우는 자세를 걸음의 한 장으로 씀 · 장을 하나씩 따로 받아 두 다리가 번갈아 나가지 않음 · 윗몸을 서 있는 그림으로 고정(`match` + `keep`) · 네 장.
              방법: ① `stand`(두 발을 모으고 선 자세 — 줄인 서 있는 그림 K=8을 본으로) ② stand 넷을 놓은 2x2 시트(한 점 5화소 · 칸 768x512 · 바닥 y 495 / 1005)를 본으로 **네 장을 한 그림에** 받음 = 닿음 · 지나감 x 두 다리(`w1~w4`) ③ 그 네 장을 놓은 시트를 본으로 사이 넉 장(실림 · 뻗음 x 두 다리 — 대장 `i1~i4` · 부관 `j1 · j2 · j4`). 시트를 칸마다 자르는 것 = 화소 그대로. 장의 옵션 `small`(줄인 본으로 받은 장 — 다시 줄이지 않는다) · `anchor [가로, 999]`(가로 = 칸 안에서 몸의 가운데가 있던 자리 · 맨 아랫줄이 바닥).
              걸린 것: 부관의 첫 사이 장 시트는 한 점 5.33화소로 굵게 와(옮기면 6% 작다) 다시 받음 — 시트마다 한 점의 크기를 재야 한다(가장자리 주기). 「실림」 장의 디딘 발은 두 번 다 닿은 자리에 그대로 왔다(화소 자리를 적어 줘도 안 지킴) — 남은 흠으로 알림. 부관의 반대쪽 「실림」은 j1을 한 번 더 씀.
              걷는 빠르기: 부관 34 → 44 · 대장 38 → 46(디딘 발이 한 걸음 1초에 46~47점 뒤로 간다 — 제 제안). `run` = w1 · (i|j)1 · w2 · (i|j)2 · w3 · … 초당 4장. 옛 걷는 장(mk2_*_walk*.png)은 목록에서 뺌(파일은 남김).
              확인: 규칙 검사 통과 · 시험 탭 `&lunepat=none`(패턴을 쓰지 않고 걷기만)으로 0.25초마다 여덟 장 확인 · 테스트 294,468개 실패 0 · Play(리븐 Lv.32 확인용)에서 걸어 들어오는 부관 확인. 움직이는 그림(APNG) `dev/WALK_1_*_loop.png` · `WALK_2_*_move.png`. 올린 판 chars_1~3 + mask.
              (Play 도중 화면 찍기가 한 번 5분쯤 멈췄고, 그 사이 확인용 캐릭터가 조금 움직이고 기술 E가 켜져 있었다 — 사용자가 Studio를 만진 것으로 보인다. 그 뒤 4초 동안 입력이 없는 것을 보고 끄고 `LuneGuest`를 지웠다.)
          ▶ 2026-10-12 밤 사용자: "추가 패턴 적용하고 , 지금 보스 둘다 제가 walk 애니메이션 가져왔습니다.\n이거 사용해보세요"
          ✔ S96 ① 새 패턴(`STORYBOSS_NEXT` — 부관 7 · 대장 6)을 **게임에** 옮김 ② 걷는 동작 = 사용자가 가져온 `walk.png`(받은 화소 그대로).
              걷기: `bosses.js` `BOSS_WALK_GOT`(부관 loop 7~28 · 초당 14 / 대장 loop 3~20 · 초당 9) → `python tools/build_lune_boss_userwalk.py`(격자를 재고 — 게임의 한 점 = 3.75 · 3.42화소 — 걷는 한 바퀴의 장을 잘라 `chars/<보스>_run.png` · `userwalk.json`. 화소는 그대로, 투명한 곳의 숨은 색만 채움) → `build_lune_boss_made.mjs`가 bossclips의 run에 끼움(how asis · px) → `build_lune_bosses.mjs`가 k = 1/px.
              도트로 옮겨도 봤다(칸마다 가장 많은 색) — 받은 그림보다 거칠어 버림. Codex로 만든 걷는 동작은 `BOSS_WALK_CODEX_1012`에 기록(쓰지 않음). 걷는 빠르기: 부관 44 → 34(그림의 디딘 발 2.4점/장 x 14) · 대장 46(5.0 x 9). 그림판 3 → 11장(올린 이미지 22).
              패턴(서버 `sim/room.luau`): `bossCan · bossPick`(거리 reach / far · 체력 from · every · 몫 w · 방금 쓴 것 피함 — `self.rng`) · `bossStart`(연속기 chain — 첫 번째는 제 예고대로, 둘째부터 quick배) · `bossBegin`(겨눈 자리 aim · 표시된 자리 `self.blasts`) · `bossDone` · stepBoss(roar · 도약 leapFrom/leapTo/alt · 연속기의 한 걸음 slide) · 물결의 wait · 표시된 자리의 판정. snapshot 9 → 12칸(겨눈 자리 · 연속기 · 빠른 패턴).
              자리와 시간의 셈(서버 = 화면): 새 모듈 `sim/bosspat.luau`(tell · act · spots · leapAlt · leapTo · waves). 그림 `bossfx.luau`(spot · blast · jump · roar · bladeCrest · strike의 새 갈래 · tell의 도약 / 검기 / aim). 화면 `bossView.luau`(표시된 자리 `self.spots` — 예고가 끝까지 가면 armed · 도약의 내려앉음 · 포효 → hooks.push) · `mobsView.luau`(`patOf` — 연속기의 빠른 예고 · `m.jump`) · `boot.luau`(`state.push` — 포효에 밀려남).
              고친 숫자(시험 탭도 같이): 예고 ≥ 1.2초(휩쓸기 1.1 → 1.2 · 검기 1.0 → 1.2 · 도약 0.9 → 1.0 + 날아가는 0.6) · 연속기 quick 0.55 → 0.7. `storyBoss(id)`의 기본이 새 패턴(next = true).
              확인: 규칙 검사 통과 · 테스트 294,685개 실패 0(33 보스 테스트를 새 패턴으로 다시 씀 · 24 화면 테스트에 새 패턴 추가 · 12의 snapshot 12칸) · 난이도 부관 27초 · 51% / 대장 34초 · 66%(붙어 서서 치는 사람) · Play(리븐 Lv.32 확인용): 부관의 걷기 · 도약 예고 · 불씨 · 내려찍기 · 휩쓸기 · 포효 · 불기둥 화면 + 연속 찍기의 차례 기록 / 대장은 내달리기 예고만. 오류 0. 휴대폰 미확인.
              남은 것: 사용자의 판정(걷는 그림의 화소가 서 있는 그림보다 고운 것 · 새 패턴 · 그림판 11장) · 새 패턴의 제 몸 동작 · 대장의 새 패턴을 Play 화면으로 확인.
          ▶ 2026-10-12 밤 사용자: "작업끝나면 반드시 검증해야하는 경우 아니면 그냥 종료하고 저한테 검증해달라고 해도 됩니다. 스튜디오 키면서 검증하지말고" → **Play로 확인하지 않는다**(검사 · 테스트 · 시험 탭 화면까지만 하고 사용자에게 볼 것을 알린다).
          ▶ 같은 밤 사용자: "워크 애니메이션의 경우 고운게 어색하게 느껴져서 도트로 찍어서 적용하는 방식을 사용해야할거같습니다. 그리고 지금  키세팅을하고 다시접속하면 키세팅이 초기화됩니다.\n그리고 패턴 이팩트들  스킬이펙트 재사용하지말고 새로 만드세요 퀄리티 높게"
          ✔ S97 ① 걷는 그림 → 도트 ② 키 설정 저장 ③ 패턴의 이펙트 = 제 그림(스프라이트) 15종. **Play 미확인**(사용자에게 확인을 청함).
              ① 걷기: `python tools/build_lune_boss_userwalk.py`를 다시 씀 — 첫 장(= 서 있는 그림을 키운 것)을 서 있는 그림에 맞대 격자(P · 자리)를 찾고 → 그 격자로 모든 장을 읽는다(칸의 30% 넘게 차면 점 · 색 = 그 칸에서 가장 많은 색 — 보스의 24색) → 잔점 지우기(SPECK) → `monsters/uwd/<보스>_u<번호>.png` · `userwalk.json`(기준점).
                 `bosses.js` `walkGot()`가 그 장들을 `BOSS_MADE`의 frames(`dots` · `got` · `small`)와 run(`calm`)으로 넣는다. `build_lune_boss_made.mjs`의 calm(깜박임 고치기)은 **몸 안의 색만** 맞춘다(빈 곳까지 맞추면 윤곽이 지워진다 — 고침).
                 버린 것: Codex 그림을 옮기는 도구(같은 점 30%) · 장마다 격자 다시 맞추기(--track) · 서 있는 그림의 점을 움직임에 맞춰 옮겨 오기(영상 도구가 장마다 다시 그려 같은 조각이 없다). 첫 장이 서 있는 그림과 같은 점 74% · 67%. 그림판 11 → 3장.
              ② 키 설정: `server/lune/modules/world.luau` — `saveSoon`(키 · 퀵슬롯 · 스마트폰 배치를 바꾸면 SAVE_SOON 4초 뒤 저장 · Heartbeat의 `World.saveDue`) · `saveAccount`는 계정을 먼저 쓰고 순위판은 그 뒤 · `saving` 수를 세어 `World.stop`(BindToClose)이 쓰는 중인 저장을 STOP_WAIT 20초까지 기다린다. 테스트 `34_lune_keys_persist`(63개 — 저장소가 값을 JSON처럼 거치고 3초씩 느려도).
                 Studio에서 「API 서비스 사용」이 꺼져 있으면 저장소가 메모리뿐이라 여전히 지워진다(store.luau — 다른 까닭).
              ③ 이펙트: 청하는 글 · 틀 `python tools/build_lune_boss_fx_prompts.py`(칸 · 바닥 줄 · 기준 표시를 파란 줄로 그린 틀 `guide_fx_<꼴>.png` + 보스의 서 있는 그림 `ref_<보스>_k5.png`) → Codex(한 번에 하나) → `monsters/mk4_<보스>_fx_<이름>.png` 12장
                 → `python tools/build_lune_boss_fx.py`(초록 · 파랑 빼기 → 보스의 색 + 새 색 → 이펙트마다 정한 크기 `px`로 다시 찍기 · `soft` 경계 둥글림 · `sit` 바닥에 붙이기 · `tone: false`) → `bossfx.json` · `chars/<보스>_fx_*.png` · `compare_fx_*.png`
                 → `build_lune_boss_made.mjs`가 bossclips에 같이 싣는다(how fx) → bosses → export. 자료 = `bosses.js` `BOSS_FXLAY · BOSS_FXART · BOSS_FX`(패턴 → 그림 · 자리) — `storyBoss()`가 패턴에 `fx · spots.fx · wave.fx · leap.fx · summon.fx · dash.trail · dash.crash · phase.fx`로 붙인다.
                 트는 곳: 시험 탭 `luneTab.js`의 `fx.sprite`(frameOf) · 게임 `effects.luau`의 `Effects:play`(delay · back · loop · vx · lo · hi · fade) — `bossfx.js / bossfx.luau`의 blast · jump · roar · strike · crash · wave · dashTrail은 그 그림을 틀 뿐이다(인자에 who가 생겼다). 기술의 이펙트 부품(beam · ring · spike · shards · rise · cut · slash · pop · streaks)과 crest · bladeCrest는 보스에서 뺐다. 예고(zone · lane · alert · callMark · spot)와 흔들림은 그대로.
                 겪은 것: Codex는 점의 굵기(4.0 · 5.3 · 7.3화소)와 크기(물결 = 청한 것의 두 배)를 제멋대로 그린다 · 바탕이 투명하기도 초록이기도 · 바닥 줄에서 띄워 그리기도(같은 그림의 윗줄 1점 · 아랫줄 15점) · 드물게 흐린 그림(포효 — 다시 받음. 옛 것은 `old_mk4_…_v1.png`).
                 검사: 패턴이 트는 그림이 bossclips에 있어야 한다 · 물결 · 표시된 자리 · 포효는 그림이 꼭 있어야 한다 · FXART의 동작은 어느 패턴이든 써야 한다.
              확인: 규칙 검사 통과 · 테스트 294,999개 실패 0(24를 새 방식으로 다시 씀) · 시험 탭 화면(dev/FX_2_*) · Studio에 새 코드가 들어간 것(Edit에서 script_grep). 올린 그림판 3장 + 마스크 3장. `assets/lune`의 chars_4~11(+마스크)은 이제 안 쓰는 찌꺼기 — 지우지 않았다(사용자에게 물음).
              남은 것: 사용자의 게임 확인(걷기 · 키 설정 · 이펙트) · 예고도 그림으로 바꿀지 · 새 패턴의 제 몸 동작.
          ▶ 2026-10-13 사용자(게임에서 보고): "검기 패턴 보스 크기에비해 너무 비루하게 나갑니다. 검기가 너무작아요 \n그리고 walk 애니메이션 보면 찌그러지는듯한느낌이 너무심합니다.\n스킬 이펙트들은 맘에듭니다.\n그러면 이번엔  제가드린 애니메이션을 그대로 도트로 옮기는것보다 \n동작 원리만 정확하게 파악하고  walk 애니메이션을 만들어봅시다. \n지금 어택이나 다른 애니메이션 만든것처럼"
              → 패턴의 이펙트 그림(S97 ③)은 **승인**. 검기는 키운다. 걷는 동작은 가져오신 그림을 옮기지 말고 원리를 읽어 공격 동작처럼(Codex 자세 → 도트) 새로 만든다.
          ✔ S98 ① 검기 두 배 ② 걷는 동작 = 원리로 새로 만든 여덟 장(윗몸은 서 있는 그림의 점 그대로). **Play 미확인**.
              ① 검기: `BOSS_FXART.scoutcaptain.blade.fx_blade` px 8 → 4 · soft 1.6(칸 39x33 → 77x66) · `STORYBOSS_NEXT`의 bladewave · storm `wave.up` 18 → 28(제 숫자).
              ② 원리(잰 것 — `python tools/study_lune_boss_walk.py` · 적어 둔 곳 `bosses.js` `BOSS_WALK_STUDY` 머리말): 윗몸은 한 덩어리로 오르내리기만(부관 2.5 · 대장 4.5점 — 닿을 때 낮고 모일 때 높다) · 디딘 발은 장마다 같은 만큼 뒤로(2.4 · 5.3점/장) · 앞발은 멀리(+34 · +30), 뒷발은 곁에(+9 · +17) · 자락 · 사슬 · 꼬리는 늦게.
                 **가져오신 그림은 검은 윤곽의 절반(52% · 48%)이 투명하게 뚫려 있다** — 도트로 옮긴 것이 거칠었던 큰 까닭. 본으로 쓸 때는 메운다.
                 만드는 법: `python tools/build_lune_boss_walk_prompts.py` → `pose2_<보스>_walk_<1~4>.png`(이음매 `seam` 위 = 서 있는 그림의 점 그대로 · 아래 = 가져오신 장(`picks`) · 바닥에 긴 표시 = 몸 가운데 + 짧은 표시 둘 = 디딘 발의 뒤꿈치 · 발끝 `feet`) + `prompt_mk6_…`(칸마다의 자세 글 `say` · 걸음의 설명 `gait`)
                 → Codex(한 장에 두 자세) → `mk6_<보스>_walk_<n>.png` → `--split` → `mk6_<보스>_w1~8.png` → `build_lune_creatures.mjs --bosses` → `build_lune_bosses.mjs` → `build_lune_boss_made.mjs`(`walkMade()` — match · keep = seam: 윗몸은 서 있는 그림의 것 · `shelf` = 이음매의 턱 깎기(대장)) → bosses → export.
                 겪은 것: 가져오신 장을 통째로 본으로 주면(mk5) Codex가 팔 · 무기까지 흔들리게 그려 이음매에서 어긋난다(윗몸과 같은 점 35%) → 윗몸을 본에 미리 얹으면 85% · 격자도 5.00화소로 맞는다.
                   표시 · 글 없이는 두 발이 모이는 자세를 벌려 그린다(디딘 발이 10점 어긋남) → 발 자리 표시 + 칸마다의 글로 3점 안. 대장의 털가죽 그늘(가져오신 그림에만 있는 어두운 안쪽)은 본에서 털의 색으로 바꾼다(`fur`).
                   배경의 until-루프로 다음 Codex 작업을 이어 걸 때는 앞 작업의 `last_*.txt`까지 기다린다(그림 파일만 보면 겹칠 수 있다). 셸을 멈춰도 codex exec는 남는다 — 제 것만(명령줄로 확인하고) 멈춘다.
                 빠르기: 부관 초당 5.7장 · 34점/초(그대로) / 대장 초당 5장 · **speed 46 → 55**(디딘 발이 한 바퀴에 48 · 88점 뒤로 간다 — 발이 미끄러지지 않게. 제 숫자). 대장 w2 · w3의 dx = 디딘 발이 고르게 가게.
                 가져오신 그림을 옮기는 길(`BOSS_WALK_GOT` · `walkGot` · `build_lune_boss_userwalk.py` · `uwd/`)은 기록으로 남김(쓰지 않음).
              확인: 규칙 검사 통과 · 테스트 295,058개 실패 0(난이도 그대로 — 부관 27초 · 51% / 대장 34초 · 66%) · 장마다 디딘 발의 자리(스크래치의 walkfeet.py — 모두 3점 안) · 시험 탭의 검기 화면 · 올린 그림판 3 + 3장 · Studio에 들어간 것(script_grep). 걷는 모습은 볼 수 없어 사용자에게 청함(dev/WK_*).
              남은 것: 사용자의 판정(걷는 느낌 · 팔이 안 움직이는 것 · 대장의 빠르기 55 · 검기의 크기) · 여덟 장이 끊겨 보이면 열두 장으로.
          ▶ 2026-10-13 사용자(게임에서 보고): "좋습니다.  합격이고  이제  우리 게임에서 미구현된게 무엇이있죠?" → S98(걷는 동작 · 검기) **합격**. 곁들여 여쭌 것(열두 장 · 팔의 흔들림 · 대장의 빠르기 55)에는 답이 없었다 — 지은 대로 둔다.
          ▶ 2026-10-13 사용자: (오디오 스무 개를 Studio의 Import로 올리고 번호가 보이는 화면을 보냄) "업로드 완료했어"
          ✔ S99 소리 연결 — 음악 열두 곡 + 효과음 여덟 개의 번호를 `node tools/build_lune_music.mjs '{…}'`로 적음(`assetpack/lune/sounds.json` → `music.generated.luau` — 빈 번호 0).
              화면에서 읽은 번호는 Studio(Edit)에서 `MarketplaceService:GetProductInfo`로 이름을 대조함(스무 개 모두 맞음). 사용자가 올릴 곡의 폴더 이름을 `gameupload`로 바꿔 도구도 그 이름을 쓰게 고침.
              보스의 곡: 두 스토리 보스가 사냥터 맵(r1c4 — 곡 field_c)에 서 있어 `lair` · `boss` 곡이 틀 데가 없었다 → `STORYBOSS[보스].music`(부관 lair · 대장 boss) → story.music → `bossView.luau`가 나타난 보스가 바뀔 때 `hooks.music(곡 | nil)` → `boot.luau`가 `Music.play` / `Music.scene`. 테스트 24에 추가. 검사: 그 곡이 music.js에 있어야 한다.
              확인: 규칙 검사 통과 · 테스트 295,062개 실패 0 · Studio에 들어간 것(script_grep). **소리는 들을 수 없다 · Play 미확인** — 사용자에게 청함. 2~4지역의 장면은 제 곡이 없어 field_a로 떨어진다(범위 밖). 단추 소리 · 소리 크기 설정은 없다.
          ▶ 2026-10-13 사용자: "코덱스 활용해서  우리게임 아이콘이랑,영문이름, 썸네일, 배경사진 이런거 만들어주세요"
          ✔ S100 알리는 그림과 영문 이름 — 자료 `js/lune/design/store.js`(`STORE`: 이름 · 소개 글 · 그림 목록) · 청하는 글 `python tools/build_lune_store_prompts.py`(본 = 승인받은 다섯 영웅 `ref_heroes.png` + 처음 화면 `ref_title.png`)
              → Codex 세 번(`assetpack/lune/store/mk_store_keyart · icon · bg.png`) → `python tools/build_lune_store.py`(16:9로 잘라 1920x1080 · 아이콘 512 · 제목은 갈무리14(BDF)를 직접 읽어 처음 화면의 꼴로 얹는다 — 그림 생성기에 글씨를 그리게 하지 않는다)
              → 올릴 파일 `C:/YJS/Roblox/Assets/character/luna/store/`(icon_512 · thumbnail_1_keyart · thumbnail_2_world · background_1920x1080 · keyart_1920x1080) · 공방 그림 `dev/STORE_*`.
              영문 이름 제안 = Heirs of the Moon(다른 후보 Moon Heirs · Moonheir · Heir of the Moon · Lunar Heirs — 웹 검색으로 같은 이름의 게임을 못 찾음). **사용자의 답을 기다림.** 「Luneblade」(팩 이름)는 쓰지 않는다.
              겪은 것: Codex가 아이콘의 밤하늘을 투명하게 빼고 그려 왔다(RGBA) → 처음 화면의 하늘색 띠를 깔아 메움. 흰 제목은 달 위에 얹으면 묻힌다 → 어두운 하늘 쪽에.
              알릴 것: 그림 속 영웅은 승인받은 새 그림인데 게임 안은 아직 Luneblade 원본이다(썸네일과 게임이 다르다) · 대표 그림의 용 그림자 · 아이콘의 얼굴(리븐)은 내 판단 · 실제 게임 화면의 썸네일은 만들지 않았다(청하면).
          ▶ 같은 날 사용자(그 그림을 보고): "아니 왜  우리 에셋캐릭터로 만들어야지 왜 저 캐릭터들을넣어 뭐하냐 너" → **영웅이 나오는 그림은 게임의 캐릭터(팩의 스프라이트)로 그린다.** 2026-10-07의 Codex 시안(달 가면의 영웅 — `Assets/character/luna/<직업>.png`)은 쓰지 않는다.
          ✔ S100-2 아이콘 · 대표 그림을 게임의 캐릭터로 다시 — 본 `ref_heroes.png` = `assetpack/lune/chars/<직업>_idle.png`의 첫 장을 열 배로 · 글에 "생김새는 정해져 있다(둥근 검은 몸 · 흰 뿔 · 흰 눈 · 무기 하나 — 사람 · 기사로 바꾸지 말 것)".
              아이콘 = 리틀 액시온(민트 도끼) · 썸네일 ① = 다섯 캐릭터 + 달 + 용 + 제목. 앞의 그림은 `old_mk_store_keyart_c4.png` · `old_mk_store_icon_c4.png`으로 남김(쓰지 않음). 풍경 · 썸네일 ②는 그대로(캐릭터가 없다).
          ▶ 사용자(다시 만든 그림을 보고): "좋습니다." — 영문 이름은 따로 정해 주지 않았다(Heirs of the Moon은 여전히 제안).
          ▶ 같은 말에 이어(메이플스토리 상점 화면과 함께): "그리고 이제  대장간 장비제작이나, 상점에서 소비템 구매하는거나  메이플스토리처럼 아이템 아이콘이 보여야합니다."
          ✔ S101 상점 · 제작 창의 줄마다 아이템 그림 — 시험 탭과 게임에 같이.
              치수: 공방 `design/ui.js`의 `UILAYOUT.shop`(iconS 24 · nameW 120 · priceW 36) · 새 `UILAYOUT.craft`(row 44 · tabH 24 · makeW 58 · makeH 22 · feeW 34 · matW 135 · note · hint) → 게임 `Layout.SHOP` · `Layout.CRAFT`.
              상점: [칸 24 + 그림 18] 이름 · [달돈] 값 · 사는 단추. 그림 이름 = `ShopWindow.stockIcon(stock, class)`(물약 · 주문서 = 그 아이템의 것 · 장비 = `ItemCell.icon` — 무기는 내 직업의 것 · 달가루). 못 사는 것도 그림은 보인다.
              제작: 윗줄 [칸 + 만들 장비의 그림] 이름 · [달돈] 삯 · 「제작」(높이 22), 아랫줄 재료 둘([그림] 이름 가진 수/드는 수 — `ShopWindow.craftParts`가 재료마다 { icon, text, ok }를 준다. 그 앞의 한 줄 글 `craftNeeds`는 없앴다). 못 만드는 것은 아랫줄에 「Lv.N부터 만든다」.
              탭: `ui/paint.js`의 `paintShop`(그림) · 새 `paintCraft`, `?lunedemo=shop | craft | craft2`.
              검사: 15(치수 — 이름과 달돈 · 값이 겹치지 않는다 · 재료의 글 「미스릴 광석 9999/20」이 칸에 든다 · 레시피의 재료는 둘까지) + 끝에 **상점 · 제작 창을 화면 없이 지어 보는 검사**(Ui를 가짜로 — 다섯 직업 x Lv.1 · 10 · 30: 줄마다 칸과 그림 · 그림 이름이 아이콘 판에 있다 · 같은 줄의 글 · 그림 · 단추가 가로로 겹치지 않는다 · 「제작」은 재료가 모여야 눌린다 · 누르면 그 레시피가 서버로). 일부러 자리를 틀리게 하면 825개가 실패하는 것을 봤다. 전체 31만 개쯤 0 실패.
              Play로 보지 않았다(사용자에게 확인을 청함). 강화 창 · 퀘스트 보상 · 창고는 그대로.
          ▶ 2026-10-13 사용자: "게임 설명 글좀 만들어줄래  로블록스에 업로드할때 소개 란에 들어가는 게임소개야" → 한글(488자) · 영문(990자) 소개 글을 `design/store.js`의 `STORE.about`에 넣음(1000자 한도는 내 기억 — 다시 찾아보지 않았다고 알림).
          ▶ 같은 날 사용자(남은 일의 목록을 보고): "파티 퀘스트는 필요없고   탐사수첩은 뭔가요?  일일의뢰는 설계하는것이 좋습니다. / 소리조절 있어야합니다. / 부탁퀘스트는 무엇인가요? / 스킬 초기화 물약은 추후 추가하겠습니다. 신경쓰지마세요 / 강화창이랑 퀘스트 보상에 아이템그림 들어가야합니다."
              → **파티 퀘스트는 만들지 않는다 · 스킬 초기화 물약은 사용자가 뒤에 넣는다(만들지도 묻지도 않는다)** · 탐사 수첩 · 부탁 퀘스트는 무엇인지 설명함(내가 붙인 이름이라 낯설었다 — 부탁 = 사이드 퀘스트, 못 하는 하나 = 「묵은 도토리」).
          ✔ S102 퀘스트 보상 · 강화 창의 그림 — `questWindow.luau`: `rewardText`(한 줄 글)를 없애고 `rewardParts(reward, level, class)`(조각 { icon?, text }) + `rewardLayout(parts)`(자리와 폭). 물약 = `Items.potionFor(level).icon` · 장비 = `ItemCell.icon`(내 직업) + `Items.name`.
              `forgeWindow.luau`: 드는 것 두 줄(달가루 · 정수) 앞에 그림(`COST_ICONS = { "dust", "orb" }` · 줄 높이 COST 20 · 창의 높이 +8). 장비와 재료의 칸은 처음부터 그림이었다(앞의 보고가 부정확했다 — 알림).
              검사 15의 끝: 모든 퀘스트 x 다섯 직업 x 레벨 다섯의 보상 줄(그림 이름 · 폭 ≤ 300 · 차례) · 퀘스트 창을 지어 탭 셋의 보상 그림이 제자리인지 · 강화 창 여덟 단계 x 별 0~25의 드는 것 줄. 일부러 틀리게 하면 잡는 것을 봄. 시험 탭에는 이 두 창이 없다(그림 없음).
          ✔ S103 소리 설정 — 공방: `basics.js` WINDOWS에 `sound`(여는 키 없음 — 메뉴에서) · `ui.js` `UILAYOUT.sound`(줄 34 · 「−」「+」 22 · 칸 열 개 11x14 · 처음 10칸) · `paint.js` `paintSound` · 시험 탭 `?lunedemo=sound | sound7-3 | sound7-3-off`.
              게임: `music.luau`에 `Music.level = { music, sfx }`(0~10칸) · `gain(kind)` · `setLevel` · `import` · `export`(배경 음악 = 틀고 있는 곡의 크기에 곱한다 · 효과음과 징글 = 낼 때의 크기에 곱한다 · 0이면 내지 않는다) · `ui/soundWindow.luau` · 메뉴의 「소리 끄기 / 켜기」 → 「소리 설정」(PC · 스마트폰).
              저장: **계정의 것**(`sim/account.luau` `sound = { music, sfx, on }` — `cleanSound` · `setSound` · pack / unpack / view) · 패킷 `Sound` · 서버 `onSound` → `saveSoon`. 화면은 `first.select.sound`를 처음 화면의 음악을 틀기 전에 얹는다(`Music.import`). 확인용 임시 캐릭터는 처음 크기.
              검사: 34의 끝(Sound → 저장 → 나갔다 들어옴 · 말이 안 되는 값 아홉 가지 · 바꾸자마자 나가기 · 소리 설정이 없던 옛 저장) + 새 35(계정의 셈 · 크기의 셈 · 창을 지어 단추와 칸을 모두 누른다). 처음 크기 = 100%(지금까지와 같다). 단추 소리는 없다.
          ✔ S104 파티 퀘스트를 설계에서 뺌 — `basics.js` UNLOCK의 Lv.20 줄 · `world.js` 지역마다의 `party`(넷) · GROWTH의 gates · splitNames · LIFE.cycles의 줄 · `quests.js` 부탁 넷의 보상 글(「파티 퀘스트 … 안내 · 달돈」 → 「달돈」) · `economy.js` PAY · DUST.from의 줄 · `atlasTab.js`. 검사: 「지역마다 파티 퀘스트를 알려 주는 부탁」 규칙을 「파티 퀘스트가 남아 있으면 오류」로 바꿈.
              빼고 나니 「강화: Lv.150 한 부위 10성 = 하루치 달가루 안」이 1.4배로 어긋남 → 일일 의뢰의 달가루를 5 → 20분 치로(하루치의 합 160분 치 그대로). 게임 쪽은 만든 적이 없어 바뀐 것이 없다. 파티(같이 사냥) · 파티 버프 · 파티 경험치는 그대로.
          ✔ S105 일일 의뢰의 설계안(만들지는 않았다) — `js/lune/design/daily.js`(`DAILY` · `huntPool` · `dailyOf(지역, 날)` · `dailyXp / Money / Dust(L)`) · 「퀘스트 · 수첩」 탭의 맨 위 · 검사(풀 · 서른 날 뽑아 보기 · 보상의 크기 · economy.js와 맞는가).
              조사: 메이플 아케인 리버 일일 퀘스트(마을의 주민 · 그 지역 몬스터 600 → 400 → 200 · 심볼) · 로스트아크 에포나(하루 3개). 가져오지 못한 글이 많다(StrategyWiki · Icy Veins는 403).
              안: 그 지역의 메인을 끝내면(1지역 = 「불타는 마을」 · Lv.28) 마을의 「의뢰 게시판」에서 하루 셋(사냥 40마리 둘 + 순찰 하나 — 7분쯤) · 자정(한국 시간)에 바뀜 · 모든 사람에게 같은 의뢰 · 보상은 **내 레벨** 기준(의뢰 하나 = 경험치 40마리 치 + 달돈 20마리 치 · 셋을 다 내면 달가루 20분 치). 「흔적의 공명」은 넣지 않음(미룸).
              묻는 것: 여는 때(Lv.28 / 더 일찍) · 게시판 / 새 주민 · 하루의 양 · 순찰 의뢰를 넣을지(그림 셋).
          ▶ 2026-10-13 사용자(설계안을 보고): "탐사수첩은 필요없습니다.   부탁퀘스트 필요합니다. 일일 퀘스트 필요합니다. 게시판이랑 상호작용해서 일퀘받는거 좋습니다. 근데 좀더 간결하게 해도 될거 같습니다.  5분쯤 걸리게 / 일일 의뢰는 10부터 열죠"
              → **정해진 것: 일일 의뢰 = 게시판 앞에서 · Lv.10부터 · 5분쯤 · 간결하게 / 탐사 수첩은 만들지 않는다 / 사이드 퀘스트는 있어야 한다.**
          ✔ S106 일일 의뢰를 만듦(시험 탭의 창 + 게임) — 줄인 것(내 판단): 하루 둘 · 둘 다 사냥 30마리(순찰 의뢰 · 그만두기를 뺌).
              설계 `js/lune/design/daily.js`(`DAILY` · `huntPool` · `dailyPick(지역, 레벨, 날)` · `dailyXp / Money / Dust` · `dailyGame()`) → 게임 `data/daily.generated.luau`(레벨마다의 보상 150개 · 풀 · 글 · 맞춰 볼 값 checks).
              의뢰를 뽑는 법: 풀(사냥터마다 그 몬스터 — monsterPlace.js) 가운데 그 몬스터의 가장 낮은 레벨 ≤ 내 레벨인 것의 **높은 셋(near)** 에서 날짜로 둘(`top[(day + i) % k]`). 날 = `floor((os.time + 9시간) / 86400)`(자정 = 한국 시간).
              게시판 = 마을 그림에 이미 있던 소품 `board`(town.js props — 사당 옆 발판 F의 x 396)를 **말을 걸 수 있는 물건**으로: `TOWNMAP.boards` → `build_lune_town2.mjs`가 장면의 npcs에 `stone = true`로 올림(명예의 전당의 비석과 같은 방식) · `items.js NPCDO.board = 'daily'`. 새 그림 0장.
              게임: `sim/daily.luau`(sync · accept · onKill · turnIn · view · mark · tracked · pack / unpack — 캐릭터의 `h.daily[지역] = { day, tasks{ scene, mob, n, have, st 0·1·2 }, bonus }`) · `hero.luau`의 저장 · 패킷 `Daily`(Function — view는 어디서든 · accept / turn은 `nearNpcId(게시판)`) · `DailyView`(잡을 때마다) · `world.luau`의 `applyResult`가 퀘스트 다음에 `Daily.onKill`.
              화면: `ui/dailyWindow.luau`(창 `daily` — `state.openNpc`의 kind "daily" · 멀어지면 닫힘) · 알리미 `questPanel.luau`의 `layout(…, daily)`에 「일일」 줄 · 게시판 위의 `! / ?`(`Daily.mark`) · Lv.10에 닿으면 `Guide.banner`.
              보상: 의뢰 하나 = 경험치 · 달돈 30마리 치(내 레벨) · 둘을 다 내면 달가루 20분 치. **경험치는 40 → 30으로 내림**(Lv.10에서 둘 = 한 레벨의 154% → 115%).
              검사: 새 36(자료 · 뽑기가 공방과 같다 · 하루의 흐름 · 저장 · 알리미의 줄 · 창) + 13의 끝(서버: 게시판 앞에서 받고 · 그 맵에서 **실제로 잡아** 수가 오르고 · 게시판에 낸다 · 다시 들어와도 남는다). 전체 365,921개 0 실패. Play로 보지 않았다.
              남은 것: 게시판은 초승달 마을뿐(주막에는 그림이 든다) · 다른 지역의 게시판 · 자정에 접속 중인 사람의 화면은 다음에 게시판을 열거나 잡을 때 바뀐다 · 시험 탭에는 창의 그림만 있다(받고 잡는 놀이는 없다).
          ✔ S107 탐사 수첩을 설계에서 뺌 — `quests.js`의 지역마다 `notebook`(넷) · SIDESPLIT의 10%(비워 둠 — 부탁의 몫을 올리면 게임에 있는 부탁들의 경험치가 달라진다) · `basics.js` WINDOWS의 `note` · UNLOCK Lv.15 · KEYS의 N · `economy.js` PAY의 줄 · `world.js`의 글들 · 탭. 검사: 수첩이 남아 있으면 오류.
              곁들여: 창고의 가장 큰 칸 수 56 → 40(`storeGrows` = 지역마다 부탁 하나뿐). 숨은 자취 · 달의 기록은 설계에 남김(게임에 없음).
          ✔ S108 1지역의 부탁 열을 모두 — 「묵은 도토리」(Lv.19 · r1s8): 도토리 할머니 · 보상 보스 검은엄니를 부르던 것 → **고갯마루 노인 · 망루 아래의 굴 두더지 스물**(사냥 — 새 주민 · 새 물건 그림 없이. 줄거리와 말은 내가 채움). `MOB_NOW`에 굴 두더지 · `OLD`의 검은엄니에 `noQuest`(여는 부탁이 없다 — 보스의 사다리를 다시 짤 때 정한다) · 도토리 할머니를 「새로 세울 사람」에서 뺌. 테스트 27의 「부탁 아홉」 → 「열」.
          ▶ 2026-10-13 사용자(게임에서 — 출력 창과 화면): "이런 버그가 발생합니다.  포탈시 페이드아웃하면서 다 로드 시키고 넘어가야하는데 이게 왜 이런버그가 생기는지" — `[lune] 장면을 그리지 못했다 r1c2: …effects:406: attempt to index nil with 'Destroy'`(문을 지난 뒤 캐릭터 · 몬스터가 없고 이전 맵의 그림과 분홍 이펙트만 남음).
          ✔ S109 고침 — 까닭: `Effects:destroy`가 날아가는 것(`self.shots`)을 모두 흰 줄(`s.frame`)이라고 보고 지웠다. 제 그림으로 나는 것(`s.sprite` — `atk.shot.clip`이 있는 몬스터: 빈 투구 helm · 이끼 두꺼비 frog · 굴뚝 도깨비 chimney · 따개비 barnacle)이 떠 있는 동안 문을 지나면 nil을 지우려다 오류.
              그 치우기가 `enterScene`의 맨 앞이라 새 장면이 통째로 안 그려졌다(그림 불러오기 · 막과는 상관없다). `endShot`과 `update`는 두 가지를 가렸는데 `destroy`만 빠져 있었다.
              ① `effects.luau`의 destroy가 둘을 가려 지운다 ② `boot.luau`의 enterScene이 이전 장면의 것 일곱(캐릭터 · 몬스터 · 보스 · 이펙트 · 다른 사람들 · 맵 · 이름표의 층)을 하나씩 pcall로 치운다(오류는 warn — 새 장면은 그린다).
              검사 24에 「날아가는 것이 떠 있는 채로 치운다」(흰 줄 · 그림 · 쏘는 몬스터 모두) — 고치기 전의 코드로는 같은 오류로 실패하는 것을 봄. 전체 366,028개 0 실패. Play로 다시 보지 않았다.
              배운 것: 한 가지 것에 꼴이 둘 생기면(흰 줄 / 그림) 만드는 곳 · 고치는 곳 · **치우는 곳**을 모두 본다 — 장면을 떠나는 길은 그 순간에 떠 있는 것이 있어야만 드러난다.
          ▶ 2026-10-13 사용자(남은 일의 목록을 보고): "소리는 일단 제가 나중에 또 다시 에셋 구해올거라서 지금 신경쓰지마시구요 / 쪽지, 비석 같은건 그냥  메인스토리 푸는  약하게 스포하는 도구로만 사용하세요 / 의뢰 게시판은  의도적으로 마을에만 넣겠습니다. 추후 대형도시급 되는 마을이 생기면 거기도 의뢰게시판을 넣구요 지금은 마을만 / 사당지하 개발 해야합니다.  이렇게  30이전 마무리 되면 그후에 다시 이야기합시다"
              → **소리는 손대지 않는다(에셋을 가져오실 때까지) · 읽을거리 = 메인 이야기의 가벼운 예고로만(보상 없음) · 의뢰 게시판은 마을(과 뒤의 대형 도시)에만 · 사당 지하를 만든다 · Lv.30 앞이 마무리되면 다음을 이야기한다.**
          ✔ S110 사당 지하(설계의 맵 r1cs = 게임의 장면 `in_cellar`) — 메인 아홉째 「불타는 마을」: 차돌 → **사당 지하의 정예 검병 열둘(Lv.28)** → 보름 영감. 전에는 싸움 없이 받아서 가기만 했다.
              방: 한 화면짜리 실내(`town.js`의 `cellars` — under 'shrine' · stair 348 · need 'r1m9' · door 24 · mobs 넷 · stones 비석) · 그림 `town/indoor/raw_cellar.png`(Codex — 본 = raw_shrine.png · 지시문 prompt_cellar.txt) → `build_lune_town2.mjs`가 방들의 반복문에 지하를 넣어 짓는다(문은 위의 방으로 · fight · story · 위의 방에는 `down_cellar` 포탈).
                도구를 고친 것: 그림의 바닥이 낮아 잘라 낼 네모가 그림 아래로 나가면 도트로 줄이다 죽었다 → 맨 아랫줄을 늘린다. 내보내기는 방들의 포탈도 한 번 더 따라가 지하를 찾는다 · `rest`는 fight면 false · `story`를 싣는다 · `FIELD.in_cellar` · 곡 = dark.
              닫힌 문: 장면의 portals에 `need = 퀘스트의 이름표` → 서버 `onTravel`이 `Quests.reached`(받았거나 끝냈다)가 아니면 돌려보내고, 화면 `SceneView:setPortals`가 그림 · 글을 숨기고 `portalNear`가 건너뛴다(`drawQuests`가 부른다). 승인받은 사당 안의 그림은 고치지 않았다.
              이야기의 방: `scene.story` → 졸개는 처음에 없다(`away`) · `Room:stepStory`가 그 졸개를 잡는 퀘스트를 하는 사람(`Quests.wantsKill`)이 방에 있으면 하나씩(0.5초 간격) 내보내고, 없으면 모두 치운다. 쓰러뜨리면 여느 졸개처럼 다시 나온다(밀려드는 병사) · 열둘을 채우면 사라진다.
              읽을거리: 방의 비석 = 말을 걸 수 있는 물건(stone — 명예의 전당의 비석 · 의뢰 게시판과 같은 방식). 글 「다섯은 검은 용과 함께 잠들었다 / 닮은 아이가 오는 날까지 이 자리를 지켜라」는 내가 채움. 설계의 traces · records(1지역 14개)는 아직 게임에 없다.
              검사: 13의 끝(닫힌 문 → 받은 뒤 내려감 → 하나씩 나타남 → **실제로 열둘을 잡음** → 사라짐 · 다시 안 나옴 → 퀘스트 없는 사람에게는 없음 → 촌장에게 돌려줌 → 끝낸 뒤의 조용한 방) · 10(실내의 문: 나가는 문 하나 + 퀘스트로 열리는 지하) · 30(need가 있는 문은 받기 전에 못 지나감). 전체 374,648개 0 실패. 그림 1장 올림(back_in_cellar.png = rbxassetid://128001628966145). Play로 보지 않았다.
              알릴 것: 마을의 그림은 불타지 않는다(말로만) · 수(열둘 · Lv.28 · 자리 넷)와 받을 때의 말은 내 제안 · 시험 탭에서는 포탈이 늘 보인다.
          ▶ 2026-10-13 사용자(게임에서 해 보고): "2차 전직 조건 너무 오래걸리고 어렵습니다. 허수아비 과해요 / 플레이어 체력표기 gui 체력 다는거나  회복되는게 잘 보이지않습니다. 효과가 좀 들어가야해요 / 그리고 초승달마을에서 망루까지 가는게 과하게 깁니다. 루즈하게 길어요 / 갈래길로 갈라버리는건 괜찮은데  망루까지 지금 10개넘게 포탈을 타야하는게 문제입니다. / 마을~ 망루 까지 사냥터 좀 줄이세요  월드맵도 맞춰서 업데이트 하시구요 / 사당지하도 월드맵에는 표시가 되어야합니다."
          ✔ S111 마을 → 망루의 길: 문 열 → 일곱(맵은 그대로 · 문만 다시 이음 — `maps.js`의 gates · LINKS). 줄기 town → r1a1 → r1af → r1b1 → r1bv → r1b3 → r1cc → r1c1.
              가지: r1af → hunt → r1a3 → r1a4 / r1bv → r1b2(→ r1bh · r1bl) / r1cc → r1b4. 새 문 둘(주막의 12.5칸 = 굽잇길 · 야영지의 9.2칸 = 망루 아래 — 울타리와 천막을 조금 옮김). 굽잇길 · 망루 아래의 왼쪽 문은 없앰(막다른 가지).
              `journey.js`: links · trunk · rhythm · 도표의 자리 · `WORLDART.r1.at`(r1a1 · r1a2 · r1a3 · r1b4를 옮김). 맵을 지우지 않은 것은 내 판단(사냥터마다 레벨 · 퀘스트 · 일일 의뢰가 걸려 있다) — 더 줄이려면 사용자가 뺄 맵을 정한다.
              곁들여: `Q.npcScene`의 같은 거리 가르기(마을 = homes가 먼저 — 샛별이 마을과 세 갈래 길에 선다) · 테스트 13의 잘못된 대입 한 줄(`sb.stale = true`)이 길이 바뀌며 드러나 고침.
          ✔ S112 사당 지하를 월드맵에 — `journey.js` r1의 마디 `r1cs`(kind dead · town의 가지) · `WORLDART.r1.at.r1cs = [34, 180]`. `worldmap.luau`: 실내의 마디 찾기가 퀘스트로 열리는 문(need)을 열린 문 다음에 따라간다(사당 안 = 마을의 마디) · 이야기의 방은 사냥터로 권하지 않는다.
          ✔ S113 2차 전직을 짧고 쉽게 — `JOBQUEST[0].map` r1c3 → **r1cs(사당 지하)** · 조각 10 → **5**(100%) · 수련 인형 dummy 체력 1.6 → 1.0 · 한 방 1.4 → 1.0 · 다시 치기 2.4 → 2.8.
              사당 지하: 수련 인형 셋을 더 놓음(`cellars.mobs`) · 포탈의 need = `['r1m9', 'job2']`(하나라도 받으면 열린다 — `Q.reached`가 표를 받는다) · 이야기의 방은 **종류마다 따로** 나온다(`Room:stepStory` — `Q.wantsMob`: 잡기 + 그 졸개에게서 모으기). 검사: 전직 퀘스트는 「열 개까지 · 100%」.
              테스트: 13(전직의 장면 · 다섯 개 · 사당 지하에서 **실제로 잡고 주워** 끝냄 · 병사와 인형이 따로 나옴) · 10 · 23 · 30(need가 표).
          ✔ S114 체력 바의 효과(시험 탭 + 게임) — 셈 `shared/lune/ui/hpFx.luau` = 공방 `js/lune/ui/hpfx.js`(수 `UILAYOUT.vitals.fx`: hold 0.35 · drain 0.9 · fill 0.9 · flash 0.22 · delta 0.9).
              닳을 때 = 띠는 바로 줄고 닳은 자리가 밝게 남았다 따라 줄어든다 + 흰 번쩍임 + 「-N」(잇달아 맞으면 더한다) / 찰 때 = 찬 자리가 풀빛으로 먼저 + 띠가 차오른다 + 풀빛 번쩍임 + 「+N」. 흔들림은 없다.
              게임: `hud.luau`의 Lag · Gain · Flash 층과 `Hud.step(dt)`(boot의 그리는 고리) · `Hud.resetHp()`(캐릭터를 바꿔 들어올 때). 시험 탭: `?lunedemo=hurt | heal`(효과가 한창인 모습으로 멈춤).
              검사: 새 37(효과의 셈 · 마을 → 망루 문 ≤ 7 · 줄기의 사냥터 ≤ 3 · 가지에 모두 닿는다 · 사당 지하의 마디). 전체 382,235개 0 실패. Play로 보지 않았다.
          ✔ S115 월드맵 = 실제 포탈(사용자 2026-10-13: "월드맵이랑 실제 포탈이랑 안맞잖아요 … 기본적인건 놓치지맙시다") — S112에서 굽잇길을 주막의 가지로 돌리고도 표시를 초입 – 주막의 길 위에 둔 것이 잘못.
              `WORLDART.r1.at`: r1b2 [364,128] · r1bh [318,138] · r1bl [356,156] · r1b4 [200,100]. 지도 창은 `region.links`(+ 다른 지역으로 나가는 줄)를 늘 흐린 점줄로 그린다(`WM.lines` · `WM.linkDots`).
              이름표: `WM.placeLabels(items, lines)` — 가린 점의 수 + 남의 표시에 더 가까우면 4(`WM.PLACE`)의 합이 가장 작은 짝을 찾는다(앞선 답에서 0 → 1 → 2번 벗어나 보기 · 늘 같은 답).
              **규칙: 포탈의 연결을 바꾸면 표시의 자리도 함께 본다** — 검사 38: 줄 ⇔ 실제 포탈 · 줄이 남의 표시에서 12점 안을 지나지 않는다 · 줄끼리 엇갈리지 않는다 / 검사 28: 줄의 점이 절반 넘게 보인다 · 이름표가 제 표시에 가장 가깝다.
              미리 보기: scratchpad `render_map.py`(테스트 28이 찍는 `[MAP]` · `[LINE]` 줄을 그림 위에 얹는다) → `assetpack/lune/dev/NAVI_1_worldmap.png`.
          ✔ S116 퀘스트 길찾기(게임에만 — 시험 탭에는 없다) — 셈 `shared/lune/ui/navi.luau`: `target`(받기 전 = 주는 주민 · 하는 중 = 그 사냥터의 몬스터 / 살펴볼 자리 · 다 했다 = 돌려줄 주민 · 일일 = 사냥터 → 게시판) · `path`(need 문은 받은 뒤에만) · `aim` · `dir` · `arrow`.
              알리미: 줄마다 `key`(`questPanel.luau` — 퀘스트 id · `daily:<지역>:<차례>`)와 단추(`questHud.luau`의 `naviButton` 16x13 · 누르는 자리 24x19 · `QuestHud.navi` / `onNavi`). 머리 위 화살표 `client/lune/naviArrow.luau`(Overlay 층 "Navi" · UP 44).
              boot: `state.navi`(하나만 · 다시 누르면 끔 · 안내할 것이 없어지면 저절로 끔 · 캐릭터를 바꾸면 끔). 월드맵의 「가는 길」도 켠 퀘스트를 따른다(`WM.naviGoal` · `WM.goalCard(…, navi, daily)`).
              층이 다른 곳은 가로를 먼저 맞추고 위 · 아래(발판 길찾기는 없다). 메이플의 길찾기는 웹에서 확인하지 못함(사용자에게 알림).
              검사: 새 38(할 수 있는 퀘스트 61개 · 일 54개의 진행마다 가리키는 곳 + 문을 따라 닿는가 · 「빈 갑옷」의 줍기 · 사당 지하의 문 · 일일 의뢰 · 방향 · 단추와 화살표를 화면 없이). 전체 442,949개 0 실패. Play로 보지 않음.
          ✔ S117 일일 의뢰 30 → **8마리**(사용자 2026-10-13: "더낮게 지금 이대로면 20분정도 걸립니다") — `DAILY.kills 8` · `DAILY.pace 3`(실제의 빠르기: 1분에 3마리쯤 — 걷기 · 다시 나오기까지) · `dailyMinutes()` = perDay x kills ÷ pace(검사: 5분쯤).
              **교훈: 설계의 빠르기 `rateAt`(1분에 12.5~20마리)는 실제의 네 배쯤이다** — 시간을 셀 때 쓰지 말 것. 레벨업 시간의 셈도 같은 빠르기라 실제는 더 느릴 수 있다(사용자에게 알림 · 손대지 않음). 보상은 그대로.
              게임: `Daily.sync`가 같은 날의 아직 내지 않은 의뢰를 새 마릿수로 맞춘다(옛 30마리짜리). 테스트 36.
          ✔ S118 길찾기 화살표 = Codex의 그림(사용자: "화살표 퀄리티 더 올리고") — `assetpack/lune/ui/prompt_navi_arrow.txt` → `raw_navi_arrow.png` → `tools/build_lune_navi.mjs`(흰 바탕을 가장자리에서 채워 지움 · 장마다 칸의 크기를 잼) → `navi_arrow.png/json` → 부품 naviUp · naviRight · naviDown · naviLeft(`build_lune_ui.mjs`).
              `client/lune/naviArrow.luau`: Kit.part를 Overlay 층에 2배(SCALE)로 · 한 점씩 오간다. 네 방향의 크기가 한두 점씩 다르다(다시 받은 `raw_navi_arrow2.png`도 같았다 — v1을 쓴다). ui_kit.png 새로 올림.
              길찾기 단추: 켜면 NaviGlow(둘레의 accentHot 빛 — `QuestHud.step(clock)`이 비침을 0.15~0.75로 오르내린다) + Shine, 끄면 원래 색.
          ✔ S119 알리미: 「−」 = 중요한 것만 · 「+」 = 모두 + 스크롤 — 처음 만든 것(「−」 = 머리줄만 접기 · 「+」 = 판을 메뉴 단추 위까지 늘림 · 한 줄 꼴 · 「외 N개」)은 같은 날 퇴짜:
              사용자 "퀘스트 가 - 누르면 중요한거 메인 , 일퀘 이런거만 뜨고  + 누르면 다보이는 식이여야죠 … 스크롤을 넣어야죠 무식하게 아래로 계속확장하면 어쩌라는거에요".
              `Panel.layout(…, fold)`: fold = 중요한 것만(`Panel.KEY_TAGS` main · job · daily + 부탁이 아닌 길잡이). 돌려주는 높이 = 적은 것 전체 · info { total, hidden, fold, view = 판의 높이, scroll, any }.
              `Panel.maxH` = min(공방의 칸 hud.quest.h **204**, 창에서 메뉴 단추 위까지) · 스마트폰 H_TOUCH 98. 넘치면 `Ui.scroll`(ScrollingFrame — 휠 · 끌기 · 민트 막대 3점) 안에서 스크롤. 머리줄과 단추는 판에(늘 보인다).
              `QuestHud.scrollY`(다시 그려도 그 자리) · 단추를 누르면 0. 처음 모습 = 모두(제 판단 — 물어 둠). 저장하지 않는다.
              테스트 38(5절): 열 개(메인 둘 + 부탁 여덟) + 일일 둘 — 모두 / 중요한 것만 / 스크롤 칸 · 판의 높이 · 스크롤한 자리 · 스마트폰. Play로 보지 않음(스크롤의 손맛은 사용자가 확인).
          ✔ S120 길찾기가 맵을 안다 — 사용자 2026-10-13(옛 망루의 화면): "맵 이해가 없는상태로 길찾기를 구현하니까 … 올라가는 발판은 왼쪽에있는데 위에 있는 포탈은 오른쪽에 있으니까 오른쪽으로 가라고 화살표가 방향을 안내하잖아요 이거 말이 안되는거에요".
              `shared/lune/ui/naviMesh.luau`: 발판(rows의 설 수 있는 칸의 가로 줄 — 가시 칸은 뺀다) → 자리마다(SPACING 8) `P.step`으로 뛰어 본 길(MOVES: 제자리 · 옆(HOLDS 다섯) · 2단 / 하단 점프 / 걸어 내려서기) → `Mesh.route`(다익스트라 — 걷기 + 뛰기 + COST의 덤) → `Mesh.dirOf`.
              뛸 자리는 구간이다(edge.lo · hi — 옆 자리에서도 되는 쪽은 TAKE 5, 안 되는 쪽은 0.75) · 한 자리에서만 되는 뜀(solo)은 값 +0.8. 한 맵 100~300ms라 `Mesh.work(key, budget)`로 나눠 잰다(`Navi.prepare` — 한 장에 6자리 · 다 잴 때까지는 예전의 셈).
              `Navi.arrow`: out.mapped · out.edge. boot: 땅에 있을 때만 다시 셈한다(공중에서는 `state.naviDir` 그대로).
              **교훈: 「이것까지는 셈하지 않습니다」라고 적고 넘어간 것이 바로 퇴짜의 까닭이었다 — 길을 가리키는 기능은 실제로 갈 수 있는 길이어야 한다.**
              검사 39: 1지역 25맵 · 길 569 · 발판을 건너는 398개를 화살표대로 `P.step`으로 따라가 닿는다 · 옛 망루의 자리(발판 쪽을 가리킨다). 다른 지역의 맵은 발판을 재는 것까지만. Play로 보지 않음.
          ✔ S121 알리미의 처음 모습 = 중요한 것만(사용자: "퀘스트는 중요한것만 보이는게 디폴트입니다") — `QuestHud.fold = true`.
          ✔ S122 아래를 가리킬 때 화살표가 흔들리던 것(사용자 2026-10-13: "하단을 가르킬때는 왜 고장나면서 지진난것처럼 동작하나요?") — 까닭: 아래층으로는 어디서 하단 점프를 해도 값이 같아(동점) 몬스터가 움직일 때마다 뛸 자리가 바뀌었다.
              `Mesh.NEAR_FIRST 0.05`(첫 걸음까지 걷는 시간에 덤 — 가까운 뜀을 고른다) · `Mesh.TAKE 8`(= SPACING: 되는 두 자리 사이는 어디서든 뛴다) · 구간의 끝은 NUDGE 2점 옆에서 다시 재고(`phase "refine"`) NARROW 3점보다 좁은 뜀은 버린다 · `Mesh.at(edge, x)`.
              `Navi.aim`: 겨누던 몬스터를 그대로(`Navi.KEEP 48`). 검사 39(4-2절): 가만히 서 있으면 0번 · 걸어가는 동안 ≤ 2번 · 구간의 폭.
              **교훈: 길을 고르는 셈에 동점이 있으면 답이 장마다 바뀐다 — 동점을 깨는 규칙을 넣고, 움직이는 표적 · 걸어가는 나로 「화살표가 바뀐 횟수」를 잰다.**
          ✔ S123 몬스터 · 보스 체력 띠의 효과(사용자: "몬스터 체력바도  유저 체력바처럼 고도화 되어야합니다.") — `client/lune/ui/hpBar.luau`(`HpBar.attach(bar, w, h)` — Lag · Gain · Flash 층 · 셈은 hpFx.luau 그대로).
              `mobsView.luau`: m.barFx · 없는 동안 / 나타나는 동안 reset + set(1) · 쓰러지는 동안 효과가 끝날 때까지 띠를 남긴다 · 처음 본 다친 몬스터는 효과 없이. `bossView.luau`: BossView.barFx · shownMob이 바뀌면 reset.
              시험 탭에는 없다(게임에만). 테스트 24(끝 절). Play로 보지 않음.
          ✔ S124 정찰대장의 패턴 이펙트 여섯 장을 다시(사용자 2026-10-13: "정찰대장 스킬이펙트 빨간+하양으로 나오는거 너무 이상하게 나옵니다. 망루의 부관은 훌륭합니다.") — `tools/build_lune_boss_fx_prompts.py`: WHO의 색 = 네 단계의 붉은 불 · EXTRA = 셋째 본(부관의 mk4_towerlieutenant_fx_slam.png) + 「굵게 · 가는 줄 금지」.
              `mk4_scoutcaptain_fx_*.png` 새로(옛 것 `monsters/fx_v1/`) → `build_lune_boss_fx.py` → `build_lune_boss_made.mjs` → `build_lune_bosses.mjs`. `BOSS_FXART.scoutcaptain`의 px를 새 그림에 맞춰 조정(크기는 옛 것과 비슷하게).
              Codex가 투명한 PNG의 숨은 색에 빛 번짐을 넣어 온다 — 알파를 반영해서 봐야 한다(옮기는 도구는 알파 128로 자른다).
          ✔ S125 단추의 글(사용자: "세상 어떤 RPG 에서도 버튼에 낸다라는 워딩쓰지않습니다") — `DAILY.words`: accept 수락 · turn 보상 받기 · done 완료 · all 모두 완료 시 · reset 매일 자정 초기화 · back 의뢰 게시판으로 간다. 말풍선의 끝 글 「수락 · 완료」(boot · 시험 탭). 검사: 일일 의뢰의 단추에 「~다」 금지.
          ✔ S126 알리미의 크기 세 단계 — `Panel.MIN / MID / MAX`(처음 MID) · `Panel.layout(…, size)` · `QuestHud.size` · `sizeButton(panel, plus)`(「−」 「+」 늘 둘 다 · 못 누르는 쪽은 BarOff). 테스트 38.
          ✔ S127 사당 지하: 나오는 수 = 잡으라는 수 — `questplay.js` 메인 9 = 정예 검병 4 · JOBPLAY[2] = 조각 4 · `town.js` cellar의 dummy 넷. 테스트 13(step.n == 방의 그 몬스터 수).
          ✔ S128 초승달 마을의 작은 나루 → 은달 항구의 부두 — `TOWNMAP.harbor { x 995, to ct5, done r1m9, prop pier, propX 995, tuck 9 }` · 대장간의 섬 62 → 60칸 · 대장간 x 952 → 928 · 모루 864. 나루의 문 = `town/prompt_pier3.txt`(틀 guide_pier.png — 돌문을 16배로 키운 것을 고쳐 그리게 해야 굵은 도트로 온다) → `raw_pier.png` → `node tools/build_lune_pier.mjs 19.6` → `pier.png` 57x55(build_lune_town2가 그림판에 붙인다).
              `maps.js`: r1cc → ct1 · ct1 → r1cc 임시 문을 뗌 · ct5에 [60.2, town, 배 — 초승달 마을로]. 게임: `Quests.finished` · `Quests.portalOpen(book, portal)`(need = 받은 뒤 · done = 끝낸 뒤) — world.onTravel · boot.setPortals · navi.path / aim · worldmap.nodeOf가 같이 쓴다. `WM.ROWS_MAX 4`.
              검사: 1지역의 맵에 ct*로 가는 문이 없다 · 나루의 done = r1m9 · 부두에 돌아오는 문. 테스트 38 · 30 · 28 · 13. 물 · 배는 그리지 않음(사용자에게 물어 둠). Play로 보지 않음.
          ✔ S129 최종 점검(시작 → Lv.30 · 2차 전직 · 1지역의 이야기 끝) — 사용자 2026-10-13: "어색한부분이나 구현되어야하는 기능이나  잘못된 버그라던가 있는지 최종 체크하고,  넘어가겠습니다."
              가상의 플레이 다섯 직업(LUNE_PLAY=axion,salamander,riven,mooni + reaper): 모두 2차까지(1:40 ~ 2:21 · 액시온만 쓰러짐 2 · 물약 186병). NODODGE(액시온)도 통과.
              고친 것: r1m9의 끝 말("야영지 너머 …" → 나루) · 나루가 열렸을 때의 큰 알림(`Quests.opens` · `Quests.OPENED` · boot의 Quests 받는 곳) · 큰 알림의 줄 세우기(`guide.luau` queue) · 샛별의 말 · 「옛 망루」의 설명 · startplan의 옛 글 셋.
              알린 것(정해 주실 것): Lv.22~25 퀘스트 없는 사냥 구간(부탁 둘을 제안) · 액시온의 망루 난이도 · 「불타는 마을」인데 마을의 모습이 그대로 · 야영지 → 사당 지하의 긴 길.
              확인 못 한 것: 오늘 넣은 화면의 실제 모습(Play 안 함) · 실제 스마트폰 · 두 사람 파티. 테스트 38(6절).
          ✔ S130 파티는 처음부터(사용자 2026-10-13: "게임시작부터 그냥 열리면되지 왜 10부터인가요?") — `basics.js` WINDOWS party from 10 → 1 · UNLOCK의 파티 줄을 Lv.1로. 서버 `PARTY_FROM`은 data/ui.generated의 windows에서 읽는다(따로 적은 10을 없앰). 검사: 파티 창 from = 1. 테스트 13(Lv.1 둘이 맺는다).
          ✔ S131 (시험 — 게임에 넣지 않음) 보스의 스켈레톤 방식을 공방에서 보여 줌 — 사용자 2026-10-13: "공방열고  보스만  스켈레톤 방식으로 한번 보여줄래요?"
              공방 탭 #rig(「스켈레톤」 — `js/lune/rigTab.js`): 정찰대장을 ① 지금의 장 그림 ② 조각을 화면에서 돌림(로블록스의 그림 틀을 돌린 꼴) ③ 도트 격자에서 돌림 — 나란히. 동작 넷(대기 · 걷기 · 공격 · 포효)은 CLIPS의 숫자.
              조각: `python tools/build_lune_boss_rig.py` → `assetpack/lune/rig/scoutcaptain/`(still을 다각형으로 여덟 조각 · 새로 그린 점 없음 · 떼어 낸 밑은 그늘색으로 메움 · 부스러기는 맞닿은 조각에). 화면 찍기: `?rigclip=attack&rigt=0.55#rig`.
              본 것: 흔들림(깃발 · 꼬리 · 천 · 숨쉬기)은 쓸 만하다 · 공격 / 걷기 / 포효는 조각이 딱딱해 종이 인형처럼 보이고, 자세를 새로 그려야 하는 동작(뿔나팔을 부는 팔 · 낮게 내딛는 다리)은 못 한다. 판정은 사용자가 보고 정함.
          ✔ S132 (시험 — 게임에 넣지 않음) 스켈레톤의 조각 · 관절을 사용자가 직접 찍는 편집기 — 사용자 2026-10-13: "2. 방식이 좋은거같은데 아예  조각내서 조각끼리 움직이는 방식 / 근데이걸 점을 내가 찍어줄까?  너가 인식해서 하니까 이상하게나오는거같은데"
              정해진 것: ② 화면에서 돌리는 방식(로블록스에서 되는 방식) · 조각의 경계와 관절은 사용자가 찍는다(제가 자동으로 가른 것은 처음에 놓아 두는 것일 뿐).
              공방 탭 #rig의 「조각 · 관절 찍기」: 고르기 · 둘러서 넣기(점을 찍어 둘러싼다 — 첫 점 / 두 번 누르기 / Enter로 닫는다) · 칠해서 넣기(붓 1 · 3 · 5점) · 관절 찍기 · 돌려 보기(큰 그림에서 바로 돈다 · 돌린 채 관절을 끌 수 있다)
                · 목록(이름 · 붙는 곳 · 가려진 자리 메움 · 앞뒤 · 삭제 · 조각 추가) · 되돌리기(Ctrl+Z) · 저장(Ctrl+S). 규칙: 그림의 점은 모두 꼭 한 조각의 것(「넣기」 = 고른 조각에 준다).
              저장: 공방 서버의 `POST /save-rig?boss=<보스>` → `assetpack/lune/rig/<보스>/rig_user.json`(그 파일 하나에만 쓴다 · 앞의 것은 `rig_user.prev.json`) — **서버를 다시 켜야 이 길이 있다**. 못 쓰면 파일로 내려 준다.
              셈은 `js/lune/rigCore.js`(화면 없이 돈다) · 검사 / 사용자가 저장한 것 읽기 = `node tools/check_lune_rig.mjs`(조각마다 점 수 · 관절 · 붙는 곳, 포개면 원래 그림과 같은가). 화면에서 눌러 보기: `?rigplay=sel:head;tool:lasso;c:44,8;…;key:Enter#rig`.
              **다음**: 사용자가 찍어 저장하면 → `check_lune_rig.mjs`로 읽고 → `rigTab.js`의 CLIPS(지금은 제가 가른 조각의 이름표 sword · head …에 맞춘 숫자)를 그 조각에 맞춰 다시 적는다. 게임에 넣을지는 그 뒤에 사용자가 정한다.
          ✔ S133 폰의 단추 · 폰 메뉴의 스크롤 · 스킬 창의 % 피해 — 사용자 2026-10-13(폰에서 해 보고): "모바일에서 상호작용 버튼 아래에 있는 버튼 없애고 메뉴탭 열었을때 스크롤이 되어야해 모든메뉴를 접근할수가 없다 / 그리고 스킬 퍼뎀같은거 스킬 창에 설명에 나와있어야해  메이플처럼 / 스킬레벨 추가로 찍으면 퍼뎀올라가는것도 보여야하고"
              ① `basics.js` TOUCH에서 칸 1의 단추(상호작용 아래 — 물약)를 뺌 → 칸 단추 열하나(칸 2 ~ 12 · `ui.generated`의 quick.touch). 폰 배치의 셈 `quickTouchFix`(공방 ui.js) = `Quick.touchFix / touchStart`(게임): 단추가 없는 칸의 것은 단추가 있는 첫 빈 칸으로 — 새 캐릭터의 물약은 칸 5, 전에 칸 1에 놓아 둔 것은 들어올 때(`Hero.setSlots(…, true)`) 옮겨진다. 물약의 새 자리는 제 제안.
              ② 폰 메뉴: `UILAYOUT.touchMenu` · `Layout.touchMenu(n, uiH)` — 판은 화면에 들어가는 높이까지만, 그 안에서 `Ui.scroll`로 민다(boot의 Touch.init onMenu).
              ③ % 피해: 1차의 사냥기 · 보스기는 공방이 글을 만들어 `kitEffects`에 실어 보냄(`combat.js`의 DMGWORDS · damageParts · damageText — effectText / hasEffect에 넣어 시험 탭의 스킬 창에도 뜬다). 2~4차의 쓰는 스킬은 게임이 `Caster.profile`로 잰 값으로 적음(`shared/lune/ui/skillDamage.luau` — 화면에서 sim/room을 처음 불러온다). 스킬 창은 `SkillDamage.text(id, lv)`를 「지금 · 다음」에 적는다.
                 % = 전투력에 곱하는 값 x 100. 화면의 피해 숫자 = 전투력 x % x dmgScale(10) x (맞는 상대면 1.5). **% 뒤의 「쓰는 시간」은 제가 붙임** — 2차의 빠른 스킬이 한 번의 %로는 1차보다 작게 보이는 곳이 셋(액시온 사냥기 · 보스기, 살라맨더 보스기): 사용자에게 알리고 물음.
              테스트 40(`40_lune_skill_touch.luau`): 적힌 % = 서버의 피해(1차 열 개 x 네 레벨 · 2~4차 x 레벨 1과 마스터) · 레벨마다 글이 달라짐 · 공방의 글 = 게임의 셈 · 폰의 단추와 배치 · 메뉴의 치수. 18 · 34의 폰 배치 기대값을 고침. 설계 검사에 규칙 셋(칸 1의 단추 없음 · 상호작용 아래 빔 · 레벨마다 % 가 달라짐).
              못 본 것: 실제 화면(Play 안 함) — 폰에서 메뉴가 밀리는지 · 스킬 창의 모습. 스킬 창을 화면 없이 짓는 테스트는 없다(Instance.new를 직접 쓴다).
          ✔ S134 채팅 = Roblox의 기본 채팅 — 사용자 2026-10-13: "우리가 자체 채팅을 구현하는게 아니라 로블록스 채팅이 있어요 로블록스 공식문서좀 확인해보고 ,  그걸 어떻게 로블록스 채팅을 우리게임에 자연스럽게 사용하게 연결할수있는지 / 불가능하다면 그냥 채팅 없어도됩니다."
              전: 글은 TextChannel:SendAsync로 보내되 창 · 쓰는 칸은 우리 것(Roblox의 창 · 입력줄을 끔). 지금: Roblox의 창 · 입력줄 · 채널 탭을 켜고 그대로 쓴다 — `client/lune/chat.luau`를 새로 씀(색 · 이름의 앞머리 `Chat.prefix` · `Chat.focused` · `Chat.bottom`).
              공식 문서에서 확인: 기본 화면 셋(ChatWindowConfiguration · ChatInputBarConfiguration · ChannelTabsConfiguration — 탭은 기본이 꺼짐) · 자리는 Horizontal/VerticalAlignment · 크기는 Width/HeightScale · 입력줄의 키 KeyboardKeyCode(기본 Slash) · 이름은 OnIncomingMessage의 PrefixText · 알림은 DisplaySystemMessage · 창의 자리는 AbsolutePosition/AbsoluteSize(본보기 「Get Total Chat UI Bounds」 — 보통의 ScreenGui 좌표) · 글 치는 중 = IsFocused.
              뺀 것: HUD의 「채팅」 칸 · HUDTOUCH의 채팅 · TOUCH의 「채팅」 단추 · UILAYOUT.chat · `Layout.CHAT / chatOpen` · `Tags.chatLine / chatClean` · `Input.onEnter` · `Chat.open / close / setTouch` · 시험 탭의 채팅 줄 그리기. 더한 것: `ui.js`의 CHATUI(→ `ui.generated`의 chatUi) · `Input.typing` · `PartyHud.setTop`(PC에서 채팅 창 아래로 — 폰은 제자리).
              서버(`server/lune/modules/chat.luau`)는 그대로: RBXGeneral = 같은 맵 · 「파티」 채널 = 같은 파티(이름만 chatUi에서 읽음). Studio 편집 상태에서 속성 이름을 읽어 확인(ChatVersion = TextChatService · 설정 넷이 TextChatService 바로 아래).
              못 본 것: 실제로 뜬 모습 전부(Play 안 함) — 창의 크기 · 파티원 칸이 놓이는 자리 · 폰에서의 여닫기 · 「/」를 누른 순간의 키. SetCore("ChatActive")는 문서에 없어 쓰지 않았다. Enter로 여는 것은 넣지 않음(물음). 테스트 14 · 40(5절).
              고침(사용자가 Studio의 Output을 보여 줌 — "value of type nil cannot be converted to a number · chat:56"): 자료(CHATUI.window)에서 뺀 stroke를 TextStrokeTransparency에 걸려던 줄이 chat.luau에 남아 있었다(pcall 안이라 게임은 그대로 돌았다 — 같은 start의 마지막 줄 「[lune] 시작」이 뒤에 찍혔다). 그 줄을 빼고, 값이 없으면 걸지 않고 알림(warn)을 남기게 함.
                테스트 40의 5절이 가짜 TextChatService에 `Chat.init`을 실제로 돌린다(nil을 넣으면 진짜처럼 오류 · 걸어야 하는 속성 열여섯이 다 걸리는지 · 받은 글의 앞머리). 같은 잘못을 일부러 다시 넣어 테스트가 잡는 것을 확인. 가짜 Color3에 fromHex를 더함(mock.luau).
          ✔ S135 (시험 — 게임에 넣지 않음) 스켈레톤용 보스를 부위별 조각으로 받아 공방에서 움직여 봄 — 사용자 2026-10-13: "이제  디자인은 늑대 굳이 아니여도 됩니다.  코덱스에게  스켈레톤에 적합한 형식으로 만들어달라고 요청하고  애초에  각각 부위별로 받은뒤에 조합했을때 벌어지는 부분이 없게 여유분 있게 파츠들을 제작하고  스켈로톤용  보스를 받아보고  공방에서  실험해봅시다."
              받은 것(`assetpack/lune/rigdesign/` — Codex 두 번): ① 디자인 `raw_rk_design.png`(「철갑 선봉장」: 검은 철갑의 기사 — 부위가 뚜렷이 나뉘게 청함. 8화소 격자 → 161x122점 `design_dots_span1.png`) ② 조각 시트 `raw_rk_parts.png`(①을 6화소 격자로 다시 그린 `ref_rk_k6.png`를 붙여 청함: 부위 열넷 · 가려진 자리까지 그림 · 관절마다 여유분 · 같은 방향 · 정해 준 배치). 청한 글 `prompt_rk_design.txt` · `prompt_rk_parts.txt`.
              옮기기 `python tools/build_lune_rig_boss.py`(셈 `tools/lune_rig_dots.py`) → `assetpack/lune/rig/ironvanguard/`(parts.png · design.png · rig.json kind 'layers' · check.png). 조각 시트에는 고른 격자가 없다(조각마다 5.0~7.4화소 · 칼은 더 크게 옴) → 디자인에 대 보고 크기를 잼(몸 6.85화소/점 · 칼 7.20).
                자리: 무늬가 뚜렷한 일곱(투구 · 흉갑 · 허리 · 앞천 · 망토 · 앞 윗팔 · 칼)은 디자인에 대 봄 · 어두운 팔다리 일곱은 관절끼리 맞물림(발 = 바닥 · 정강이 위 끝 = 무릎 갑옷 · 아랫팔 위 끝 = 팔꿈치 갑옷 · 칼 자루 = 주먹) — 색만 대 보면 엉뚱한 어두운 자리에 붙었다(두 번 실패). 앞천의 십자 무늬는 마름모로 바꿔 찍음.
              탭 #rig: 보스를 고름(철갑 선봉장 / 정찰대장). 조각 보스의 도구 = 고르기 · 조각 옮기기(끌기 · 화살표 · 붙은 조각도 같이 · 받은 디자인 비쳐 보기) · 관절 찍기 · 돌려 보기. `rigCore.js`에 kind 'layers'(fromLayers · layerAt · moveLayer) · 서버의 저장 길이 layers를 받음 · `check_lune_rig.mjs`가 layers를 검사.
                동작 넷(대기 · 걷기 · 내리베기 · 기합)은 `CLIPS_BY.ironvanguard`의 숫자. **발 고정**(동작의 `ground` — 발 조각의 가장 낮은 곳이 바닥에 닿게 온몸을 올리고 내린다): 없으면 발끝이 바닥을 파고든다.
              본 것(화면을 찍어): 조립된 모습이 선다 · 걷기 · 공격 · 기합에서 관절이 벌어지지 않는다 · 발이 바닥에 붙는다. 조립된 모습은 디자인과 똑같지는 않다(조각의 비율이 조금 다르다 — 사용자가 탭에서 맞춘다). 움직이는 모습 자체는 멈춘 장면으로만 봤다.
              참고: 사용자가 정찰대장의 관절을 탭에서 고쳐 저장해 두었다(`rig/scoutcaptain/rig_user.json` 2026-10-13 — 손대지 않는다).
          ✔ S136 (시험) 철갑 선봉장 — 사용자가 찍어 저장한 점으로 동작을 다시 적음 — 사용자 2026-10-13: "자 이제 내가 점찍은대로 다시해볼래요?"
              저장된 것(`rig/ironvanguard/rig_user.json` 20:32): 자리 · 앞뒤 · 붙는 곳은 그대로, 관절 열넷 가운데 열을 옮김 — 투구 (55.5, 17.5) · 흉갑 (59.5, 39.5) · 허리 (54.5, 59.5) · 앞천 (55, 84.5) · 망토 (47, 52) · 앞 허벅지 (37.5, 88.5) · 앞 정강이 (35, 114) · 뒤 허벅지 (74.5, 89.5) · 뒤 정강이 (75.5, 114) · 뒤 윗팔 (70, 29.5) · 뒤 아랫팔 (71, 58.5). 앞 팔 둘과 칼은 그대로.
              읽은 것(제 풀이): 옮긴 점들은 **보이는 조각의 가운데**다(정강이는 발목 쪽 · 망토는 등에 닿는 곳). 그 점을 조각이 도는 중심으로 그대로 썼다.
              동작: `CLIPS_BY.ironvanguard` = 찍은 점에 맞춘 것(허벅지 ±16° + 옆으로 4점 · 넘기는 다리는 4점 든다 · 정강이는 발목에서 반대로 돌려 장화를 바닥과 나란히 ≤ 14° · 뒤 아랫팔 ≤ 14° · 앞천 ≤ 8°) — 가운데에서 도는 조각은 양 끝이 반대로 움직이므로 관절의 여유분 안에서만 돌린다.
                `CLIPS_BY['ironvanguard@auto']` = 제가 처음 잡은 관절의 동작(남겨 둠). 탭이 지금 화면의 관절이 어느 쪽에서 왔는가(basis)로 고른다 — 「처음 받은 배치로 다시 시작」 = 제 관절 + 제 동작(견주기) · 「되돌리기」 = 찍은 점으로.
              본 것: 멈춘 장면 여덟(걷기 넷 · 공격 둘 · 기합 · 대기)에서 이음매가 벌어지지 않고 발이 바닥에 붙는다. 서 있는 자세가 다리를 벌린 자세라 걷기는 다리가 엇갈리지 않는 「쿵쿵 걷기」다(제 관절의 것도 같다).
          ✗ S137 **스켈레톤 방식 폐기** — 사용자 2026-10-13: "그냥 스켈레톤 방식은 폐기합시다. 폐기하고  이후 개발로 돌아옵시다". S131 · S132 · S135 · S136의 시험은 여기서 끝. 보스의 동작은 지금 방식(장 그림 — Codex로 자세를 받아 도트로 옮긴다) 그대로다.
              공방에서 뺀 것: 「스켈레톤」 탭(index.html · app.js) · 저장 길(tools/server.mjs의 POST /save-rig — 서버는 다시 화면만 내준다) · 목록의 모양(style.css).
              남겨 둔 것(지우지 않았다 — 지울지는 사용자에게 물음): `js/lune/rigTab.js` · `rigCore.js` · `tools/build_lune_boss_rig.py` · `build_lune_rig_boss.py` · `lune_rig_dots.py` · `check_lune_rig.mjs` · `assetpack/lune/rig/`(사용자가 저장한 rig_user.json 둘 포함) · `assetpack/lune/rigdesign/`(Codex의 그림 둘).
          ✔ S138 **경매장 = 메이플 옥션 방식** — 사용자 2026-10-13: "경매장 부터 진행합시다.  알아서 조사하고 판단하고 해서  경매장 구현 해보세요" → (내 나름의 방식으로 만든 것을 보고) **"메이플 식 경매장을 말하는거긴합니다."** → 같은 날 메이플 옥션의 짜임으로 다시 만들었다.
              처음 만든 것(버림): 은달 항구의 경매사 앞에서만 · 산 것은 바로 가방 · 묶음은 통째로 · 탭 「구매 · 판매 · 내 물건」 · 60일 · 저장소 `LuneMarket_v1`.
              지금(메이플 옥션 — 공식 가이드 · maplestorywiki · 나무위키에서 확인): 메뉴의 「경매장」(창 "auction", 키 Y — 어디서나) · 경매사 「금송」(ct2)에게 말을 걸어도 같은 창 · 탭 「구매 · 판매 · 완료 · 시세」 ·
               소비/기타는 개당 가격 + 낱개 구매 · 24/48시간 · 보증금(올릴 때 — 다 팔리면 돌려받는다) · 수수료 5%(대금을 받을 때) · 「완료」에서 수령 / 대금 수령 / 반환 / 재등록 / 모두 받기 · 365일 보관 · 판매 10건 · 받지 않은 구매품 100건.
               메이플과 다르게 둔 것: Lv.61 · 3일 조건 없음(레벨의 문턱은 사용자의 까닭이 있어야) · 보증금 100달돈(내 판단) · 찜 / 미리보기 / 일괄 구매 / 옵션 필터 / 가격 수정 없음 · 시세 = 분류의 최근 거래 목록(90일 · 200건).
              규칙 · 낱말: 공방 `js/lune/design/economy.js`의 AUCTION → `items.generated`의 MARKET. 치수 `UILAYOUT.auction`. 검사 규칙 `check_lune_design.mjs`(탭 넷 · 24/48 · 5% · 365일 · 여는 키).
              저장: DataStore `LuneMarket_v2`에 분류마다 문서 하나(`b_w_<직업>` · `b_a_<부위>` · `b_u` · `b_e`) = { v = 2, list = 줄들, log = 최근 거래 }. 줄 = { id, u, sn, it(올린 것), p(개당), t, e, l(남은 수), c(닫힘), b(최근 구매 몇 건 — 같은 구매를 두 번 치지 않게) }.
               문서를 바꾸는 것은 `Store.marketUpdate`(UpdateAsync) 하나뿐 — 셈은 `shared/lune/sim/market.luau`의 txList · txBuy(남은 수를 줄이고 시세에 적는다 · 구매의 표 token으로 한 번만) · txClose(닫는다 — 남은 수가 굳는다) · txSettle(지운다) · txPurge.
              계정의 「맡긴 것」(`acct.market.list`): 판 것 = { b, it, p, t, e, got(대금을 받은 수), d(낸 보증금) } · 산 것 = { hold, it, p(치른 값), t }(「완료」의 「낙찰」). `Market.resolve` → { state(selling · ended · soldout · back · void · hold), left, sold, due } · `Market.amount` → 대금 · 수수료 · 돌아오는 보증금.
              **차례가 곧 안전장치다(바꾸지 말 것 — 41번 검사가 일부러 고장을 내서 본다)**: 올리기 = 가방에서 뺌 · 보증금 → 맡긴 것에 적음 → 계정 저장(`saveNow`) → 장부에 줄. 사기 = 달돈 먼저 뺌 → txBuy → 「낙찰」로 적음 → 바로 저장.
               대금 수령(판매 중) = 받고 got만 늘린다(장부는 안 고친다). 끝내기(취소 · 반환 · 재등록 · 다 팔린 것 — `marketFinish`) = txClose → 남은 것 · 대금 → 맡긴 것에서 지움 → 계정 저장 → 저장됐을 때에만 txSettle.
               저장소가 답하지 않으면(적혔는지 모름) 되돌리지 않고 맡긴 채로 둔다 · 살 때는 다시 읽어 그 표가 적혀 있으면 산 것(`Market.boughtBy`). 사람마다 한 번에 하나(`s.marketBusy`) · 처리 중에는 나가는 저장과 「캐릭터 선택」이 기다린다(`marketIdle`) · 서버가 닫힐 때도 기다린다(`saving`).
              서버: `world.luau`의 onMarket(패킷 `Market` — mine · browse(목록 + 시세) · list · buy(수) · settle(take · collect · back · relist) · all). 임시 캐릭터(guest) 불가 · 쓰러져 있으면 불가 · 주민 앞이 아니어도 된다. 장부는 `MARKET.cache`(8초) 동안 같이 본다(새로 고침도 2초 안에는 다시 읽지 않는다).
              화면: `client/lune/ui/auctionWindow.luau` · 적는 글과 셈은 `shared/lune/ui/auctionView.luau`(doneRows · sellingRows · ask · form …) · 값은 줄이지 않고 쉼표로(`Format.comma`) · 적는 칸 = `Ui.field`(Roblox의 TextBox). boot: 창에 키가 있어 메뉴 · 키 설정에 저절로 들어간다.
              공방: 시험 탭에 창의 모습(`js/lune/ui/paint.js`의 paintAuction — `?lunedemo=auction · auctionhat · auctionuse · auctionask · auctionaskn · auction2 · auction2f · auction3 · auction4`. 모양만).
              관리 탭(관리자만): 「아이템」 → 「경매장 시험」 → 「시험 물건 올리기 · 치우기」(`Admin` 패킷의 market fill / clear — 판 사람의 번호 0, 「시험 판매자」).
              검사: `41_lune_market.luau`(618개) — ① 셈 ② 진짜 store.luau + 가짜 DataStore ③ 서버의 흐름(낱개 구매 · 여럿이 같이 삼 · 느린 저장소 · 저장 실패 · 답 없는 저장소 · 도중에 나감 · 서버를 일곱 번 새로 띄워 이어 감 — `server()`가 RESET으로 서버를 새로 띄운다) ④ 글의 폭 ⑤ 가짜 Ui 부품 위에서 진짜 창을 눌러 봄(진짜 서버 코드에 물림) ⑥ 관리자의 시험 물건.
              알려진 한계: 값을 치른 직후 저장하기 전에 서버가 죽으면 산 것이 사라질 수 있다(바로 저장해 틈만 줄였다) · 분류 하나가 문서 하나라 사람이 많아지면 레벨대로 더 나눠야 한다 · 장신구는 분류가 없어 못 올린다 · 쪽 넘기기 없음.
              보지 못한 것: 게임 화면(Play 안 함) · 스마트폰. (자동 검사의 전체 수는 돌릴 때마다 조금 다르다 — 13_lune_world의 검사 수가 표를 도는 차례에 따라 달라진다. 실패는 없다.)
          ✔ S139 **플레이 뒤의 말씀(2026-10-13) — 경매장 넷 · 퀘스트 일곱** — 말씀 그대로는 공방 「개발 진행」 맨 위 확인 요청에 옮겨 두었다.
               **퀘스트의 줄**(사용자: "라인이 이어지듯이" · "한npc 에 같은시점에 몇개를 겹쳐서" 안 된다): 공방 `design/questplay.js`의 `LINE.r1` = 1지역 19개의 차례(메인 9 + 사이드였던 10). `regionQuests`가 `after` = 줄의 바로 앞 것으로 잇고, 줄에 든 것은 게임에 `kind = "main"` · `line = true`로 나간다. 어느 때든 받을 수 있는 것은 하나. LINE이 없는 지역(2~4)은 메인끼리 · 사이드끼리 차례로.
                `LINE_FIT = 10`: 그 레벨까지는 줄의 퀘스트마다 경험치를 「다음 퀘스트의 레벨에 닿게」 자동으로 맞춘다(퀘스트가 시키는 사냥의 경험치는 가장 낮게 쳐서) — 수를 손으로 고치지 말 것. Lv.10 뒤의 빈 곳(9→12 · 14→18 · 22→25 · 26→28)은 그대로 사냥(사용자의 말씀은 "10 까지는").
                Lv.10 전에는 「주는 주민 = 앞의 것을 돌려받는 주민」(첫 기술만 예외 — 사당 안의 사제 → 문 밖의 샛별). 검사 규칙 `check_lune_design.mjs`(줄의 차례 · 레벨 · 사냥 없이 Lv.10 · 주민 · 첫 퀘스트의 주문서) + `17_lune_quests.luau`.
               **드랍 · 세기 = 몬스터 기준**(사용자: "하드코딩 박는식으로 개발을하면안되요"): `sim/quests.luau`의 `counts(def, step, scene)` — `step.only`가 아니면 어느 맵이든 센다 · 떨어뜨린다. `only`는 이야기의 자리에서만 세는 걸음(지금은 「불타는 마을」의 사당 지하 하나 — 퀘스트 자료에 적는다). 길찾기도 같다: 지금 맵에 그 몬스터가 있으면 「여기」(`Navi.aim`).
               **귀환 주문서**: 「첫 기술」의 보상 `scrolls: 5`(5는 내 판단) → `Hero.questDone`이 가방 자리를 보고 준다 · 퀘스트 창의 보상 칸에 그림과 수.
               **대화**: 스페이스 = 다음 줄, 누르고 있으면 쭉(`TALK_HOLD` 0.35 / 0.16초). 돌려주면 `state.chain`으로 그 주민의 다음 퀘스트 대화가 바로 이어진다(`state.questTalk` — 돌려줄 것 먼저, 그다음 줄 것 하나). 메인 · 전직 퀘스트를 받으면 `state.navi = id`(길찾기 켜짐).
               **알리미**: 받을 수 있는 퀘스트를 띄우지 않는다(`questPanel.luau`의 guides = {}) — 사용자: "퀘스트 ui에 받을수있는 퀘스트 띄우지마세요".
               **화살표가 반대쪽을 가리키던 것**: 길(포탈의 차례)은 맞았고 화살표가 「다음에 뛸 자리」를 가리켜서였다(그 자리가 캐릭터의 몇 점 오른쪽). `Navi.TAKE_NEAR = 40` — 뛸 자리가 그 안이면 `Mesh.actDir`(뛰어서 갈 쪽)을 가리킨다. 사용자의 화면(달그림자 사냥터 → 보름 영감)을 검사로 재현했다.
               **경매장**: 수량 = 적는 칸(`Ui.field` — 판매 양식의 `countBox` · 살 때의 `askBoxQty`, 셈은 `auctionView.count(text, max)`: 숫자만 · 넘으면 그 수) · 구매 줄을 누르면 상세(`ItemDetail.show("auction", …)` — `auctionView.info`, 같은 줄을 다시 누르면 닫힘) · 묶음의 줄은 이름 + 「남은 수량 n개」(`rowText` · `stock`) · 수량 칸 옆 「/ n개」(`of`).
               **메뉴 단추 여덟**(경매): 무엇을 어느 차례로 놓는가는 공방 `design/ui.js`의 `menu.row`(boot.luau가 읽는다 — 코드에 적지 않는다). 이름표 `labels.auction = '경매'`(내 판단).
                가장 작은 격자(768 — **1080p 창 모드 · 125% 노트북이 이 격자다. 드문 경우가 아니다**: 게임 배율 4 → 화면 틀 배율 2)에서는 여덟이 넓은 간격(38)으로 스킬 칸에 닿는다 → 화면 칸 「메뉴 단추」의 `tight { w = 254, gap, beside = 스킬 칸 }`: `hudRect` / `Layout.rect`가 이웃에 닿으면 줄어든 폭을 돌려주고, 간격은 그 폭에서 나온다(`menuPitch` — 296 → 38, 254 → 32). 격자가 바뀌면 `Hud.placeMenu`(Stage.onResize).
                촘촘할 때 세 글자 이름표 둘이 이웃하면 붙는다(틈 2점) → 차례를 세 글자 · 두 글자가 번갈아 오게(…퀘스트 · 경매 · 월드맵 · 메뉴). 검사가 이웃한 이름표의 틈(`labelGap` 4)을 본다 — 단추를 더 넣거나 이름을 바꾸면 여기서 걸린다.
                그 격자에서는 경매장 창(636) 옆에 상세 판(232)이 들어갈 자리가 없어 상세가 창의 왼쪽 위를 덮는다(`Windows.beside`가 화면 안으로 민다 — 값과 「구매」는 안 가린다). 사용자에게 알렸다.
               공방: 시험 탭의 단추 줄도 여덟 · 경매장 시연에 수량 칸 / 남은 수량 / 상세(`?lunedemo=auctiondetail`) · `?lunezoom=4`(화면 틀의 가장 작은 격자로 본다 — 확인용). 그림 `assetpack/lune/dev/AUCTION_2 · 5 · 7*.png` · `MENU_8_*.png`.
               검사: 전체 483,594개 통과 · 가상 플레이(29번, `LUNE_PLAY=`) 다섯 직업 모두 Lv.30 · 2차 전직(Lv.10은 「이름 없는 비석」을 끝낼 때 — 7~8분). 줄의 대사 19개를 다시 읽었다(「망루 앞의 차돌」 → 「수비대 야영지의 차돌」).
               보지 못한 것: 게임 화면(Play 안 함) — 수량 칸의 타자 · 스페이스를 누르고 있을 때의 빠르기 · 실제 화면의 화살표 · 스마트폰. 물은 것: Lv.10 뒤의 빈 곳을 채울지 · 사이드 10개를 메인 줄에 넣은 것 · 주문서 5장 · 단추의 이름 「경매」와 자리.
          ✔ S173 **펫 = 서기 그림 하나 · 탈것 셋의 달리기 = 질주 여섯 장(sprite-gen) — 2026-10-21 (사용자: "펫은 idle 제외하고 그냥 움직이기만하면되지 스프라이트 시트 자체가 안필요합니다. 그리고 탈것들 달리기 모션 똑바로 만들어야합니다. splite-gen 활용해서")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 펫: lune_ride_hand.mjs의 펫 run · jump 없앰 · rideView는 늘 idle(pmoveT 없앰) · 시험 63. ride.js의 petSize 0.6이 10-20 제 블록 교체로 지워져 있던 것 되살림(시험 64가 잡음). 탈것: dino-workshop/assetpack/lune/ride/gallop/gallop.py(parts · guides · prompts · take · prev · report · check · raw — 몸 = 서기 첫 장의 점 · 다리 넷만 Codex(sprite-gen generate_sprite_image.py, 앞 장 붙임) · 격자는 알고 있는 몸에 맞춰 잰다(칸마다 아홉 곳) · Codex가 그린 몸 높이 = actual.json · 네 발이 뜬 장 rise 1) · chain.sh · board.py · ridecheck.py · align_body.py(WSL — curation dx · dy). sprite-gen 실행 폴더 gallop/<wolf|deer|boar>/run(raw = 한 점 16화소 · palette.lock = 서기 그림의 색 · 사슴 = 마젠타 바탕 · --min-used-pixels 200 — 기본 400은 작은 탈것을 「빈 장」으로 본다) → 시트가 제 장과 점 하나 틀림없이 같음(대조). build_lune_ride_made.mjs sheetFrames(clip.sheet · pick · plan.json의 bob = seat) · 점프 = 질주 첫 장 · pad 늑대 [3,6,3,1] · 사슴 [8,5,2,1]. 전체 498,551개 통과 · chars_2 · chars_3(+ mask) 올림 · Rojo 확인 · #dev 맨 위 확인 요청(RIDE_1021_*). **같은 날 고침**(사용자: "왜 탈것을 종아리를 잘라서 움직이게 하는거에요? 스프라이트 시트 재생이아니라?" — 몸을 고정하고 다리만 갈아 끼운 것이 잘못): ride/gallop/full.py — 여섯 장을 한 그림(3 x 2칸 · 한 점 10화소)에 몸 전체로 Codex가 그림(자세 안내 = 처음 판 · 생김새 = 서 있는 그림) → cut(간격 10 고정 · 칸마다 위상 · 칸보다 넓게 읽고 몸 덩어리만 · 외톨이 · 모서리 점 지움 · 땅/공중 2점으로 세로 · 몸통(gallop.py torso)으로 가로 · 몸통의 오르내림 = seat) → raw full_g → sprite-gen. 빌더 sheetFrames = 원본 장과 점 하나 틀림없이 맞춰 자리 · plan.seat. gallop.py still()은 chars.json 기준점으로 자르게(사슴 pad를 넓힌 뒤 낡은 pad로 잘라 오른쪽 5열이 잘렸던 것). pad 늑대 [14,4,3,1] · 사슴 [14,8,2,1] · 멧돼지 [11,4,2,1]. 전체 498,551개 통과 · 다시 올림 · Rojo 확인. **탄 모습**(사용자: "캐릭터가 탑승한모습이 자연스럽지않아요" — 앉은 자리 · 너무 큼 · 상반신만 · 굳어 있음 · "idle 재생하면될듯 그 위치에서"): ride.js rider { size 0.8 · sink 2 · gap 1 · dip.run [0,1,0,0,1,0] } · seat는 x · x0 · x1만(y · front 없앰 — 빌더가 장마다 안장 다섯 열의 등 높이를 재서 발 · _front를 정한다) · 내보내기 riderSize · rideView:update가 셋째 값(크기) · Sprite:set 소수 배율이면 exact · Cast:look ×a.rideSize · boot state.actor.rideSize · othersView o.rideSize · o.hx/o.hy(boot의 look이 다른 사람의 몸을 땅 자리로 다시 그리던 것 고침) · cashShop 미리보기 · 공방 상점 미리보기(chars.json rider). 시험 67(111개) · 전체 498,662개 통과 · chars_3 다시 올림 · Rojo 확인. **앉는 자리 · 안장**(사용자: "늑대 탑승위치가 갑자기 앞쪽으로가서 엄청나게 이상함 · 돼지도 같은문제 · 탈것 3종 모두 캐릭터 색깔이랑 같은 색깔의 안장을 만들어서 자연스럽게 이어버릴것"): ride.js seat.mark(늑대 초승달 · 멧돼지 갈기 혹 top 7) → 빌더가 장마다 표식이 옮긴 만큼 seatx · 등 높이도 그 자리에서 · RIDE.saddle(rows · at · pal 슬레이트 — 네 가지 견줌 saddle_try.png)을 <동작>_front에 장마다 그려 넣음 · 내보내기 bobx · rideView x + (seat.dx + bobx) · 공방 미리보기 seatx. 시험 67(117개) · 전체 498,668개 통과 · chars_3 다시 올림 · Rojo 확인. **흔들림 없음**(사용자: "좋은데 플레이어가 조금더 아래로, 플레이어 흔들림 없애고 안장 외곽선 거의 없는수준으로 연하게"): rider { sink 4 · dip 없앰 } · 빌더가 동작마다 한 자리(sx = 표식 이동의 평균 · top = 등 높이의 가운데 값 · 점프는 riderAt로 달리기의 자리) · 안장도 그 자리 · saddle.pal.o #353a42. 시험 67(높이 한 가지) · 전체 498,674개 통과 · chars_3 다시 올림 · Rojo 확인. **빈틈 없음**(사용자: "안장이랑 캐릭터 사이에 빈공간이 있으면안됩니다"): RIDE.saddle rows = 윗면이 꽉 찬 둥근 덮개(솟은 끝 · 패인 곳 · 밝은 줄 없앰) · ride/gallop/gapcheck.py(영웅 다섯 x 탈것 셋 그려 봄 · gap_board.png). 전체 498,668개 통과 · chars_3 다시 올림 · Rojo 확인. **원래 크기**(사용자: "캐릭터가 탈것 탔을때 너무작다 크기는 원래대로해야겠네"): rider.size 1 · 안장 폭 15 · 시험 67(원래 크기) · 전체 498,668개 통과 · chars_3 다시 올림 · Rojo 확인. **멧돼지 갈기 빈틈**(사용자: "이게 돼지만 프레임에서 빈공간 보이는부분이있어요 돼지 갈기가 보이는부분"): ride.js 멧돼지 seat.pad { up 5 · 옅은 갈기 색 다섯 } → 빌더가 영웅 자리 둘레(안장 윗줄부터 위 5줄 · -6~+5열)의 그 색을 안장 몸 색으로 바꿔 멧돼지 그림을 다시 쓴다. 전체 498,774개 통과 · chars_3 다시 올림 · Rojo 확인. **크기 · 빠르기**(사용자: "안장 외곽선 다시 넣고, 탈것들의 크기가 좀더 커야하고, 속도도 더 빨라야함"): ride.js mountSize 1.2 · mountSpeed 1.3 · rider.sink 3 · saddle 13폭 · o #232931 → chars.json 탈것 size(게임 Sprite.sizeOn) · rideView가 영웅 자리 x 탈것의 배 · boot 탄 동안 input.speed = mountSpeed(사다리 위 제외) · 공방 상점 미리보기 mp. 시험 67(134개) · 전체 498,785개 통과 · chars_3 다시 올림 · Rojo 확인. **펫 튐 · 거리 · Cash 경고**(사용자: "펫이 거리를 더 벌려야합니다 … 마을을 일자로 달리면 계속 팅기듯이 … 캐시 요청한도라는 경고는 무엇인지"): rideView 걸림 = 펫이 가려는 쪽으로 움직인 만큼(전에는 거리 줄기 — 달리면 1.2초마다 순간 이동) · 달리는 동안 갈 곳은 늘 영웅의 뒤 · 그림 = 영웅의 점 + 간격 · ride.js pet.behind 44 → 64 · boot togglePet/toggleRide를 once(요청 중 누름 무시 — Cash 빈도 제한 초당 3 · 6). 시험 63(곧게 달려도 순간 이동 없음 · 간격 흔들림 · ⑨ 영웅 980) · 전체 498,687개 통과 · Rojo 확인. **스마트폰 점검**(사용자: "지금 추가한 모든 작업들 달빛상점이나 다른요소들 모바일에서도 정상동작하게 작업되어있는지"): boot 폰 메뉴 = state.openWin(win.id)(전에는 Windows.toggle — 상점이 창으로 · 마을 밖에서도 열렸다) · 단추 배치 choices에 가진 펫 · 탈것(state.cash — 모르면 state.cashFetchNow → Touch.rechoose) · touch openChooser = Layout.touchChooser(ui.js UILAYOUT.touchChooser — 왼쪽 위 tl · 화면에 들어가는 만큼 · Ui.scroll · 이름 두 줄) · basics.js 놓는 법 글. 시험 66(75개 — tslots에 펫 · 탈것 · 이름 두 줄 · 다섯 직업 판이 화면 안 · 칸 단추를 덮지 않음) · 전체 498,733개 통과 · 규칙 검사 통과 · Rojo 확인. 실제 폰 · Play 안 봄.
          ✔ S174 **한 대만 쳐도 퀘스트 숫자 — 2026-10-21 (사용자: "퀘스트 깰때 몇마리 잡아라 … 내가 한대만 치면 다른사람이 잡아도 잡은걸로 판정이 들어가야해요")** — sim/room.luau damageMob이 mob.hitBy(이번 삶에서 친 사람)를 적고 strike가 쓰러질 때 거둬 kill.credit = 경험치를 받는 사람(잡은 사람 · 같은 맵 파티원) + 친 사람 가운데 방에 살아 있는 사람 · 스토리 보스는 방의 모두 · world.luau applyResult가 Quests.onKill · Daily.onKill · Quests.drops를 credit으로(경험치 · 업적 · 패스 · 모험의 서 · 달돈 · 장비는 gains 그대로). questplay.js 규칙 글. 시험 68(19개) · 전체 498,752개 통과 · 규칙 검사 통과 · Rojo 확인. #dev 맨 위에 지금의 처치 · 드롭 규칙 정리. Play 안 봄.
          ✔ S175 **파티마다 따로 된 방 — 2026-10-21 (사용자: "파티마다 따로 되어야합니다 … 한서버에 100명 있으면 차례를 엄청나게 기다려야하는겁니다. 설계부터가 잘못됬어요 솔로게임처럼되어있습니다")** — export_lune_game.mjs: 스토리 보스의 방 · story 방 · 튜토리얼 꿈에 scene.inst = "party"(r1c4 · in_cellar · dream) + SCENES.base(방 이름 → 장면). world.luau roomKeyFor(place 안 — 이미 그 장면의 방이면 그대로 · 같은 파티의 방 · 아니면 <장면>#번호) · onTravel/moveTo가 place 뒤 s.scene · 돌아온 문 = base · 빈 #방은 닫음 · resumeScene에 sc.inst · 꿈 비교는 Tutorial.isDream(서버 · 화면 21곳). 설계 이름과 견주는 곳은 base로: quests.luau(onKill · onVisit · wantsMob · wantsKill · spotsIn · use · drops) · achieve visited · navi aim · worldmap path · cine(find · findAll · before · lookAt · fits). bosses.js 글. 시험 69(48개) · 13 · 26 · 29 · 30 · 31 · 33 · 42 · 50 · 51을 새 방식으로 · analytics Death 필드는 방 번호를 뗀다. 전체 495,957개 통과(약 2,800개 적은 것은 시험 13이 보낸 메시지마다 세는데 꿈이 사람마다 나뉘어 메시지가 준 것 — 표시를 뺀 복사본과 구간별로 견줘 확인) · 규칙 검사 통과 · Rojo 확인. Play 안 봄.
          ✔ S176 **초기화 무료 · 이름표 레벨 · 넓은 명예의 전당 · 대영주의 성 순위 판 · 쿠폰 + 기본펫 — 2026-10-21 (사용자: "스텟, 스킬 초기화 완전무료로 … 닉네임 이름표 왼쪽에 레벨 … 명예의 전당 좀더 넓찍하게 … 대영주의 성에도 … 순위 표시 … 검정색 동그랗게 생긴 … 기본펫 … 쿠폰 코드 입력창")** — ① Hero.freeReset = 찍은 것이 있으면 몇 번이든(resets는 저장의 꼴만) · Hero.statsSpent · 패킷 StatReset(world 등록 자리에 바로 — world.luau 지역 이름 200 한도) · statWindow 「초기화」(UILAYOUT.stat.resetW 92 · 두 번 누르기) · skillWindow 늘 「초기화」 · items.js 상인의 statreset 줄 뺌 · basics.js SPRULE · 시험 탭 paint.js paintStat · luneTab statreset. ② 이름표 판 바깥 왼쪽에 레벨(사용자 "이름테두리 바깥에 레벨표기입니다" — 처음엔 판 안에 넣었었다): ui.luau Ui.tag의 lead · Ui.tagLead(판의 왼쪽 테두리 밖 3점 · small_o) · othersView.levelText · boot · 시험 탭 paint.js nameTag(lead) · luneTab tagOf. ③ town/indoor/raw_hall.png 다시(Codex v3 — 예전 raw_hall_v1.png) · town.js 비석 face [68,76,148,135] · [161,76,242,135] · [254,75,335,135] · back_in_hall 올림. ④ city/indoor/raw_ct_castle.png 다시(Codex v3 — 예전 raw_ct_castle_v1.png) · city.js ct_castle.stones(board · pad 1 · face [95,48|80|111,185,70|102|133]) · build_lune_cityrooms stones · 내보내기 board · pad · hallStones.luau · luneTab 같은 셈 · back_ct_castle 올림. ⑤ cash.luau coupons · couponCode · redeem · server modules/coupons.luau(LIST — 처음 DONGGEULI → pet_round) · CashServer.coupon(틀린 번호 1분 다섯 · saveNow · notify) · 패킷 Coupon · ui/couponWindow.luau(메뉴 「쿠폰」 · UILAYOUT.coupon) · boot wctx.coupon · ride.js pet_round(free coupon · line) · bm.js SHOP_PETS(상품 · 줄 · built에서 뺌) · cashWindow.product가 쿠폰 펫도 · 그림: bm/bm_pet_round.png(Codex 시안 셋) → build_lune_ride.py --only → lune_ride_hand.mjs pet_round(구멍 16 · 풀 3 · 숨 · 깜빡) → made · 아이콘 icons/icons24 끝에 한 칸(ride_icons.json에도) → build_lune_ui · chars_3 · mask · ui_kit 올림. 시험 70(74개) · 18 · 13 · 47 · 54(성의 숨은 이야기 st_manor tx 7 → 17) · 66. 전체 495,721개 통과 · 규칙 검사 통과 · Rojo 확인. Play 안 봄. **이어서 "동글이 좀더 작게"**: lune_ride_hand.mjs pet_round = 손으로 다시 찍은 17 x 14점(rows · pal — build_lune_ride_made가 R.rows를 읽게) · 아이콘 다시 자름(ride_icons.json at 18 [2,4] · 24 [-1,1]) · chars_3 · mask · ui_kit 다시 올림 · 시험 70(80개). **이어서 "검정동글이말고 재까마귀 몬스터 모델 그대로 … 몬스터보다는 크기가 작게 … 쿠폰펫"**: ride.js pet_crow「아기 재까마귀」(free coupon · from crow) · build_lune_ride_made가 from = 몬스터의 서기 띠를 그대로 옮겨 petSize 0.6으로(chars.generated에서 몬스터와 같은 그림판 칸) · RIDE_HAND에서 pet_round 뺌(RIDE_HAND_UNUSED) · 아이콘 칸을 ride_pet_crow로(18 [15,6] · 24 [9,3]) · coupons.luau DONGGEULI → pet_crow · 시험 70(86개) · ui_kit 다시 올림(chars_3은 예전 것과 같아져 그 번호). **이어서 "테스트 계정에서 다시 쿠폰을 입력할수없어서 … 달빛패스 일딴 비활성화 … 펫은 펫 탭으로 … 달빛상점 ui가 너무 작아 모바일에서도 반응형"**: CashServer.syncCoupons(계정을 읽을 때 쓴 쿠폰의 지금 펫을 넣고 저장 — world.luau s.acct 자리) · bm.js BM_SHOP.tabs 편의 · 펫 · 재화 · 꾸밈 · 보관함 · rows.pet · off [pass] · built에서 pass 뺌 · 검사기 off 규칙 · layout.luau L.shopSpace(묶음 k배 — maxScale 1.5 · 정수 화소 우선 · bottom 8) · cashShop.luau 묶음 Panels + UIScale · 미리보기 world 배율을 정수 화소로. 시험 70(110개) · 62(탭을 이름표로) · 65. **이어서 "쿠폰 기록을 초기화해줘 쿠폰등록하는것부터 영상을찍어야해"**: CashServer.resetCoupons(쓴 쿠폰 · free 펫 · petOut) · world onAdmin "coupons"(saveNow · CashGot · sendWho) · adminWindow 탭 「계정」 · 「쓴 기록 지우기」 · 시험 70(119개) · 30(계정 탭은 단추 하나).
          ✔ S177 **퍼블리시한 게임의 오류 보고 — 2026-10-21 (사용자: "이 스크린샷은 퍼블리시한 게임에서 오류가뜬겁니다. 왜 어던오류가 있는거고 해결도하세요")** — ① forgeWindow:417(1,727번): 첫 내려치기 전 STRIKES[0] → prevAt = STRIKES[strike] or 0 · 시험 53. ② pixelText:55 invalid UTF-8(554번): %s 빈칸 지우기(이름 칸 title · cashWindow · couponWindow · auctionView · cash.couponCode · pixelText fitLine)를 ASCII [ \t\r\n]로 · pixelText.Clean(깨진 바이트 → ?)을 Measure · Wrap · Fit에 · 시험 70. ③ 계정 잠금으로 내보냄(퍼블리시 때 서버를 옮기며): LOCK_TRIES 6 → 24(36초 — 닫히는 서버의 30초보다 길게). ④ 빈도 제한: Item 12/20 · 물약 state.sendPotion 0.34초 · Hop 0.6초 · Move 0.08초. ⑤ 우리 밖: 소리 HTTP 502 · CoreGui GameSettings · Teleport GameEnded · DataStore 줄서기 경고. 전체 495,782개 통과 · Rojo 확인.
          ✔ S188 **탈것 · 펫 그림의 빈 점 — 2026-10-22 (사용자: "멧돼지 idle 인지 run인지 배경 보이는 모션있다 픽셀 잘려서 배경보이는 부분이 있어 확인해서 고쳐라")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 장마다 몸 안에 갇힌 투명한 점을 셌다: 쇠 멧돼지 서기 3 · 4째 장 (15,11) · 달리기 1째 장과 점프 (36,18) · (37,18) · 달리기 5째 장 (25,4). 같은 검사로 달빛 늑대(서기 네 장 (28,21) · 달리기 1째 장 · 점프 (13,14) · 달리기 4째 장 (27~29,18))와 초롱 달토끼(옮긴 도트 rows.json의 빈칸 12 — 귀 털 옆 · 초롱 줄 옆 · 두 발 사이)도 찾았다. 하나씩 이웃을 보고 색을 정해 메웠다(제가 정한 것): tools/lune_ride_hand.mjs의 patch(장마다 — 멧돼지 · 늑대) · fix(원본 점 — 초롱 달토끼) · holesOk(초롱 달토끼 서기 3째 장 (26,20) = 초롱과 귀 털 사이의 원래 빈 곳 — 메우지 않는다). build_lune_ride_made.mjs: patch를 읽고(그 자리가 비어 있을 때만) · 빈 점이 남으면 알린다. 규칙 검사: 펫 · 탈것 71장의 빈 점(holesOk 빼고). chars_3 · chars_mask_3 다시 올림(110906936684772 · 88680934346320). 견주기 그림 assetpack/lune/dev/HOLES_1022_before_after.png.
          ✔ S187 **무기 · 로브 색 바꾸기(염색약 둘) — 2026-10-22 (사용자: "무기 색깔 바꾸는거 할수있어? 로브색깔이나" · "살라맨더 머리색 바뀌는걸로하죠")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 영웅 다섯은 모든 동작이 사실상 다섯 색(몸 #393e46 · 얼굴 · 테두리 #232931 · 흰색 · 무기 2~3단계)이라 색만 깔끔하게 바뀐다. 공방 design/dye.js(DYE — 무기 색 6 · 로브 색 6 · 영웅마다 본디 색상 · dyePixels). export: 영웅의 장 584개만 판 하나(1024x664)에 다시 모아 dye_body.png(몸의 점만 흰색) · dye_p_<색>.png 6장(무기의 점만 그 색 — 색상만 돌려 명암 유지) → 영웅의 장에 + (ux, uy) · dye.generated.luau. 올림: 7장 + ui_kit. 게임: sprite.luau setLook(로브 = 흰 판에 ImageColor3 · 무기 = 그 색의 판, 캐릭터 그림의 아이로 겹침 · 뒤집기 · 투명도 · 색을 따른다) · sim/dye.luau(choices · valid · clean · apply) · hero.look(저장 · view) · roster · Account.view · world onCash "dye"({ part, id } — 한 개를 쓰고 바꾸고 sendWho · saveNow) · 가방 · 퀵슬롯에서 쓰면 cashWindow "dye:point" · "dye:robe"(미리보기 판 · 색 칸 · 「변경」 · 살라맨더 = 「머리 색 바꾸기」) · othersView · title(고르는 화면) · cashShop 미리보기. bm.js dyepoint · dyerobe(49 · 거래 가능 · 꾸밈 탭) · 아이콘(Codex bm_dyes.png → raw_bm_4 · icons24 · icons) · 대시보드 그림 두 장(build_lune_bm_images.py에 「이름을 준 것만 쓰기」를 더했다 — 다른 그림은 그대로) · 등록표. 공방 탭 ?lunedemo=cashdye · cashdyerobe · dyelook. 시험 79(98개). 전체 501,090개 통과 · 규칙 검사 통과 · Rojo 확인. ROBLOX_IDS dyepoint · dyerobe = 0. 같은 날 사용자 "달빛상점에서 염색약 빼 일단 이건 계획이고 달빛상점에 보여주면안되는거야" → BM_SHOP.off에 dyepoint · dyerobe(rows · built에서 뺐다 — 탭에 없고 살 수 없다 · 등록표에서도 빠짐) · 염색의 셈 · 창 · 그림판 · 올린 그림은 게임에 남김 · 시험 79 고침(104개).
          ✔ S186 **여러 개 분해 · 더 똑똑한 펫 · 로벅스 펫 빨아들이기 — 2026-10-22 (사용자: "장비 분해를 한번에 여러개 할수있게 해달라, 펫이 너무 멍청해서 조금이라도 높은턱이 있으면 멍청하게 못줍는다 펫 지능 상향해라 로벅스 펫은 자석범위로 빨아들이는 형태로 한다 원래이미 펫을 가지고 있는사람들도 패치 적용되면 똑같이 적용 되어야한다 누락되면안된다")** — 확인은 사용자(Play 안 함 · 커밋 안 함). ① 여러 개 분해: 공방 ui.js bag sortW 64 → 48 · bulkW 44 · footGap 6(가장 작은 가방 폭 222점에 맞음) · WORDS.bulk(여러 개 분해 · 고른 장비 · 받는 달가루 · 분해 · 모두 · 풀기 · 취소 · 장비 {n}개를 분해할까요?) · paint.js 「분해」 단추 · 고른 칸 밝힘 · luneTab bulkSpec · ?lunedemo=bagbulk · bagbulkask. 게임: sim/bag.luau Bag.dismantleMany(겹친 것 · 없는 것 건너뜀 · 200개까지) · world onItem "dismantleMany"(업적은 분해한 수만큼) · bagWindow(장비 탭 아래 「분해」 → 칸 눌러 고름 · 풂 → 옆 판 · [분해] 한 번 더 묻기 · [모두] = ★0이고 ▲ 아닌 것) · boot 받은 달가루 글. ② 펫: ride.js RIDE.pet magnet 24 → 32 · climb 40 · hop 28 · windupChase 0.06 · suck { r 80 · every 0.15 } — rideView(주우러 갈 높이 차 40 · 머리 위 것은 밑에서 뛰어오름 · 아래층이면 걸어 내려가거나 발판 뚫고 · 로벅스 펫 = free 없는 펫은 둘레 80점 원 안을 0.15초마다 빨아들임 — 펫 종류로 정해져 이미 산 사람도 같다) · 서버 onPetPick 간격(로벅스 펫 suck.every) · PetPick 빈도 6 → 10. 시험 78(새 29개) · 63 고침 · 전체 500,788개 통과 · 규칙 검사 통과 · Rojo 확인. 같은 날 사용자 "로벅스 펫 빨아들이기 범위 더크게" → suck.r 80 → 160 · suck.reach 256(서버가 받는 영웅과의 거리 — 전에는 128이라 넓혀도 막혔다) · rideView far · world onPetPick · 시험 78에 넷 더.
          ✔ S185 **영구 게임 패스 둘 — 경험치 1.25배 · 드롭률 1.25배 — 2026-10-22 (사용자: "경험치 1.25 배, 드롭률 1.25배 패스 팔고싶은데 영구적용패스" · "패스가 로블록스에 개발자상품말고 패스라고 하는게 있어 그걸 말하는거야 구매하면 영구적용되는 효과로")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 공방 bm.js: 상품 xp125 「경험치 1.25배 패스」 · drop125 「드롭률 1.25배 패스」(kind pass · effect { xp 0.25 } / { drop 0.25 } · 값 249 · 편의 탭의 첫걸음 묶음 다음 · built · 그림 buff_exp / orb(있는 것을 빌림) · 한 줄 설명 · BM_DASH 설명 · ROBLOX_IDS 0) · 내보내는 상품에 effect · ui.js BUFFTIP.forever 「영구」 · pass(xp · drop · hint) · build_lune_bm_images.py(두 패스의 512 그림 — 이때 다른 상품 그림도 다시 만들어져 펫 셋의 그림이 지금 게임의 펫 그림으로 바뀌었다) · write_lune_bm_dash.mjs(등록표를 개발자 상품 · 게임 패스 두 묶음으로 — 게임 패스 = Monetization → Passes → Create pass · 번호 = ⋯ → Copy Asset ID). 게임: sim/cash.luau(Cash.expMul = 1 + 쿠폰 0.5 + 패스 0.25 — 더한다(제가 정한 것) · Cash.dropMul · Cash.passEffect) · sim/room.luau(lootFor: 장비 · 재료 · 귀한 물건만 dropMul — 달가루 · 달돈(dropFor) · 퀘스트 물건은 그대로) · sim/hero.luau(view에 passes) · server cash.luau(CashServer.applyPasses — 번호가 있고 만들어 둔 패스를 UserOwnsGamePassAsync로 물어 h.passXp · passDrop · passOwn / 산 순간에도 · 값 읽기 = 패스는 InfoType.GamePass(전에는 모두 Product)) · world.luau(캐릭터로 들어설 때 뒤에서 applyPasses → sendSelf · 패스를 사면 sendSelf) · boot(버프 줄 끝에 그 그림 · 「영구」 · 설명 = 「사냥 경험치 +25%」 · 「장비 · 재료가 나올 확률 +25%」 · 「영구 — 계정의 모든 캐릭터」). 시험 77(새 33개 — 자료 · 배율 · 3만 번 굴려 장비 · 재료 1.25배쯤 · 달가루 그대로 · 서버가 들어설 때 묻고 얹음 · 화면에 보냄 · 상점 「보유」 · 번호가 없으면 묻지 않음) · 전체 500,543개 통과 · 규칙 검사 통과 · Rojo 확인. 이어서(사용자 "지금 계산법좋다 근데 아이콘은 너무 못생겼는데?"): 전용 아이콘 bm_passxp(금빛 위 화살표 + 민트 수정) · bm_passdrop(열린 보물 상자 + 분홍 · 민트 보석) — Codex(assetpack/lune/bm/prompt_bm_passes.txt → bm_passes.png → ui/raw_bm_3.png · bm_sheets.json) → icons24 → build_lune_ui → ui_kit.png 올림(135427631187121) · 대시보드 그림 다시. 전체 501,035개 통과. 번호(사용자가 대시보드 Passes에 만든 것 — 249로벅스): xp125 = 2044688783 · drop125 = 2044970818 → ROBLOX_IDS · 시험 77이 진짜 번호를 확인. 전체 500,583개 통과 · Rojo 확인.
          ✔ S184 **던전 「수정 거울숲」 = 일자 맵 · 몰려오기 — 2026-10-22 (사용자: "이거 던전 만든거 있잖아 일자맵에다가 가운데로 계속 몬스터 몰려오는 형식으로 해줘 쾌감 느껴지게")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 공방 design/dungeon.js: DUNGEON.swarm(per 36 · last 16 · elites 3 · cap [10, 22] · every [0.6, 0.22]초 · speed 48 · pace [0.8, 1.25] · near 64 · edge 2.6칸 · combo gap 2초 / from 5 — 모두 제가 정한 것) · tier.arena(32칸 평지 · 가운데 16칸에 선다 · 왼쪽 끝 = 나가는 수정 문 · 오른쪽 끝 = 같은 문 그림(꾸밈) · 소품 = 수정 숲 것 그대로) · base r2a2 → dg1 · dungeonArenas()(maps.js와 같은 꼴 — build_lune_maps.mjs가 같이 짓는다 · mobHp) · dungeonQueue()(종류마다 36 · 마지막 거미 16 + 정예 3 = 163 · 나오는 쪽 번갈아) · swarmPace() · words.kills 「처치 {n} / {max}」 · combo 「{n} 연속 처치!」 · 소개 글 고침 · ui.js UILAYOUT.dungeon.comboGap. 내보내기: 일자 맵 장면 → 던전 장면 dg1(swarm · 몬스터 = 차례 · 구간 = 맵 전체 · 나가는 문의 빛 1.5배). 그림: ground_dg1_1.png 올림(102570354131734). 게임: sim/rift.luau(Rift.swarmPace · start에서 queue · stepSwarm — cap이 차지 않았고 every가 지났으면 다음 것을 수정 문에서 · 처치한 몫만큼 cap↑ every↓ · 다 잡으면 완료 · view에 swarm · total) · sim/room.luau(몰려오기의 움직임 — 가장 가까운 사람에게 곧장 · 빠르기 = max(쫓는 빠르기, 48 x pace) · 쏘는 것도 near 안으로 · 나는 것은 덮칠 거리에서 덮침) · riftView.luau(아랫줄 「처치 72 / 163」 · 판 아래 「12 연속 처치!」 — 남은 수가 줄면 이어 세고 2초 동안 안 줄면 끊김 · 늘 때 0.15초 하얗게). 시험 탭: luneTab.js(SWARM · swarmSpawn · stepSwarm · 주인공에게 곧장 · 나가는 문의 빛 · ?lunescene=dg1&lunedemo=riftrun(72마리 잡은 때) · riftelite(마지막)) · paint.js paintRiftHud(처치 · 연속 처치). 시험 75(2,652개 — 일자 맵 · 차례 · 양 끝 · 번갈아 · cap을 넘지 않음 · 잡을수록 더 · 달팽이도 48 · 처치한 수 · 서버 흐름) · 12(몰려오기의 장면은 문 곁 규칙에서 뺌) · 전체 500,565개 통과 · 규칙 검사 통과 · Rojo 확인.
          ✔ S183 **폰에서 대쉬하다 땅 속에 끼는 것 · 점프 · 상호작용 단추도 끌어 옮기기 — 2026-10-21 (사용자(폰 스크린샷 — 세 갈래 길 오른쪽 턱 안에 박힘): "모바일에서 내가 지금준 스크린샷처럼 대쉬하다가 맵을뚫고 낑기는 현상 발생합니다 그리고 모바일에서 상호작용, 점프키 같은거 위치 다 바꿀수있어야해요 드래그앤 드랍으로 다른 버튼들처럼")** — 확인은 사용자(Play 안 함 · 커밋 안 함). ① 끼임: 화면의 물리(physics.luau P.step)는 벽에서 멈춘다(그대로 옮겨 대쉬 · 뛰기를 3,000번 x 1,200걸음 돌려도 0번) — 몸이 땅 속에 들어가는 길은 서버가 준 자리(되돌리기 Warp · 들어서기)뿐이다. 서버는 자리 보고를 거리로만 보고 맵 칸을 보지 않으며, 어느 맵의 보고인지도 몰랐다(원인 하나로 확정하지 못함 — 후보: 다른 맵의 늦은 보고 · 문의 대답이 늦어 화면과 서버의 맵이 어긋남). 고친 것: sim/physics.luau P.freeSpot · P.unstick(막힌 칸 안이면 가장 가까운 빈 자리 — 칸의 윗면마다 위로 먼저 · 옆은 두 배로 침 · 6칸까지) · room.luau Room.physics · boot.luau(한 걸음마다 끼었으면 꺼냄(사다리 위 빼고) · Warp · 장면에 들어설 때 · Move에 맵 이름을 붙임) · packets Move 넷째 인자 · world.luau(onMove: 다른 맵의 보고는 받지 않음 · 4초 넘게 계속 다르면 서버의 맵으로 moveTo(Revive) / 되돌려 보낼 자리 · place가 세우는 자리를 freeSpot / moveTo를 앞에서 이름만 지음(지역 이름 한도) / 문 · Revive의 대답에 꺼낸 자리). ② 던전 출구(S182의 잘못): 문 왼쪽 30점 · 맵 시작 자리의 높이(176)라 반달네 옛집의 높은 땅 속에 섰다 → 그 문의 높이(160). ③ 폰 단추: 공방 basics.js TOUCH 4번 「뛰기」 → 칸 13(처음에는 점프) · 14번 「상호작용」 → 칸 14(처음에는 상호작용) · ui.js QUICK.acts { act_jump home 13 · act_interact home 14 } · quickPlace(밖에서 온 것으로 덮지 않음) · quickClear(빼지 못함) · quickTouchFix(없으면 처음 칸에 · 둘이면 하나) · export touchCheck · check 본보기 더함 · check_lune_design 터치 규칙(칸 2~14 · act는 menu만). 게임: ui/quick.luau Q.ACTS · Q.act · place · clear · touchFix · pic · sim/hero.luau(폰 배치에만 받음 · 스킬을 다시 찍어도 점프 · 상호작용 · 펫 · 탈것은 칸에 남음 — 펫 · 탈것이 빠지던 것도 같이 고침 · 저장을 읽을 때 salvage가 지우지 않음) · touch.luau(칸 단추에 점프 · 상호작용이면 글 · 누르고 있는 동안 뛰기 · 상호작용 · 「단추 배치」에서 끌어 바꾸기 · 끄는 모습에 글 · frameOf가 옮긴 자리를 찾음 · 목록 판은 왼쪽 아래 칸 단추 위에서 끝남(Layout.touchChooserFit)) · boot(목록에 점프 · 상호작용 · tslot에 놓인 것이면 아무것도 안 함). 메뉴 단추 · 조이스틱은 그대로(제가 정한 것). 시험 76(새 142개 — 꺼내기 · 모든 맵의 서는 자리 · 서버 · 칸 셈 · 가짜 화면으로 폰 단추를 누르고 끌기) · 13 · 34 · 40 · 66 · 75 고침 · 전체 497,973개 통과 · 규칙 검사 통과 · Rojo 확인.
          ✔ S182 **달빛 상점 로딩 · 구간 던전 「수정 거울숲」(Lv.30~40) — 2026-10-21 (사용자: "달빛상점 로딩 너무길다" · "수정틈안에 들어가면 던전 입장 멋지게 있고 , 파티로 들어갈수도있고 개인으로 들어갈수도있는 문이 하나 있고 … 망루에서 이 던전관련 퀘스트를 주는게 있어서 … 이 퀘스트는 30에 열려 … 크고 색도다른 느낌표 … 메이플에 몬스터파크 처럼 … 다잡고나서 … 일괄 경험치 … 하루에 한번 … 한국시간 자정에 초기화 … 던전 맵디자인은 있던거 돌려써 … 던전이름은 알아서 잘지어서")** — 확인은 사용자(Play 안 함 · 커밋 안 함). ① 상점 로딩: 서버 cash.luau가 상점에 들어설 때마다 상품 값(GetProductInfoAsync)을 하나씩 차례로 받았다 → 서버가 켜질 때부터 뒤에서 한꺼번에(task.spawn) 받아 두고 10분마다 다시(실패하면 30초 뒤) · 상점은 받아 둔 값을 바로 쓴다(CashServer.prices) · 공방 bm.js space.minLoad 0.5 → 0.3초. ② 던전: 공방 design/dungeon.js(새 — DUNGEON 하루 1번 · 10분 · 끝나고 8초 · 파티 4 · 몬스터 체력 0.6배 · 때림 0.8배 · 정예 체력 5배 · 때림 1.3배 · 몬스터 1.5배 · 보상 = 그 레벨 경험치의 0.5 / tiers dg1 「수정 거울숲」 Lv.30~40 · 몬스터 Lv.34 · 바탕 r2a2(수정 오솔길) · 문 r2ah(반달네 옛집 = 수정 틈) x 27.6칸 · 물결 그루터기 · 달팽이 · 개구리 · 거미 + 정예 거미 = 다섯 물결 76마리) · city.js CITYQUESTS dq01 「수정 틈의 문」(Lv.30 · big · 곰솔(성문 앞) · 끝 NPC 없음 — 문에 손 대기로 끝) · CITY_SPOTS riftgate · maps.js r2ah 문(riftgate 그림 · 높이 104) · ui.js QUESTMARK 「!!」(주황 #ff8a2b · 4x9 점) · UILAYOUT.dungeon · basics.js WINDOWS dungeon. 그림: 수정 문 = Codex(assetpack/lune/looks/raw_riftgate_kit.png → build_lune_look2.mjs riftgate 80x108 · 문 안쪽 어둡게 채움) · ui_kit markBig. 올림: props_r2a1.png 71040232429267 · ui_kit.png 137411895578654. 게임: sim/rift.luau(던전 = 토벌의 엔진 · dungeonDone · dungeonMark(Daily.dayOf — 한국 자정) · dungeonXp · canDungeon) · sim/room.luau(던전의 몬스터 = 경험치 · 물건 · 퀘스트 · 모험의 서 · 업적 · 패스 숫자 없음) · sim/quests.luau(Q.mark 「!!」) · world.luau(onRift enter · dungeonEnter(문 곁 60점 · 파티 = 같은 맵 2명 이상) · riftPay(한꺼번에 경험치 · 그날 끝) · 끝나면 문 왼쪽 30점에 선다 · 퀘스트 use에서 endNpc false면 바로 끝) · client ui/dungeonWindow.luau(새) · boot(문 앞 ↑ = 던전 창 · 닫힌 문 = 「수정 문이 굳게 닫혀 있다」 + 곰솔 안내 · 맵 이름은 토벌 · 던전의 판이 떠 있으면 숨는다) · sceneView(「!!」 · 문의 빛 1.5배) · riftView(던전의 글). 실패하면 그날 횟수를 쓰지 않는다(제가 정한 것). 시험 탭: paint.js paintDungeon · 토벌 판의 dg 글 · luneTab ?lunedemo=dgquest · dgdoor · dgclosed · dgactive · dgopen · lunescene=dg1&lunedemo=riftrun · riftend(헤드리스 Edge로 봄 — 맵 이름이 던전 판과 겹친 것 · 소개 글이 넷째 줄로 넘친 것 · 나올 때 문 앞이 아니라 시작 자리에 선 것을 고침). 시험 75(새 226개) · 17 · 28 · 30 · 38 고침 · 전체 497,675개 통과 · 규칙 검사 통과 · Rojo 확인.
          ✔ S181 **수량 창 — 수를 정하는 모든 곳 — 2026-10-21 (사용자: "잡화상점에서 물약이나 달가루 구매할때 1개 아니면 10개밖에 못사잖아 이거 수량 입력하는 모달 받아서 처리해야지 이렇게하면안되는거야 모든 곳에서 수량받아서 처리해")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 공방 ui.js UILAYOUT.count(w 264 · 줄 치수 · words range · max · cost · short · gain) · WORDS.ask.buy(몇 개를 살까요? · 사기). 게임: shared ui/countPick.luau(parse — 숫자만 · 맨 앞 0 · 최대를 넘으면 최대 / hi · first · buyMax · step) · Layout.COUNT · sim/bag.luau Bag.roomInView · storeRoomInView(보낸 것의 셈 = Bag.room) · client ui/countBox.luau(화면 가운데 · 어두운 막 · 묻는 글 · [그림] 이름 · [−] [수량 칸] [+] [최대] · 범위 · 합계(모자라면 빨강) / 받을 달돈 · 확인 · 취소 · Enter · PC는 열리자마자 칸에 적는다 · 창이 닫히면 같이 닫힘) · 상점: 「1 · 10」 → 「사기」 하나(여럿 사는 것 = 수량 창 · 가장 많이 = 한 번에 파는 수 · 달돈 · 가방의 자리) · 가방: 버리기 · 나누기 · 맡기기 · 팔기 = 수량 창(상세 판의 -10 -1 +1 +10은 쓰지 않음) · 상점에 끌어다 놓기(팔기) · 창고: 찾기 · 두 번 누르기 · 끌어서 가방으로 · 가방에서 끌어 맡기기 = 묶음이면 수량 창(맡기기 · 찾기는 들어가는 만큼까지) · 경매장은 그대로(10-13부터 적는 칸) · 달빛 상점의 보관함은 그대로(들어가는 만큼 한꺼번에) · boot: 수량 창이 떠 있는 동안 게임의 키를 받지 않는다(Input.typing). 시험 탭: paint.js paintCount · paintShop 단추 하나(shopbuy · shopback) · luneTab askCount · shopBuy · countNow · countKey(숫자 · 지우기 · Enter · Esc) · 끌기 · ?lunedemo=countbuy · countsell · countsplit(헤드리스 Edge로 봄). 시험 74(새 70개) · 15(물음 8가지) · 전체 495,914개 통과 · 규칙 검사 통과 · Rojo 확인.
          ✔ S180 **한글 입력 상태의 키 버그 대비 — 2026-10-21 (사용자: "로블록스에서 한글쓴다음에 키가 안먹히는 버그가있거든? 로블록스에서 유명한 버그야 이거 확인해봐")** — 확인은 사용자(Play 안 함 · 커밋 안 함). 찾은 것: 나무위키 「Roblox」 2019년 기록(한/영 키가 「한」이면 이동이 제대로 되지 않고 누른 키가 영어로 다시 누를 때까지 계속 움직이거나 안 움직인다 · 해결 = 한/영 키를 영어로 · 채팅에 영어를 쳐서 보냄) · DevForum 「Movement key in Korean doesn't work」(2021-01 · 게임 안에서만 · Studio는 아니다 · 답 없음) · 「Chat bug when entering Korean」(2026-02 · 마지막 한글 글자가 TextBox.Text에 들어가지 않는다 — 다른 버그). 우리 게임: 이동 = 방향키 · 뛰기 = Space(글자가 아니다) · 퀵슬롯 Q W E R A S D F X · 줍기 Z · 탈것 N · 창의 키 = 글자. client input.luau: byKey · wasDown · Input.poll(BindToRenderStep LuneInputPoll · RenderPriority.Input — 묶인 키마다 IsKeyDown: 뗐는데 눌린 채면 떼고(키보드로 누른 것만) · 새로 눌렸는데 모르면 누른다 · 글 치는 중 · 고르기 화면 · 키 설정 · Roblox 메뉴 동안은 누르지 않음 · 그때부터 누르던 키는 다시 눌러야) · KeyCode 0(Unknown/None) 글쇠 + 묶인 키가 하나도 안 눌린 장면 → 3초 안에 두 번 → Input.onIme(1분에 한 번) · IME_WORDS · boot: 큰 알림 「한글 입력 상태」 「글자 키가 먹지 않으면 한/영 키를 눌러 영문으로 바꿔 주세요」 6초. IsKeyDown이 한글 상태에서 맞는지 · 한글 상태의 글쇠가 KeyCode 0인지는 확인하지 못했다(Studio에서는 버그가 나지 않는다고 함). 시험 73(새 21개) · 전체 496,208개 통과 · Rojo 확인.
          ✔ S179 **쿠폰 탈것 「떠도는 책」 — 2026-10-21 (사용자: "간단한 탈것 하나 만들어볼래? 무료로뿌릴거고 쿠폰용이야 애니메이션 소요가 심하지않게 이미 있는 떠도는 책 몬스터에서 위에 플레이어가 타는형식으로 라이딩 만들고 이동속도는 유료보다 느리게 그냥 플레이어 이동속도로 만들어줘")** — 확인은 사용자(Play 안 함 · 커밋 안 함). ride.js mount_book(free coupon · from book · speed 1 · seat { x 17, y 15, x0 9, x1 25, saddle false }) · lune_ride_hand.mjs mount_book(from · steady #1fa89c · lift 3 · idle 6fps · run · jump 12fps = 몬스터 띠 그대로) · build_lune_ride_made.mjs monsterFrames(몬스터 띠의 장을 그대로 · 몸 높이를 첫 장에 맞춤 · 기준점 = 몬스터의 것 + lift) · seat.y(앉는 줄을 정해 둠) · saddle false · 견준 그림 ride/book_try.png · book_try_saddle.png · 아이콘 ride_mount_book(icons 18 (144,270) · icons24 (72,624) 끝에 붙임 · ride_icons.json) · bm.js SHOP_MOUNTS(상품 · 탭 · built에서 뺌) · 내보내기 mounts free · line · speed · chars_3 · chars_mask_3 · ui_kit 다시 올림. 게임: boot 탄 동안 빠르기 = 탈것의 speed 또는 mountSpeed · Cash.redeem mount(고른 것이 없으면 고른다) · CashServer.coupon mount · syncCoupons · resetCoupons 탈것도 · coupons.luau FLYINGBOOK → mount_book(번호는 제가 정한 것) · couponWindow 이름 · cashWindow 쿠폰 탈것도 상품처럼. 시험 72(새 109개) · 전체 496,081개 통과 · 규칙 검사 통과 · Rojo 확인. **이어서 "책 라이딩 z인덱스가 플레이어가 더 높으면 안됩니다 . 책이 우선으로 보여져야해요"**: seat.over(build_lune_ride_made — <동작>_front = 탈것 그림 전체) · 왼쪽 책장이 얼굴을 가려 seat.y 15 → 10(12 · 10 · 8 견줌 — ride/book_try_front.png) · 앞 그림이 탈것 그림과 같아져 그림판이 줄어 chars_3 · mask_3이 커밋된 것과 같아졌다(예전 번호 그대로) · 시험 72(127개) · 전체 496,220개 통과 · Rojo 확인.
          ✔ S178 **관리자 확성기 — 모든 서버에 공지 — 2026-10-21 (사용자: "로블록스는 서버가 여러개가 돌아가는 구조잖아 내가 모든 서버에 확성기로 말할수있나? 어드민기능으로 확성기같은게 필요한데")** — 확인은 사용자(Play 안 함 · 커밋 안 함). server modules/megaphone.luau(MessagingService 주제 LuneMegaphone · 80자 · 5초에 한 번 · TextService로 거른 글 GetNonChatStringForBroadcastAsync · 소식 번호로 두 번 띄우지 않음 — 최근 50개) · world.luau start(이 서버의 sessions 모두에게 — 캐릭터 고르기 화면의 사람도) · onAdmin "megaphone"(관리자만 — 계정 번호) · 패킷 Megaphone(서버 → 화면) · boot: 화면 위 큰 알림 「공지」 8초 + 채팅 알림 「[공지] …」 · guide.luau 큰 알림 아랫줄 두 줄까지(칸 높이 Ui.M.body + 8 + smallLine x 2) · adminWindow 「계정」 탭 「확성기」 칸 + 「보내기」(Enter도) · 시험 71(새) · 30 · 38. 표시 방법(큰 알림 + 채팅 · 8초 · 80자 · 5초)은 제가 정한 것. 다른 서버로 가는 것은 퍼블리시한 게임에서만(Studio는 서버가 하나). 전체 495,820개 통과 · 규칙 검사 통과 · Rojo 확인.
          ✔ S172 **가방의 캐시 탭 · 퀵슬롯 14칸 · 말풍선 · 펫 자석 — 2026-10-21** — 확인은 사용자(Play 안 함 · 커밋 안 함). 상점 줄 = 「보유」만(cashWindow rows · paint.js) · bagWindow 넷째 탭 cash(Cash.view의 pets · mounts · 상세 판 · 두 번 누르기 · 끌기 → 퀵슬롯) · boot state.togglePet / toggleRide(퀵슬롯 · 가방 · N 키) · Quick.ride · Quick.pic ride_ · Hero.canSlot(펫 · 탈것) · QUICK n 14 · rows(아랫줄 1~6 · 13 / 윗줄 7~12 · 14) · keys X · 3 · 스킬 칸 352/256 · narrow(below 820 → 220 · 칸 사이 4) · L.rect · L.slotPlace(i, n, gw) · L.slotCell · talk.luau 말풍선 clamp 없앰 · 화면 밖이면 숨김 · rideView 자석(magnet 24 · onPick(id, x, y)) · Effects:pull. 공방: ui.js · basics.js · luneTab(bagcash · 캐시 탭 · 펫 칸) · paint.js(가방 · 말풍선 pin) · check(터치 칸 2~12 · rows). 시험 66 · 49 · 63 · 14 · 40 · 62 · 전체 498,726개 통과 · Rojo 확인.
          ✔ S171 **달빛 상점 = 들어가는 공간 · 마을에서만(상점 · 경매장) · 펫 재접속 — 2026-10-21 (사용자: "달빛상점은 메뉴탭 안에 숨어있는게 아니라 … 메이플스토리 캐시샵처럼 아예 무적공간으로 들어가버리는 형태 … 캐시샵은 마을에서만 … 경매장도 마을에서만 … 펫은 … 재접속하면 그대로 … 로딩중 잠시 넣고 그동안 다 로드해서")** — 확인은 사용자(Play 안 함 · 커밋 안 함). shared sim/town.luau(Town.is) · server world.luau: inRoom이 s.shop을 뺀다 · Cash "enter"(마을 · 살아 있음) / "leave"(moveTo로 그 자리) · buy는 안에서만 · outside()로 움직임 · 기술 · 줍기 · 물약 · 경매장 … 막음 · onMarket = 마을에서만(Market.WHY.town). client cashShop.luau(공간 · 미리보기 · CashWindow를 그대로 · Curtain.load) · boot: 단추 줄 · ` · state.openWin(상점 = 공간, 경매장 = 마을) · 마을 밖으로 나가면 경매장 창을 닫는다 · 처음 이름표(room.who)에서 내 펫 · 시작할 때 shop_ 그림을 미리. cashWindow: 펫 · 탈것 줄 → ctx.cashPreview. 공방: bm.js BM_SHOP.space · ui.js 단추 줄(월드맵 → 상점) · basics.js 키 Backquote · economy.js why.town · paint.js paintCashSpace · luneTab ?lunedemo=cashshop · 검사(글 · 칸 · 768 x 432). 시험 65(62개) · 41 · 62 고침 · 전체 498,531개 통과 · shop_bg.png 올림 · Rojo 확인.
          ✔ S170 **펫 그림 합격 · 펫이 지형 위를 걷는다(메이플 일반 펫) — 2026-10-21 (사용자: "오케이 합격이고 펫도 지형에 걸려야해요 지금 펫 지형 다뚫고 다니는데 지형에 걸려서 플레이어에게 가지 못하는 거리가 되어버리면 그때는 텔레포트 해서 붙는방식으로 메이플스토리에서 일반펫이 어떻게 작동하는지를 파악하고 , 그에맞춰 작업하면 됩니다.")** — 확인은 사용자(Play 안 함 · 커밋 안 함). client rideView.luau: 펫 = 영웅과 같은 Physics.step(1/60초) · 벽 · 턱 = 0.2초 웅크렸다 뜀 · 위 발판의 영웅은 아래에서 기다림 · 아래로는 걸어 떨어짐 · 얇은 발판은 하단 점프 · 같은 높이 구덩이는 뛰어 건넘 · 순간 이동 = 영웅이 땅에 서 있을 때 가로 384 · 세로 72점보다 멀거나 1.2초 동안 4점도 못 가고 44점보다 멀 때 · 설 자리 spotFor(벽 속 · 다른 높이면 22점 → 반대쪽 → 곁) · 줍기는 제 높이(위 18 · 아래 4점)만. RIDE.pet에 windup · warpX · warpY · stuck · lookUp · lookDown(출처 · 제가 맞춘 것 표시) · boot · othersView가 scene을 넘김 · 시험 63을 시험 맵으로(32개) · 전체 498,461개 통과 · Rojo 확인. SNS 탭: 펫 그림을 「올려도 되는 것」으로(움직임은 판정 전).
          ✔ S169 **펫의 크기 = 0.6배(한 점이 정수 화소) — 2026-10-21 (사용자: "이게 펫이 해상도가 딱 맞는 크기가 있을거야 좀키우면서 그게 어느정도인지 찾아봐")** — 0.5배는 1080p(배율 5)에서 한 점 2.5화소 → 0.6배 = 3화소(0.8배 = 4화소는 영웅보다 커서 뺐다). client sprite.luau Sprite.sizeOn: 화면 배율 x 크기를 반올림한 화소(1440p · 720p는 0.67배) · 폰(소수 배율)은 그대로. RIDE.petSize 0.6 · 시험 64(80개) · 전체 498,447개 통과 · 그림은 바뀌지 않아 올린 것 없음 · Rojo 확인. 견줌 C:\YJS\Roblox\dino-workshop\assetpack\lune\ride\hand\size_try.png · size_zoom_1080p.png.
          ✔ S168 **공방 「SNS 홍보」 탭(#sns) — 2026-10-21 (사용자: "공방에 sns 탭을 만들고, 거기에 내가 영상이나 , 글, 사진으로 홍보용으로 올라가도 되는사안들 즉 수정없이 픽스가 완료된 사안들을 정리하고 어느 폴더에있는지도 적고")** — 공방 js/lune/snsTab.js · 목록 js/lune/design/sns.js(확정 13가지 · 아직 14가지 · 라이선스 원문 인용) · check_lune_design.mjs가 파일 63개가 있는지 본다. 사용자가 새로 확정하면 notYet → items로 옮긴다.
          ✔ S167 **펫 = 다시 시안 판 + 연한 바깥 테두리 — 2026-10-21 (사용자: 시안의 은빛 달토끼를 보이며 "원래 처음버전 이버전에서 외곽선을 연하게")** — 확인은 사용자(Play 안 함 · 커밋 안 함).
               공방 tools/lune_ride_hand.mjs: 큰 시안 판 펫 셋을 되살림(edge = { key, t: PET_EDGE 0.4 — 제가 고른 값 }) · 작은 도트 판은 PET_SMALL로 남김(쓰지 않음). tools/build_lune_ride_made.mjs: softEdge(장마다 — 투명한 곳에 닿은 테두리 점만 안쪽 몸의 색 쪽으로 t) · RIDE.petSize 0.5 되살림 · EDGE_TRY=0,0.25,0.4,0.55,0.7 → C:\YJS\Roblox\dino-workshopssetpack\lune
ide\hand\edge_try.png. 아이콘 자리 · 대시보드 펫 세 장 다시. 따라오기 · 줍기(S166)는 그대로. 전체 498,267개 통과 · 그림판 셋 다시 올림 · Rojo 확인.
          ✔ S166 **펫 셋을 작은 도트로 · 멀리서 따라오며 달려가 줍기 — 2026-10-20 (사용자: "플레이어랑 펫이 거리가 좀 있어야하고 좀멀리서 쫓아오는 느낌이야 아이템주우면서 그리고 가 버전보다 아까처럼 열화시킨 버전이 게임에 잘어울린다 하지만 열화시킨버전 퀄리티가 너무 안좋아서 퀄리티좀 올려봐 형태는 단순해져도된다")** — 확인은 사용자(Play 안 함 · 커밋 안 함).
               그림: 공방 tools/lune_pet_dots.mjs(손으로 찍은 작은 펫 셋 — 은빛 15 x 14 · 초롱 17 x 11 · 목도리 15 x 15, 바탕 = Codex의 작은 그림 bm/ride/pet_small4.png) → lune_ride_hand.mjs(dots: true · 한 점짜리 숨 · 귀 · 술 · 달 · 목도리 끝 · 눈 깜빡 · 깡충 3점) → build_lune_ride_made.mjs(새 말 stretch = 몸을 한 점 늘림 · 펫의 size 없앰 — RIDE.petSize 삭제). 견줌: assetpack/lune/ride/hand/review_pets.png · view_pet_*.png · lineup.png. 아이콘 ride_icons.json의 펫 자리를 가운데로 다시 · 대시보드 펫 세 장 = 한 점 18화소 + 밝은 테 한 점(사용자에게 다시 올려 달라고 함).
               따라오기 · 줍기(design/ride.js RIDE.pet = behind 44 · base 40 · per 2 · max 160 · chase 150 · jumpTo 220 · reach 96 · slack 32 · every 0.3 — 제가 정한 수치): client rideView.luau가 펫을 움직이고 떨어진 것에 닿으면 PetPick(번호) → server world.luau onPetPick(펫 꺼냄 · 살아 있음 · every · Room:pickup(reach + slack)) — 전의 서버 petPick 고리(0.3초마다 바로 줍기)는 없앴다 · 패킷 PetPick(6/초) · analytics의 MonsterDrop에 PetPick. 시험 63(24개). 전체 498,373개 통과 · 그림판 셋(chars_3 · chars_mask_3 · ui_kit) 다시 올림 · Rojo 확인.
          ✔ S165 **펫 셋 · 탈것 셋 · 달빛 패스(30일) — 2026-10-20 (사용자: "펫은 종류 다르게 별도상품으로 … 같은기능을가진 별도의 펫으로 판매 … 탈것은 사다리에서 감추기 좋습니다 … 탈것, 펫 애니메이션 만들고, 게임에 적용하고" · "달빛패스에 시즌이라는 개념이 필요가 없잖아")** — 확인은 사용자(Play 안 함 · 커밋 안 함).
               그림: 공방 tools/build_lune_ride.py(시안 → 도트 1:1 · ride/rows.json · compare · grid) → tools/lune_ride_hand.mjs(손으로 고친 점 · 부위를 옮긴 동작) → tools/build_lune_ride_made.mjs(ride/chars/*.png · _front · chars.json · view · lineup) → export(chars.generated에 합침 · data/ride.generated.luau = seat · bob · pet 규칙) · 아이콘 = build_lune_icons의 ICON_DIRECT(ride_icons.json — 도트를 그대로 자른다) · 대시보드 = build_lune_bm_images.py.
               게임: sim/cash.luau(acct.bm.pets · mounts · petOut · mount, grant · setPet · setMount · pack) · sim/pass.luau(산 때부터 30일 · 달빛 · 칸 30 · 끝난 뒤 다시) · server world.luau(petPick 0.3초 · Room:pickup의 reach · onCash pet · ride · roster의 pet · ride · 기술 = 내림 · 경매장 칸 +5) · client rideView.luau(펫이 따라오기 · 탈것 · 앉는 자리 · 등을 앞에) · boot(N 키 · 사다리 · 기술 · 맞음에서 감춤) · othersView(다른 사람의 것) · ui/cashWindow(꺼내기 · 넣기 · 타기 · 내리기 · 패스 탭).
               상품 번호: 달빛 패스 3720321110 · 여덟(10-20) 넣음 · 펫 · 탈것 여섯은 아직(0 → 「준비 중」). 검사 전체 498,345개 통과 · 그림판 다섯 다시 올림 · Rojo 확인.
          ✔ S164 **결제 처리 + 「달빛 상점」 창 — 2026-10-20 (사용자: "경험치 쿠폰 판매해도 됩니다. 꾸밈탈것 만들어도 됩니다. 만들어 봅시다. 그리고 대시보드에 상품신청할때 붙일 이미지도 있어야해요")** — 확인은 사용자(Play 안 함 · 커밋 안 함).
               셈: shared/lune/sim/cash.luau(acct.bm = 보관함 box · 처리한 결제 번호 rec · 주간 week/wc(한국 시각 월요일 0시) · 계정에 한 번 once · 캐릭터 칸 slots · 창고 store / grant · take · use · view · ready = 번호 있음 + built) · 가방의 확장 h.bagPaid(Bag.growPaid) · 경험치 쿠폰 h.expLeft(Hero.tick · killXp x1.5) · Account.maxChars.
               서버: server/lune/modules/cash.luau(ProcessReceipt — 결제 번호를 계정과 한 번에 저장 · 저장 실패 = 되돌리고 NotProcessedYet · 이미 준 결제 = PurchaseGranted / prompt = 한도를 본 뒤 구매 창) · world.luau onCash(view · buy · take · rename) · 유료 아이템 쓰기(onPotion) · PolicyService로 유료 아이템 경매 막기(PAID_LOCKED) · Debug("cash", n).
               화면: client/lune/ui/cashWindow.luau — 메뉴 → 「달빛 상점」(basics.js WINDOWS cash) · 탭 편의 · 재화 · 꾸밈 · 패스 · 보관함 · 「구매」 → Net "Cash" buy → CashGot 알림(Guide.banner) · 보관함 「받기」 · 「모두 받기」 · 가방 / 퀵슬롯에서 이름 바꾸기 주문서 = 이 창의 「이름 바꾸기」(arg "rename"). 공방 paint.js paintCash · ?lunedemo=cash · cash1~5 · cashsoon · cashgot · cashrename.
               설계: 공방 design/bm.js(BM · BM_SHOP(탭 · 줄 · 글 · built) · BM_RULES · bmGame → data/bm.generated.luau) · ROBLOX_IDS = 대시보드의 상품 번호(지금 모두 0 → 「준비 중」). 대시보드 이미지 tools/build_lune_bm_images.py → assetpack/lune/bm/dashboard/<상품>.png(512 x 512).
               검사: 전체 497,926개 통과(61 결제 · 62 상점 창) · 규칙 검사(글이 줄에 · 단추에 「~다」 없음 · 폰 높이 432) · ui_kit.png 다시 올림(rbxassetid://107662017170229) · Rojo로 Studio에 들어온 것 확인. 남은 것: 상품 번호(사용자) · 펫 · 순간이동 · 꾸밈 · 달빛 패스(그림 · 설계를 고르시면).
          ✔ S163 **BM(유료 상품) 설계 — 2026-10-20 (사용자 결정: 스타포스 관련 판매 안 함 · 달가루 · 달돈은 계정당 수량 제한 · 경매장 거래 가능 · 꾸밈 됨 · 월정액은 패스 느낌)** — 공방 js/lune/design/bm.js(상품 12 · 달빛 패스 · 거래 · 하지 않는 것 · 아이디어 · 넣는 차례) · 「돈 · 상점」 탭 아래 「유료 상품(BM)」 · 규칙 검사에 BM 규칙. 값 · 수량은 모두 제안 · 게임에는 아직 없음(판정 뒤 결제 처리부터).
          ✔ S162 **사다리 오르기 그림에서 머리 위 검은 ㄱ자(올린 팔)를 뺐다 — 2026-10-20 (사용자: "캐릭터위로 이상하게 뿔처럼 나오는거 검정색으로 … 저 위에 ㄱ자로 출력되는건 왜나오는거야")** — 10-17에 그린 「머리 위로 올린 한 손」(2점 굵기 막대 다섯 줄 + 가로 3점 손)이 게임에서 검은 뿔로 보였다. 공방 tools/build_lune_climb.py에서 올린 팔을 지우고 다섯 영웅의 climb 그림을 다시 그림(몸 · 번갈아 드는 발 · 어깨 옆 손은 그대로, 흰 ㄴ자 원래 뿔도 그대로) → 내보내기 → chars_3 · chars_mask_3 다시 올림 · ids 적음 · Studio에 Rojo로 들어온 것 확인. 검사: 규칙 검사 통과 · 공방 시험 탭 은달 항구 사다리에서 무니 확인. Play 안 함.
          ✔ S161 **구조의 빈 곳 메우기 — 8시간 자율 작업(2026-10-18 08:44~16:45 · 사용자: "계획세우고 반영하고 … 8시간동안 자율적으로") — 만든 것 ①~㉖ + 코드 검토 1~15차(확인은 사용자 — Play 안 함 · 커밋 안 함)** — 상용 MMORPG에 견준 점검(전투 · 아이템 · 맵 · UI 세 갈래)에서 고른 것을 차례로. #dev 맨 위 항목에 ①~㉑.
               ① 약해짐 표시(버프 줄의 buff_death · 쓰러진 상자의 줄 UILAYOUT.death.weak) ② 맵 이름(client/lune/mapName.luau · UILAYOUT.mapName — 보스 체력 칸의 자리) ③ 획득 알림(client/lune/gainLog.luau · HUD 8 「획득 알림」 · UILAYOUT.gainLog)
               ④ 레벨 업 연출(Guide.banner + Cast:levelUp) ⑤ 주민의 고르는 말(Quests.talkMenu · Talk.menu — ↓ 옮기기 · ↑ 고르기) ⑥ 4차 전직 퀘스트(JOBPLAY 4 — 외성 밖 들판 정예 창병 · 넷). 시험 탭: ?lunedemo=weak · gainlog · mapname · talkmenu · ?lunehero=번호.
               ⑦ 창고 칸 +4(acct.storeGot · Bag.growStore) ⑧ 비선공 수습 검병(combat.js passive) ⑨ 3 · 4지역 · 바다 사냥터 35장 가로 줄이기(spread_still_mobs.mjs) ⑩ 달빛 부적 · 능력치 초기화 주문서(STOCK perLv) ⑪ 되사기(Bag.buyBack) ⑫ 퀘스트 보상 달돈 → 획득 알림.
               ⑬ 사냥터 정예(combat.js FIELD_ELITE — every 30 · hp 10 · hit 1.5 · xp 10 · money 10 · loot 5 · 2지역부터): scene.elite(export) → Room.new가 졸개 목록 끝에 자리 하나(away) → Room:eliteCount → events "elite" → packets Elite → boot(높이 옮김 · Guide.banner · Cast:eliteRise). 탭 ?lunescene=r2a1&lunedemo=elite.
               ⑭ 버프 그림의 설명(ui.js BUFFTIP · Hud.tipPanel/showBuffTip · boot paintBuffs의 tip) ⑮ 단추 · ↑ 안내의 「~다」 → 이름씨(WORDS.ask · death.yes · SPOTS/STORIES act 17 · 규칙 검사 「단추 · ↑ 안내의 말」) · 퀘스트 「포기」 · 캐릭터 고르기 확인 · 삭제 · 취소.
               ⑯ 퀘스트 포기 두 번 누르기(QuestWindow.DROP_SURE · 3초) ⑰ 분해도 묻기(WORDS.ask.dismantle · gainDust · ItemDetail.ask gainWord) ⑱ 게임 설정의 「화면」(client/lune/viewOpts.luau · sound.fx · nums — 다른 사람의 스킬 효과 · 피해 숫자).
               ⑲ 경험치 줄의 설명(XPTIP · Hud.showXpTip) ⑳ 가방이 가득 참(Bag.fullTabs · 가방 단추 점 · 획득 알림 줄) ㉑ 퀵슬롯 칸의 설명(Hud.slotTipOf · showSlotTip — PC). 탭: ?lunedemo=bufftip · sound · xptip · slottip.
               ㉒ 더 좋은 장비 ▲(BagWindow.better · ItemCell opts.better · 탭 swapDiff) ㉓ 붉은 0 · 다시 쓰기 끝 반짝임(Hud.READY_T · slot.ready) ㉔ 경매장 「팔림」(World.notifySold · packets Sold · MessagingService LuneSold · Hud.marks) ㉕ 분석 FieldElite ㉖ 월드맵 파티원 점(MapWindow.partyOf · ctx.myId).
               큰 설계 셋 구체안(#dev · 탭 ?lunedemo=bag,bonusopt = 추가 옵션의 모습만) · 옛 주인 패턴 초안(bosses.js R2OLD_PLAN — 부위 파괴 · 보스기로 뒤집기) · 규칙 검사(단추의 말 · 사냥터 정예).
               검토 에이전트 둘(오후 · 오전 것): TIP 선언 순서 · 폰 톡 · 캐릭터 바꿀 때 가방 점 · 메뉴 다시 지을 때 점 · 포기 단추 글 · 창고 창 24칸(늘린 칸이 안 보임 → 스크롤 · makeCell) · 맵 이름 baseT · 고르는 말 ↓(Input.take) · Talk.start가 고르는 말을 걷음 · 부적/초기화 성공 글 · 비선공 표적 · 창고 줄지 않음(loadStore far · growStore max) · 폰 「메뉴」 점(phoneMark) → 고침. 린트 줄(정의되지 않은 이름)을 꼭 볼 것.
               검토 2차(10-14~17 것 — 에이전트 셋): 파티 버프(Party.mates에 세션 → 캐릭터 · sessionOf) · 토벌 lootRng 씨앗(장면 이름 전부 + 「#」 방은 시각) · 사다리 GRAB_LOCK 0.3(뛰어 놓은 뒤) · 튜토리얼 물약 단계(onReturn tutChanged · 들어올 때 60%) · Party.leave가 보낸 초대도 지움 · accept는 파티장의 초대만 · Hero.pack last = 쓰러졌으면 home · 쓰러지면 Talk.close · 채팅 General = 같은 맵끼리만 · rift 창 닫기 · claimAll 건너뛰기 · 출석 줄 MaxLines 1 · noPay 글 · 모험의 서 mobY 232 · 경관 = 막이 걷힌 뒤(afterLift) · 폰 「둘러보기」 · 기술이 사다리를 놓음 · Warp가 사다리를 놓음 · moveTo/World.jump가 되살림 · 소생 레벨 차이(REVIVE_GAP). 마을 건물 안의 귀환 주문서는 10-16에 정한 대로 둠(검토의 제안을 되돌림 — 검사 13).
               검토 3차: navi에 { id, kind, x, y }(m.info) · stick.mobId · cineWorld boss y · Market.WORDS.soldNote(sold 「판매 완료」를 덮었던 것) · AttendNew → fetchDaily · 경매 탭 바꿈 뒤 이어 받기 · 스킬 초기화 뒤 slots 받기 · 찬스 타임의 파괴 방지 없음(items.js · items.luau) · 되살리기 재료 = 가방의 것(inGear) · forgeWhy 지움 · 제작 · 일일 0.8초 · 창 닫는 거리 60/40 · quickEdit 손가락 · 공짜 첫 별 ≤ 레벨+10.
               검토 4차(계정 · 저장 · 이동): store.read → (ok, 값, failed) · loadAccount/loadOld의 failed → 들어오기에서 LOAD_KICK(스튜디오만 오프라인) · saveAccount 실패 = 다시 dirty · removePlayer leaving[uid] · onChars charsBusy · onReady 잠금 기다림 ≤40초 · World.stop pcall
                 onMove: 이동 몫 MOVE_RATE 300 · MOVE_CAP 180(World.now와 os.clock 가운데 긴 시간으로 채움) · 맵 옮긴 첫 보고 JUMP_SLACK 360 · 시작 자리 받기 = holeNear(바닥이 뚫린 칸 곁) · warpAt = Caster.MOVERS(g.move · g.teleport — 재 볼 때 알아 둠) · hero.warpMark → 한 번만 · s.trust(검사만 세움 — 테스트의 jumped를 바꿈)
                 전직 차례(Q.state: 앞 차수의 전직 퀘스트를 끝내야 · Hero.questDone이 job+1만) · 퀘스트 물건 창고 불가(Bag.NO_STORE · 가방 창 · 탭) · 늦은 판정 pcall · cur.hero == hero · 저장 세기를 틱 앞으로 · 장면 on = Cine.known · 처음 · 기술 쓰면 inCine 끔
               검토 5차(요청 31개 · 전투): skillPlace(기술 요청의 자리 = 이동 몫 · 받지 않으면 되돌림) · UP_RATE 240 / UP_CAP 160(위로 가는 몫) · 1차 next = prevTime − 0.15 · start = 앞 동작의 끝(쌓이지 않게) · caster TILL_GAP 0.6(till 구간 스킬 — 도약)
                 leaveWorld s.keep[cid](체력 · cds · 물약 대기 — KEEP_TIME 600) · Hero.shiftClock(place — kit.at · actUntil · pass의 streakAt/pressAt/surge/rekindle/venom) · room.matesOf(독 · 소환 · 장판 → World.matesIn) · 초기화 busy · 1차 뒤 구간도 caster:busy
                 Caster:strike 쓰러짐 · gainXp 쓰러짐이면 체력 그대로 · 이름 확인 NAME_BURST 5 / NAME_GAP 3 · 경매 새로 고침 10초 · onRank pushRank 30초 · Cine.fits(맵 · 퀘스트) + 틀면 h.cine. 검사 13 「서버 검토 5차」 · 21 도약 · 26 risky −1.
               검토 6차(화면): Input.flush(막 걷힘 · Revive · Raise · 장면 끝) · adopt가 cineSeen/cineQueue/cineScene · weakLeft · TutView.reset · 메뉴 점 · playCine 전 skill/push 멈춤 · MapName 막힘 = BossView.box.Visible · enterScene에서 setBuffs/haste
                 Warp가 push · skill.imp 멈춤 · 쓰러지면 climb/push nil · 폰 메뉴에 menu 창(keys 빼고) · PC 메뉴 중복 뺌 · closeMenus(장면 · 대화 · 캐릭터 선택) + 장면이면 창 닫기 · PartyHud.ask(nil) · Ready 30번 + 알림
                 achieve/tome/rift 기다림 표시 · touch onResize가 누름을 놓음 · hall failed + 다시 묻기 · Stage.onResize가 빼는 함수를 돌려줌(title) · stat/hud 설명의 자리 = Stage.ui 기준. 검사 57 ⑰.
               검토 7 · 8차(시험 탭 ↔ 게임): Items.firstFree(서버 Bag.enhance · 대장간 창 같은 셈) · 탭: etc_paper → mat_ore1 + iconOf 지킴 · firstFree · 낀 장비 부서지면 가방으로 · 부서진 것 장착 불가 · 되살릴 재료는 가방의 것만 · 분해 달가루 · 정렬 부서진 것 끝 · specNow(전투력 · 장착 비교 · ▲ 같은 셈)
                 탭: // 주석이 삼킨 코드 넷(간이 포탈 ↑ · 데모 스위치) · 정예(가장 많은 몬스터 · MONSTERS.plan 이름 · FIELD_ELITE.hit) · mobKind(비선공) · 맵 이름(보스 칸 · 막히면 끝) · 상점 shortNum · 퀘스트 달돈 알림
                 게임: slotTipOf(스킬 창 열림이면 nil · 효과 줄 중복 없앰) · Gain money/dust(일일 · 토벌) · eliteRng 씨앗(keySeed + 시각) · 경관 act 「둘러보기」 + 규칙 검사(scene.json vista.act). 물음: 보스 방 물약 대기 5초(설계) vs 1초(게임).
               검토 9차(퀘스트의 말 ↔ 자료): questplay r2s10 하늬 해요체 · r2m4 발자국 · r2m5 글귀 = world.js · job3 첫 말 · job4 정예 창병 / city cq01 촌장 편지 · 포구 → 나루 · cq03 자기소개 뺌 · cq15 장터 거리 · cq23 초소 / cine 1편 끝 카드 · 바람 첫 말 / world r2m1 글.
               검토 10차(보스 방): Room:stepPresence(서 있는 보스 = 쓰러지는 중이거나 필요한 사람이 있으면 그대로 · 없으면 이야기 차례) · Room:forget(떠날 때 그 사람의 laters — place · leaveWorld · removePlayer) · 보스가 dead/gone이면 waves 거둠 · 졸개 x를 구간 안으로. 검사 33에 둘 · 57 ⑲.
               검토 11차(파티): Room:liveMates(맞는 순간 방에 살아 있는 파티원 — strike · caster heal) · Party.leave → (남은 사람, 흩어짐, 초대가 지워진 사람) · world partyLeave(PartyAsk from=false) · removePlayer는 저장 전에 파티에서 뺌 · 토벌 끌어가기 = 인사 · alive · not inCine. 물음: 지원 기술의 레벨 차이.
               검토 12차(저장): unpackStacks 넘친 수를 맞춰 빈 칸에 · unpackItem 별 = 상한 · Bag.unpack가 뒤 칸만큼 bagGrow · Hero.unpack 레벨 min(MAX) · 없어진 스킬만 빼고 · 퀵슬롯 salvage · cleanKeys(lenient) · cine/achieve 숫자 열쇠 · Account.unpack pcall → cannotRead · World.stop 한꺼번에(stopping — 순위판 건너뜀) · Store.saveAccount saveSeq(옛 다시 쓰기 그만).
               검토 13차(몬스터): mobsView rgbOf가 「#rrggbb」 글도(정예 겉모습 — 검게 나왔다) · 맞은 뒤 쫓기가 Buffs.stealth를 본다(연막탄). 검사 24에 정예 색.
               검토 14차(경매장): marketFinish가 사본에 없어도 txClose(장부의 none이 맞는 답 · 있었으면 entry = true → txSettle) · marketDoc는 읽는 사이 더 새 사본이 들어오면 덮지 않음 · Store.saveAccount stale = 실패로 · MARKET_WAIT 120 · canForce(둘러보기 · 내 목록 · 사기 다시 읽기 10초). 남음: 사기 중 꺼짐 · 장부 100줄 · 수수료 내림.
               검토 15차(폰 무게): Who 받을 때 떠난 사람의 Cast:drop · pixelText SetMaxWidth 같은 값이면 건너뜀 · Sprite:set 같은 장 · 자리면 건너뜀(보이기만 맞춤) · gainLog 글자 목록을 글이 바뀔 때 모으고 흐림이 바뀔 때만 씀 · mapName.fade도 보이는 정도가 바뀔 때만(lastA) · effectOf 기억(effectMemo) · 퀘스트 화살표 셈 1초에 10번(naviAt) · Hud.setBuffs 그림이 같으면 글만(buffShape). 다음 할 일(#dev): 피해 숫자/소리 재사용 · 캔버스 그린 곳만 · 길찾기 횟수 · 획득 알림 글자 훑기 · 퀘스트 알리미 통째 다시 짓기 · 버프 칸.
               새 검사: 58 HUD(가짜 Stage/Ui — mock.luau의 Instance.new에 사건 신호 · CREATED) · 59 대화창 · 60 맵 이름(옛 코드에서 실패함을 확인) · 49에 늘린 창고 · 28에 월드맵 파티원 · 41에 「팔림」. 공방 devTab: 확인 요청 글의 **굵게**를 굵은 글로.
               보스: 그림자 사수 후보 A1~A3(bossdesign/r2 — BOSS20_1 · 2) · 부단장 분홍(BOSS20_3) · 옛 주인 ④(BOSS23) — 10-16의 후보판(BOSS21 · 22)을 확인하지 않고 더 뽑은 것(#dev에 밝힘) · 차례 제안.
               손대지 않은 것(까닭): 숨은 포탈(사용자 10-10 「문은 한 그림」) · 귀환 주문서 20%(사용자 10-14) · 장신구 드롭(설계상 옛 주인 보스에게서만 — 물음으로) · 몬스터의 발판 이동(메이플도 제 발판 — 10-08에 알림). 테스트 57(새로) · 15 · 34 · 35 고침.
          ✔ S160 **사다리 오르기 그림 다시(2026-10-17 · 사용자: "사다리올라가는거 정신병있냐? 누가 이따위로만들어")** — 첫 그림(키 34점 네모 몸 · 긴 팔 둘)이 팩 영웅과 다른 생물이었다.
               tools/build_lune_climb.py를 새로: BODY = 영웅마다 대기 그림에서 옮긴 뒷모습 틀(폭 · 키 · 뿔 · 발 · 색 그대로, 얼굴만 뺌) · 올린 팔 = 두 기둥 사이(8 · 11열 — 기둥 옆이면 같은 색이라 안 보였다) · 내린 손 = 어깨 옆 · 반대 발 듦 · 등의 무기.
               4칸 = 왼손 위 둘 · 오른손 위 둘(fps 8). 공방 탭에 ?lunehero=번호(화면 확인용). 올림 chars_2 · 3 · mask_2 · 3. 검사 전체 490,420개 통과. 사진의 검은 막대 = 살라맨더의 열기 게이지.
          ✔ S159 **반달 나루를 뺐다(2026-10-16 밤 · 사용자: "성지에서 바로 사냥터인데 반달나루가 굳이 필요해?" → 고름 「빼고, 사람은 은달 항구로」)**
               길: ct 큰 성문 127.6 → r2a1(이름 「나루 뒷길」 → 「성문 밖 숲길」 · 왼쪽 문 → ct). r2t = maps.js SHELVED_MAPS(짓지도 내보내지도 않음 — 파일 · 그림은 그대로) · GONE { r2t: 'ct' } → scenes.gone(로그인 때 hero.last · home을 옮긴다).
               사람: squire 113 · woodcutter 105.8(성문 앞) · beodeul 28.8(부두 — 「늙은 사공」, 내가 정한 구실) · dahong = ct_spice만. city.js CITY_ALSO = 'r2' → 장면의 also(ct · 방 20곳) → Quests.givesIn(atNpc · mark · npcScene · 서버 onQuest).
               퀘스트: r2m1 「수정 숲으로」 · cq03 「성문 앞의 견습 기사」(말 전하기) · cq24 「성문 밖의 저녁」(region false) · 새는 나룻배 · 반달의 고향 집 · cq09 · cq13의 글. HUB.r2 = ct · SCENE_NOW ct. st_ferry → ct 123.6 「성문 탑의 머릿돌」(area city) · 달조각 r21 → r2a4 40.5/7.
               설계: world.js r2 town = ct 「은달 항구」 · story.js 2편 hub · continents(도시 → 수정 숲 = walk · 나룻배 탈것 뺌) · journey(r2t 마디 · 길 · HOMES · WORLDART). 월드맵 r2: Codex가 나루 마을 → 도시의 동쪽 성문(prompt_r2b.txt · 옛 그림 raw_r2_v1_ferry.png) — 올림 worldmap_r2 · props_r2c1.
               검사: 규칙 검사(성문 ↔ r2a1 · r2t가 남지 않았다) · 게임 전체 490,514개 통과(테스트 13 · 17 · 28 · 31 · 54) · 스튜디오 동기화 확인. Play 안 함.
          ✔ S158 **큰 성문 · 2지역 사냥터 줄이기 · 나갔던 곳에서 시작(2026-10-16 밤 · 사용자: "성문같은 그림이 훨씬 크게 느껴져야합니다" · "반달나루 부터 … 사냥터들도 다 가로로 너무긴데" · "게임을 시작하면 항상 초승달마을에서 시작합니다")**
               성문: looks/raw_city6_kit.png → bigate 230x162(build_lune_look2 — harbor 한 장은 폭 512로) · ct 127.6(포탈 r2t를 그 아치 안 · art false) · 향신료 가게 101.6 · 성문 초소 110 · 마루 119.6 · 긴 사다리 116.
               사냥터: tools/shrink_lune_maps.mjs(가로 비율로 땅 · 발판 · 소품 · 몬스터 · 문 · 사람 · 스폰과 questplay/city.js의 tx · 달조각을 옮김 — 문은 끝에서의 거리를 지킨다) → tools/fix_lune_mobs.mjs(딛는 땅 · 발판 · 문 곁 3.6칸 · 겹침).
                 r2a1 30 · r2a2 34 · r2a3 32 · r2a4 42 · r2b1 32 · r2b2 34(봉오리 10 — monsterPlace · 테스트 23) · r2b3 32 · r2b4 40 · r2c1 32 · r2c2 32 · r2af · r2bl · r2cl 30. tools/print_lune_map.mjs = 글자 그림. 바닥 그림 13장 올림.
               시작: hero.last(place()가 적는다 · Hero.pack/unpack) · world resumeScene — 갑판 = 닿는 곳(voyageLanding) · rf#번호 · bosses · 꿈 = ret · 없는 장면 = home · 옛 저장 = home. 테스트 31(다시 들어오기 여섯) · 13(첫 퀘스트 뒤 = 사당 안).
          ✔ S157 **사다리 오르기 동작 · 경관 화면 가득(2026-10-16 밤 · 사용자: "사다리 올라가는 모션 만들어서 적용해줘" · "테라스 뷰 보여주는거 잘려서나온다")** — 팩에 오르기가 없어 tools/build_lune_climb.py가 다섯 영웅마다 4장(등 · 팔다리 번갈아 · 무기 색 그대로)을 그려 chars/<영웅>_climb.png · chars.json clips.climb(build_lune_demo가 다시 돌려도 남긴다).
               게임: physics.clipOf = "climb" · boot은 사다리 위에서 ↑ · ↓를 안 누르면 장을 멈춘다 · othersView(사다리 위면 climb — Others.new(…, scene.ladders)) · chars 판 둘 · 그늘판 둘 올림. 탭: clip climb · 멈춤 · ?lunedemo=climb · climb1~3.
               경관: vistaView를 기준 격자(960x540) 대신 Stage.ui 전체(fromScale 1)에 — 화면 꼴에 따라 잘리던 것 · 이름은 아래 가운데 틀(AnchorPoint). 검사: 10(오르기 네 장) · 전체 실패 0 · Studio 동기화.
          ✔ S156 **은달 항구 2차 — 모든 건물의 실내 · 큰 성과 경관 · 사다리 · 성문 → 반달 나루 · 배와 비행선 · 모든 지역의 월드맵(2026-10-16 밤)** — 사용자가 고른 것: 성문 → 반달 나루 → 사냥터 · 배 · 비행선 모두 탈것 · 모든 건물 · 모든 지역.
               길: maps.js ct 성문 [109.4 r2t] 하나만 걸어서 나간다 · r2t 서쪽 [2.6 ct 「은달 항구로」] · seat · port의 ct 포탈 뺌 · ferryman(노을)을 ct 부두 34.6 · seat 14.4로 · skyhand(나래) port 9.4 row 9.
               탈것: city.js VOYAGE = routes 배열(id · from · npc · kind ship/airship · ship · to · at · dest · need · lines · locked) + deck(갑판의 말) · sim/voyage.luau(route(scene, npc) · routesFrom · isCrew · onShip · open(book, r)) · world onSail(player, npcId) · packets Sail(t.string) · boot sailTalk(r.lines) · navi/worldmap/quests.opens가 routes를 돈다.
                 갑판: build_lune_cityrooms가 탈것마다(ship_out · ship_home · ship_sea_out · ship_sea_home · air_out · air_home) — 비행선 = raw_airship_deck.png + cloudStrip(발밑 구름 d -70) + 먼 산(rock d -8). music.js air_ = 항구의 곡(제 선택).
               실내: CITYROOMS 열넷 더함(ct_harbor · ct_inn · ct_fisher · ct_stable · ct_spice · ct_guardpost · ct_musician · ct_flower · ct_oldhouse · ct_scribe · ct_maid · ct_castle(doors → ct_terrace) · ct_terrace(out ct_castle · vista) · ct_tower) — 그림 city/indoor/raw_<방>.png(make_prompts_round2.py).
                 사람: dolsoe · nurung · cityhost · galmae · galgi · dahong · hangyeol · saebyeok · solgae를 방 안으로(FOLK where · people.js) · guildclerk 2층 79.4. 이야기 st_dock · st_manor · st_tower를 방 안으로 · st_oldhouse(새 — 제 것) · 달조각 넷을 빈 집으로 · manorwall 101.6.
               성: looks/raw_city5_kit.png → castle 221x159(harbor 소품) · ct 3층 96(관저 · 깃발 · 가로등 뺌). 경관: raw_vista_city.png → vistaPicture(16단 + 민트 · 분홍) → maps/ct_terrace/vista.png · scene.vista { img, title, sub, x, act } → export vista_ct_terrace.png · client vistaView.luau(FADE 0.7 · HOLD 3.2 · 0.9 · HUD 위) · boot 들어설 때 · ↑ 가운데 · 탭 같은 셈(?lunedemo=vista).
               사다리: maps.js ladders [칸, 위 줄, 아래 줄] → build_lune_maps(딛는 자리 확인 · maps/ladder.png 16x16을 그린다) → scene.ladders · ladderImg → export → physics(ladderAt · climb — CLIMB 80 · GRAB 7 · ↑ 잡기 · 꼭대기 ↓ 잡기(뛰기 없이) · 뛰기 놓기 · 기술 · 대쉬면 놓기 · clipOf idle) · boot input.up · sceneView 16점 조각을 쌓아 그린다 · 탭 climbStep. ct에 셋(57 · 71.2 · 115.4).
               월드맵: worldmap/make_prompts_regions.py → raw_city · r2 · sea · r3 · r4 → build_lune_worldmap → journey.js WORLDART(그림을 보고 적은 자리 · out) · export(좌표 1 넘으면 붙임) · worldmap.luau peopleLine(사람 9 + 외 n명) · 이름 둘 줄임(분화구 — 기슭 · 비탈 · 가장자리 / 봉인의 회랑 — 계단 · 쐐기의 방).
               대사: 강 위의 나루(성문) · 다홍의 짐(성문 옆 향신료 가게) · 편지(갈매의 집) · 노래(서기의 방) · 누룽(여관 부엌) · 새벽(성의 하녀 · 성의 등불 기름 · 성 담장) 고침.
               검사: 규칙(탈것 · 사다리 · 방의 사람 · 방 안의 ↑ 자리 · 월드맵의 지역 WORLDMAP_MORE) · 테스트 10(사다리) · 54(탈것 여섯 · 방 열여덟 · 성 ↔ 테라스 · 경관) · 13 · 28 · 38 고침 · 전체 실패 0 · Studio 동기화 · 그림 30장 올림. 보지 못한 것: Play(사다리 · 경관 · 탈것) · 폰.
          ✔ S155 **귀환 주문서 = 가장 가까운 마을(2026-10-16 · 사용자: "마을귀환 주문서라는게 가장가까운 마을로 이동하는 귀환주문서지 초승달마을로 고정 귀환하는 주문서가 아닙니다")** — 전에는 늘 SCENES.start(초승달 마을).
               export: 장면마다 ret = 문을 가장 적게 지나 닿는 HOMES의 마을(같으면 HOMES의 앞) · 마을 자신 · 꿈 · 배의 갑판 = false. journey.js HOMES에 seat(물마루 마을) 더함(아랫마을 광장 r4a4는 몬스터가 있어 뺌 — 4지역의 맵은 등불 포구로) · 검사의 마을 목록에 continents.js의 마을.
               서버 onPotion(scroll): 이미 마을 · 배 위(「배 위에서는 쓸 수 없다」) · ret 없음(「여기서는 쓸 수 없다」) → World.jump(ret). items.js RETURNSCROLL 글 「가장 가까운 마을로」. 배 시간 60 → 10초(사용자 "배타는 시간 더 짧게 10초정도").
               검사: 13(맵마다 가는 마을 · 토벌의 방 · 배 · 꿈 · 모든 장면에 ret) · 전체 실패 0. Studio는 Play 중이라 동기화를 보지 못함.
          ✔ S154 **은달 항구 다시 짓기 — 한 장 · 배 · 만나면 열림(2026-10-16 저녁 · 사용자: "대도시에 쓸데없이 포탈만 이리저리로 복잡하게 … 호감도는 왜만드는거고 … 왜 그냥 포탈이에요")** — 고른 것: 한 장의 큰 도시 · 배 위에서 시간을 보낸다 · 호감도를 빼고 만나면 열림.
               도시: maps.js ct 한 장(136x34 · look harbor = city + port 소품 합침 · 1층 row 30 거리 · 2층 thin 40~98 row 22 광장 · 3층 thin 70~132 row 14 관저 · 소품 · 사람 · 문에 row). ct1~ct6 지움(디스크의 maps/ct1~6 폴더는 남김 — 지우지 않음).
                 문: 방 다섯(ct_store 41 · ct_smith 61 · ct_storage 75 row 30 / ct_auction 45.6 · ct_office 76 row 22) + 도시 밖 셋(r2t 2.6 · seat 34 · port 120). 숨은 이야기 · 달조각 · 퀘스트 자리에 row(questplay tileSpot · city.js groundY).
               방: tools/build_lune_cityrooms.mjs(Codex raw_ct_*.png → 한 화면 · 문 26 → ct) · city.js CITYROOMS. 배: raw_ship_deck.png(바깥 투명 · deckLine) → maps/ship_out · ship_home(layers 하늘 · 먼 바닷가 d -14 · 물결 sea.png d -40 · 배 · flags ship rest · 선장 · 문 없음).
               배: city.js VOYAGE(time 10 — 처음 60 → 사용자 "배타는 시간 더 짧게 10초정도" · captain · need r1m9 · routes town → ship_out → ct(at 19,30) · ct → ship_home → town) → city.generated.voyage · sim/voyage.luau(route · onShip · open · leftText).
                 서버 world: onSail(선장 앞 · open · moveTo 갑판 · s.voyage · Voyage 이벤트) · tick이 때가 되면 내림(voyageLanding — at 또는 선장 왼쪽) · place()가 배 밖이면 s.voyage를 지움. packets Sail · Voyage.
                 화면: boot state.sailTalk(선장 → 「탑승」) · voyageView(위 가운데 「○○까지 n초」 — riftHud 자리) · sceneView 레이어 d(흘러감). town.js harbor = 선장(포탈 없음). 사람 captain 너울(raw_people12).
                 길: navi path에 배 한 걸음 · aim = 선장(갑판이면 here) · worldmap hopsOf(문 + 배 — nodeOf · exits · path) · ROWS_MAX 5 · info 주민 10명 + 외 n명 · Quests.opens(r1m9) = 「선장 — 은달 항구로 가는 배」.
               만나면 열림: city.js MEET(citysmith · citykeeper · auctioneer · clerk · warden — opens · lines) · bond.luau 새로(met · shard · story · kill · tome · open — 호감도 · 선물 뺌, 예전 저장의 pts 버림).
                 서버: nearNpc가 Bond.opened를 봄(제작 · 창고 · 경매사 말) · onDaily · onRift = 「먼저 인사를 나눠야 한다」 · onBond meet(→ Quests.onMeet) · 받을 때 이미 만난 사람 onMeet. cq02 할 일 meet x5(questplay stepOf meet).
                 화면: boot openNpc가 처음이면 인사(Talk, 제목 = 구실, 단추 「인사」) → Bond meet → 알림 → 그 창. 지움: rapportWindow · paintRapport · UILAYOUT.rapport · layout L.RAPPORT · 선물 넷 · 업적 friend.
               공방: luneTab(호감도 뺌 · MEET 인사 · 선장 「탑승」 → 갑판 → VOYAGE.time 뒤 내림 · paintVoyageHud · 레이어 d · ?lunedemo=meet · meetwarden · voyage · voyageend) · 검사 규칙(도시 한 장 · 1지역 → 도시 문 없음 · 선장 · 갑판 · MEET · 호감도가 남지 않음 · 방에 선 사람 · 층이 다르면 겹치지 않음).
               검사: 54 새로(만나면 열림 · 배의 흐름 — 364) · 55(의뢰소 · 인사 · 도시 대장장이) · 56 · 10(갑판) · 17 · 18 · 27 · 28 · 38 고침 · 전체 실패 0 · Studio 동기화 · 그림 16장 올림.
               보지 못한 것: Play · 시험 탭에서 배가 닿는 순간(헤드리스는 시간이 안 흐름). 물은 것(devplan ask): 발판 밑을 벽으로 채울지 · 들어올 때 마지막 마을에서 시작할지(지금은 늘 초승달 마을 — 2편도 매번 배).
          ✔ S153 **글 맞춤 · 퍼널 · 옛 주인 후보(2026-10-16)** — 사이드 퀘스트 넷 · 메인 「검은 수정」의 설명을 할 일과 주는 사람에 맞춤(PLAY2의 text) · analytics Part2Quest 퍼널(LINE2 열둘 — 테스트 50) ·
               옛 주인 후보: bossdesign/r2 raw_r2_T1~T3(천년 수정목) · Z1~Z3(달자라) → board2.py → dev/BOSS22 · devplan ask(넣을지 · 고를지). 게임은 그대로.
               후보 열둘을 게임 크기로(키 85점 · 13색 · 주인공과 3배): bossdesign/r2/scale_board.py → dev/BOSS23. 마지막 전체 검사 469,592 · 실패 0 · Studio 동기화 확인.
          ✔ S152 **확인 보강(2026-10-16)** — 테스트 56(2편의 퀘스트 모두를 받기 → 할 일 → 보상까지 셈으로 · 302) · 테스트 55에 화면 코드(토벌 창 · 위의 판 · 끝의 판)를 그리지 않고 돌림 · worldmap.nodeOf 캐시 = 바탕 장면.
               보스 패턴 초안 bosses.js R2BOSS_PLAN(그림자 사수 7 · 부단장 7 — 「물러서기」만 새 셈) · devplan: 레벨 곡선 물음(30→60 사냥만 약 1만 9천 마리 · 퀘스트가 약 34%).
          ✔ S151 **장터 거리의 대장장이 담금 · 창고지기 한아름(2026-10-16)** — 도시에 대장장이 · 창고지기가 없었다(바람의 말과 어긋남). people.js citysmith · citykeeper(Codex raw_people11 — 첫 그림 정면이라 다시 · 눈 fix) · maps ct3 18.8 · 38.2 · NPCDO smith/store · ROLE_NPC
               게임: ForgeWindow.title = 연 대장장이(boot openNpc가 ForgeWindow.opener를 적음 · windows.luau title nil → 이름) · 창고 제목은 「창고」 그대로. villagers.png 올림(123222851711135). 테스트 55에 도시 대장장이 제작.
          ✔ S150 **2편 제작 재료 · 장비 · 보스 후보(2026-10-16 · 자리 비움 동안)** — 빈 곳: 제작 재료 · 대장장이 제작이 Lv.29에서 끝나 있었다.
               items.js MATS mat_ore4~6(수정 · 흑수정 · 월은 광석) · mat_hide4~6(이끼 · 여우 털 · 비늘 가죽 — Lv.30 · 40 · 50대 15%) · CRAFT.need 30/40/50(한 벌 153~187마리) — 이름 · 숫자 내 것
               아이콘 Codex raw_etc_9.png → etc_sheets.json · build_lune_icons · build_lune_ui → ui_kit.png 올림(127701484464218). 제작 탭이 여섯이 되어 UILAYOUT.craft.note를 비우고 hint에 합침(아래 줄)
               테스트 15 고침(재료 Lv.30대 2 · Lv.60 0 · 제작법 30 · 아래 줄 폭). 안내인 바람의 「항구의 첫날」 끝 말에 토벌대장 소개 두 줄. naviMesh 캐시 = 바탕 장면(rf1#3 → rf1)
               보스 후보(게임은 그대로): bossdesign/r2 — 그림자 사수 S1 검은 수정 순찰자 · S2 뿔 풍뎅이 사수 · S3 그림자 허수아비 / 타락한 부단장 C3 망령 대장(10-15에 살려 둔 것) · K2 수정에 묶인 기사 · K3 잿빛 심문관 → dev/BOSS21 · devplan ask
          ✔ S149 **수정 틈 토벌 — 반복 던전 · 2편 업적(2026-10-16 · 같은 자리 비움 동안 · 10-15 「반복 콘텐츠는 대도시 이후」)** — 로스트아크 카오스 던전 · 메이플 몬스터파크 참고. 모두 내 제안(devplan ask).
               공방: design/city.js RIFT · riftWaves · riftPay · riftGame(단계 rf1 Lv.30 r2a1 · rf2 Lv.40 r2b1 · rf3 Lv.50 r2c1 · 물결 셋 + 정예 둘(체력 6배 · 힘 1.5배 · 분홍 look) · 하루 2번 · 5분 · 완료 30초 뒤 광장)
               토벌대장 무진(warden — Codex raw_people10.png · 눈 고침 fix) = 역할 주민(NPCDO rift) · ct2 57 · basics WINDOWS rift · ui.js UILAYOUT rift/riftHud/riftEnd · paint.js paintRift/paintRiftHud/paintRiftEnd
               시험 탭: SCENES에 rf1~3(바탕 맵의 그림) · ?lunedemo=rift · riftrun · riftelite · riftend · 토벌대장 ↑ → 창 → 입장. music.js rf* = dark
               export: scenes.generated에 rf1~3(바탕 장면을 빌림 · 문 하나 → ct2 · warps 없음 · mobs에 wave/elite) + scenes 메타테이블(rf1#3 → rf1) · city.generated.rift
               게임: sim/rift.luau(기록 h.rift · 방의 셈 start/step/view/due · rollGear) · room.luau(wave/elite · 다시 안 나옴 · 정예 체력/힘) · hero pack/unpack ·
               world.luau(onRift view/enter — 토벌대장 앞 · 레벨 · rf<n>#번호 방 · 같은 맵 파티원 · tick: RiftView 알림 · 완료 보상 riftPay · due → 토벌대장 앞 · 빈 방 닫음 · 문으로 나오면 토벌대장 앞 · World.hasRoom)
               packets Rift · RiftView · RiftPay · client ui/riftWindow · riftView(위의 판 · 끝의 판) · mobsView 정예 look · music 방 이름 #번호 · 업적 count rift/shard/story/friend(+7개)
               확인: 규칙 검사(토벌 규칙 더함) · 테스트 55(657) · 전체(23 · 48은 rift 장면을 빼도록 고침) · villagers.png 올림(126819372033542) · Studio 동기화. Play로는 보지 않음.
          ✔ S148 **2편(Lv.30~59) — 은달 항구 · 사람 · 호감도 · 흩어진 퀘스트 · 모험의 서(2026-10-16 · 사용자: "30~ 60 구간을 제작 … 대도시로 진입해서 사람들과 커넥션 … 로스트아크로 치면 베른 북부 첫 진입 … 퀘스트는 필수 진행이 아니라, 여기저기 흩어져있고" · 8시간 자리 비움)** —
               설계: 공방 design/city.js(CITYLIFE.study · RAPPORT · GIFTS · FOLK 13 + FOLK_OLD(하늬) · CITYQUESTS cq01~cq25 · CITY_SPOTS · STORIES 7 · SHARDS 25 · TOME · cityGame()) → export city.generated.luau.
               사람 그림: Codex raw_people6~9.png → build_lune_people.mjs(villagers_all.png를 32칸마다 접음 — npcCols; 게임 sceneView · cineView · 탭 cellX/cellY). 아이콘 raw_etc_7 · 8(퀘스트 물건 10 · 선물 4 · shard_moon). 올림: villagers.png · ui_kit.png.
               퀘스트: questplay.js — cityQuest(cq · region false = 도시 · cq01만 r1) · QUESTS 차례 r1 → 도시 → r2~ · SCATTER ['r2'](부탁끼리 앞뒤 없음) · 새 할 일 visit(at — Quests.onVisit · world place()) · rapport(Quests.setStages · stageOf — 서버는 함수, 화면은 표) · reward.gifts · play.text ·
               npcScene이 지역에 없으면 어디서든 · PLAY2 메인 7~9(보스 대신: 검은 결정 20 + 아치(ridgearch) · 향로 20 · 제단(pyre)) · job3(종탑 종지기 · 달빛 서린 종 조각 4 — 그림 fragment) · 탐색 tileSpot(아래에서 찾은 땅).
               게임: sim/bond.luau(호감도 · 선물 · 단계 보상 · 달조각 touchShard · 숨은 이야기 read · 몬스터 onKill · 모험의 서 area/claimTome · view/pack/unpack · h.bond 캐릭터마다) · gift.luau(items) · hero(bond 저장 · questDone 선물 · open tome · Bond.questDone) ·
               world(onBond "view · talk · gift · claim · read · tome" · BondView(shard · quest · open) · onMove의 달조각 · place의 onVisit · 처치 Bond.onKill · describe.bond) · packets Bond · BondView · client ui/rapportWindow · tomeWindow · boot(state.bond · setBond · bondTalk · 대화 끝 「↑ 호감도」 ·
               숨은 이야기 = 자리(drawSpots) · 달조각 그림(drawShards) · 메뉴(menu 창 — 출석 · 업적도 이제 뜬다) · 메뉴 점) · 일일 의뢰 지역마다(daily.js boards.r2 = ct2 clerk from 33 · Daily.regionAt · dailyWindow arg) · 선물 = RARE(from 30).
               장면: cine.js c2_arrive(cq01 · ct5 들어올 때) · c2_end(r2m9 끝). 공방 탭: paint.js paintRapport · paintTome · luneTab BOND_DEMO(?lunedemo=rapport · rapport2 · tome · tome2 · 도시 사람 말 → 호감도 · 달조각 줍기 · 숨은 이야기).
               검사: 54(새) · 15 · 17 · 18 · 27 · 28 · 38 고침 · 설계 규칙(2편 블록 · 일일 게시판 · 도시 퀘스트는 지역 줄 밖). 보지 못한 것: Play · 폰. 물은 것: 계정 공유 여부 · 사람 · 이야기 · 선물 가게 · 2편 보스 · 다음 반복 콘텐츠 · 3차 전직 자리.
          ✔ S147 **강화 · 대장장이 · 스펙 다시 짬(2026-10-15 · 사용자: "강화 섹션이 문제가 많습니다 … 데미지가 어떤 계산식으로 적용되는지 지금 개판이에요 싹다 다시 확인하세요")** —
               스펙: 공방 numbers.js 2-1 `SPEC`(스탯 공격력 = (주 x4 + 부) x 공격력 x (1+공%) /100 x (1+데미지%) x (1+최종%) · 한 타 = 스탯 공격력 x 스킬% x 0.9~1.1 x 맞는 상대 1.5 x 크리 · 전투력 = 버프 뺀 스탯 공격력 x 크리 기댓값 ·
               받는 피해 감소 = 60 x D / (D + 4 x armorDef(몹Lv))) · 무기 공격력 20 + 1.5L · 방어구 올스탯 3 + L/2 · 방어력 5 + L · 장신구 올스탯 절반 · 성능 -10/-5/0/+5/+10% · 별 % 4/9(무기) · 6/12(방어구) · 모두 22성(STARCAP 하나) ·
               정수 0 · 달가루 적어도 1 · `COMBAT.rules.dmgScale` 10 → 1 · 몬스터 체력 = 7.5 x refAttack(L) x ease(옛 값은 mobHpOld · 보스 설계의 LOADOUTS는 옛 powerOf — unitHp · unitPow로 바꿔 씀).
               게임: config/numbers(weaponAtk · armorStat · armorDef · starPct · statAtk · refAttack · cutOf) · sim/items(options · sum · cut · transfer 뺌) · sim/hero(spec · attackBase · power · specView · sheet) · sim/passives(atkPct · finalMul) ·
               ui/itemInfo(specOf · refSpec · wearDiff · optText · 이름에 +n 없음 · stars) · ui/starText · Ui.stars · itemDetail(별이 맨 위) · itemCell(★N) · equipWindow(Lv.N ★N) · auctionView(★N 공격력 x) · statWindow · sheet.
               대장장이: client/lune/ui/forgeWindow.luau 새로(탭 제작 · 강화 · 제작 그림 → ItemDetail · 고를 칸 = 장착 중 먼저 · ui.forgeDrop(가방에서 끌어다) · 연출 STRIKES 0.05/0.4/0.75 · REVEAL 1.05 · END 1.9 · BindToRenderStep · 칸 = 건너뛰기 ·
               되살리기 · RESULT.restore) · shopWindow의 대장장이 상점 · buildCraft 뺌 · 달가루 = 잡화 상인 · 대장장이는 사지 않음 · Bag.transfer 뺌.
               공방(시험 탭이 본보기): items.js 4-4(enhanceInfo · enhanceRoll · forgeLines · forgeGain · forgeChoices · craftInfo · FORGEWORDS · aucSub) · paint.js paintForge · paintForgeAfter(연출) · 옛 paintCraft 지움 ·
               luneTab J = 대장장이 창 · ?lunedemo=forge · forgecraft · forgedetail · forgeanim · forgeok · forgedrop · forgeboom · forgebroken · 고를 칸 휠 · 경매장 줄도 게임의 셈(aucSub). export checks.forge → 테스트 53이 강화 줄의 글을 맞춰 본다.
               용어: 치명타 → 크리티컬 · 최종 피해 → 최종 데미지 · 주는 피해 → 데미지 · 없는 효과를 적은 설명 고침. 검사 53(새) · 11 · 12 · 13 · 15 · 18 · 20 · 22 · 29 · 40 · 41 · 44 고침.
               29번: 직업마다 따로 돌리면 다섯 모두 2차 전직(0:23~0:26 · 쓰러짐 0). 다섯을 한 번에 돌리면 넷째가 「옛 망루」 1층의 정예 검병을 못 잡고 멈춘다(봇의 서는 자리 문제로 보임) — 사용자가 그만두라 함("이 테스트루프 의미도없는거 그만돌리세요"), 더 보지 않음.
               보지 못한 것: Play(대장장이 창 · 연출 · 끌어다 놓기) · 폰. 물은 것: 별 % · 성능 % · 낮은 레벨 22성이 싸다(Lv.1 무기 달가루 504) · 달가루를 상인이 파는 것 · 정수를 다시 넣을지 · 강화 소리.
          ✔ S146 **출석 · 업적(2026-10-15 · 사용자: "출석보상, 업적 만들어야합니다" — 판 · 목록 · 보상은 내 제안)** — 공방 design/attend.js(28칸 · 한국 자정 · 큰 칸 7/14/21/28 · 보상) · achieve.js(27개 · 410점 · 브론즈/실버/골드 · goal.kind)
               → export attend.generated · achieve.generated · ui.js UILAYOUT.attend · achieve · basics.js WINDOWS attend · achieve(메뉴에서).
               게임: sim/gift.luau(보상 꾸러미 — 물약은 그 레벨의 것 · 다 안 들어가면 안 줌) · sim/attend.luau(checkIn · claim · view) · sim/achieve.luau(지역 = 장면의 region · killed · visited · forged · check · claim · claimAll · view) ·
               account.luau의 att · ach(계정의 것) · world.luau(onAttend · onAchieve · achTick 1초 — 쓰러짐 · 자정 · check / 처치 · 분해 · 제작 · 강화 · 일일 · 파티 · 경매 대금 · 들른 맵의 셈 · selfView attReady · achReady) ·
               packets Attend · Achieve · AchDone · AttendNew · ui/attendWindow · achieveWindow · touch.luau 메뉴의 점 · boot(창 등록 · ctx · 그날 처음이면 출석 창 · 업적 띠 = Guide.banner).
               공방: paint.js paintAttend · paintAchieve · achBanner · luneTab ?lunedemo=attend · attendfull · achieve1~6 · achbanner. 검사: 51 · 52 + 규칙(글이 줄에 들어간다). 게임 488,177개 통과. Play 안 함.
          ✔ S145 **플레이어 데이터 기록(2026-10-15)** — server/modules/analytics.luau(AnalyticsService: 온보딩 19단계 · MainQuest · Level 퍼널 · LevelUp · JobAdvanced · Death · DailyDone · Enhance · 달돈의 경제(60초 묶음)) ·
               요청은 Analytics.wrap으로 감싼다(무엇이 달돈을 바꿨나) · 관리자 · 확인용 · 봇은 안 적음 · Studio는 안 보냄 · hero.played(논 시간 · 저장). 검사 50. 게임 이름 「[Pixel RPG] 달의계승자」(store.js · 썸네일의 영문 줄을 뺌).
          ✔ S144 **최종 점검 — 시작 ~ 2차 전직(2026-10-15)** — 다섯 직업 모두 2차 전직(0:23~0:25 · 쓰러짐 0) · 연출 13개의 사람 · 일일 의뢰 Lv.10~30 · 첫 강화 · 고친 것: 버린 퀘스트 설명의 작업 메모 · 노인의 옛 혼잣말(맵 파일) ·
               옛 망루 설명의 깃발 · 문 이름의 「(임시)」 → 규칙 검사가 막는다(플레이어 글의 작업 메모 · 맵 파일의 옛 혼잣말).
          ✔ S143 **오류 · 명예의 전당 · 가방 스크롤(2026-10-15)** — ① 「quests:563 attempt to concatenate string with boolean」(매 화면): 줄에서 뺀 퀘스트를 하는 중이던 캐릭터 → 길찾기가 돌려줄 주민(false)을 찾다 멈춤.
               `Q.npcScene`이 주민이 없으면 nil · `Q.unpack`이 할 수 없게 된 퀘스트의 「하는 중」을 지운다(끝낸 것은 남김) — 테스트 17. (주황 경고 UIBlox FoundationProvider = 로블록스 코어, 우리 코드 아님)
               ② 명예의 전당에서 관리자 계정 빼기: `Admin.isId` · `Rank.userOf(key)` → rankBoards가 관리자의 줄을 거름 · pushRank는 관리자면 올리지 않고 한 번 지움 · addSpent도 건너뜀 · onRank의 rankSent nil 막음(관리자가 순위를 물으면 오류였을 것) — 테스트 13
               ③ 가방 = 스크롤: bagWindow의 ▲▼를 없애고 칸을 Ui.scroll 안에(늘린 만큼 칸을 만든다 · 막대 3점) · 스마트폰은 칸을 HOLD 0.3초 누르고 밀어야 끌기(quickEdit의 extra.hold · onStart — 끄는 동안 스크롤을 세움) — 테스트 49. 시험 탭의 가방은 24칸 본보기라 그대로.
               검사: 게임 487,521개 + 49 통과 · Studio(새 창 id 60840a33…)에 Rojo로 들어온 것 확인. Play 안 함.
          ✔ S142 **해 보신 뒤 열 가지(2026-10-15)** — 소리 1/3(수락 0.17 · 완료 0.18 · 데미지 0.05 — music.js) · 타수를 차수마다(COMBAT.lines.per = [3,4,6,8] · nuke = [5,7,10,15] — `Lines.count(hits, nuke, job)`, Caster.lines가 CAST.job을 넘긴다)
               · 간이 포탈(maps.js `warpsFor` · `WARP` → scenes.generated `warps` · `warpAlpha` · 서버 `Net "Hop"`(world.luau onHop → Warp) · sceneView는 문 그림을 28%로 · `warpNear` · 시험 탭 nearWarp) — 몬스터가 사는 맵 57곳(in_cellar · dream 빼고), 다른 맵으로 가는 문(portals)과 따로
               · 말풍선(Talk.hush — enterScene) · Lv.30까지 줄로(questplay `LINE_FIT = 30` · 「주민이 안 바뀐다」 규칙은 `LINE_HEAD = 10`) · 세 갈래 길 문 17 → 11.8칸
               · 줄 20 → 14(빠진 여섯 = PLAY.side에서 `DROPPED_1015`로 — 이름표는 그대로라 받을 수 없음 · quests.js에 dropped) · 옛 망루 + 깃발 찾기(spot flag) · 마을 밖의 그림자 + 물약 10 · 불타는 마을 = espearman(town.js cellars · combat FIELD)
               · 일일 의뢰가 줄에 남은 몬스터를 피함(`Quests.lineMobs` → `Daily.pick(..., skip)` · 공방 dailyPick) · 망루 아래(r1b4) 지움(그림 폴더는 maps/_removed_1015 · mole은 bench) · r1_sight = r1m2 enter
               · 명예의 전당 = 비석에 새긴 글(town.js stones `face` · build_lune_town2 · export npcs.face · 게임 `client/lune/hallStones.luau`(Net Rank · 30초) · NPCDO에서 hall_* 뺌 · npcNear가 비석을 건너뜀 · 시험 탭 in_hall)
               검사: 공방 규칙 통과 · 게임 478,967개(새 47 비석 · 48 간이 포탈) · 그림 2장 올림 · Rojo 확인. Play 안 함.
          ✔ S141 **퀘스트 연출(장면) · 1지역 메인 줄의 이야기** — 2026-10-15. 사용자: "현재 메인 퀘스트 라인 너무스토리 몰입이 안됩니다 … 뭐해라, 뭐잡아라 반복 … 몰입되는 중간에 연출이 있는것도아니고 다른게임들 어떻게 스토리 진행하는지 좀 파악하고 만들어야합니다." (같은 때 두 보스의 걷기를 늦춤: 성벽 거인 34→20 · 간수 24→15)
               조사(로스트아크 · 메이플 · 던파 · 엘소드 · WoW · FF14) = 설계 `cine.js`의 STUDY_CINE → 「줄거리 · 세계」 탭(storyTab의 lineHtml — 조사 · 끌고 가는 질문 · 장마다 퀘스트 · 대사 · 장면).
               자료: 공방 `js/lune/design/cine.js` — CINE(장면 13: when = { quest, on = before · enter · accept · goal · complete, map } · steps) · CHAPTERS(1편의 장 다섯 — 장의 첫 퀘스트를 받을 때 카드) · LOOK(불타는 마을 동안 town · in_shrine · in_cellar의 붉은 덮개) · PICTURES(벽 그림 — 직업마다 한 장) · CINE_LOOK · WEAPON_WORD.
                 대사 = `questplay.js` PLAY(1지역 20개 다시 씀 — 이름 · 할 일 · 마릿수 · 주민은 그대로). 「@id 」 = 그 사람이 말한다(@hero = 내 캐릭터) — 게임의 Talk.speaker가 이름표를 바꾼다. 설명 글 = world.js MAIN · quests.js SIDE(낡은 달력 · 옛이야기 · 깃발).
               셈: 공방 `js/lune/cine.js` = 게임 `shared/lune/cine.luau`(같은 셈 — Cine.new · step · input · findAll · before · lookAt · known). 그리기: 시험 탭 `luneTab.js`(「연출」 고르개 · `&lunecine=<id>&lunecinestep=<n>` 화면 확인용) = 게임 `client/lune/cineView.luau`(세계를 덮는 층 55 · 글 · 단추 층 70 · 말은 Talk.cine).
               게임의 연결(boot.luau): Quests 이벤트에서 accept · goal · complete를 줄 세움 · 맵에 들어서 막이 걷히면 enter · before · 줄은 playCine가 하나씩(막 · 쓰러짐 · 주민과 말하는 중에는 기다림) · 장면 동안 step은 넘기기만(↑ · 스페이스 · Esc 건너뛰기) · 돌려준 뒤 다음 퀘스트의 말(state.chain)은 장면이 끝날 때까지 기다림 · 맵을 바꾸면 장면을 끝내고 줄을 비움.
                 sceneView: camOverride(카메라) · npcOver(주민의 자리 · 쪽 · 숨김 · 걷기). 서버: Net "Cine" on/off(h.inCine — Hero.hurt · Room:hurtHero가 막음 · 90초에 저절로 풂) · seen(h.cine에 적어 저장 — Hero.pack의 cine · Hero.view의 cine).
               벽 그림: `assetpack/lune/cine/` — raw_mural.png(Codex · 본 = ref_heroes_lineup.png) → dots_mural → mural_clean(돌 색의 외톨이 점만 지움) → mural_lift(돌 바탕 한 단계 밝힘) → mural_<직업>.png(얼굴 지움 — 칼자국, 내 직업만 반쯤). 만든 법 = 그 폴더의 mural_dots.py → mural_clean.py → (밝히기는 한 줄 — UP 표) → mural_scratch.py.
                 게임 그림 cine_mural_<직업>.png 다섯 올림(ids.json). 검사: 공방 규칙(장면의 사람 · 맵 · 1지역 앞부분의 큰 낱말 · 「@id」) · 게임 497,253개(새 45_lune_cine · 46_lune_cineview — 화면 코드를 가짜 화면에 끝까지 그림). Play 안 함(사용자가 볼 차례).
          ✔ S140 **새 스토리 보스 둘 — 성벽 거인 · 쇠사슬 간수(sprite-gen 시트)** — 2026-10-15. 사용자: 새 디자인 채택 → sprite-gen으로 동작 시트 → 성벽 거인 「오케이 좋습니다」 → "오케이 게임에 적용해보세요".
               자리: id는 그대로(towerlieutenant = 성벽 거인 · scoutcaptain = 쇠사슬 간수 — 퀘스트 r1m7 · r1m8 · 망루 꼭대기). 이름은 공방 자료 전부(world · questplay · quests · story · journey · maps · music · numbers · startplan · basicsTab)와 관리 창 단추에서 바꿈.
               시트: `dino-workshop/assetpack/lune/bossanim/<rampart|jailer>/`(sprite-sheet-alpha.png + manifest.json · 만든 법 = plan_*.py · rig/ · 그 폴더의 도구들) → 설계 `bosses.js`의 `BOSS_SHEET`(동작마다 poses · holds · fps · hit · swing) →
                 `build_lune_boss_made.mjs`가 그 보스는 BOSS_MADE 대신 시트를 띠로 옮김 → `build_lune_bosses.mjs`(그림판의 몸 = 시트의 대기 칸) → export. `storyBoss().anim`도 BOSS_SHEET에서(`sheetSeq`).
               `swing`(새 값): 예고의 끝에 보여 주는 휘두르는 장 수 — `bossfx.js` · `shared/lune/bossfx.luau`의 body(없으면 1 — 옛 보스 그대로). 테스트 24가 「멈춘 장 = hit - swing」 · 「휘두르는 첫 장」을 본다. 검사: 시트 동작의 fps 4~20.
               이펙트: 성벽 거인 = 부관의 것 그대로(자리만 — BOSS_FX). 간수 = 새 일곱(`build_lune_boss_fx_prompts.py`의 FX['scoutcaptain'] · Codex는 sprite-gen의 생성기로 · 색의 본 = 간수의 새 그림 `PAL_FROM`). 옛 붉은 것은 `monsters/fx_captain_1013/` · `FXART_CAPTAIN_1013`.
               검사: 규칙 통과 · 그림판 6장 올림(chars_1~3 · 마스크) · 게임 검사 496,492개 통과 · Studio에 Rojo로 들어온 것 확인. Play 안 함(사용자가 볼 차례).
          ✔ S49 보스의 설계(글만) — 1지역의 보상 보스 셋(검은엄니 · 부관의 필드 보스 · 정찰대장의 무기와 노말/하드)은 쓰지 않는다고 `world.js` BOSSRULES 맨 위에 적음 · `basics.js` UNLOCK에서 Lv.10 보스 수첩 / Lv.20 옛 주인 / Lv.28 지역 보스 노말을 뺌 · WEAPON.ways를 상점 · 몬스터 · 제작 · 스토리 보스로 고침 · startplan의 차례 ④ ⑤와 「보스」 줄을 고침.
              **남은 것**: 보스 사다리의 자료(OLD · TIERS · LADDER · numbers.js의 구간과 드랍표)는 옛 설계 그대로다 — 장비를 주는 보스가 어느 구간부터 나올지 정할 때 다시 짠다(얽힌 검사가 많다). 굴(멧돼지 굴) · 망루 꼭대기는 게임에 빈 방으로 남아 있다. 도르래 줄은 만들지 않는다.
          ☐ (옛 메모) 보스 — 메이플 조사 — Lv.1~29는 직업 스토리뿐 보스 없음 · Lv.30~59 테마던전의 스토리 보스(보상은 퀘스트 완료가 준다) · 보상을 주는 첫 보스는 Lv.50 이지 자쿰(하루 한 번) · Lv.65 발록(출처 grandislibrary Level Content Guide).
             우리 설계에서 걸리는 것: 옛 주인 검은엄니(Lv.20 · 하루 한 번 · 목걸이) · 부관이 필드 보스로 다시 나와 장비를 주는 것(Lv.25) · 정찰대장 스토리의 무기 드롭(Lv.28) · UNLOCK의 Lv.10 보스 수첩 / Lv.20 옛 주인 / Lv.28 지역 보스 노말 · startplan 차례 ④ 「첫 보스 검은엄니」.
             게임에는 지금 보스가 하나도 없어 어긋나는 것이 없다(굴 · 망루 꼭대기는 빈 방). 보스 사다리(world.js TIERS · numbers.js)는 얽힌 데가 많아 정리안을 사용자에게 보이고 답을 받은 뒤 고친다. 도르래 줄은 만들지 않는다.
          ☐ 그 다음(차례대로): ① 1지역의 보스 셋의 싸움(검은엄니 · 망루의 부관 · 정찰대장 — 대신해 둔 메인 둘을 되돌린다. 동작 그림을 누가 만들지 답을 기다림) ② (끝 — S55) 맵에 놓인 것 앞에서 ↑를 누르는 퀘스트 ③ 달빛 문(마을 사이 이동 — Lv.30에 망루에서 마을까지 맵 열둘을 걸어야 한다)
             ④ 사당 지하 「불타는 마을」 ⑤ 2지역으로 가는 길의 안내(전직한 뒤 「반달 나루」 — 뱃사공 노을이 어디 있는지) ⑥ 첫 강화가 반드시 성공하는지 확인 ⑦ 둘이 들어가 파티 확인.
        같이 찾은 것: 팩에 안 쓰는 공격 동작 — Warrior/Slashes(11장) · Archer/Super Shoot(9장) · Spearman/Charge(17장) · Bomber/Electrocute(12장). 정예 병사 셋에 앞의 셋을 쓴다(시험 탭에서 먼저 — 아직 안 함).
  - 직업마다 Studio에서 확인한다(확인용 임시 캐릭터). 수치는 모두 [제안]으로 적고 공방 「개발 진행」 탭에 묻는다.
