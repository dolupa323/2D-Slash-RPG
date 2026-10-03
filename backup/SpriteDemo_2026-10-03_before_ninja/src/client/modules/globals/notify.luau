-- 알림 — 에셋 공방 UI 탭 "대화·알림" 예시 화면 그대로(도트 UI).
--  위 가운데 토스트: 진보라 알약 + 아이콘 + 글씨, 2.2초 뒤 사라짐(최대 3개가 아래로 쌓임).
--    몬스터 첫 발견 / 아이템 획득 / 서버 알림(가방이 가득 찼어요 등)에 쓴다.
--  "새 친구!" 팝업: 처음 쓰러뜨린 몬스터(서버 DexDiscovered) — 몬스터 그림 2배, 이름, 속성, [도감 보기] [좋아!].
-- 다른 모듈은 exports.Toast(text, icon?)로 알림을 띄운다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local items = require(ReplicatedStorage.shared.data.items)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local UI = require(script.Parent.Parent.ui.pixelUI)

local C = UI.colors
local TOAST_TIME = 2.2
local MAX_TOASTS = 3
local SHEET = townWorld.data.monsterSheet
local ELEMENT = {
	fire = { name = "불", icon = "fire" },
	water = { name = "물", icon = "water" },
	grass = { name = "풀", icon = "leaf" },
}

local exports = {}
local toasts = {}

local function gui(): ScreenGui
	if exports.screenGui and exports.screenGui.Parent then
		return exports.screenGui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "Notify"
	g.ResetOnSpawn = false
	g.DisplayOrder = 40
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.screenGui = g
	return g
end

local function relayout()
	for i, t in toasts do
		t.Position = UDim2.new(0.5, 0, 0, 4 + (i - 1) * 22 * UI.CurrentScale())
	end
end

function exports.Toast(text: string, icon: string?)
	local w = UI.Text.Measure(text, "body") + (if icon then 30 else 16)
	local holder = Instance.new("Frame")
	holder.Name = "Toast"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(w, 20)
	holder.Parent = gui()
	UI.Scale(holder)
	local pill = UI.Pill(holder, 0, 0, w, 20, true)
	local x = 8
	if icon then
		UI.Icon(pill, icon, 5, 4)
		x = 20
	end
	UI.Label(pill, text, x, 4, { Color = C.white })
	table.insert(toasts, 1, holder)
	while #toasts > MAX_TOASTS do
		table.remove(toasts):Destroy()
	end
	relayout()
	task.delay(TOAST_TIME, function()
		local i = table.find(toasts, holder)
		if i then
			table.remove(toasts, i)
		end
		holder:Destroy()
		relayout()
	end)
end

-- 몬스터 그림(시트 줄 row, 대기 첫 장) ImageLabel
function exports.MonsterImage(parent: Instance, row: number, x: number, y: number, scale: number)
	local img = Instance.new("ImageLabel")
	img.Name = "Monster"
	img.BackgroundTransparency = 1
	img.Image = townAssets.MONSTER_SHEETS[townWorld.MonsterSheet(row)]
	img.ImageRectSize = Vector2.new(SHEET.cellW, SHEET.cellH)
	img.ImageRectOffset = townWorld.MonsterFrameOffset(row, 0)
	img.ResampleMode = Enum.ResamplerMode.Pixelated
	img.Position = UDim2.fromOffset(x, y)
	img.Size = UDim2.fromOffset(SHEET.cellW * scale, SHEET.cellH * scale)
	img.ZIndex = 5
	img.Parent = parent
	return img
end

-- "새 친구!" 팝업
function exports.NewFriend(row: number)
	local species = townWorld.data.species[row]
	if not species then
		return
	end
	if exports.popup then
		exports.popup:Destroy()
	end
	local PW, PH = 180, 158
	local holder = Instance.new("Frame")
	holder.Name = "NewFriend"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromOffset(PW, PH)
	holder.Parent = gui()
	UI.Scale(holder)
	exports.popup = holder
	local panel = UI.Panel(holder, 0, 0, PW, PH)
	UI.TitleTag(panel, "새 친구!", PW / 2, -13)
	exports.MonsterImage(panel, row, PW / 2 - SHEET.cellW, 16, 2)
	local name = UI.Label(panel, species.name, PW / 2, 78, { Font = "title", Color = C.pinkD, Align = "center" })
	name.Frame.Position = UDim2.fromOffset(PW / 2 - name.Width // 2, 78)
	local el = ELEMENT[species.element] or { name = species.element, icon = "star" }
	local typeText = el.name .. " 속성"
	local tw = UI.Text.Measure(typeText, "body") + 15
	UI.Icon(panel, el.icon, PW / 2 - tw // 2, 101)
	UI.Label(panel, typeText, PW / 2 - tw // 2 + 15, 102, { Color = C.ink })
	local function close()
		if exports.popup == holder then
			exports.popup = nil
		end
		holder:Destroy()
	end
	UI.Button(panel, 12, PH - 34, 72, 24, { Color = "white", Text = "도감 보기", OnClick = function()
		close()
		local dex = require(script.Parent.dex)
		dex.open()
	end })
	UI.Button(panel, PW - 84, PH - 34, 72, 24, { Color = "pink", Text = "좋아!", OnClick = close })
end

function exports.load(scene: Scene)
	if exports.listening then
		return
	end
	exports.listening = true
	Net.OnClient("DexDiscovered", function(row)
		exports.Toast("새 몬스터를 발견했어요!", "star")
		exports.NewFriend(row)
	end)
	Net.OnClient("Notify", function(text)
		exports.Toast(tostring(text))
	end)
	Net.OnClient("ItemAcquired", function(itemId, count)
		local def = if itemId == "Gold" then { Name = "골드", KitIcon = "coin" } else items[itemId]
		if def then
			exports.Toast(("%s %d개를 얻었어요"):format(def.Name, count), if def.KitIcon ~= "" then def.KitIcon else nil)
		end
	end)
end

function exports.start(scene: Scene) end
function exports.unload(scene: Scene) end

return exports
