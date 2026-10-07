-- 게임 세계의 자리에 붙는 화면 글씨 — 발밑의 이름표 · 졸개의 체력 띠 · 주민의 말풍선 · 떠오르는 알림 글.
--  이것들은 글씨라서 화면 틀의 고운 격자에 그리지만(client/lune/stage.luau의 ui 층), 놓이는 자리는 게임 세계의 도트다.
--  그래서 화면마다 "게임 도트 → 화면 틀의 점"으로 바꿔 자리를 다시 잡는다(카메라가 움직이면 같이 움직인다).
--  게임 도트 하나는 화면 틀의 2.5점(1080p)이라 반 점에 걸릴 수 있다 — 가까운 점으로 맞춘다(화면에서 1픽셀 안쪽의 어긋남).
local Stage = require(script.Parent.stage)

local Overlay = {}
Overlay.camX, Overlay.camY = 0, 0

function Overlay.init()
	Overlay.root = Stage.group(Stage.ui, "Over", 20)
	return Overlay
end

-- 장면마다의 층(장면을 바꿀 때 통째로 지운다). z = 겹치는 차례
function Overlay.layer(name: string, z: number): Frame
	return Stage.group(Overlay.root, name, z)
end

-- 카메라(게임 도트)를 알린다 — 장면을 그릴 때마다
function Overlay.setCamera(camX: number, camY: number)
	Overlay.camX, Overlay.camY = camX, camY
end

-- 게임 세계의 (wx, wy) → 화면 틀의 점
function Overlay.x(wx: number): number
	return math.floor((wx - Overlay.camX) * Stage.ratio + 0.5)
end

function Overlay.y(wy: number): number
	return math.floor((wy - Overlay.camY) * Stage.ratio + 0.5)
end

-- 게임 도트의 길이 → 화면 틀의 점(가까운 점으로)
function Overlay.len(dots: number): number
	return math.floor(dots * Stage.ratio + 0.5)
end

return Overlay
