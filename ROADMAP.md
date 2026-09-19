# 슬래시 RPG — 장기 구현 로드맵

> **이 문서의 목적**: 세션이 바뀌어도(컨텍스트가 리셋되어도) 여기서부터 이어서 작업할
> 수 있도록, 지금까지 뭘 했고 뭘 참고했고 다음에 뭘 할지를 기록한다. 새 세션을 시작할
> 땐 이 파일부터 읽는다.
>
> **참고 프로젝트**: [Cheruton](https://github.com/abnermtj/Cheruton) (Godot 3.2.1,
> GDScript, 2D 사이드스크롤 RPG — NUS Orbital 2020 Honorable Mention). 우리 게임과
> 장르/시점(2D 사이드뷰)·콘텐츠 구성(마을+던전+몬스터+상점+장비)이 매우 비슷해서 전반적인
> 설계 참고용으로 깊게 조사했다. 단, Cheruton은 **싱글플레이어·로컬 프로세스** 게임이고
> 우리는 **서버 권위 멀티플레이어**(Roblox)라, 그대로 베낄 수 없는 부분이 많다 — 각
> 항목마다 "그대로 되는지/재설계가 필요한지"를 명시한다. 실제 조사 근거(코드 발췌)는 이
> 세션의 대화 기록에 있고, 여기엔 결론과 우리 프로젝트용 작업 항목만 정리한다.

## 지금까지 완료된 것 (Phase 0)

- 플레이어 캐릭터: 이동/점프/idle/run/attack 애니메이션, 서버에 위치/공격 신고
  (`heroTracking.luau`), client-authoritative 리플리케이션(공식 문서 패턴 확인·검증됨).
- 포탈: 씬(마을 "village" ↔ 사냥터 "Backfield") 간 이동, "포탈은 통로" 개념(돌아가는
  포탈 위치로 스폰), 마커 네이밍 컨벤션(`Portal_<대상씬>`, `Spawn`).
- 첫 몬스터 "Sprout Grub": **서버 권위**로 재설계 완료(공식 문서 Replication
  Guide/Authority System 패턴) — 서버가 만들고 움직이면 자동 복제, 클라이언트는 순수
  뷰어. 마커 여러 개(`Monster_SproutGrub` 접두사) = 스폰 지점 여러 개(메이플스토리식),
  각자 순찰/어그로/공격/피격/사망/리스폰(3~4초) 독립 처리.
- 전투 기초: 방향성 있는 사거리 판정(정면 앞쪽만, 수직 범위 제한), 임팩트 프레임 기반
  판정 타이밍(OpenMMO 참고 — 애니메이션 끝이 아니라 스윙 중간에 판정), 체력바(몬스터
  머리 위, 클라이언트 로컬 UI), 데미지 숫자 팝업(알파 페이드 방식), 죽을 때 페이드아웃.
- HUD: HP/MP/EXP 바(숫자만 표시, 진짜 마나/경험치 콘텐츠는 아직 없음), 인벤토리 그리드
  UI(자리표시자, 서버 연동 스켈레톤만 — `playerData.luau`에 레벨/경험치/인벤토리
  DataStore 저장 뼈대 있음).
- 엔진 버그 수정: `CanCollide=false`인 상대(몬스터)와 겹친 상태에서 플레이어가 위아래로
  계속 튀던 버그 — `GetCollidingObjects.luau`가 CanCollide 체크 없이 무조건 velocity를
  깎아버려서, 그 뒤에 검사하는 진짜 바닥과의 충돌 계산이 오염되던 게 원인. 실측(라이브
  좌표 로깅)으로 확인 후 CanCollide=false 쌍은 이벤트 기록용으로만 남기고 velocity 계산엔
  관여 안 하도록 패치(`Packages/UpsideEngine/Lib/Util/Geometry/GetCollidingObjects.luau`).

## Cheruton 조사 핵심 요약 (전체 조사 내용은 세션 로그 참고)

| 영역 | Cheruton 패턴 | 우리 프로젝트 적용 여부 |
|---|---|---|
| 데미지 숫자 | 스케일로 등장/축소(팝업 0.3배→0.1배), 알파 페이드 없음, 위+랜덤 좌우 이동, ~0.7초 | 참고해서 스타일 다듬기 (Phase 1) |
| 체력바 | **이중 바**(빠른 바 즉시, 느린 바 1.5초 큐빅 이즈로 뒤늦게 하락 — "깎여나가는 잔상") | 그대로 이식 (Phase 1) |
| 피격 반응 | **히트스탑**(0.04초 전체 정지) + 카메라 흔들림 + 넉백 | 그대로 이식 (Phase 1) |
| 공격 판정 | 프레임 % 계산이 아니라 **실제 히트박스가 특정 프레임 구간에만 켜짐**(범위 있음) | 임팩트 프레임 "점" 판정 → "구간" 판정으로 개선 (Phase 1) |
| 콤보 | 공격 애니메이션 후반 50%에 다시 입력하면 다음 콤보로 연결(입력 버퍼링) | 나중에 (Phase 6, 무기/스킬 확장과 함께) |
| 상태 머신 | FSM 노드가 자식 상태를 이름으로 자동 탐색, `changeState(name)` 신호로 전환 — 순수 플러밍 40줄 | 개념만 참고(모듈 기반으로 이미 유사하게 구현 중), 몬스터 종류 늘어나면 공용 FSM 유틸로 추출 고려 (Phase 6) |
| 저장/영속성 | **로컬 싱글톤** DataResource, 임시 dict에서 작업 후 명시적 커밋, 수동 저장 트리거 | **재설계 필요**: 서버 DataStore가 진실(이미 `playerData.luau` 스켈레톤 있음), "작업용 사본→커밋"은 유지, 저장 트리거는 서버 자동(주기+중요 이벤트)로 (Phase 2) |
| 아이템 | 마스터 데이터 테이블(정적) + 인벤토리에 필드 복사 저장(denormalized), 카테고리별 탭 | 데이터 구조는 그대로 참고. **장비 ID를 위치 인코딩(카테고리*100+인덱스)한 부분은 이식 금지** — 명시적 ID/UUID 써야 함(서버 검증·거래 대비) (Phase 3) |
| 상점/루팅 | 몬스터별 루팅 테이블(아이템별 확률/수량), 상점은 "스테이지"별 판매 목록 | 그대로 참고 가능 (Phase 3) |
| UI 구조 | **스택 기반 팝업 매니저** — 최상단만 입력 받음, 특정 팝업이 스택에 있으면 자동 일시정지, "대화 중엔 다른 팝업 금지" 모드 | 그대로 이식(단, "일시정지"는 클라 로컬 개념으로 — 서버는 안 멈춤) (Phase 4) |
| NPC/대화 | 정적/이동 NPC 공용 베이스 클래스, 순찰은 레이캐스트로 낭떠러지/벽 감지, 대화는 NPC 이름으로 레코드 조회 + 타자기 효과 | 순찰 로직은 몬스터 시스템과 유사하게 재사용 가능. 대화 에디터는 없으므로 직접 설계 (Phase 5) |
| 퀘스트 | **Cheruton 자체에 없음**(완료 여부 불리언 플래그 몇 개가 전부) | 우리가 처음부터 설계해야 함 (Phase 5, 낮은 우선순위) |
| 보스전 | 공격 상태 자체가 **예비동작→실제동작→회복(ANTICIPATION→ACTION→RECOVER)** 하위 단계 + 텔레그래프(예고 동작) + 원거리 투사체 | 서버 몬스터 AI에 그대로 적용 가능한 핵심 패턴 (Phase 6) |
| 카메라 | 흔들림, 이동 방향 전환 시 룩어헤드, 레벨마다 마커로 경계 설정 | 그대로 이식(클라이언트 로컬 개념이라 멀티플레이 이슈 없음) (Phase 7) |
| 사운드 | 중앙 매니저 없음 — 버스(Master/Music/SFX) 볼륨 + 각 스크립트가 알아서 로컬 사운드 재생 | 그대로 참고(Roblox SoundService/SoundGroup으로) (Phase 8) |
| 폴더 구조 | **기능(엔티티)별로 폴더 소유** — Player/Enemy/Level 각자 자기 UI·사운드·이펙트까지 포함. client/server 분리축과는 직교 | client/server 축은 유지하되, 그 *안에서* 기능별 하위 폴더 구조 채택 고려 (Phase 9, 리팩토링) |

## 로드맵 (순서대로 진행)

### Phase 1 — 전투 타격감 (Combat Juice) [진행 중]
- [x] 카메라 흔들림 유틸(`client/modules/globals/camera.luau`의 `Shake(duration, amplitude)`
      — Camera 클래스의 공개 필드 `OffsetPosition` 활용, CameraTracker 추적 로직에
      영향 안 줌) — 플레이어 피격(강하게)/몬스터 피격(약하게) 때 호출 연결 완료
- [x] 몬스터 넉백: 맞은 반대 방향으로 즉시 좌표 이동(`sproutGrub.luau`,
      `KNOCKBACK_DISTANCE`) — 물리를 안 쓰는 몬스터라 속도가 아니라 좌표 직접 조작
- [x] 체력바 이중 바(빠른 바 즉시 반영 + 느린 바가 1.5초에 걸쳐 목표치로 하락)로 개선
      완료(`monsterHealthBar.luau`)
- [x] 데미지 숫자를 스케일 팝업+축소 방식으로 교체 완료(`damageNumbers.luau`) — 알파
      페이드 대신 UIScale로 커졌다 작아지며 사라짐, 좌우 랜덤 드리프트
- [x] 플레이어 HUD 체력바도 동일하게 이중 바 적용 완료(`hud.luau`의
      `createDualFillOverlay` — monsterHealthBar.luau와 동일한 1.5초 감쇠 로직)
- [x] ~~히트스탑~~ / ~~플레이어 넉백~~ — 둘 다 구현했다가 **되돌림**. 넉백이
      `hero.Velocity.X`를 바꾸면서, 키를 안 누르고 있을 때 velocity로 facing을 정하는
      로직이 넉백 방향으로 캐릭터를 휙 돌려버렸고, 그 상태로 다음 공격 신고가 잘못된
      facing으로 서버에 전달돼 사거리 판정에 실패해 데미지 숫자도 안 뜨는 연쇄 버그로
      이어짐(실측 확인). 이 게임엔 둘 다 불필요하다고 판단해 제거. 대신 맞았을 때
      캐릭터가 잠깐 회색으로 3번 깜빡이는 것으로 대체(`heroController.luau`의
      `playHitFlash`, `ImageColor3` 토글)
- [x] 공격 판정을 "임팩트 프레임 한 점"이 아니라 "임팩트 프레임 근처 몇 프레임 구간"으로
      넓힘 완료 — `heroController.luau`가 `ATTACK_IMPACT_WINDOW_FRAMES`(3프레임) 동안
      매 프레임 신고하고, `sproutGrub.luau`가 `HIT_COOLDOWN`(0.2초)으로 같은 스윙의
      중복 신고를 걸러 데미지가 한 번만 들어가게 함

### Phase 1 완료 — 다음은 Phase 2(플레이어 영속성 재설계)

### Phase 2 — 플레이어 영속성 재설계
- [x] 기존 `server/modules/playerData.luau` 스켈레톤을 실제 게임플레이와 연동 — 몬스터
      처치 시(`sproutGrub.luau`, 마지막으로 때린 플레이어) `playerData.AddExperience`로
      경험치 지급(20), 레벨업 처리(필요 경험치 = 100 + (레벨-1)*50), `StatsUpdated`
      RemoteEvent로 클라이언트 hero 필드(Level/Experience/MaxExperience) 갱신, 레벨업
      시 체력 회복(`playerStats.luau`). 씬 이동마다 hero가 새로 만들어지므로 씬 전환 시
      서버에서 최신 값을 다시 받도록 unload에서 started 플래그 초기화.
      레벨에 따른 MaxHealth 성장 완료(100 + (레벨-1)*20, `playerStats.luau`), 테스트용
      임시 체력 1000 제거. 레벨업 연출(`levelUpEffect.luau`), 씬 로딩 블랙아웃
      (`loadingScreen.luau`, `sceneLoader.luau`)도 이 단계에서 추가됨.
      현재 체력도 저장/복원함(포션 도입 전에 "포탈 타면 회복되는" 버그성 플레이 차단) —
      클라이언트가 체력이 바뀔 때마다 `ReportHealth`로 서버 세션에 알리고
      (`playerData.luau`, 최대 체력 공식은 클라 `playerStats.luau`와 중복 정의돼 있으니
      바꿀 땐 둘 다 수정), 새 hero가 만들어질 때 저장된 체력을 이어받음. 죽어서
      리스폰하면 가득 채워서 시작.
- [x] "작업용 사본에서 수정 → 커밋" 패턴 유지, 저장 트리거를 서버 자동(주기 배치저장은
      이미 있음 + 로그아웃 시 즉시저장도 이미 있음 — 그대로 유지, Cheruton처럼 수동
      키입력 저장은 필요 없음)
- [x] 레벨업 시 스탯 증가 공식 설계(Cheruton의 "장비 스탯으로 서서히 수렴" 방식은
      비추천 — 더 단순하고 예측 가능한 공식으로)

### Phase 3 — 아이템/인벤토리/장비
- [x] 아이템 마스터 데이터 테이블 — `shared/data/items.luau`(이름/타입/StackMax/설명/
      Icon). 공격력/방어력은 장비 항목 추가할 때 같이 확장. Icon은 비워두면 UI가 이름
      앞 두 글자로 대신 표시 — 이미지 에셋 오면 Icon만 채우면 됨
- [x] 인벤토리 저장 = `{Slot, ItemId, Count}` 촘촘한 배열(DataStore는 희소 숫자 키
      테이블을 못 저장함), 아이템 ID는 명시적 문자열, 서버 `playerData.AddItem`이 스택/
      빈 칸 처리 + `InventoryUpdated`/`ItemAcquired` 전송, 클라 인벤토리 UI 반영 +
      획득 토스트. 로드 시 서버에서 현재 인벤토리를 직접 받아옴(접속 직후 이벤트 유실 버그 수정)
- [x] 몬스터별 루팅 테이블(확률/수량) — `shared/data/lootTables.luau`, 새싹벌레 죽을 때
      마지막으로 때린 플레이어에게 `RollLoot`로 지급. (미완: 골드 드롭 — 골드 화폐/UI는
      상점 단계에서 같이)
- [x] 장비 착용/해제 + 공격력/방어력 반영 — 아이템에 `EquipSlot`(Weapon/Armor)/`Attack`/
      `Defense`, 서버 `playerData.Equip/Unequip`(교체·가방 가득 참 처리, `EquipAction`/
      `EquipmentUpdated` 리모트, `data.Equipment` 저장), 전투는 서버가
      `GetAttackDamage`(기본 10+무기)/`GetDefense`(몬스터 피해에서 차감, 최소 1)로 계산.
      UI: 가방(인벤토리)에서 장비 아이템을 누르면 착용, 메뉴의 칼 교차 아이콘으로 여는 별도 장비 탭(`equipment.luau`)에 착용 장비 슬롯(누르면 해제)+능력치(레벨/체력/공격력/방어력) 표시(드래그앤드롭은 미구현). 나무 검/
      잎사귀 갑옷은 새싹벌레가 8% 확률로 드롭
- [x] 골드 화폐 — `data.Gold` 저장, `GoldUpdated` 리모트, 새싹벌레 골드 드롭(3~8),
      인벤토리 패널에 표시, 획득 토스트. (메뉴의 "상점" 아이콘은 일반 상점이 아니라 나중에
      개발자 상품을 파는 캐시샵용 — 골드로 사고파는 상점은 만들지 않음. 골드 사용처는
      NPC 도입 이후 필요해지면 그때 설계)

### Phase 4~8 — 범위 밖(확장하면서 필요할 때 개발)
- 4(팝업 스택/설정 메뉴)는 필요한 부분(스택 매니저, 설정 볼륨)까지만 구현 완료. "대화 중 팝업 잠금"은
  불필요 — 채팅/대화는 로블록스 기본 채팅을 쓴다.
- 5(NPC/대화/퀘스트), 6(몬스터 다양화/보스/콤보), 7(씬/레벨 확장), 8(오디오)은 콘텐츠를 늘려가면서
  그때그때 개발한다. 지금 계획에서 다루지 않는다.

### 구조 개편 (온라인 MMORPG 구조로) — 점검 결과와 계획
참고: Ryzom Core(ryzomcore). 서비스가 역할별로 분리돼 있다 — EGS(Entities Game Service: 캐릭터/아이템/
전투/미션의 **서버 권위** 상태), AIS(몬스터 AI), Frontend Service(클라 입력 검증 + 시야 내 엔티티만 전송),
Persistent Data(저장), sheets(아이템/크리처/드롭 등 **데이터 파일**로 정의), Mirror(서비스 간 상태 공유).
Roblox는 서버 하나라 "서비스 = 서버 모듈"로 매핑한다. 원칙: (1) 서버가 모든 게임 상태의 진실,
(2) 게임 규칙/수치는 코드가 아니라 데이터, (3) 클라이언트 입력은 전부 검증, (4) 같은 값을 두 곳에 정의 금지.

점검에서 나온 문제(우선순위 순):
1. **클라이언트 신뢰(치트 가능)** — 체력을 클라이언트가 직접 깎고 서버에 보고(`ReportHealth`), 위치/공격 위치·방향을
   클라이언트가 보고(`heroTracking`, 검증 없음), 공격 속도 제한 없음(몬스터별 0.2초 쿨다운뿐), 사망/리스폰/씬 이동/
   플레이어가 있는 씬 판정도 클라이언트 보고에 의존. → 플레이어 상태(체력/위치/씬)를 서버가 소유하고, 클라이언트는
   "입력"만 보낸다. 공격은 서버가 쿨다운·사거리 검증, 이동은 속도 상한 검증, 씬 이동은 서버가 승인.
2. **하드코딩 중복** — 최대 체력 공식(클라 `playerStats` + 서버 `playerData`), 기본 공격력(서버 + 클라 `equipment`),
   인벤토리 칸 수(서버 16 + 클라 4x4), 몬스터 시트 에셋 ID(서버 `sproutGrub` + 클라 `monsterHealthBar`), 씬 이름
   ("village"/"Backfield" 문자열이 여러 파일), 몬스터 수치·스프라이트·판정 상수가 `sproutGrub.luau` 안에 통째로.
   → `shared/config`(밸런스 상수)와 `shared/data`(몬스터/아이템/드롭/씬 정의)로 한 곳에 모으고 양쪽이 같은 걸 읽는다.
3. **몬스터가 종류별 파일 하나** — 새 몬스터마다 복붙하게 된다. → 공용 몬스터 서비스(AI 상태 머신, 스폰/리스폰,
   판정) + 몬스터 정의 데이터(스탯/시트/드롭 표)로 분리(Ryzom의 AIS + creature sheet 구조).
4. **`playerData.luau` 하나에 전부**(저장+스탯+인벤토리+장비+골드+경험치, 550줄) → 저장(Persistence), 스탯/성장,
   인벤토리/장비/재화 서비스로 분리. 저장 데이터에 **스키마 버전**과 마이그레이션 훅 추가(지금은 필드 추가 때마다
   임기응변으로 `or {}` 처리).
5. **네트워크 계층 없음** — RemoteEvent가 여러 모듈에서 제각각 생성/이름 문자열 사용, 입력 검증/요청 빈도 제한이 없다.
   → 중앙 Net 모듈(리모트 정의 한 곳, 인자 검증, 요청별 rate limit). (Punch-RPG의 NetController 패턴)
6. **관심 영역(relevancy) 없음** — 서버 몬스터가 모든 클라이언트에 복제된다(마을에 있어도 사냥터 몬스터 정보 수신).
   씬이 늘면 대역폭이 그대로 늘어난다. 이미 씬 이름 숨김(`__ServerOnly`)으로 이름 충돌만 피한 상태. → 씬 단위로
   복제 대상 제한(Ryzom Frontend Service의 시야 기반 전송에 해당).
7. **사망/리스폰 처리가 클라이언트** — 서버가 사망 판정을 하고 리스폰 지점/패널티를 결정해야 한다.
8. **경험치/드롭 귀속** — 마지막으로 때린 사람 한 명만. 파티/기여도 분배는 확장 항목.
9. **엔티티 식별** — 몬스터 종류를 이미지로 구분하는 임시방편(`MonsterKind` 필드가 복제 안 되는 원인 미해결).
   → 복제되는 필드가 무엇인지 파악해 정식 식별자 확보 또는 서버가 종류 정보를 별도 이벤트로 전달.

**UpsideEngine 공식 문서 확인 결과 (Replication Guide: Authority System / Server Setup / Client Setup / How it works,
NetworkingService·AuthorityService 문서, 공식 멀티플레이어 데모 `notreux/UpsideEngineMultiplayerDemo`, 엔진 소스
`Classes/Internal/Request.luau`) — 개편 방향은 이 범위 안에서만 잡는다:**
- 플레이어 캐릭터는 **클라이언트 권위**가 공식 권장 패턴이다("Assign client authority to player-controlled
  characters for smooth gameplay"). 서버는 `ReplicationRequest`를 받아 `request:Accept()`로 서버 쪽 복사본을 만들고
  `authorityService:SetAuthority(character, "Client")`를 한 번 건다. **`characters[player]`로 추적하는 것이 문서의
  "production" 패턴**이다. → 우리 `server/modules/replication.luau`는 `Approve()`만 부르고 있어 서버가 플레이어의
  캐릭터 복사본을 갖지 않는다(그래서 위치/공격 위치를 별도 RemoteEvent로 받고 있었다). 문서대로 `Accept()`+권위 지정+
  플레이어별 추적으로 바꾸면 서버가 이미 복제된 복사본에서 위치를 직접 읽을 수 있다(`ReportHeroPosition` 불필요).
  ※ 우리가 예전에 Approve만 쓰게 된 이유(서버 복사본 관련 부작용)가 있었는지 Studio에서 진단으로 먼저 확인할 것.
- **위치를 매번 검증/거절하는 것은 문서가 명시적으로 비권장** ("aggressive validation can cause lag or false positives",
  "Rejection should be rare"). 문서의 검증 방식은 **중요한 행동(데미지, 아이템 획득 등)만 RemoteEvent로 서버가
  검증**하는 것. → 이동은 클라이언트 권위 유지 + (선택) 텔레포트급 이상치만 서버가 감지. 공식 데모의 `attackManager`처럼
  **공격은 클라이언트가 "방향/의도"만 보내고 서버가 서버 쪽 캐릭터 복사본 위치로 판정**한다.
- **서버가 잠깐 권위를 가져오는 것은 문서가 허용**("Temporary server control is acceptable for knockback, teleportation,
  and crowd control") — 리스폰/씬 이동 같은 강제 이동은 `SetAuthority(character, "Server")` → 위치 설정 → `"Client"`
  복귀로 서버가 수행 가능. 단 "권위를 자주 바꾸지 말 것"(동기화 문제).
- 서버 소유 오브젝트(NPC/몬스터/월드)는 서버 권위가 기본이고 자동 복제("no ReplicateOnChange() needed") — 지금 몬스터
  구조는 문서와 일치.
- 공식 데모는 RemoteEvent에 **Remo + t(타입 검증)** 라이브러리를 쓴다(`shared/packets.luau`에 리모트를 한 곳에 정의하고
  인자 타입 검사). 우리는 wally를 안 쓰므로 같은 개념(리모트 정의 한 곳 + 인자 타입 검사)을 직접 만든다.
- 문서에 **없는 것**: 수신 대상 필터링(관심 영역), 복제 요청 수정/필터링 API, `ReplicationPerSecond` 상세.
  → F단계(관심 영역)는 엔진이 지원하는지부터 소스로 확인해야 하고, 지원이 없으면 "씬 이름 규약 + 클라이언트 쪽
  무시" 정도로 범위를 줄인다.

수정된 진행 순서(문서 기준):
A) [완료] 설정/데이터 한 곳으로 — `shared/config/balance.luau`(최대 체력·경험치 공식·기본 공격/방어·인벤토리 칸 수), `shared/config/scenes.luau`(씬 이름), `shared/data/monsters.luau`(몬스터 정의: 스탯/시트/판정 범위, 클라 식별용 시트 목록 자동 수집)
B) [완료] 리모트 정의 한 곳 + 인자 타입 검사 + 요청 빈도 제한 — `shared/net/packets.luau`(정의), `shared/net/net.luau`(Net.OnServer/FireClient/FireAllClients, Net.FireServer/Invoke/OnClient). 기존 리모트 이름은 그대로라 Studio의 ReplicatedStorage.Remotes 구조 동일
C1) [완료] 위치 보고 제거 — 서버가 히어로 복제 요청(ReplicationRequest)의 내용에서 위치를 직접 읽음(`replication.luau` → `heroTracking.OnHeroReplicated`), 공격은 방향만 받고 서버가 아는 위치로 판정 + 서버 공격 간격 검증(`balance.ATTACK_COOLDOWN`), 씬은 씬 진입 시 1회 보고(`ReportHeroScene`, C3에서 서버 승인 방식으로 대체 예정). C2) [완료] 체력/피해/사망/레벨업 회복을 서버 세션이 소유 — `playerData.DamagePlayer`, `PlayerHealthChanged` 패킷(health,maxHealth,damage,died), 클라이언트 `ReportHealth`/`MonsterAttackedPlayer` 제거, 클라는 서버 결과를 반영하고 연출/리스폰 이동만 수행(리스폰 위치/씬 결정은 C3에서 서버로). C3) [완료] 씬 이동 서버 승인 — 클라 `RequestTravel` → 서버 `travelService`가 서버 소유 플레이어 씬(`heroTracking`, 접속 시 마을·사망 시 마을)과 포탈 위치(`Portal_<목적지>` 사각형 vs 서버가 아는 히어로 위치)를 검증 → `TravelApproved`로 클라가 실제 전환, `ReportHeroScene` 제거. ※ 엔진이 클라이언트 권위라 클라가 로컬로 씬을 바꿔도 서버의 씬 정보는 그대로여서 몬스터/공격/드롭에는 영향이 없다. (Accept 전환은 엔진 사본이 권위가 Server인 오브젝트의 후속 요청을 걸러내는 점 때문에 SetAuthority 검증과 함께 보류)
C) [원안] 서버가 플레이어 캐릭터 복사본을 추적(`Accept`+`SetAuthority(Client)`+`characters[player]`) → 위치 보고 제거,
   공격은 의도만 받고 서버 복사본 위치로 판정 + 공격 쿨다운 서버 검증, 체력/사망/리스폰은 서버 세션이 진실(클라이언트는
   서버 이벤트로만 체력 변경), 강제 이동은 임시 서버 권위
D) [완료] `playerData` 분리 — `server/services/`: persistence(저장/로드/세션 락/오토세이브), playerSchema(저장 형태 + SchemaVersion 마이그레이션), progressionService(경험치/체력/사망), inventoryService(인벤토리/장비), currencyService(골드), lootService(드롭); `server/modules/playerData.luau`는 접속/퇴장 + Net 연결만
E) [완료] 공용 몬스터 서비스 + 몬스터 정의 데이터 — `server/services/monsterAI.luau`(종류 무관 AI: 스폰/순찰/어그로/공격/피격/사망/리스폰/드롭), `server/modules/monsterSpawner.luau`(`shared/data/monsters.luau`의 모든 정의를 자동으로 돌림), `sproutGrub.luau` 삭제. 새 몬스터 추가 = monsters.luau에 정의 + lootTables에 같은 키 드롭 표(코드 수정 불필요)
F) [완료] 관심 영역(씬 단위) — 엔진 사본(`Runtime/Networking.luau`, `Services/NetworkingService.luau`)에 `RelevancyFilter`/`ResyncClient` 훅 추가(엔진 미지원이라 패치), `server/modules/relevancy.luau`가 서버 소유 오브젝트(몬스터)를 플레이어가 있는 씬에만 복제하도록 필터 등록, 씬 이동 시 `travelService`가 새 씬 오브젝트를 재동기화. 플레이어 캐릭터도 같은 씬일 때만 전달 + `RemoveReplicated`로 씬이 갈라진/새로 만들어진 캐릭터의 옛 사본 제거(유령 방지) + 죽은 몬스터 캐시 정리(재동기화 시 유령/크래시 방지). 별도로 로컬 히어로는 다른 Character와 물리 충돌하지 않음(`SkipCharacterCollisions`, 엔진 사본 패치)

### Phase 9 — 구조 정리 (위 "구조 개편"으로 대체)
- [x] 위 A~F 단계 전부 완료(진행 상황은 여기 체크박스로 갱신)
