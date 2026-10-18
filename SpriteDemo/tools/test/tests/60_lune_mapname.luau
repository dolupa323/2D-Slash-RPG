-- 「달의 계승자」 — 맵 이름(client/lune/mapName.luau)의 흐려짐을 화면 없이 돌려 본다(2026-10-18).
--  까닭: 코드 검토가 찾은 버그 — 글자 그림(pixelText)은 같은 글이면 다시 짓지 않아 흐려진 투명도가 남는데, show가 「처음 투명도(baseT)」를 지워
--  그 흐려진 값을 처음 값으로 읽었다 → 같은 지역의 둘째 맵부터 지역 줄이, 같은 이름의 맵에 다시 들면 맵 이름이 보이지 않았다.
--  가짜 글: 글이 바뀔 때만 글자를 새로 짓는다(진짜 pixelText와 같다). 글자의 처음 투명도는 0 · 그림자 글자는 0.6.
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local L = Layout.MAPNAME

local glyphs = {} -- 지금 살아 있는 글자들
local box
local function glyph(base: number)
	local g = { ImageTransparency = base, attrs = {}, base0 = base }
	function g:IsA(class) return class == "ImageLabel" end
	function g:GetAttribute(k) return self.attrs[k] end
	function g:SetAttribute(k, v) self.attrs[k] = v end
	table.insert(glyphs, g)
	return g
end
local function textItem()
	local it = { value = nil, mine = {} }
	function it.set(_, v)
		if v == it.value then
			return -- 같은 글이면 글자를 다시 짓지 않는다(진짜 pixelText처럼)
		end
		it.value = v
		for _, g in it.mine do
			table.remove(glyphs, table.find(glyphs, g))
		end
		it.mine = {}
		for _ = 1, #v // 3 do
			table.insert(it.mine, glyph(0))
			table.insert(it.mine, glyph(0.6)) -- 그림자 글자
		end
	end
	return it
end
MOCK("Client/lune/stage", {
	REF_W = 960,
	place = function()
		box = { Visible = false }
		function box:GetDescendants() return glyphs end
		return box
	end,
})
MOCK("Client/lune/ui/ui", { COLOR = setmetatable({}, { __index = function(_, k) return k end }), text = function() return textItem() end })

local MapName = req("Client/lune/mapName")
MapName.init({})
local function fullyShown(): boolean
	for _, g in glyphs do
		if math.abs(g.ImageTransparency - g.base0) > 1e-6 then
			return false
		end
	end
	return #glyphs > 0
end
local function run()
	-- 들어와서 다 보일 때까지
	MapName.step(L.fadeIn + 0.05)
end
local function fadeAway()
	-- 장마다 조금씩(실제처럼) — 거의 다 흐려졌을 때(글자가 0.95쯤 투명)에 멈춘다. 한 번에 넘기면 흐려지는 중간을 건너뛰어 버그가 드러나지 않는다
	for _ = 1, 400 do
		if MapName.alpha() < 0.05 then
			break
		end
		MapName.step(1 / 60)
	end
	expect(MapName.alpha() > 0 and box.Visible, "(흐려지는 중)")
end

-- 같은 지역의 두 맵: 지역 줄은 그대로(글자를 다시 짓지 않는다) · 맵 이름만 바뀐다
MapName.show("r2a1")
run()
expect(box.Visible and fullyShown(), "첫 맵: 지역 · 맵 이름이 다 보인다")
fadeAway()
MapName.show("r2a2")
run()
expect(box.Visible and fullyShown(), "같은 지역의 둘째 맵: 지역 줄도 다 보인다(흐려진 값을 처음 값으로 읽지 않는다)")
fadeAway()
-- 같은 이름의 맵에 다시(집 → 마을 · 되살아남): 지역 · 이름 모두 같은 글
MapName.show("r2a2")
run()
expect(box.Visible and fullyShown(), "같은 맵에 다시 들어도 다 보인다")
-- 흐려지면 사라진다
MapName.step(L.hold + L.fadeOut + 0.1)
expect(not box.Visible, "다 흐려지면 사라진다")
-- 그 자리를 다른 것이 쓰면(보스 체력 · 장면 · 창) 바로 사라진다
MapName.show("r2a1")
MapName.step(0.1, true)
expect(not box.Visible, "막히면 바로 사라진다")
