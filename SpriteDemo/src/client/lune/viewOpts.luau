-- 화면 설정(2026-10-18 — 메뉴 → 「설정」의 「화면」 두 줄 · 공방 ui.js의 UILAYOUT.sound.view): 다른 사람의 스킬 효과(fx) · 다른 사람의 피해 숫자(nums)를 보일지.
--  메이플 · 로스트아크의 「다른 캐릭터의 스킬 이펙트」처럼 — 사람이 많은 맵에서 폰이 버거울 때 끈다. 내 것은 늘 보인다. 몸의 움직임 · 몬스터의 맞는 모습 · 설치 · 소환은 그대로.
--  소리 설정과 함께 계정에 저장된다(shared/lune/sim/account.luau의 sound.fx · sound.nums — 없으면 켜짐 · sound.lang — 언어, 2026-10-27)
local ViewOpts = { fx = true, nums = true, myNums = true, lang = "auto", touch = "new" } -- myNums = 내가 때린 피해 숫자(2026-10-30 사용자 "자기 자신의 데미지 표기도 설정에서 끄기 켜기 할수있게") -- lang = 언어(2026-10-27 — "auto" · "ko" · "en": shared/lune/lang.luau) · touch = 폰 단추 배치(2026-10-28 — "new" · "old")

-- 저장된 설정을 얹는다(서버가 준 계정의 sound)
function ViewOpts.import(sound: any)
	if typeof(sound) == "table" then
		ViewOpts.fx = sound.fx ~= false
		ViewOpts.nums = sound.nums ~= false
		ViewOpts.myNums = sound.myNums ~= false
		ViewOpts.lang = if sound.lang == "ko" or sound.lang == "en" then sound.lang else "auto"
		ViewOpts.touch = if sound.touch == "old" or sound.touch == "left" then sound.touch else "new" -- left = 왼손 배치(셋째 — 2026-11-14) · 2026-11-13의 bar(바로가기)는 새 배치로(바로가기 줄은 이제 세 배치 모두)
		ViewOpts.bar = if typeof(sound.bar) == "table" then table.clone(sound.bar) else nil -- 바로가기 줄에 놓은 것(2026-11-13 — touchBar.luau)
		ViewOpts.chat = if typeof(sound.chat) == "table" then sound.chat else nil -- 채팅 창을 옮긴 자리(2026-11-09 — chat.luau Chat.pos · PC)
		-- 화면 배치(2026-11-12 — ui/arrange.luau · 창의 제목 줄 끌기): 기기 종류마다 { [판의 이름] = { x, y } } · 폰의 채팅 창 자리는 그 안의 Chat
		ViewOpts.ui = { pc = {}, touch = {} }
		if typeof(sound.ui) == "table" then
			for _, kind in { "pc", "touch" } do
				if typeof(sound.ui[kind]) == "table" then
					ViewOpts.ui[kind] = table.clone(sound.ui[kind])
				end
			end
		end
		ViewOpts.applyUi()
	end
	ViewOpts.applyLang()
	ViewOpts.applyTouch()
end

-- 지금 기기 종류(PC · 폰)
function ViewOpts.kind(): string
	local ok, touch = pcall(function()
		return require(script.Parent.stage).touchLike()
	end)
	return if ok and touch then "touch" else "pc"
end
-- 저장된 화면 배치를 건다: 판 · 창의 옮긴 만큼(Stage.moved) · 채팅 창의 자리(PC = sound.chat · 폰 = ui.touch.Chat)
function ViewOpts.applyUi()
	local kind = ViewOpts.kind()
	local Stage = require(script.Parent.stage)
	table.clear(Stage.moved)
	for name, v in (ViewOpts.ui and ViewOpts.ui[kind]) or {} do
		if name ~= "Chat" and typeof(v) == "table" then
			Stage.moved[name] = { x = v.x, y = v.y }
		end
	end
	local chatPos = if kind == "touch" then (ViewOpts.ui and ViewOpts.ui.touch.Chat) else ViewOpts.chat
	pcall(function()
		require(script.Parent.chat).setPos(chatPos)
	end)
end
-- 지금의 화면 배치를 담는다(저장하기 전에): 지금 기기 종류의 것만 바꾼다
function ViewOpts.captureUi()
	local kind = ViewOpts.kind()
	ViewOpts.ui = ViewOpts.ui or { pc = {}, touch = {} }
	local Stage = require(script.Parent.stage)
	local out = {}
	for name, v in Stage.moved do
		out[name] = { x = math.floor(v.x + 0.5), y = math.floor(v.y + 0.5) }
	end
	local ok, chatPos = pcall(function()
		return require(script.Parent.chat).pos
	end)
	chatPos = if ok then chatPos else nil
	if kind == "touch" then
		out.Chat = if chatPos then { x = chatPos.x, y = chatPos.y } else nil
	else
		ViewOpts.chat = chatPos
	end
	ViewOpts.ui[kind] = out
end

-- 고른 폰 단추 배치를 건다(예전 배치 = 상호작용 단추가 조이스틱 바로 옆 · 체력 막대도 그때의 자리 — 2026-10-28 ·
--  바로가기 = 오른쪽 위 바로가기 판 · 「전체」 묶음 메뉴 — 2026-11-13: touchBar.luau · 버프 · 퀘스트 알리미의 자리도)
function ViewOpts.applyTouch()
	if ViewOpts.touch == "bar" then
		ViewOpts.touch = "new" -- (2026-11-13의 「바로가기」 = 이제 새 배치와 같다 — 셋째 자리는 왼손 배치)
	end
	local old = ViewOpts.touch == "old"
	local bar = true -- 바로가기 줄 = 세 배치 모두(2026-11-14 사용자 — 「세 배치 모두 개편 메뉴로」 · 「전체 판 = 화면 가득」 — 전에는 「바로가기」만 · 새 · 예전 배치는 「메뉴」 단추 → 창 이름 목록)
	pcall(function()
		require(script.Parent.touch).setStyle(ViewOpts.touch)
		require(script.Parent.hud).setLegacy(old)
		require(script.Parent.hud).setLeft(ViewOpts.touch == "left") -- (왼손 배치 — 2026-11-14)
		require(script.Parent.gainLog).setLeft(ViewOpts.touch == "left")
		require(script.Parent.hud).setBar(bar)
		require(script.Parent.questHud).setBar(bar)
		require(script.Parent.touchBar).setItems(ViewOpts.bar)
		require(script.Parent.touchBar).setOn(bar)
	end)
end

-- 고른 언어를 화면에 건다(자동이면 로블록스의 언어 설정) — 바뀌었으면 그려 둔 글을 모두 다시 그린다
function ViewOpts.applyLang()
	local Lang = require(game:GetService("ReplicatedStorage").shared.lune.lang)
	local ok, locale = pcall(function()
		return game:GetService("LocalizationService").RobloxLocaleId
	end)
	local was = Lang.code
	Lang.set(Lang.pick(if ok then locale else nil, ViewOpts.lang))
	if Lang.code ~= was then
		require(script.Parent.Parent.modules.ui.pixelText).RefreshAll()
		pcall(function()
			require(script.Parent.chat).build() -- 채팅 창의 탭 자리는 글의 폭으로 놓는다(언어가 바뀌면 다시 — 2026-11-06)
		end)
	end
end

-- 저장할 꼴에 얹는다(소리 설정의 표에 fx · nums를 더한다)
function ViewOpts.into(t)
	t.fx, t.nums, t.myNums, t.lang, t.touch = ViewOpts.fx, ViewOpts.nums, ViewOpts.myNums, ViewOpts.lang, ViewOpts.touch
	t.chat = ViewOpts.chat -- (채팅 창을 옮긴 자리 — 2026-11-09)
	t.ui = ViewOpts.ui -- (화면 배치 — 2026-11-12)
	t.bar = ViewOpts.bar -- (바로가기 줄 — 2026-11-13)
	return t
end

function ViewOpts.toggle(key: string): boolean
	if key ~= "fx" and key ~= "nums" and key ~= "myNums" then
		return false
	end
	ViewOpts[key] = not ViewOpts[key]
	return true
end

return ViewOpts
