-- 쿠폰 창 — 메뉴 → 「쿠폰」(2026-10-21 사용자: "쿠폰 코드 입력창있어야하고 그 쿠폰 입력하면 그 기본펫 지급하는 방식으로 합니다").
--  위에 안내 두 줄 · 쿠폰 번호를 적는 칸과 「사용」 · 아래에 결과 두 줄(받았다 · 까닭). 번호는 서버가 본다(server/lune/modules/cash.luau의 CashServer.coupon —
--  쿠폰의 목록은 서버에만 있다). 받은 펫은 가방의 「캐시」 탭에 들어온다(꺼내 둔 펫이 없으면 바로 꺼낸다 — 산 펫과 같다).
--  치수 · 글은 공방 js/lune/design/ui.js의 UILAYOUT.coupon. 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local UI = require(lune.data["ui.generated"])
local RIDE = require(lune.data["ride.generated"])
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = UI.layout.coupon
local W = S.words

local CouponWindow = {}
CouponWindow.LAYOUT = S

function CouponWindow.size(): (number, number)
	return S.w, S.noteY + S.noteH
end

-- 펫의 이름(ride.generated의 pets — 상점에서 팔지 않는 펫도 든다)
local function petName(id: string?): string
	for _, q in RIDE.pets do
		if q.id == id then
			return q.name
		end
	end
	return id or ""
end
CouponWindow.petName = petName

function CouponWindow.build(body: Frame, ctx, w: number, _h: number)
	local _ = Layout
	Ui.text(body, W.guide, 0, 0, w, { lines = 2, color = C.dim })
	local field = Ui.field(body, 0, S.fieldY, w - S.btnW - 6, S.fieldH, W.placeholder)
	field.Name = "CouponInput"
	local note = Ui.text(body, "", 0, S.noteY, w, { lines = 2 })
	local busy = false
	local use
	local function say(text: string, color: Color3)
		note:set(text)
		note:color(color)
	end
	local function send()
		if busy then
			return
		end
		local text = field.Text
		if string.gsub(text, "%s", "") == "" then
			say(W.empty, C.dim)
			return
		end
		busy = true
		use:setEnabled(false)
		say(W.busy, C.dim)
		task.spawn(function()
			local ok, res = false, nil
			if ctx.coupon then
				ok, res = ctx.coupon(text)
			end
			busy = false
			use:setEnabled(true)
			if ok and typeof(res) == "table" and res.ok then
				field.Text = ""
				say(Format.fill(W.got, { name = petName(res.pet) }), C.accent)
				if ctx.couponGot then
					ctx.couponGot(res) -- 가진 펫 · 탈것을 다시 읽는다(가방의 캐시 탭 · 폰의 단추 배치 목록)
				end
			else
				say(if typeof(res) == "table" and typeof(res.why) == "string" then res.why else W.fail, C.red)
			end
		end)
	end
	use = Ui.button(body, W.use, w - S.btnW, S.fieldY, S.btnW, send, { main = true, h = S.fieldH })
	use.frame.Name = "Do_coupon"
	field.FocusLost:Connect(function(enter: boolean)
		if enter then
			send()
		end
	end)
	local view = {}
	function view.refresh(_me) end
	-- (시험용) 적고 누른 것처럼
	function view.try(text: string)
		field.Text = text
		send()
	end
	view.note = note
	return view
end

return CouponWindow
