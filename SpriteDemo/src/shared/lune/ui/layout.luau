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
	return { x = r.x + math.floor((w - UI.grid.w) * fx + 0.5), y = r.y + math.floor((h - UI.grid.h) * fy + 0.5), w = r.w, h = r.h }
end

-- 게임 세계의 배율 s에서 화면 틀의 배율과 격자(client/lune/stage.luau와 같은 셈)
function L.gridFor(s: number): (number, number, number)
	local us = math.max(1, math.floor(0.4 * s + 0.5))
	return 384 * s / us, 216 * s / us, us
end

-- ---------- 늘 보이는 화면 ----------
L.VITALS = D.vitals -- 왼쪽 아래 덩어리: 윗줄에 레벨 · 이름 / 체력 바(숫자는 바 안) / 가는 경험치 줄과 그 옆의 %
L.SKILLS = D.skills -- 스킬 칸: 두 줄 x 여섯. 칸 위에 키 딱지(높이 keyUp)
L.MENU = D.menu -- 창을 여는 단추: 여섯까지, 오른쪽 끝에 붙여. 그림 아래에 이름(labels = 칸에 맞춘 짧은 이름)
L.PARTY = D.party -- 파티원 칸: 한 사람 = 이름 한 줄 + 가는 체력 줄. ask = 초대 알림(위쪽 가운데)
L.QUEST = D.quest -- 퀘스트 알리미: 이름 한 줄(본문 글씨) · 할 일 한 줄(작은 글씨) · 퀘스트 사이
L.CHAT = D.chat -- 채팅: 평소에는 채팅 칸에 마지막 몇 줄, 쓸 때는 넓은 판(open)
L.TAG = D.tag -- 이름표: 한 줄의 높이(쌓을 때) · 발밑에서 아래로 띄우는 만큼 · 가장 넓을 때
L.MOBBAR = D.mobBar -- 졸개의 체력 띠: 크기(화면 틀의 점) · 발밑에서 위로(게임의 도트)

-- 쓰는 칸이 n개일 때 i째 칸의 자리(스킬 칸 틀 안): 여섯까지는 아랫줄에 가운데로 모으고, 일곱째부터는 윗줄에 같은 식으로
function L.slotPlace(i: number, n: number): (number, number)
	local s, K = UI.hud.skills, L.SKILLS
	local pitch = K.slot + K.gap
	local row = if i <= K.cols then 1 else 2
	local inRow = if row == 1 then math.min(n, K.cols) else n - K.cols
	local k = if row == 1 then i else i - K.cols
	local left = math.floor((s.w - (inRow * pitch - K.gap)) / 2)
	return left + (k - 1) * pitch, s.h - K.slot - (row - 1) * (K.slot + K.keyUp + K.rowGap)
end

-- 메뉴 단추 아래에 적는 이름(칸에 맞춘 짧은 이름이 있으면 그것)
function L.menuLabel(id: string, name: string): string
	return L.MENU.labels[id] or name
end

-- n개 가운데 i째 단추의 x(메뉴 칸 틀 안)
function L.menuX(i: number, n: number): number
	return UI.hud.menu.w - (n - i + 1) * L.MENU.pitch + (L.MENU.pitch - L.MENU.slot)
end

-- 쓰는 중의 채팅 판의 자리(아래 끝은 채팅 칸의 아래 끝에서 dy 아래)
function L.chatOpen()
	local c, o = UI.hud.chat, L.CHAT.open
	local h = o.pad + o.lines * L.CHAT.line + 4 + L.CHAT.field + o.pad
	return { at = c.at, x = c.x + o.dx, y = c.y + c.h - h + o.dy, w = o.w, h = h }
end

-- ---------- 창(화면 오른쪽 · 왼쪽의 옆 판) ----------
L.WIN = D.win -- 판에서 속까지: 옆으로 pad, 위로 head(제목 줄), 아래로 foot. edge · top = 화면 끝에서 띄우는 폭
L.BAG = D.bag -- 가방: 칸 여섯 x 넷. 탭 줄(gridY) 아래에 칸, 그 아래 infoH에 이름 · 설명 · 단추 셋(같은 폭 — 사이 gap) · 돈
L.EQUIP = D.equip -- 장비 창: 왼쪽 = 칸 하나 + 글(textW), 오른쪽 = 장신구 네 칸
L.SHOP = D.shop -- 상점: 물건 이름(본문 글씨) · 값 · 사는 단추(들)
L.STAT = D.stat -- 능력치 창: 속의 폭 · 줄(top부터 row씩) · 주/부의 자리 · 값의 오른쪽 끝 · + 단추의 폭 · tip = 능력치에 마우스를 올렸을 때 창 옆에 뜨는 설명 판
L.SKILL = D.skill -- 스킬 창: 차수 탭 · 안내 줄 · 스킬들(cols줄 x rows) · 오른쪽의 설명

-- 능력치 창의 속(폭 · 높이). n = 능력치의 수
function L.statBody(n: number): (number, number)
	return L.STAT.w, L.STAT.top + n * L.STAT.row + 8 + M.button + 14 + 20
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

-- 가방의 속(폭 · 높이)과 단추 셋의 폭
function L.bagBody(ratio: number): (number, number)
	local s = L.cellFor(ratio)
	return L.BAG.cols * s, L.BAG.gridY + L.BAG.rows * s + L.BAG.infoH
end

function L.bagButtonW(bodyW: number): number
	return math.floor((bodyW - L.BAG.gap * 2) / 3)
end

-- 장비 창의 속(폭 · 높이)과 오른쪽 덩이의 왼쪽 끝
function L.equipBody(ratio: number): (number, number, number)
	local s = L.cellFor(ratio)
	local rx = s + L.EQUIP.gap + L.EQUIP.textW + L.EQUIP.gap
	return rx + L.EQUIP.accCols * s, math.max(5 * (s + 2) - 2, 2 * s + 150), rx
end

return L
