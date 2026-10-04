# NINJA_PLAN — 「오문 닌자전」 개발 계획과 진행 상태 (Claude 작업용)

> 기준 사양: `NINJA_DESIGN.md`. 옛 계획 `DEV_PLAN.md`(포획 게임 M0~M4)는 남겨 두되 더는 기준이 아니다.
> 방식(사용자 지시 2026-10-03): 단계마다 개발 → Claude가 스스로 검증 → 다음 단계. 사용자는 공방만 만진다.
> 백업: 전환 직전 상태 = `sprite-gen/backup/SpriteDemo_2026-10-03_before_ninja/`(src · assets · 옛 문서).

## 검증 방법 (Studio 없이도 되는 것부터)

1. **자동 테스트**: `cd SpriteDemo && python tools/test/run.py`
   - 전 파일 컴파일 검사(`tools/luau/luau-compile.exe`) + 로직 테스트(`tools/test/tests/*.luau`).
   - `tools/test/mock.luau`가 로블록스 환경을 흉내 낸다(game · script · require · Vector2 · Random · task 가짜 시계 `advance(초)`).
   - 서버·공용 모듈과 도트 글씨 모듈(폭 재기 · 줄바꿈)은 실제 코드를 그대로 돌린다. 그 밖의 클라이언트 화면 모듈은 컴파일 검사 + UI 부품 이름 검사.
   - 새 기능을 넣으면 테스트 파일을 추가한다(가짜 플레이어 · `MOCK(경로, 값)` · `SERVICE(이름, 값)`).
2. **내보내기 자체 검증**: `node tools/export_ninja.mjs`(dino-workshop) — 시작 자리 · 포탈 · 스폰 구역이 막혔는지 경고.
3. **공방 미리보기**: http://localhost:8090 → 「세계」 · 「이야기 · 퀘스트」 · 「스킬 · 장비」(설계 + 인술 시연 · 무기 표) · 「닌자 맵」(씬 · UI 예시 화면) · 「글꼴」 탭.
4. **Studio**: 그림 업로드와 실제 플레이 확인. Studio가 켜져 있고 MCP가 연결돼야 한다(Rojo 플러그인 Connect 필요).

## 그림을 게임에 넣는 절차 (Studio 필요)

1. `cd dino-workshop && node tools/export_ninja.mjs` → `SpriteDemo/assets/ninja/*.png` + `townWorld.generated.luau` + `itemIcons.generated.luau`.
   UI 키트는 따로: `node tools/export_ninja_ui.mjs` → `assets/ninja/ui.png` + `uiKit.generated.luau`(맵 미리보기 · 아이템 시트를 예시 화면에 쓰므로 export_ninja 다음에 돌린다).
   글꼴은 `node tools/export_ninja_font.mjs` → `assets/ninja/font_*.png` + `pixelFont.generated.luau`.
2. `SpriteDemo/assets/ninja`에서 `python -m http.server 8094 --bind 127.0.0.1` → Studio MCP `upload_image`로 objects · monsters · player · npcs · items · fx · ui · ground_*.png · font_*.png 업로드 → 그 python만 종료.
3. `node tools/write_ninja_ids.mjs '<업로드 결과 JSON>'` → `townAssets.generated.luau`.

## 전면 교체 원칙 (사용자 지시 2026-10-03)

보이는 것은 전부 팩 기준이다 — 맵 · 캐릭터 · 몬스터뿐 아니라 **UI 스타일 · 아이템 · 이펙트**까지. 옛것을 섞어 쓰지 않는다.

- UI: 팩 UI(나무 테마 · 대화 상자 · 스킬 아이콘 · 키 그림 · 얼굴 그림)로 만든 키트 — 공방 `tools/export_ninja_ui.mjs` → `assets/ninja/ui.png` + `shared/data/uiKit.generated.luau`.
  부품 이름: panel · tag · tab_on/off · button_primary/plain · pill · slot · bar_* · dialog_face · icon_* · act_* · key_* · skill_<인술>(+_off) · face_<NPC>.
  색 이름: ink · paper · accent · accentD · accentL · good · goodD · red · sky · yellow · gray · grayD(옛 pink/mint 이름은 없다).
  아이콘은 그림 자기 크기 그대로(정수배) 놓는다 — 12칸에 억지로 늘리지 않는다.
- 아이템: `items.luau` = `ninjaItems` + `ninjaWeapons`만. 옛 아이템(나무 검 · 잎사귀 갑옷 · 물약 · 방울 · 몬스터 재료 · 무지개 알)은 표에서 없앴고,
  옛 저장 데이터는 저장 v10이 바꿔 준다(나무 검 → 닌자도, 잎사귀 갑옷 → 수호 부적, 물약 → 음식, 나머지는 없앰). 새 플레이어 = 닌자도 + 수리검 30 + 주먹밥 5.
- 이펙트: 공용 재생기 `client/modules/packFx.luau`. 무기 맞음 = 팩 FX/Attack(무기 종류마다 `weapons.luau` hitFx), 폭탄 = 팩 폭발, 레벨업 = 팩 반짝이, 인술 = 팩 원소 이펙트.
- 글꼴: 레트로 비트맵 글꼴 **「갈무리」**(Galmuri — Lee Minseo(quiple), SIL Open Font License 1.1: 상업 이용 · 게임에 넣기 가능). 본문 = Galmuri11(한글 폭 12),
  제목 = Galmuri14(한글 폭 15). 사용자가 2026-10-03에 참고 그림(가는 획 · 둥근 ㅇ의 레트로 글꼴)을 주며 "이런 느낌 나오게"라고 해서 골랐다.
  그 전에 Claude가 멋을 부려 만든 「닌자체」는 "끔찍하다 · 인식률이 안 좋다"로 버려졌다 — 글꼴은 읽기 쉬움이 먼저다.
  공방: 원본 `assetpack/fonts/*.bdf` + `LICENSE.txt` → `tools/import_bdf_font.mjs` → `js/fontData.js` → `js/font.js`. 게임: `tools/export_ninja_font.mjs` →
  `assets/ninja/font_*.png`(6장) + `pixelFont.generated.luau`(칸 12x13 / 16x20, `hangulAdv`). 라이선스 사본 `assets/ninja/FONT_LICENSE_Galmuri_OFL.txt`.
  글자판에 든 기호: ♥ ★ × · … ♪ — → ← ↑ ↓ ▲ ▼ ● ○ 「 」(그 밖의 글자는 "?"). 영문 · 숫자가 예전보다 넓다(숫자 8칸) — 숫자 자리는 넉넉히.
- **글씨는 칸을 넘지 않는다**(사용자 지시): `pixelText`의 `MaxWidth`(넘으면 줄바꿈) · `MaxLines`(넘으면 …). `UI.Label`은 부모 칸 크기가 정해져 있으면
  저절로 제한을 잡고, 옆에 버튼 등이 있는 자리는 직접 폭을 준다. 대화 상자는 두 줄씩 쪽을 넘긴다. 새 창을 만들면 `tools/test/tests/06_text.luau`에 그 자리 폭을 적어 검사한다.
- 옛것 정리(2026-10-03 사용자 승인): 폐기한 횡스크롤 게임의 코드(heroController · village · Backfield · 옛 장비 창/메뉴/체력바 · monsterSpawner ·
  monsterAI · lootService · sceneBootstrap) · 옛 자료(monsters · lootTables · materials.generated · townMap.generated · uiTheme · uiAssets.generated) ·
  옛 그림(`assets/` 아래 ninja · fx 말고 전부)을 지웠다. 공방도 닌자 탭 3개(닌자 맵 · 글꼴 · 팩 확장 시안)만 남겼다.
  되살릴 일이 있으면: 게임 = git 기록 + `sprite-gen/backup/SpriteDemo_2026-10-03_before_ninja/`, 공방 = `C:\YJS\Robloxackup\dino-workshop_2026-10-03_before_cleanup\`.
- 아직 남은 옛것(꺼져 있음 — 지울지는 사용자 결정): 펫 · 포획 코드(`features.PETS/CAPTURE = false` — petBox · pets · petFx · petService · petSkillService ·
  capture · petSkills*.luau · fxAssets.generated · `assets/fx`), 플레이스의 `ReplicatedStorage` 속성 `UpsideEngineDB`(옛 편집기 씬 자료 — 더는 읽지 않는다),
  옛 문서(GAME_DESIGN.md · DEV_PLAN.md · ROADMAP.md · HANDOFF_*.md).
- 그림 업로드: 2026-10-03 완료(15장 — objects · monsters · player · npcs · items · fx · ui · ground_village · ground_field1 · font_body 2 · font_title 4).
  그림을 다시 내보내 내용이 바뀌면 다시 올려야 한다(`write_ninja_ids.mjs`에는 15장의 id를 모두 줘야 한다).
- 검증: 테스트가 "모든 아이템이 팩 아이콘인지 · 옛 아이템이 표에 없는지 · 코드가 쓰는 UI 부품과 색이 키트에 있는지 · 인술 아이콘 · 얼굴 그림 · 맞음 이펙트가
  있는지 · 게임 글이 각 창의 글 자리에 잘리지 않고 들어가는지"를 보고, 실행기가 클라 코드의 UI 부품 이름(아이콘 · 버튼 색 · 게이지 색)이 키트에 있는지 훑는다.

## 설계는 공방에서 먼저 (2026-10-03 사용자 지시: "에셋공방에서 만들어보고 그대로 옮기는 형식")

- 설계 자료: `dino-workshop/js/ninja/design/` — `world.js`(지역 8곳 · 거점 마을 · 사냥터 줄기 71개 · 탈것 · 보스 · NPC 배역 27명), `story.js`(줄거리 · 9장 · 본 퀘스트 52개 · 대사 TALK),
  `skills.js`(전직 표 · 공용 기술 · 전직 패시브 안 · 정해야 할 것). 사용자는 공방 「세계」 · 「이야기 · 퀘스트」 · 「스킬 · 장비」 탭에서 본다.
- 검증 + 옮기기: `node tools/export_ninja_design.mjs` — 몬스터 · 아이템 · 보스 · NPC · 맵 이름 · 레벨이 서로 맞는지 보고(어긋나면 멈춤), 퀘스트 레벨 · 보상 숫자를 게임 공식으로 셈해
  `SpriteDemo/src/shared/data/quests.generated.luau`(게임 퀘스트 자료)와 `preview/design.json`(공방 탭용)을 쓴다. 맵은 지금처럼 `js/ninja/maps.js` → `export_ninja.mjs`.
- 순서: 공방 설계 자료를 고친다 → export로 검증 → 공방 탭에서 본다 → 게임 테스트(`tools/test/run.py`). 게임 쪽 generated 파일은 손으로 고치지 않는다.
- **퀘스트 ✅(코드 · 테스트 07) / 화면 확인 ⏳**: 규칙 `shared/config/quests.luau`, 서버 `server/modules/questService.luau`(QuestTalk — 받기/끝내기, 처치 = `townMonsters.OnKill`, 가기 = `heroTracking.OnSceneChanged`),
  저장 `Quest = { Index, Accepted, Progress }`(v12), 클라 `globals/quest.luau`(오른쪽 위 추적창 172x42 + NPC 대화 연결 — 퀘스트 대사가 가게 · 강화 · 전직 창보다 먼저).
  지금 할 수 있는 곳까지: m001 ~ m104(서장 + 1장의 넷째). m105(거대 말랑이)는 보스가 아직 없어 받기만 된다.
- **맵 ✅(업로드까지)**: 나비 언덕 1(애벌레) · 2(애벌레 · 팔랑나비) · 3(팔랑나비 · 도토리쥐) · 큰 웅덩이(도토리쥐, 연못 — 보스 자리). 연못 = `maps.js`의 `water` 사각형(팩 TilesetWater 자동 타일, 못 지나감).
- **스킬 재설계(설계만 ✅ / 게임 ⬜)**: 사용자 지시(2026-10-03) "전직마다 인술이 많아야 하고, 같은 이펙트를 일자 · 원형으로만 바꾼 것은 다른 스킬이 아니다. 메이플 1~4차 전직 구조를 참고".
  `design/skills.js`를 메이플식으로 다시 썼다(117개 — 유파 핵심 장치 · 전직별 고유 4/5/6/6 · 공용 12 · SP 예산). `export_ninja_design.mjs`가 구조를 검사한다(전직마다 주력기 하나 · 패시브 있음 · 쓰는 법 3가지 이상 ·
  종류+이펙트 조합이 겹치지 않음 · 팩 이펙트 이름이 실제로 있음 · SP 예산 ±15%). 게임은 아직 옛 구조(전직마다 인술 1개, Q R T G)다.
  옮기는 순서(사용자가 설계를 본 뒤): ① 스킬 창 + SP + 단축칸 고르기 ② 핵심 장치 5개(불씨 · 서리 · 생기 · 견고 · 전하) ③ 1차 스킬(유파마다 4 + 공용) — 공방 시연 → 게임 ④ 2차 … 새 이펙트는 그릴 때마다 공방에 먼저.
- **대쉬 ✅(코드 · 그림 업로드 · 테스트 08) / 화면 확인 ⏳** — 사용자 지시(2026-10-03): "도발 같은 스킬은 있으면 안 되고, 대쉬 같은 이동기가 있어야 한다. 풀 · 바위는 무겁게, 불 · 번개는 빠르게, 얼음은 중간".
  설정 `ninjutsu.luau` `DASH`(novice 구르기 · fire · thunder · ice · plant · rock — windup · distance · time · cooldown · hit/trail/guard · fx) · `DashFor`. 키 Shift(`DASH_KEY`) + 화면 버튼(HUD 오른쪽 아래, `act_dash` · `key_shift`).
  **대쉬는 순수 이동기**(사용자 지시: 피해 · 상태 이상 없음 — 설정에 hit/trail/guard를 두면 내보내기와 테스트 08이 막는다). 서버 `ninjutsuService` `UseDash`(쿨타임 · 기력 · 벽까지의 거리 `DashDistance`) → `NinjutsuCast("dash_<id>")`. 클라 `topDownHero.Dash`(움직임) · `town/ninjutsuFx` `dashFx`(연출) · `packFx` `hold`(머무는 장).
  새로 그린 이펙트 3종(`dino-workshop/tools/draw_ninja_fx.mjs` → `assetpack/ninja/fx_custom/`: 얼음 길 · 번개 줄기 · 덩굴) + 팩 이펙트 4종 추가. 공방 「스킬 · 장비」 탭 맨 위 대쉬 시연(`js/ninja/dashDemo.js`).
  도발류 스킬은 설계에서 뺐고 검증 도구가 막는다. Play에서 볼 것: Shift/버튼으로 대쉬, 유파마다 빠르기 차이, 길에 남는 이펙트, 벽 앞에서 멈춤, 쿨타임 숫자.
- **스킬 나무 · SP · 1차 스킬 ✅(코드 · 그림 업로드 · 테스트 04 · 09) / 화면 확인 ⏳**: `ninjutsu.luau` 「스킬 나무」 절 — `TREE`(유파 → 전직 → 스킬) · `COMMON` · `MaxOf` · `AutoFor` · `Scale` · `SpEarned` · `GrantLevelSp`.
  저장 v13: `Ninjutsu[id]` = 스킬 레벨(0 = 안 배움) · `SP[전직]` · `SkillSlots[1~4]`. 레벨업마다 지금 전직에 SP 3, 전직할 때 SP 3 + 주력기 · 핵심 장치 1레벨. 두루마리 = SP +1.
  서버 `ninjutsuService`: `LearnSkill` · `SetSkillSlot` · `UseNinjutsu(칸)` = 그 칸에 넣은 인술, 유파 바꾸면 쓴 SP 환급. 핵심 장치: 불씨(몬스터에 쌓이는 주기 피해) · 서리(느려짐 → 5에서 얼어붙음) · 생기(풀 인술이 맞으면 쌓임, 치유가 씀)
  · 견고(맞으면 쌓임, 피해 감소) · 전하(맞히면 쌓임, 공격이 빨라짐) — 내게 쌓이는 것은 `CoreUpdated`. 1차 새 스킬: 가시 씨앗(박혔다 터짐) · 달궈진 칼날 · 얼음 갑옷 · 정전기 · 공용(무기 단련 · 기력 단련).
  `townMonsters`에 훅 `OnPlayerHurt` · `OnAttackSpeed` · `OnKill`. 클라 `globals/ninjutsu.luau`: 단축칸 = 고른 인술, 스킬 창(K · HUD 버튼 — 전직 탭 · 목록 · 설명 · 배우기 · 칸에 넣기), 기력 게이지 위 핵심 장치 값.
  2~4차는 옛 인술이 자리를 지킨다(암문 2차는 비어 있음). Play에서 볼 것: 1차 전직 직후 SP 3 · 스킬 창, 불씨/서리가 몬스터에 붙는 모습, 가시 씨앗이 2초 뒤 터지는지, 전하 값과 공격 빠르기, 옛 저장 데이터가 v13으로 올라온 뒤 단축칸.
- **2차 고유 스킬 ✅(유파마다 5개 = 25개 · 코드 · 그림 업로드 · 테스트 09 뒷부분) / 화면 확인 ⏳**: `ninjutsu.luau` 「2차 스킬」 절.
  새 종류 — zone(설치: 불기둥 · 얼음 벽 · 치유꽃 · 번개 덫, `NinjutsuCast` targets = { 번호 }, 끝나면 `zone_end`) · buff(열기 · 숲의 숨결 · 질풍 → `BuffUpdated`) · detonate(점화) · shatter(깨뜨리기)
  · discharge(방전) · decoy(얼음 분신) · counter(되받아치기). line/projectile 덧붙임 — hits · follow(화염 방사) · segments(지면 강타) · pull(덩굴 채찍) · shots · single · mark(뇌전 수리검) · firmBonus(바위 던지기).
  패시브 — 타오르는 마음 · 차가운 피 · 뿌리 내림 · 무거운 몸 · 감전. 옛 인술 fire_burst · ice_freeze는 없앴고 빙창은 2차, 눈보라 · 뇌우는 3차로 옮겼다(빙문 4차는 비어 있음).
  새로 그린 이펙트: 불기둥(팩 물기둥을 불 색으로) · 치유꽃. 설계와 달라진 점: 화염 방사는 "누르고 있기"가 아니라 1.6초 고정, 얼음 벽은 길을 막는 대신 닿은 적을 멈춰 세움, 얼음 분신은 분신 그림 없이 적이 나를 놓치는 효과만.
- 아직 안 옮긴 것: 2차 공용 3개(재빠른 손 · 신체 단련 · 급소 찌르기), 3차(유파마다 6개), 4차(6개), 3 · 4차 공용. 핵심 장치가 몬스터 머리 위에 보이게(불씨 · 서리 개수), 공방 UI 예시에 스킬 창, 단축칸 늘리기(사용자 결정 — 2차부터 쓰는 인술이 4칸을 넘는다).
- 다음: 보스(거대 말랑이 — 팩 Actor/Boss) + 1차 전직 시험 → 2장 대사 · 대나무 숲 맵 · 대숲 찻집 → 탈것(R5). 정해야 할 것은 공방 「스킬 · 장비」 탭 맨 아래와 NINJA_DESIGN §0-6.

## 개편(2026-10-03 사용자 지시 — NINJA_DESIGN §0): 메이플식 성장 구조

N2(유파·인술) · N3(장비·강화)는 구조를 다시 잡는다. 아래 R 단계가 지금의 할 일이다(N4 이후는 그 다음).

- **R1 사냥터 줄기 ✅(코드 · 그림 업로드까지)**: 한 맵에 몬스터 1~2종, 번호 붙은 맵으로 이어짐 — 닌자 마을 ↔ 새싹 들판 1(말랑이) ↔ 2(말랑이 · 버섯돌이) ↔ 3(버섯돌이) ↔ 나비 언덕 1 ↔ 2 ↔ 3 ↔ 큰 웅덩이.
  공방 `js/ninja/maps.js`(field1 · field2 · field3, 포탈 `arrive: 'door'` = 넘어가면 돌아가는 포탈 앞에 나타남), 클라 `topDownHero.findSpawn`(가장자리 포탈에서 안쪽으로 한 걸음).
  Play에서 볼 것: 포탈로 넘어갔을 때 나타나는 자리, 맵마다 몬스터 종류.
- **R2 전직 · 스킬 — 코드 ✅(스킬 포인트 · 전직 시험은 남김) / 화면 확인 ⏳**: 저장 `Job`(0 견습 ~ 4, v11). Lv.1~9 견습(유파 없음) → 스승 곁에서 1차 전직(Lv.10, `ChooseSchool` = 유파 고르기)
  → `JobAdvance`로 2차 30 · 3차 60 · 4차 100. n번 인술 칸 = n차 전직 인술(유파마다 4개 — `ninjutsu.luau` `JOB_LEVELS` · `SCHOOL_INFO.skills`), 3 · 4차 인술 10개 추가(`selfHeal` 효과 포함).
  클라 `globals/ninjutsu.luau`: 인술 칸 4개(Q · R · T · G), 잠긴 칸은 전직 레벨 표시, 스승에게 말 걸면 전직 창(견습은 Lv.10부터, 내 유파 줄 버튼 = "N차 전직"). 접속하자마자 뜨던 유파 창은 없앴다.
  그림: 스킬 아이콘 20종 · 키 그림 T · G(ui.png), 바위 투사체(fx.png) — 업로드함. 테스트 04(518개): 전직 조건 · 칸 잠금 · 새 인술이 실제로 쓰이는지 · 저장 올리기.
  남김: 스킬 포인트(지금은 두루마리로 단계 올림 그대로), 2차 이후 전직 시험(보스), 최대 레벨.
- **R3 무기 특성 · 옵션 ⬜**: 무기 종류 보정이 인술에도 걸리게(피해 · 쿨타임 · 범위), 치유 특화 종류(지팡이 · 부채), 무작위 옵션(아이템마다 — 가방 칸에 옵션 저장), 등급.
- **R4 방어구 ⬜**: 모자 · 옷 · 신발 3칸(겉모습 없음). 부적(Charm)은 없애고 저장 데이터는 바꿔 준다. 팩에 방어구 그림이 없다 → 팩 그림체로 아이콘을 그려야 한다.
- **R5 지역 이동 ⬜**: 나루터/이륙장 NPC · 삯 · 레벨 제한 · 이동 연출, 다음 지역(대나무 숲 1~3)과 그 마을.

## 단계

### N0. 팩을 게임에 넣기 — 코드 ✅ / 업로드 ✅(2026-10-03) / 화면 확인 ⏳
- 공방 `js/ninja/pack.js`(팩 카탈로그: 바닥 자동 타일 · 물건 · 유파 5 · NPC 9 · 지역 8 · 몬스터 66종 레벨 · 아이템 아이콘 40),
  `js/ninja/maps.js`(닌자 마을 30x22 · 새싹 들판 40x30), `tools/export_ninja.mjs`, `tools/write_ninja_ids.mjs`, 「닌자 맵」 탭.
- 게임: 옛 형식(`townWorld.generated`) 그대로라 맵·이동·충돌 코드는 손대지 않음. 바뀐 곳 —
  몬스터 시트 4방향(`townWorld.MonsterFrameOffset`, `town/monsters.luau`), 플레이어 유파 줄(`topDownHero.school`),
  맵 바깥 색(씬 `outside`), 글씨 배율 분리(몬스터 이름표 · NPC 말풍선 · 떨어진 아이템 = 2), 도감 지역 탭,
  `shared/config/features.luau`(PETS · CAPTURE = false — 펫 버튼 · 따라다니기 · 펫 스킬 · 방울 던지기 꺼 둠).
- 검증: 내보낸 씬 데이터 858항목 검사 통과.

### N1. 사냥 기본 — 코드 ✅ / 화면 확인 ⏳(Studio 대기)
- 아이템 `shared/data/ninjaItems.luau`: 투척(수리검 · 쿠나이 · 폭탄) · 음식(주먹밥 · 초밥 · 닭꼬치) · 재료(풀잎 · 나뭇가지 · 깃털 · 돌 · 주괴 5 · 보석 4).
- 투척: `townMonsters.ThrowWeapon`(직선, 공격력 × power, 폭탄은 둘레) · 단축칸에서 사용 · `ProjectileThrown` 패킷 · 클라 날아가는 연출.
- 드롭: `shared/config/drops.luau`(지역별 표) → 처치 보상에 합침. 가게: 잡화상 = 투척 무기, 약방 = 음식·물약.
- 저장 v7: 수리검 30 · 주먹밥 5 지급, 단축칸의 방울 → 수리검.
- 팩 아이템 아이콘: 별도 시트(`items.png`) — `pixelUI`가 `icon_nj_<키>`를 이 시트에서 찾는다.
- 검증: 자동 테스트 3,331개 통과(공격 범위 · 쿨타임 · 기여도 10% · 처치 보상 · 드롭률 · 리스폰 · 투척 · 폭탄 · 반격 · 단축칸 · 마이그레이션).
- Studio에서 볼 것: 그림이 다 뜨는지, 몬스터가 걷는 방향을 보는지, 수리검이 날아가 맞는지, 가방 아이콘, 도감 지역 탭.

### N2. 유파와 인술 — 코드 ✅ / 화면 확인 ⏳(Studio 대기)
- 수치·종류 한곳: `shared/config/ninjutsu.luau`(유파 5 · 인술 10 · 기력 · 칸 레벨 · 단계 보정 · 연출 fx). 고치면 게임과 공방 미리보기가 같이 바뀐다.
- 서버 `server/modules/ninjutsuService.luau`: `ChooseSchool`(처음 무료 · 바꿀 땐 스승 곁 + 엽전 1000), `UseNinjutsu`(칸 1·2 — 레벨 · 쿨타임 · 기력 확인),
  기력(초당 6, 기본 공격 한 마리 맞힐 때마다 +4, 저장 안 함), 두루마리(`UseScroll` — 자기 유파 것, 열린 인술 중 낮은 단계 +1, 최고 5단계 · 단계마다 +15%).
- 인술 종류: 투사체(화염구) · 직선(얼음 가시 · 바위 가시) · 둘레(불꽃 폭발 · 빙결 · 덩굴 묶기 · 뇌우) · 연쇄(번개) · 회복(치유의 잎) · 방어(바위 갑옷).
  상태 이상은 `townMonsters`의 `Slow` · `Stun` · `Push` · `SetGuard`. 피해는 `townMonsters.Damage`라 기여도 · 반격 · 처치 규칙이 기본 공격과 같다.
- 저장 v8: `School`("" = 아직 안 고름) · `Ninjutsu`({ 인술 id = 단계 }). 패킷: ChooseSchool · UseNinjutsu · SchoolUpdated · EnergyUpdated · NinjutsuCast · TownMonsterStatus.
- 아이템: 두루마리 5종(`ninjaItems.luau`, Type = "Scroll") — 어느 지역에서나 1.2% 드롭(`drops.luau` SCROLL_CHANCE), 가방 [사용].
- 클라: `globals/ninjutsu.luau`(유파 고르기 창 — 유파가 없으면 접속할 때 저절로, 스승에게 말 걸면 바꾸기 / 기력 게이지 + 인술 칸 Q · R / 쿨타임 표시 /
  내 캐릭터 유파 옷), `town/ninjutsuFx.luau`(팩 이펙트 연출), `town/monsters.luau`(느려짐·멈춤 동안 몸 색).
- 그림: 팩 이펙트 13종 → `assets/ninja/fx.png` + `shared/data/ninjaFx.generated.luau`(공방 `js/ninja/pack.js` FX_SHEETS). 업로드 대상에 `fx.png` 추가.
- 공방: 「닌자 맵」 탭 「유파와 인술」 — 인술 10개가 실제 수치·이펙트로 되풀이 시연된다(`js/ninja/ninjutsuDemo.js`, 자료 = 내보내기가 만든 `preview/ninjutsu.json`).
- 검증: 자동 테스트 `04_ninjutsu`(505개) — 설정 정합성, 유파 고르기/바꾸기, 기력 소모·회복, 쿨타임, 인술 10개 판정, 느려짐 속도, 멈춤, 밀림,
  방어, 불붙음, 두루마리 단계, 드롭률, 화면 글이 도트 글꼴에 있는 글자인지. 전체 3,841개 통과.
- Studio에서 볼 것: 유파 고르기 창 배치, 인술 칸 위치(소비 단축칸 왼쪽), 이펙트 크기·자리, 다른 사람 캐릭터의 유파 옷.

### N3. 장비와 강화 — 코드 ✅(활 · 등급은 남김) / 화면 확인 ⏳(Studio 대기)
- 수치 한곳: `shared/config/weapons.luau`(무기 종류 5 — 닿는 거리 · 폭 · 공격 시간 · 피해 배율 / 강화 최대 +10 · 단계당 +8% · 확률표 · 주괴 · 값).
- 무기 14종 `shared/data/ninjaWeapons.luau`(팩 무기 — 종류 · 레벨 · 공격력 = 3 + 1.2 × 레벨). 들판 3종은 잡화 상점, 나머지는 지역 드롭 1.5%(`drops.luau` WEAPONS).
- 레벨당 공격력 +2(`balance.attackFor`) — 공격력 = 레벨 + 무기 + 강화. 몬스터 체력(20 + 10 × 레벨)에 맞춰 어느 레벨에서나 서너 대.
- 무기 종류가 기본 공격에 반영: 서버 `TownAttack`이 종류의 범위 · 간격(0.35초 × speed) · 피해 배율을 쓰고, 클라 공격 동작도 같은 배율로 빨라지거나 느려진다.
- 착용 레벨 제한(무기 · 부적 `Level`). 강화 단계는 아이템마다: 가방 칸 `Plus` ↔ 착용하면 `data.EquipmentPlus.Weapon`(저장 v9). 강화한 장비는 못 버린다(팔기는 됨).
- 강화 `server/modules/upgradeService.luau`(`UpgradeWeapon` 칸 0 = 착용 무기): 대장장이 곁에서만, 주괴 × 목표 단계 + 엽전, 실패해도 단계 그대로.
- 부적 4종(`ninjaItems.luau`, Type = "Charm", 옛 방어구 칸 사용): 방어력. 수호 부적은 잡화 상점, 나머지는 지역 드롭 0.8%(`drops.luau` CHARMS).
- 클라: `globals/upgrade.luau`(강화 창 — 대장장이에게 말 걸면 열림), 가방(칸·이름에 +N, 무기 설명에 종류 · 레벨 · 공격력), 등 뒤 팩 무기 그림 배율.
- 공방: 「닌자 맵」 탭 「무기와 강화」 표(게임 설정 그대로 — `preview/weapons.json`).
- 검증: 자동 테스트 `05_weapons`(4,908개) — 표 정합성, 레벨 제한, 종류별 범위 · 피해 · 간격, 강화(재료 · 엽전 · 확률 2,000번 · 단계 옮기기 · 최고 단계), 버리기 금지, 무기 · 부적 드롭률. 전체 8,809개 통과.
- 남김: 원거리(활 — 화살 투사체) · 등급(레어~레전더리) · 무기별 베기 이펙트 색. Studio에서 볼 것: 강화 창 배치, 무기 종류별 공격 빠르기 느낌, 등 뒤 무기 크기.

### N4. 보스와 승급 ⬜
- 구역 보스(거대 슬라임부터) · 닌자 계급 승급 시험 · 칭호.

### N5. 지역 확장 ⬜
- 대나무 숲 → 개울과 늪 → 사막 … (팩 타일셋: 물 · 사막 · 눈 · 던전 자동 타일을 `pack.js` FLOOR에 추가).

### N6. 온라인 다듬기 ⬜ / N7. BM(펫 포함) ⬜
