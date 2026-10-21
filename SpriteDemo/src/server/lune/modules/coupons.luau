-- 쿠폰(2026-10-21 사용자: "쿠폰 코드 입력창있어야하고 그 쿠폰 입력하면 그 기본펫 지급하는 방식으로 합니다" · "제가 무료 쿠폰으로 푸는 용도로 사용할 펫입니다").
--  서버에만 있는 목록이다 — ServerScriptService 아래라 화면(사람의 컴퓨터)에는 보내지지 않는다. 번호를 바꾸거나 더하려면 아래 LIST를 고친다.
--  code = 적는 번호(대문자 · 숫자만 — 화면에서 적은 글의 빈칸 · 줄표는 빼고 대문자로 맞춘 뒤 견준다. 가장 길게 24자) · pet = 주는 펫(design/ride.js의 이름표)
--  from · till = 쓸 수 있는 때(os.time — 없으면 늘). 한 계정이 한 쿠폰을 한 번만 쓴다(계정 저장의 bm.coupons). 셈은 shared/lune/sim/cash.luau의 Cash.redeem
local Coupons = {}

Coupons.LIST = {
	-- 기본펫 「아기 재까마귀」(쿠폰으로만 받는 펫 — 2026-10-21: 처음의 「까망 동글이」를 사용자가 재까마귀로 바꿨다). 번호는 제가 정한 것 — 나눠 줄 번호로 바꾸시면 된다
	{ code = "DONGGEULI", pet = "pet_crow" },
}

local BY = {}
for _, def in Coupons.LIST do
	BY[def.code] = def
end

-- 그 번호의 쿠폰(없으면 nil). code = Cash.couponCode로 맞춘 꼴
function Coupons.find(code: string?)
	return if code then BY[code] else nil
end

return Coupons
