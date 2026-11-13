-- 채널 창 — 메뉴 → 「채널」(2026-11-12 사용자: "메이플스토리처럼 한 서버에 채널을 두어서 채널변경으로 사냥터를 별개로 쓸수있는개념을 도입할수있나?").
--  줄마다 「채널 n」 · 그 채널의 사람 수 · 「이동」(지금 채널은 「지금」). 위에 안내 한 줄(사냥터만 채널마다 따로) · 아래에 결과 한 줄.
--  서버 world.luau World.onChannel(Net "Channel" — "list" · "go") · 글은 공방 design/world.js의 CHANNELS(sim/channel.luau). 화면 오른쪽의 옆 판(ui/windows.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Format = require(lune.ui.format)
local Net = require(lune.net.net)
local Channel = require(lune.sim.channel)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local W = Channel.DATA.words
local ROW, TOP, BTN_W = 30, 22, 64 -- [제가 정한 것] 줄 높이 · 첫 줄의 위 · 단추 폭

local ChannelWindow = {}

function ChannelWindow.size(): (number, number)
	return 240, TOP + Channel.COUNT * ROW + 36 -- (아래 결과는 두 줄까지)
end

function ChannelWindow.build(body: Frame, _ctx, w: number, _h: number)
	local view = {}
	local alive = true
	local data = nil
	local busy = false
	Ui.text(body, W.note, 0, 0, w, { color = C.dim })
	local msg = Ui.text(body, "", 0, TOP + Channel.COUNT * ROW + 6, w, { color = C.dim, lines = 2 })
	local rows = {}
	local function paint()
		if not alive or not data then
			return
		end
		for n, r in rows do
			local c = (data.counts and data.counts[n]) or 0
			r.people:set(Format.fill(W.people, { n = c }))
			local here = n == data.now
			r.name:color(if here then C.accent else C.text)
			r.btn:setText(if here then W.now else W.go)
			r.btn:setMain(here)
			r.btn:setEnabled(not here and not busy)
		end
	end
	local function say(text: string, color: Color3)
		msg:set(text)
		msg:color(color)
	end
	local function go(n: number)
		if busy or not data or n == data.now then
			return
		end
		busy = true
		paint()
		task.spawn(function()
			local ok, r = pcall(Net.Invoke, "Channel", "go", n)
			busy = false
			if not alive then
				return
			end
			if ok and typeof(r) == "table" then
				data = r
				if r.ok then
					say(Format.fill(W.changed, { n = r.now }) .. (if r.splits then "" else " — " .. W.town), C.accent) -- (마을이면 다음 사냥 맵부터)
				else
					say(if typeof(r.why) == "string" then r.why else W.busy, C.red)
				end
			else
				say(W.busy, C.red)
			end
			paint()
		end)
	end
	for n = 1, Channel.COUNT do
		local y = TOP + (n - 1) * ROW
		local name = Ui.text(body, Format.fill(W.row, { n = n }), 0, y + 7, 90, { font = "body" })
		local people = Ui.text(body, "", 96, y + 8, w - 96 - BTN_W - 8, { color = C.dim })
		local btn = Ui.button(body, W.go, w - BTN_W, y + 2, BTN_W, function()
			go(n)
		end, { h = 24 })
		btn.frame.Name = "Do_channel" .. n
		rows[n] = { name = name, people = people, btn = btn }
	end
	task.spawn(function()
		local ok, r = pcall(Net.Invoke, "Channel", "list")
		if alive and ok and typeof(r) == "table" then
			data = r
			paint()
		end
	end)
	function view.refresh(_me) end
	function view.destroy()
		alive = false
	end
	return view
end

return ChannelWindow
