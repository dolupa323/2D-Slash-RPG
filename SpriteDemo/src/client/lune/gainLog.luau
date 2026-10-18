-- 획득 알림 — 경험치 · 달돈 · 달가루 · 주운 것 · 레벨 업 · 퀘스트 완료를 화면 구석에 줄로 쌓는다(메이플스토리의 획득 메시지처럼).
--  2026-10-18: 얻은 것은 머리 위에 잠깐 뜨는 글뿐이라 지나가면 다시 볼 수 없었다. 머리 위의 글은 그대로 두고, 여기 줄로도 남긴다.
--  가장 아래가 새 줄. 줄마다 life초 뒤 fade초 동안 흐려져 사라진다. 같은 갈래(경험치 · 달돈 · 달가루)가 merge초 안에 이어 오면
--  새 줄을 만들지 않고 마지막 줄의 수를 더한다(사냥 중에 줄이 넘치지 않게).
--  자리 = 공방 basics.js의 HUD 「획득 알림」(PC: 오른쪽 아래 메뉴 단추 위 · 스마트폰: HUDTOUCH — 왼쪽 위 파티원 칸 아래) · 치수 = ui.js의 UILAYOUT.gainLog
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local L = Layout.GAINLOG

local GainLog = {}
GainLog.lines = {} :: { any } -- { text, color, age, kind, amount } — 앞이 오래된 줄
local box: Frame? = nil
local rows = {} -- 미리 만든 글 칸(아래가 새 줄)
local shown = {} -- 칸마다 지금 적힌 글 · 색(바뀔 때만 다시 그린다)
GainLog.touch = false
GainLog.covered = false

local function rect()
	local r = if GainLog.touch and UI.hudTouch.gainLog then UI.hudTouch.gainLog else UI.hud.gainLog
	return r
end

function GainLog.init(root: Frame)
	local r = UI.hud.gainLog
	box = Stage.place(root, "GainLog", r.at, r.x, r.y, r.w, r.h)
	for i = 1, L.lines do
		rows[i] = Ui.text(box, "", 0, (i - 1) * L.lineH, r.w, { outline = true })
		shown[i] = { text = "", color = nil }
	end
end

-- 스마트폰 단추가 켜졌다 · 꺼졌다: 자리를 옮긴다
function GainLog.setTouch(on: boolean)
	GainLog.touch = on
	if box then
		local r = rect()
		box.Position = Stage.atPosition(r.at, r.x, r.y)
	end
end

-- 오른쪽 창이 그 자리를 덮었다(PC) — 그동안은 감춘다
function GainLog.setCovered(on: boolean)
	GainLog.covered = on
	if box then
		box.Visible = not (on and not GainLog.touch)
	end
end

local MERGE = { xp = "경험치 +%s", money = "달돈 +%s", dust = "달가루 +%s" }
local function textOf(kind: string, amount: number): string
	return MERGE[kind]:format(if kind == "xp" then Format.comma(amount) else Format.short(amount))
end

-- 한 줄을 더한다. kind = xp · money · dust(같은 갈래가 이어 오면 합친다) · 그 밖(item · quest · level · note)은 늘 새 줄
function GainLog.add(kind: string, text: string?, color: any?, amount: number?)
	local last = GainLog.lines[#GainLog.lines]
	if MERGE[kind] then
		if last and last.kind == kind and last.age < L.merge then
			last.amount += amount or 0
			last.text = textOf(kind, last.amount)
			last.age = 0
			return
		end
		text = textOf(kind, amount or 0)
	end
	table.insert(GainLog.lines, { text = text or "", color = color or C.text, age = 0, kind = kind, amount = amount or 0 })
	while #GainLog.lines > L.lines do
		table.remove(GainLog.lines, 1)
	end
end
function GainLog.xp(n: number)
	if n > 0 then
		GainLog.add("xp", nil, C.accent, n)
	end
end
function GainLog.money(n: number)
	if n > 0 then
		GainLog.add("money", nil, C.gold, n)
	end
end
function GainLog.dust(n: number)
	if n > 0 then
		GainLog.add("dust", nil, C.accent, n)
	end
end
function GainLog.item(label: string, color: any?)
	GainLog.add("item", ("획득: %s"):format(label), color or C.text)
end
function GainLog.level(level: number)
	GainLog.add("level", ("레벨 업! Lv.%d"):format(level), C.gold)
end
function GainLog.quest(name: string)
	GainLog.add("quest", ("퀘스트 완료: %s"):format(name), C.gold)
end

-- 0(안 보임) ~ 1 — 줄의 나이로
function GainLog.alphaOf(age: number): number
	if age <= L.life then
		return 1
	end
	return math.max(0, 1 - (age - L.life) / L.fade)
end

-- 줄의 글자들과 처음 투명도(글이 바뀔 때 한 번 모은다 — 매 장면 GetDescendants · 속성을 읽지 않게 · 2026-10-18 검토)
local function glyphsOf(row): { any }
	local list = {}
	local frame = row.label and row.label.Frame
	if frame then
		for _, d in frame:GetDescendants() do
			if d:IsA("ImageLabel") then
				table.insert(list, { d = d, base = d.ImageTransparency })
			end
		end
	end
	return list
end
local function fadeRow(was, a: number)
	-- 흐림이 바뀔 때만 쓴다(다 보이는 동안은 아무것도 쓰지 않는다)
	local q = math.floor(a * 64 + 0.5) / 64
	if was.alpha == q then
		return
	end
	was.alpha = q
	for _, g in was.glyphs or {} do
		g.d.ImageTransparency = g.base + (1 - g.base) * (1 - q)
	end
end

-- 장마다: 줄의 나이를 더하고, 다 흐려진 줄을 지우고, 칸에 다시 적는다(아래 칸부터 새 줄)
function GainLog.step(dt: number)
	for i = #GainLog.lines, 1, -1 do
		local line = GainLog.lines[i]
		line.age += dt
		if GainLog.alphaOf(line.age) <= 0 then
			table.remove(GainLog.lines, i)
		end
	end
	if not box then
		return
	end
	local n = #GainLog.lines
	for i = 1, L.lines do
		local line = GainLog.lines[n - (L.lines - i)] -- 마지막 칸 = 가장 새 줄
		local row, was = rows[i], shown[i]
		local text, color = if line then line.text else "", if line then line.color else nil
		if was.text ~= text then
			row:set(text)
			was.text = text
			was.color = nil
			was.glyphs = glyphsOf(row) -- (새 글의 글자들 — 처음 투명도와 함께)
			was.alpha = nil
		end
		if color and was.color ~= color then
			row:color(color)
			was.color = color
		end
		if line then
			fadeRow(was, GainLog.alphaOf(line.age))
		end
	end
end

function GainLog.clear()
	table.clear(GainLog.lines)
end

return GainLog
