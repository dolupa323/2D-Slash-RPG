-- 늘 보이는 화면과 창의 치수 — 화면 틀의 고운 격자(1080p에서 960x540)에서의 값. 그리지는 않는다: 화면(client/lune/hud.luau · chat.luau · partyHud.luau · questHud.luau · ui/*Window.luau)과
--  자동 검사(tools/test/tests/14_lune_hud.luau · 15_lune_items.luau)가 같은 값을 쓰게 한데 모아 둔 것이다.
--  숫자는 여기서 적지 않는다 — 모두 공방에서 온다(사용자 2026-10-07: "공방에서 횡스크롤 시험 탭에서 먼저 구현해보고 느낌보고 게임에 반영하는 순서로 하겠습니다"):
--   칸의 자리(붙는 구석과 x · y · w · h) = 공방 「기본 · UI」 탭(data/ui.generated.luau의 hud) · 치수 = 공방 js/lune/design/ui.js의 UILAYOUT(ui.generated.luau의 layout —
--   공방의 횡스크롤 시험 탭이 같은 값으로 그린다) · 부품의 치수 = 공방의 부품 도구(data/kit.generated.luau의 ui.metric).
local UI = require(script.Parent.Parent.data["ui.generated"])
local KIT = require(script.Parent.Parent.data["kit.generated"])
local M = KIT.ui.metric
local D = UI.layout

local L = {}
L.GRID = UI.grid
L.M = M

-- 화면의 격자가 gw x gh일 때 그 칸의 자리(구석에서의 거리를 지킨다). r = { at, x, y, w, h }
function L.rect(r, gw: number?, gh: number?)
	local w, h = gw or UI.grid.w, gh or UI.grid.h
	local fy = if r.at:sub(1, 1) == "b" then 1 else 0
	local side = r.at:sub(2, 2)
	local fx = if side == "r" then 1 elseif side == "c" then 0.5 else 0
	local out = { x = r.x + math.floor((w - UI.grid.w) * fx + 0.5), y = r.y + math.floor((h - UI.grid.h) * fy + 0.5), w = r.w, h = r.h }
	-- 좁은 격자에서 왼쪽 이웃(tight.beside)에 닿는 칸은 줄어든 폭(tight.w)으로 — 오른쪽 끝은 그대로 둔다.
	--  메뉴 단추: 여덟이 넓은 간격으로는 가장 작은 격자(768)의 스킬 칸에 닿는다
	-- 좁은 격자(폭 narrow.below 미만)에서 가운데는 그대로 두고 폭만 줄이는 칸(스킬 칸 — 칸 사이가 좁아진다 · 2026-10-21)
	if r.narrow and w < r.narrow.below then
		local c = out.x + out.w / 2
		out.w = r.narrow.w
		out.x = math.floor(c - out.w / 2 + 0.5)
	end
	if r.tight then
		local o = L.rect(UI.hud[r.tight.beside], w, h)
		if out.x < o.x + o.w + r.tight.gap then
			out.x += out.w - r.tight.w
			out.w = r.tight.w
		end
	end
	return out
end

-- 게임 세계의 배율 s에서 화면 틀의 배율과 격자(client/lune/stage.luau와 같은 셈)
function L.gridFor(s: number): (number, number, number)
	local us = math.max(1, math.floor(0.4 * s + 0.5))
	return 384 * s / us, 216 * s / us, us
end

-- ---------- 늘 보이는 화면 ----------
L.VITALS = D.vitals -- 왼쪽 아래 덩어리: 윗줄에 레벨 · 이름 / 체력 바(숫자는 바 안) / 가는 경험치 줄과 그 옆의 %
L.SKILLS = D.skills -- 스킬 칸: 두 줄 x 여섯. 칸 위에 키 딱지(높이 keyUp)
L.MENU = D.menu -- 창을 여는 단추: 여덟까지(row의 차례 + 「메뉴」), 오른쪽 끝에 붙여. 그림 아래에 이름(labels = 칸에 맞춘 짧은 이름)
L.PARTY = D.party -- 파티원 칸: 한 사람 = 이름 한 줄 + 가는 체력 줄. ask = 초대 알림(위쪽 가운데)
L.DEATH = D.death -- 쓰러졌을 때 묻는 상자(위쪽 가운데): 제목 · 묻는 글 · 안내 · 단추 하나
L.COUNT = D.count -- 수량 창(화면 가운데 — 2026-10-21): 묻는 글 · [그림] 이름 · [−] [수량 칸] [+] [최대] · 범위 · 합계 · 「사기 · 취소」
L.QUEST = D.quest -- 퀘스트 알리미: 이름 한 줄(본문 글씨) · 할 일 한 줄(작은 글씨) · 퀘스트 사이
L.TAG = D.tag -- 이름표: 한 줄의 높이(쌓을 때) · 발밑에서 아래로 띄우는 만큼 · 가장 넓을 때
L.MOBBAR = D.mobBar -- 졸개의 체력 띠: 크기(화면 틀의 점) · 발밑에서 위로(게임의 도트)
L.GAINLOG = D.gainLog -- 획득 알림(2026-10-18): 줄 수 · 줄 높이 · 머묾 · 흐려짐 · 합치는 초(자리는 UI.hud.gainLog)
L.MAPNAME = D.mapName -- 맵 이름(2026-10-18): 위 가운데(보스 체력 칸의 자리) — 지역(작은 글) · 맵 이름(nameY · 본문 글) · 밝아짐 fadeIn · 머묾 hold · 흐려짐 fadeOut(초)
L.BOSS = D.boss -- 스토리 보스의 체력: 화면 위 가운데 — 이름(y) 아래(barY)에 넓은 바(안에 숫자 · pad = 좌우 여백), 그 아래(patY)에 패턴의 이름

-- 퀵슬롯 i가 놓이는 줄(1 = 아랫줄 · 2 = 윗줄)과 그 줄의 몇째인가 — 공방 QUICK.rows(2026-10-21: 칸의 번호 · 키는 그대로 두고 새 칸 13 · 14를 줄 끝에)
function L.slotCell(i: number): (number, number)
	for r, list in UI.quick.rows do
		local k = table.find(list, i)
		if k then
			return r, k
		end
	end
	return 1, i
end

-- i째 칸의 자리(스킬 칸 틀 안 — 틀은 넓은 격자의 폭 그대로). gw = 화면 틀의 격자 폭: 좁은 격자(스킬 칸의 narrow)에서는 칸 사이가 좁다(10 → 4점).
--  n은 예전의 「쓰는 칸의 수」(지금은 늘 모든 칸 — 받기만 한다)
function L.slotPlace(i: number, _n: number?, gw: number?): (number, number)
	local s, K = UI.hud.skills, L.SKILLS
	local r = L.rect(s, gw)
	local gap = math.min(K.gap, math.floor((r.w - K.cols * K.slot) / (K.cols - 1)))
	local pitch = K.slot + gap
	local row, k = L.slotCell(i)
	local inRow = #UI.quick.rows[row]
	local left = math.floor((s.w - (inRow * pitch - gap)) / 2)
	return left + (k - 1) * pitch, s.h - K.slot - (row - 1) * (K.slot + K.keyUp + K.rowGap)
end

-- 메뉴 단추 아래에 적는 이름(칸에 맞춘 짧은 이름이 있으면 그것)
function L.menuLabel(id: string, name: string): string
	return L.MENU.labels[id] or name
end

-- 화면 틀의 격자 폭이 gw일 때 메뉴 단추의 간격: 그 격자에서의 칸의 폭에서 나온다(넓은 칸 → pitch, 좁은 격자의 칸 → tight)
function L.menuPitch(gw: number?): number
	return (L.rect(UI.hud.menu, gw).w - L.MENU.slot) / (L.MENU.max - 1)
end

-- n개 가운데 i째 단추의 x(메뉴 칸 틀 안 — 틀은 넓은 칸의 폭 그대로이고 단추는 오른쪽 끝에 붙는다). gw = 화면 틀의 격자 폭
function L.menuX(i: number, n: number, gw: number?): number
	local p = L.menuPitch(gw)
	return UI.hud.menu.w - (n - i + 1) * p + (p - L.MENU.slot)
end

-- ---------- 창(화면 오른쪽 · 왼쪽의 옆 판) ----------
L.WIN = D.win -- 판에서 속까지: 옆으로 pad, 위로 head(제목 줄), 아래로 foot. edge · top = 화면 끝에서 띄우는 폭
L.BAG = D.bag -- 가방: 칸 여섯 x 넷(세 탭 모두 칸). 탭 줄(gridY) 아래에 칸, 그 아래 footH에 단추 줄(정렬 · 칸 늘리기)과 지갑(달돈 · 달가루 · 정수)
L.DETAIL = D.detail -- 아이템 상세(창 옆의 작은 판): 그림 칸과 이름 · 갈래 · 줄(이름과 값) · 알림 글 · 단추
L.STORE = D.store -- 창고: 가방과 같은 짜임 — 탭 줄(gridY) 아래에 칸, 그 아래 footH에 「정렬」(sortW)과 안내 글
L.EQUIP = D.equip -- 장비 창: 왼쪽 = 칸 하나 + 글(textW), 오른쪽 = 장신구 네 칸
L.SHOP = D.shop -- 상점의 한 줄: [아이콘 칸 iconS] 이름(nameW) · [달돈 그림] 값(priceW) · 사는 단추(buyW)
L.AUCTION = D.auction -- 경매장(넓은 창): 탭 셋 · 분류 단추 · 목록의 줄 · 판매 양식 · 아래의 알림 줄 — 공방 js/lune/design/ui.js의 UILAYOUT.auction
L.CINE = D.cine -- 퀘스트 연출(장면 — 2026-10-15): 장의 이름 · 보스의 이름 · 종이 · 「건너뛰기」의 자리(공방 js/lune/design/ui.js의 UILAYOUT.cine)
L.DAILY = D.daily -- 일일 의뢰: 머리글(top) 아래 의뢰마다 한 칸(row — 맵의 이름 · 의뢰의 이름 · 오른쪽 단추 btnW · 진행 띠 barH), 가르는 줄 아래 보상 두 줄(payRow — 이름표 labelW)
L.ATTEND = D.attend -- 출석(2026-10-15): 머리글(top) · 칸 cols x rows(cell · gap) · 가르는 줄 아래(lineY) 받을 것 한 줄(rowH) · 안내와 「받기」(btnW)
L.DUNGEON = D.dungeon -- 던전 창(2026-10-21 — 수정 거울숲): 이름 · 오늘 · 레벨 · 글 · 완료 보상 · 안내 · [혼자 입장] [파티 입장] · 까닭(portalScale · portalLift = 던전의 문의 포탈 빛)
L.WEEKLY = D.weekly -- 보스 창(2026-10-24 — 주간 보스): 이름 · 이번 주 · 글 · [노말] [하드] · 입장 레벨 · 격파 보상 · 안내 · [혼자 입장] [파티 입장] · 까닭(timeY = 보스의 방의 남은 시간 줄)
L.RIFT = D.rift -- 수정 틈 토벌(2026-10-16): 머리글(top) 아래 단계마다 한 칸(row — 이름 · 「입장」 btnW · 몬스터 · 보상) · 아래 안내(footY)
L.RIFT_HUD = D.riftHud -- 토벌 중 화면 위 가운데의 판(w x h · y)
L.RIFT_END = D.riftEnd -- 토벌이 끝났을 때 가운데의 판(w · 줄 row · pad)
L.TOME = D.tome -- 모험의 서(2026-10-16): 이름과 %(headY) · 띠(barY · barH) · 칸 다섯(partY · partRow · partBarX · partBarW) · 보상 다섯(rewardY · rewardH) · 몬스터(mobY · mobRow)
L.ACHIEVE = D.achieve -- 업적(2026-10-15): 점수 · 등급의 띠(barY · barH) · 탭(tabY) · 줄의 스크롤(listY · row x rows · 오른쪽 sideW · 「받기」 btnW · 진행 띠 barW · 막대 scrollW) · 「모두 받기」(footY · allW)
L.CASH = D.cash -- 달빛 상점(2026-10-20): 안내 · 탭(tabY) · 줄의 스크롤(listY · row x rows) — 줄 = [그림 칸 iconS] 이름 · 꼬리표 / 설명(textX부터 sideW 앞까지) / 횟수(countY) · 오른쪽 값(priceY) · 단추(btnY · btnW) · 패스 탭(passY · passRow) · 「모두 받기」(footY · allW) · 이름 바꾸기(renameY · renameH)
L.SOUND = D.sound -- 소리 설정: 줄마다 이름(labelW) · 「−」(btn) · 칸 steps개(seg x barH · 사이 gap) · 「+」 · %(pctW). 아래 muteY에 「모두 끄기 / 켜기」(muteW)
L.CRAFT = D.craft -- 제작(대장장이): 탭(tabH) 아래에 장비마다 한 줄(row) — 윗줄 = [아이콘 칸] 이름 · [달돈] 삯(feeW) · 「제작」(makeW x makeH), 아랫줄 = 재료 둘([그림] 이름 가진 수/드는 수 — 하나에 matW)
L.STAT = D.stat -- 능력치 창: 속의 폭 · 줄(top부터 row씩) · 주/부의 자리 · 값의 오른쪽 끝 · + 단추의 폭 · tip = 능력치에 마우스를 올렸을 때 창 옆에 뜨는 설명 판
L.SKILL = D.skill -- 스킬 창: 차수 탭 · 안내 줄 · 스킬들(cols줄 x rows) · 오른쪽의 설명

-- 능력치 창의 속(폭 · 높이). n = 능력치의 수
function L.statBody(n: number): (number, number)
	return L.STAT.w, L.STAT.top + n * L.STAT.row + 8 + M.button + 14 + 20
end

-- 달빛 상점의 공간(client/lune/cashShop.luau): 미리보기와 상점 판을 한 묶음으로 가운데에 나란히 — 묶음을 화면에 맞춰 키운다(k배).
--  2026-10-21 사용자: "지금 달빛상점 들어가면 ui가 너무 작아 모바일에서도 반응형 되어야하고" — 전에는 화면 틀의 점 그대로(1080p에서 574 x 332점 = 화면의 60% x 61%)였다.
--  k = 위 줄 아래 · 아래 여백 위에 들어가는 가장 큰 배(가장 크게 SP.maxScale — 공방 bm.js의 BM_SHOP.space). 한 점이 정수 화소인 배가 가까이(90% 넘게) 있으면 그것(PC 1080p = 1.5배 · 한 점 3화소).
--   폰(화면 틀 768 x 432)은 들어가는 만큼(1.17배쯤). uiW · uiH = 화면 틀 · us = 화면 틀의 한 점이 몇 화소인가(Stage.uiScale)
function L.shopSpace(uiW: number, uiH: number, us: number?)
	local BM = require(script.Parent.Parent.data["bm.generated"])
	local SP, S = BM.shop.space, D.cash
	local panelW, panelH = S.w + SP.panelPad * 2, S.listY + S.rows * S.row + S.footY + M.button + SP.panelPad * 2
	local total = SP.previewW + SP.gap + panelW
	local k = math.min(SP.maxScale, (uiW - SP.pad * 2) / total, (uiH - SP.topH - SP.bottom) / panelH)
	local px = us or 1
	local crisp = math.floor(k * px + 1e-6) / px -- 한 점이 정수 화소인 배(그 아래에서 가장 큰 것)
	if crisp >= 1 and crisp >= k * 0.9 then
		k = crisp
	end
	k = math.max(0.5, math.floor(k * 100) / 100)
	local w, h = total * k, panelH * k
	local x0 = math.floor((uiW - w) / 2)
	local y0 = SP.topH + math.max(0, math.floor((uiH - SP.topH - SP.bottom - h) / 2))
	return { k = k, panelW = panelW, panelH = panelH, total = total, x0 = x0, y0 = y0, previewX = 0, panelX = SP.previewW + SP.gap, leaveX = uiW - SP.pad - SP.leaveW }
end

-- 스마트폰의 「단추 배치」 목록(공방 ui.js의 UILAYOUT.touchChooser — 2026-10-21 점검). 놓을 것이 n개 · 화면 틀의 높이 uiH(왼쪽 위의 Roblox 단추가 가리는 높이는 뺀 것)일 때:
--  판은 왼쪽 위에 서고 화면에 들어가는 만큼만 길어진다 — 넘치는 줄은 그 안에서 위아래로 민다.
--  돌려주는 것: w · h = 판의 크기 / viewH = 칸들이 보이는 높이 / contentH = 칸들의 높이 / rowH = 한 줄(칸 + 이름 두 줄) / scroll = 밀어야 다 보이는가
L.TOUCHCHOOSER = D.touchChooser
function L.touchChooser(n: number, uiH: number)
	local K = L.TOUCHCHOOSER
	local rowH = K.cell + K.nameH
	local contentH = math.max(1, math.ceil(n / K.cols)) * rowH
	local room = math.max(rowH, math.floor(uiH - K.top - K.bottom - K.titleH - K.footH))
	local viewH = math.min(contentH, room)
	local scroll = contentH > viewH
	local listW = K.cols * K.cell + (K.cols - 1) * K.gap
	return { w = K.pad * 2 + listW + (if scroll then K.bar + K.gap else 0), h = K.titleH + viewH + K.footH, viewH = viewH, contentH = contentH, rowH = rowH, scroll = scroll }
end
-- 판이 칸 단추를 덮지 않게(2026-10-21 — 점프 · 상호작용도 끌어 옮기는 칸 단추가 되었다: 왼쪽 아래의 상호작용 단추를 판이 덮으면 끌 수 없다):
--  판과 가로가 겹치는 칸 단추가 있으면 판은 그 단추의 위 끝(K.gap 위)에서 끝난다 — 넘치는 줄은 밀어서 본다.
--  uiH = 화면 틀의 높이 · inset = 왼쪽 위의 Roblox 단추가 가리는 높이(판은 그만큼 내려 선다) · spots = 스마트폰 단추의 자리(UI.touch — 게임 도트) · ratio = 게임 도트 하나가 화면 틀의 몇 점인가
function L.touchChooserFit(n: number, uiH: number, inset: number, spots, ratio: number)
	local K = L.TOUCHCHOOSER
	local widest = K.pad * 2 + K.cols * K.cell + (K.cols - 1) * K.gap + K.bar + K.gap -- 밀기 막대까지 든 폭
	local limit = uiH - inset
	for _, t in spots do
		if t.slot and t.x * ratio < K.x + widest + K.gap then
			limit = math.min(limit, math.floor(t.y * ratio) - K.gap - inset + K.bottom)
		end
	end
	return L.touchChooser(n, limit)
end

-- 스마트폰의 메뉴(「메뉴」 단추를 누르면 뜨는 창 이름의 단추들). 사용자 2026-10-13(폰에서 해 보고): "메뉴탭 열었을때 스크롤이 되어야해 모든메뉴를 접근할수가 없다"
--  단추가 n개일 때: 판은 화면 틀(높이 uiH)에 들어가는 만큼만 서고, 넘치는 단추는 그 안에서 위아래로 밀어서 본다.
--  돌려주는 것: w · h = 판의 크기 / top = 판의 윗자리(기준 격자) / viewH = 단추들이 보이는 높이 / contentH = 단추들의 높이 / scroll = 밀어야 다 보이는가 / btnW = 단추의 폭(막대의 자리를 뺀 것)
L.TOUCHMENU = D.touchMenu
function L.touchMenu(n: number, uiH: number)
	local K = L.TOUCHMENU
	local contentH = math.max(1, n) * K.row - (K.row - K.btnH)
	local room = math.max(K.row, math.floor(uiH - K.top - K.bottom - K.pad * 2))
	local viewH = math.min(contentH, room)
	local scroll = contentH > viewH
	return { w = K.w, h = viewH + K.pad * 2, top = K.top, viewH = viewH, contentH = contentH, scroll = scroll, btnW = K.w - K.pad * 2 - (if scroll then K.bar + K.pad else 0) }
end

-- 스킬 창의 속(폭 · 높이)과 스킬 목록의 폭
function L.skillBody(): (number, number, number)
	local K = L.SKILL
	local listW = K.cols * K.colW + (K.cols - 1) * K.colGap
	return listW + K.gap + K.detailW, K.top + K.rows * K.row, listW
end

-- 장비 칸의 한 변: 장비 그림(게임의 굵은 도트 18개)에 사방으로 여백을 둔 크기. ratio = 게임 도트 하나가 화면 틀의 몇 점인가(1080p에서 2.5 → 50)
function L.cellFor(ratio: number): number
	return math.floor(KIT.icon * ratio + 0.5) + 5
end

-- 가방의 속(폭 · 높이)
function L.bagBody(ratio: number): (number, number)
	local s = L.cellFor(ratio)
	return L.BAG.cols * s, L.BAG.gridY + L.BAG.rows * s + L.BAG.footH
end

-- 창고의 속(폭 · 높이). slots = 창고의 탭 하나의 칸 수
function L.storeBody(ratio: number, slots: number): (number, number)
	local s = L.cellFor(ratio)
	return L.BAG.cols * s, L.STORE.gridY + math.ceil(slots / L.BAG.cols) * s + L.STORE.footH
end

-- 지갑의 한 칸(달돈 · 달가루 · 정수 — 셋이 같은 폭)
function L.purseW(bodyW: number): number
	return math.floor(bodyW / 3)
end

-- 상세 판: 속의 폭 · 이름이 쓰는 폭(그림 칸의 오른쪽 — 닫기 자리는 뺀다) · 값이 쓰는 폭 · 단추 n개가 한 줄에 놓일 때의 폭
function L.detailInner(): number
	return L.DETAIL.w - L.DETAIL.pad * 2
end

function L.detailNameW(ratio: number): number
	return L.detailInner() - L.cellFor(ratio) - 8 - L.DETAIL.closeW
end

function L.detailValueW(): number
	return L.detailInner() - L.DETAIL.labelW
end

function L.detailButtonW(n: number): number
	return math.floor((L.detailInner() - L.DETAIL.btnGap * (n - 1)) / n)
end

-- 상세 판 맨 위의 별(장비 — 2026-10-15)이 차지하는 높이: starRows = 별의 줄 수(22성이면 2 · 소비 · 기타 아이템은 0)
function L.detailStarsH(starRows: number): number
	return if starRows > 0 then starRows * L.DETAIL.starRow + L.DETAIL.starGap else 0
end
-- 상세 판의 높이: nameLines = 이름의 줄 수 · rows = 줄 수 · noteLines = 알림 글의 줄 수(모두 더한 것) · btnRows = 단추 줄 수 · starRows = 맨 위 별의 줄 수(없으면 0)
function L.detailHeight(ratio: number, nameLines: number, rows: number, noteLines: number, btnRows: number, starRows: number?): number
	local K = L.DETAIL
	local head = math.max(L.cellFor(ratio), nameLines * K.nameLine + K.subGap + M.small)
	local h = K.pad + L.detailStarsH(starRows or 0) + head + K.rowTop + rows * K.rowH
	if noteLines > 0 then
		h += K.noteTop + noteLines * K.noteLine
	end
	if btnRows > 0 then
		h += K.btnTop + btnRows * M.button + (btnRows - 1) * K.btnGap
	end
	return h + K.pad
end

-- 장비 창의 속(폭 · 높이)과 오른쪽 덩이의 왼쪽 끝. 높이 = 왼쪽의 다섯 칸과 오른쪽(장신구 두 줄 + 가르는 줄 + 능력치 표) 가운데 큰 것
function L.equipBody(ratio: number): (number, number, number)
	local s = L.cellFor(ratio)
	local rx = s + L.EQUIP.gap + L.EQUIP.textW + L.EQUIP.gap
	local sheet = L.EQUIP.sheet
	return rx + L.EQUIP.accCols * s, math.max(5 * (s + 2) - 2, 2 * s + 12 + sheet.top + #sheet.rows * sheet.row + 4), rx
end

-- 스마트폰 · 태블릿의 터치 단추 자리(2026-10-23 — 사용자 "모바일버전으로 아이패드로 플레이할때 불편하다고하네 방법을 찾아봐"):
--  UI.touch의 자리는 게임 화면(384x216 도트)에 적혀 있다. 큰 화면(태블릿)에서는 게임 화면이 커지는 만큼 단추도 커진다(10.2인치 iPad에서 이동 패드 지름 약 180점).
--  → 이동 패드의 지름이 TOUCH_PAD_MAX(화면의 점 — Roblox 기본 점프 단추가 큰 화면에서 120점)를 넘지 않게 k배로 줄이고, 단추마다 가까운 구석(왼쪽 · 오른쪽 / 위 · 아래)에서의
--  거리도 k배로 해 구석 쪽으로 모은다(위 구석 = 화면 위 4분의 1에 있는 것만). 폰은 패드가 그보다 작아 k = 1(그대로). 가장 작은 단추도 TOUCH_MIN점(Apple의 누르는 칸 44pt) 밑으로는 줄이지 않는다. [제가 정한 것 — 144]
L.TOUCH_PAD_MAX = 144
L.TOUCH_MIN = 44
function L.touchK(scale: number, spots): number
	local padW, least = 64, math.huge
	for _, t in spots do
		if t.kind == "pad" then
			padW = t.w
		end
		if t.kind == "pad" or t.slot or t.act then
			least = math.min(least, t.w, t.h) -- 누르는 단추만(hud는 자리뿐)
		end
	end
	local k = L.TOUCH_PAD_MAX / math.max(1, padW * scale)
	if least < math.huge then
		k = math.max(k, L.TOUCH_MIN / math.max(1, least * scale))
	end
	return math.min(1, k)
end
-- 단추 t의 자리(게임 도트 — x, y, w, h) · viewW · viewH = 게임 화면(384x216)
function L.touchRect(t, k: number, viewW: number, viewH: number): (number, number, number, number)
	local x = if t.x + t.w / 2 < viewW / 2 then t.x * k else viewW - (viewW - t.x) * k
	local y = if t.y + t.h / 2 < viewH / 4 then t.y * k else viewH - (viewH - t.y) * k -- 위 구석에는 화면 위 4분의 1의 것(메뉴)만 — 스킬 칸의 무리가 위아래로 갈라지지 않게
	return x, y, t.w * k, t.h * k
end

return L
