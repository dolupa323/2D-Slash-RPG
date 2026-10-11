-- 길잡이 — 화면 가운데의 큰 알림 한 줄(「달이 부른다」 · 「2차 전직」)과, 처음 하는 사람에게 지금 누를 키를 알려 주는 안내 한 줄.
--  설계: 공방 js/lune/design/basics.js의 START("처음 쓰는 키는 화면 가운데에 크게 한 번 뜬다") · JOBFLOW("화면 가운데에 '달이 부른다'가 뜬다") · startplan.js의 차례 ②(첫 5분).
--  판 없이, 어두운 테두리를 두른 글씨를 화면 위쪽 가운데에 적는다(보스 체력 칸 아래 — 다른 늘 보이는 것과 겹치지 않는 자리). 글은 폭을 넘지 않는다(안내는 두 줄까지).
--  안내 글은 캐릭터의 지금 상태에서 그때그때 셈한다(Guide.pick) — 무엇을 봤는지 따로 저장하지 않는다: 할 일을 하면 그 안내는 저절로 사라지고, 레벨이 오르면 더 뜨지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local GuideText = require(lune.ui.guideText)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR

local Guide = {}
Guide.HINT_W, Guide.HINT_LINES = GuideText.W, GuideText.LINES -- 안내 글의 칸(자동 검사가 글이 이 안에 들어가는지 본다)
Guide.BANNER_W = 480
Guide.HINT_Y, Guide.BANNER_Y = 50, 86 -- 화면 틀의 기준 격자(960x540)에서의 높이 — 캐릭터 머리 위로 뜨는 글(「완료」 · 「레벨 업!」)보다 위

local hintBox: Frame, bannerBox: Frame
local hint, title, sub
local hintNow = ""
local bannerLeft = 0

function Guide.init(root: Frame)
	hintBox = Stage.place(root, "GuideHint", "tc", (Stage.REF_W - Guide.HINT_W) / 2, Guide.HINT_Y, Guide.HINT_W, 40)
	hint = Ui.text(hintBox, "", 0, 0, Guide.HINT_W, { align = "center", outline = true, color = C.accent, lines = Guide.HINT_LINES, line = Ui.M.small + 4 })
	hintBox.Visible = false
	bannerBox = Stage.place(root, "GuideBanner", "tc", (Stage.REF_W - Guide.BANNER_W) / 2, Guide.BANNER_Y, Guide.BANNER_W, 44)
	title = Ui.text(bannerBox, "", 0, 0, Guide.BANNER_W, { font = "body", align = "center", outline = true, color = C.gold })
	sub = Ui.text(bannerBox, "", 0, Ui.M.body + 8, Guide.BANNER_W, { align = "center", outline = true, color = C.text })
	bannerBox.Visible = false
end

-- 안내 한 줄(없으면 nil · 빈 글)
function Guide.setHint(text: string?)
	local value = text or ""
	if value ~= hintNow then
		hintNow = value
		hint:set(value)
	end
	hintBox.Visible = value ~= ""
end

-- 큰 알림: 제목(노랑) + 한 줄. seconds 뒤에 사라진다
function Guide.banner(head: string, line: string?, seconds: number?)
	title:set(head)
	sub:set(line or "")
	bannerLeft = seconds or 4
	bannerBox.Visible = true
end

function Guide.step(dt: number)
	if bannerLeft > 0 then
		bannerLeft -= dt
		if bannerLeft <= 0 then
			bannerBox.Visible = false
		end
	end
end

function Guide.clear()
	bannerLeft = 0
	bannerBox.Visible = false
	Guide.setHint(nil)
end

-- 지금 띄울 안내를 고른다(셈은 shared/lune/ui/guideText.luau)
Guide.pick = GuideText.pick

return Guide
