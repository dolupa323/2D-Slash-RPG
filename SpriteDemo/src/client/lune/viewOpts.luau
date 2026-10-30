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
		ViewOpts.touch = if sound.touch == "old" then "old" else "new"
	end
	ViewOpts.applyLang()
	ViewOpts.applyTouch()
end

-- 고른 폰 단추 배치를 건다(예전 배치 = 상호작용 단추가 조이스틱 바로 옆 · 체력 막대도 그때의 자리 — 2026-10-28)
function ViewOpts.applyTouch()
	local old = ViewOpts.touch == "old"
	pcall(function()
		require(script.Parent.touch).setLegacy(old)
		require(script.Parent.hud).setLegacy(old)
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
	end
end

-- 저장할 꼴에 얹는다(소리 설정의 표에 fx · nums를 더한다)
function ViewOpts.into(t)
	t.fx, t.nums, t.myNums, t.lang, t.touch = ViewOpts.fx, ViewOpts.nums, ViewOpts.myNums, ViewOpts.lang, ViewOpts.touch
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
