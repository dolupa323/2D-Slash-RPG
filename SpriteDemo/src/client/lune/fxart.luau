-- 이펙트의 그림(Aseprite로 그린 것 — 무니의 수정): 공방이 내보낸 점 자료(data/fxart.generated.luau)를 그림판에 찍을 수 있는 꼴로 푼다.
--  FxArt[이름] = { w, h, buf(RGBA) , hi = 흰 모서리 · 반짝임만 남긴 그림(반투명으로 겹칠 때도 모서리는 또렷하게 — 시험 탭의 hiOf) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DATA = require(ReplicatedStorage.shared.lune.data["fxart.generated"])

local FxArt = {}
for name, e in DATA do
	local n = e.w * e.h * 4
	local buf, hi = buffer.create(n), buffer.create(n)
	local hex = e.hex
	for i = 0, n - 1 do
		buffer.writeu8(buf, i, tonumber(string.sub(hex, i * 2 + 1, i * 2 + 2), 16) or 0)
	end
	for p = 0, n - 4, 4 do
		if buffer.readu8(buf, p) > 250 and buffer.readu8(buf, p + 1) > 250 and buffer.readu8(buf, p + 2) > 250 then
			buffer.writeu32(hi, p, buffer.readu32(buf, p))
		end
	end
	FxArt[name] = { w = e.w, h = e.h, buf = buf, hi = { w = e.w, h = e.h, buf = hi } }
end

return FxArt
