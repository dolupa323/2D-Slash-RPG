# DEV_PLAN — 개발 계획 (Claude 작업용)

> 기준 사양: `GAME_DESIGN.md`(먼저 읽기). 이 문서는 "무엇을 어떤 순서로, 어느 파일에서" 만들지와 진행 상태를 적는다.
> 규칙: 한 단계(M)씩 끝내고 사용자에게 Studio 확인 체크리스트를 준다(Play 시작/정지는 사용자가 한다). 단계가 끝나면 상태를 ✅로 바꾸고 짧게 기록.
> 그림은 공방(dino-workshop)에서 만들고 🚀 보내기/업로드 절차로 넣는다. 사용자는 공방만 만진다.
> 작성 2026-10-01.

## 현재 코드 기준점 (2026-10-01 조사)

- 저장: `server/services/persistence.luau` + `playerSchema.luau`(SchemaVersion 3, 마이그레이션 표 있음 — 필드 추가는 반드시 새 버전 마이그레이션으로).
  - 지금 필드: Level, Experience, MaxExperience, Health, Gold, Inventory(탭·칸 배열), Equipment{Weapon, Armor}, Dex{[id]=true}.
- 몬스터: `server/modules/townMonsters.luau`(서버 권위, 씬별, 10Hz 이동 복제). **플레이어를 공격하지 않음.** 처치 보상 = 마지막으로 때린 사람에게 경험치 + 도감.
- 레벨 범위: `shared/config/monsterLevels.luau`(도감 순번으로 자동 계산 — 교체 대상).
- 공격: `TownAttack`(방향만 전송, 서버가 판정) · 무기 VFX `client/modules/town/weapon.luau`.
- 아이템: `shared/data/items.luau`(KitIcon/WorldIcon/Vfx). 가방 UI `client/modules/globals/inventory.luau`, 도감 `dex.luau`, 알림 `notify.luau`.
- 몬스터 데이터 원본: 공방 `js/buns.js` SPECIES(70종) → `tools/export_roblox.mjs`가 `townWorld.generated.luau`의 species로 내보냄(시트 여러 장 지원).

## 마일스톤

### M0. 데이터 기반 정리 ✅ (코드 2026-10-01 — Studio 확인·🚀 재내보내기 대기)
- 한 일: 공방 `js/buns.js` 70종에 `lv: [최소, 최대]`(초안: 속성 안 도감 순서로 1~100 고르게, 폭 ≈10) · 공방 도감 상세에 레벨 표시 ·
  `export_roblox.mjs` species에 levelMin/levelMax · `monsterLevels.luau` 종 범위 사용 + `RollLevel`(높은 레벨일수록 드묾, 옛 내보내기는 옛 규칙으로 대체) ·
  `shared/config/pets.luau`(상자·슬롯·이로치·도감 상태 상수) · `playerSchema` v4(Dex 1/2, Pets{Box,Party,Slots,Boxes}, Life{Mine,Craft}) ·
  `townMonsters` 처치 시 Dex = DEX_SEEN.
- 남은 것: 레벨 범위 초안 사용자 확인 / 조정.
- 종 데이터에 필드 추가(공방 SPECIES → export): `levelMin/levelMax`, `skill{pattern, power, proc}`(자리만), 이로치 팔레트(나중).
  - 레벨 범위는 우선 [제안] 자동 배정(속성 안 순번 기반을 1~100으로 펼침) → 사용자 확인 후 조정.
- `monsterLevels.luau`: 종 데이터의 범위를 쓰도록 교체, 최대 100. 스폰 레벨 가중치(높을수록 드묾).
- `playerSchema` v4: `Pets = { box = {개체...}, party = {상자 인덱스 ×4}, slots = 1 }`, `Dex = { [id] = 1(봤음) | 2(잡았음) }`로 변환(기존 true → 1), `Life = { mine = xp, craft = xp }`.
  - 펫 개체 형식: `{ s = 종id, l = 레벨, c = 이로치 0/1, b = 방울 등급, t = 잡은 시각 }`.
- 확인: 기존 저장 데이터가 v4로 무사히 올라가는지(Studio 로그).

### M1. 전투 규칙 (기여도 · 보상 · 사망) ✅ (코드 2026-10-01 — Studio 확인 대기)
- 한 일: `townMonsters` 몬스터별 damageBy(실제 깎은 체력만, 첫 타 시각) · 처치 시 settle(피해 순, 동점=먼저 때린 사람, 10% 이상 → 경험치·골드·속성 재료·도감 봤음 / 미만 → 기여도 알림) ·
  씬 이동·퇴장 시 기여도·어그로 삭제(`heroTracking.OnSceneChanged` 새로 추가) · 반격 AI(맞으면 쫓아가 공격, 집에서 160도트·8초 무피격·씬 이탈 시 포기) ·
  `shared/config/rewards.luau`(CONTRIB_MIN, 속성 재료, 재료 수·골드 공식) · `combat.luau` MONSTER_* · `monsterLevels.AttackDamage` ·
  items: 불씨 조각(EmberShard)·물방울 조각(DewShard) — 아이콘은 속성 아이콘 임시 ·
  `progressionService.DamagePlayer` 사망: 경험치(레벨 필요치의 5%)·골드 5% 차감 + 알림, 탑다운이면 시작 씬으로 리스폰 · 클라: 몬스터 공격 튀어나가기, 내 피격 빨간 숫자, 사망 시 시작 씬 ⭐.
- M2 연결점: `settle()`에서 i == 1(딜 1등)이 포획 선택창을 받을 자리.
- 사용자 피드백 반영(2026-10-01): 속성 재료 → **몬스터 전용 재료 70종**(공방 `js/materials.js`, 아이콘 = 도트 UI 키트 icon_mat_<id>, 도트 편집 「재료」, 도감 상세 표시) ·
  플레이어 피격 깜빡임(붉게 3번) · 몬스터 배율 3→2(MONSTER_FEET halfW 4/h 2) · 새 패킷은 반드시 `shared/net/packets.luau`에 등록(빠뜨려 시작 에러 났었음).
- 서버 `townMonsters`: 몬스터마다 `damageBy[userId] = { dmg, firstHit }`. 씬 이동 시 그 사람 기록 삭제(`travelService`/씬 변경 훅).
- 처치 시: 기여도 = dmg / 최대체력. 10% 이상 → 재료·경험치. 1등(동점 = firstHit 빠른 쪽) 계산.
- 몬스터 → 플레이어 공격(근접, 쿨타임) + 플레이어 피격/사망: 사망 시 경험치 5%·골드 5% 차감, 회복소 귀환.
- 확인: 두 계정(Studio 로컬 서버 2인)으로 기여도 10% 미만/이상 보상 차이, 1등 판정.

### M2. 포획 ✅ (코드 2026-10-01 — Studio 확인 대기)
- 한 일: 공방 `js/bells.js`(방울 5단계 아이콘 · 확률 공식) + 「방울·포획」 탭(카드·확률표·연출 미리보기) + 도트 편집 「방울」 ·
  `shared/config/capture.luau`(LEVEL_CAP 20/40/60/80/100, Chance, OFFER_TIME 10) · items Bell1~5(Tab "Use" — 방울 주머니 전까지) ·
  playerSchema v5(시험용 방울 흐린×10·맑은×3 지급) · inventoryService.CountItem/TakeItem ·
  `townMonsters`: 보상 = rewardBase(경험치·도감, 처치 즉시) + rewardLoot(골드·재료), 1등은 offerCapture(쓰러진 채 대기 TownMonsterDowned) →
  CaptureChoice 검증 → resolve(재료 / 방울 1개 소모 후 굴림: 성공 = Pets.Box 저장·Dex 잡았음·즉시 저장, 실패 = 도망·전리품 없음) → TownCapture 연출 → 리스폰 ·
  이로치 1/2048 스폰 시 굴림(펫에 C=1 저장, 그림 표시는 이로치 팔레트 생긴 뒤) · 클라 `globals/capture.luau` 선택창 · `town/monsters.luau` 포획 연출.
- **재설계(같은 날, 사용자 피드백)**: 처치 후 선택창 폐기 → 전투 중 소비 단축칸 방울 던지기.
  `capture.luau`(BaseChance × 체력 비율, THROW_*, REVEAL_TIME, HINT_HP) · packets: BellThrown/TownCapture(result)/QuickSlotsUpdated/SetQuickSlot/UseQuickSlot(CaptureOffer·CaptureChoice·TownMonsterDowned 삭제) ·
  playerSchema v6 QuickSlots · 서버 `quickSlots.luau`(놓기·쓰기: 방울 → townMonsters.ThrowBell, 물약 → 회복) · townMonsters: topDealer/ThrowBell/tryCapture(자격·굴림·2초 뒤 적용), settle은 1등 포함 모두 전리품 ·
  클라 `globals/quickslots.luau`(HUD 3칸·숫자키·터치) · `globals/inventory.luau`(패널 높이 226, [1][2][3] 놓기, 방울 상세에만 확률) · `town/monsters.luau`(방울 날아가기·포획 연출·체력 30% 이하 작은 방울 표시) ·
  공방 bells.js/captureTab 확률표 = 체력 가득~거의 없음.
- 남은 것: 이로치 그림, 모바일에서 단축칸 위치가 조작 버튼과 겹치는지 확인.  (그림: 방울 5단계 아이콘 · 던지는 방울 · 룬 문양 원 · 목에 단 방울)
- items: 방울 5종(+속성·잘 만든 변형은 M6), 스타터 방울 지급(마이그레이션).
- 처치 시 1등에게 `CaptureOffer`(10초, 몬스터 정보 + 방울별 확률). 나머지 참여자 "포획 불가" 표시.
- 클라 선택창: [재료 받기] + 방울 목록(개수·확률) → `CaptureTry(bellId)`. 서버가 확률 공식으로 굴림(GAME_DESIGN §3).
- 성공: 펫 개체 생성 → 상자, 도감 잡았음. 실패: 몬스터 도망 연출, 시도자 재료 없음. 시간 초과 = 재료.
- 스폰 시 이로치 1/2048 판정(표시는 이로치 팔레트가 생긴 뒤 — 공방 작업).
- 확인: 확률 표시 = 서버 확률, 실패 시 재료 없음, 다른 참여자 재료 정상.

### M3. 펫 ✅ (코드 2026-10-01 — Studio 확인 대기)  (그림: 펫은 기존 몬스터 시트 재사용, 목 방울 오버레이)
- 한 일: `pets.SlotCount(레벨, Paid)`(1 + Lv20 + 유료 ≤ 4) · 서버 `petService.luau`(PetAction Add/Remove/Lead/Release, PetsUpdated) ·
  잡으면 파티 빈 칸에 자동 추가 · 클라 `globals/petBox.luau`(몬스터 상자: 함께 다니기 4칸 · 박스 6x5 · 함께/상자로/대표로/놓아주기 두 번 확인) ·
  `town/pets.luau`(내 파티 전부 발자취 따라오기, 남에겐 캐릭터 필드 PetLead로 대표 1마리, 목에 방울) · HUD 발바닥 버튼(공방 ui.js icon paw).
- 지금은 파티 편성을 어디서나 할 수 있음(마을 상자에서만 할지는 추후).
- 상자 UI(박스 30칸 × 8, 놓아주기 확인창) · 파티 편성(마을 상자에서) · 슬롯 해금(1 기본, Lv20 → 2).
- 소환: 내 펫 전부를 내 화면에서 따라다니게(클라 계산). 다른 사람에겐 대표(파티 1번) 1마리만 — 캐릭터 필드로 대표 펫 정보 복제.
- 확인: 2인 테스트로 내 화면 4마리/상대 화면 1마리.

### M4. 패시브 스킬 ✅ (코드 2026-10-01 — Studio 확인 대기)
- 한 일: 공방 `tools/export_fx.mjs`(종마다 고른 이펙트 팩 장면 → `assets/fx/fx1~4.png` 1024 시트 + `shared/data/petSkills.generated.luau`) ·
  `tools/write_fx_ids.mjs` → `shared/config/fxAssets.generated.luau`(업로드 완료) · `shared/config/petSkills.luau`(패턴 확률·배율·거리, Power/Damage/SkillOf) ·
  `townMonsters` 피해 함수 하나로(dealDamage — 기여도·반격·처치) + OnPlayerAttack 훅 · Living · Damage ·
  서버 `petSkillService.luau`(공격마다 파티 펫별 쿨타임 0.8초·확률 → PetSkill 연출 + 피해 source "pet:<종>" / buff는 체력 덜 찼을 때만 회복) ·
  packets PetSkill · 클라 `town/petFx.luau`(패턴별 연출: 펫 자리에서 날아감·둘레·회전·내리꽂기·버프, 맞은 몬스터에 그 종 맞음 이펙트) ·
  `town/monsters.luau`(펫 피해는 베기 없이 하늘색 숫자, Feet) · `town/pets.luau`(PetPosition).
- 이펙트를 바꾸려면: 공방 `js/monsterFx.js` PICK 수정 → `node tools/export_fx.mjs` → fx 시트 다시 업로드 → `write_fx_ids.mjs`.
- 남은 것: 스킬 수치 초안 사용자 확인, 다른 사람 화면에서는 대표 펫 외 펫 스킬이 주인 발에서 나가 보임(펫이 안 보이므로).
- 공격 1회마다 서버가 파티 펫별 발동 판정 → 피해(주인 기여도에 합산) → 씬에 연출 이벤트.
- 5패턴(투사체·주변 원형·회전·낙하·버프) 구현, 종별 스킬 표(우선 [제안] 자동 배정 → 사용자 확인).
- 공방: 무기 도감처럼 "스킬 도감/미리보기" 탭 추가(패턴·VFX 확인용).

### M5. 무기 ⬜  (그림: 무기 목록 아이콘·착용 모습, 등급 테두리 색)
- items: 무기에 등급·착용 레벨·공격력(등급별)·액티브 스킬. 장비 인벤토리에 개체 형태(등급 포함)로 저장.
- 대장간 제작(레어 고정) · 드롭(GAME_DESIGN §6 확률, 몬스터 레벨 근처) · 액티브 스킬 버튼(PC 키 + 모바일 버튼).
- 필요 결정: 무기 목록·액티브 스킬(§13) — 시작 전에 사용자와 정하기.

### M6. 맺음석 생활 콘텐츠 ⬜  (그림: 맺음석 5단계, 광맥, 곡괭이, 세공사 NPC, 속성 방울)
- 광맥 오브젝트(공용, 재생) · 곡괭이 등급 · 캐기/세공 숙련도 · 세공사 NPC(방울 제작, 속성 방울, 잘 만든 방울).
- 필요 결정: 광맥 재생 시간·숙련도 곡선(§13) — [제안]으로 시작 가능.

### M7. 진행 · 소셜 ⬜
- 튜토리얼: 스타터(불·물·풀) 선택 + 스타터 방울 → 첫 전투 → 첫 포획.
- 파티(최대 3, 경험치 +10%) · 1:1 거래창(양쪽 확인 2단계, 몬스터 제외) · 칭호(이름 위) · 체육관 1곳(인스턴스, 배지+칭호).
- 필요 결정: 지역·체육관 구성(§13).

### M8. BM ⬜
- 개발자 상품: 펫 슬롯 3·4, 레벨업 사탕 등. 구매 처리는 서버 `ProcessReceipt`(중복 지급 방지).

## 공통 원칙
- 판정·확률·보상은 전부 서버. 클라이언트는 표시·연출만.
- 새 저장 필드는 마이그레이션으로만. 펫 상자는 촘촘한 배열로(DataStore 안전).
- 한 씬 20~30명 기준으로 이벤트 빈도·크기를 점검(펫 위치는 복제하지 않음).
- 단계마다 공방 미리보기로 그림 먼저 확인받고, 코드 끝나면 Studio 체크리스트.
