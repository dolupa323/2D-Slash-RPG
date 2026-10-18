-- 화면 설정(2026-10-18 — 메뉴 → 「설정」의 「화면」 두 줄 · 공방 ui.js의 UILAYOUT.sound.view): 다른 사람의 스킬 효과(fx) · 다른 사람의 피해 숫자(nums)를 보일지.
--  메이플 · 로스트아크의 「다른 캐릭터의 스킬 이펙트」처럼 — 사람이 많은 맵에서 폰이 버거울 때 끈다. 내 것은 늘 보인다. 몸의 움직임 · 몬스터의 맞는 모습 · 설치 · 소환은 그대로.
--  소리 설정과 함께 계정에 저장된다(shared/lune/sim/account.luau의 sound.fx · sound.nums — 없으면 켜짐)
local ViewOpts = { fx = true, nums = true }

-- 저장된 설정을 얹는다(서버가 준 계정의 sound)
function ViewOpts.import(sound: any)
	if typeof(sound) == "table" then
		ViewOpts.fx = sound.fx ~= false
		ViewOpts.nums = sound.nums ~= false
	end
end

-- 저장할 꼴에 얹는다(소리 설정의 표에 fx · nums를 더한다)
function ViewOpts.into(t)
	t.fx, t.nums = ViewOpts.fx, ViewOpts.nums
	return t
end

function ViewOpts.toggle(key: string): boolean
	if key ~= "fx" and key ~= "nums" then
		return false
	end
	ViewOpts[key] = not ViewOpts[key]
	return true
end

return ViewOpts
