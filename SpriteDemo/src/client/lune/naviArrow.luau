-- 길찾기의 화살표 — 캐릭터 머리 위에 가야 할 쪽을 가리킨다(셈은 shared/lune/ui/navi.luau).
--  사용자 2026-10-13: "그 버튼 누르면  길찾기 되면서 가야하는 방향 캐릭터 머리위에 화살표로 알려주는 기능 추가하세요" → 같은 날 "퀘스트 길찾기  캐릭터 머리위에 화살표 퀄리티 더 올리고"
--  그림: 처음에는 내가 네모로 짠 한 색 화살표였다 → Codex가 그린 민트 수정 화살표(밝은 윗면 · 어두운 아랫면 · 흰 빛 · 어두운 테두리)를 칸 그대로 옮긴 부품 넷
--   (naviUp · naviRight · naviDown · naviLeft — 공방 tools/build_lune_navi.mjs → build_lune_ui.mjs → 부품 그림 한 장). 여기서 모양을 따로 그리지 않는다.
--  왼쪽 · 오른쪽 · 위 · 아래의 그림 넷을 만들어 두고 하나만 보인다. 가리키는 쪽으로 조금씩 오간다. 문 · 주민 앞에 다 오면 위쪽 화살표가 빠르게 오간다(↑를 누른다).
--  화면 틀의 격자에 그린다(그림의 한 점 = 화면 틀의 SCALE점 — 정수 배라 도트가 뭉개지지 않는다. 게임 세계의 자리는 Overlay가 옮겨 준다).
local Overlay = require(script.Parent.overlay)
local Kit = require(script.Parent.ui.kit)

local NaviArrow = {}
NaviArrow.UP = 44 -- 발밑에서 화살표 가운데까지(게임의 도트 — 머리 위)
NaviArrow.SCALE = 2 -- 그림의 한 점이 화면 틀의 몇 점인가
NaviArrow.PART = { up = "naviUp", right = "naviRight", down = "naviDown", left = "naviLeft" }
NaviArrow.WAVE = { slow = 6, fast = 12, reach = 4 } -- 오가는 빠르기(가는 중 · 다 왔다) · 오가는 폭(화면 틀의 점)

function NaviArrow.new()
	local self = setmetatable({}, { __index = NaviArrow })
	local layer = Overlay.layer("Navi", 14)
	self.frames, self.size = {}, {}
	for dir, part in NaviArrow.PART do
		local w, h = Kit.partSize(part)
		local f = Kit.part(layer, part, 0, 0)
		f.Name = "Arrow_" .. dir
		f.Size = UDim2.fromOffset(w * NaviArrow.SCALE, h * NaviArrow.SCALE)
		f.Visible = false
		self.frames[dir] = f
		self.size[dir] = { w * NaviArrow.SCALE, h * NaviArrow.SCALE }
	end
	self.shown = nil :: string?
	return self
end

-- dir = "left" | "right" | "up" | "down" | "enter" | "none" | nil · (wx, wy) = 캐릭터의 발밑(게임 세계) · clock = 흐른 시간(초)
function NaviArrow:set(dir: string?, wx: number, wy: number, clock: number)
	local face = if dir == "enter" then "up" elseif dir == "none" then nil else dir
	if face ~= self.shown then
		for name, f in self.frames do
			f.Visible = name == face
		end
		self.shown = face
	end
	if not face then
		return
	end
	local f, size = self.frames[face], self.size[face]
	-- 가리키는 쪽으로 오간다(다 왔으면 빠르게 — ↑를 누르라는 뜻). 한 점씩 딱딱 움직인다(도트 그림이라 반 점에 걸치지 않게)
	local W = NaviArrow.WAVE
	local wave = math.floor((math.sin(clock * (if dir == "enter" then W.fast else W.slow)) + 1) / 2 * W.reach + 0.5)
	local ox = if face == "left" then -wave elseif face == "right" then wave else 0
	local oy = if face == "up" then -wave elseif face == "down" then wave else 0
	f.Position = UDim2.fromOffset(Overlay.x(wx) - math.floor(size[1] / 2) + ox, Overlay.y(wy - NaviArrow.UP) - math.floor(size[2] / 2) + oy)
end

function NaviArrow:hide()
	self:set(nil, 0, 0, 0)
end

return NaviArrow
