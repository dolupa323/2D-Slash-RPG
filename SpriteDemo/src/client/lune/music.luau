-- 음악 — 장면마다의 배경 음악과 짧은 징글(레벨 업 · 전직), 효과음(줍기 · 완료 · 수락 …).
--  때릴 때 · 맞을 때 · 대쉬의 소리는 없다(사용자 2026-10-14: "플레이어랑 몬스터 때릴 때 나는 소리랑 맞을때 나는 소리 전부 빼겠습니다. 대쉬 소리 빼겠습니다.") · 뛰기 소리도 없다("점프소리도 제거하세요").
--  다만 내 타의 데미지 숫자가 뜰 때마다 「damage」가 한 번씩 난다(사용자가 고른 소리 — 틈 0: 여러 마리 · 여러 타가 겹쳐도 하나하나 난다).
--  2026-10-14 사용자가 소리를 다시 골라 올렸다 — 퀘스트 완료 · 사망 · 숨은 방에는 징글이 없고(배경 음악을 줄이지 않는다) 효과음만 난다.
--  사용자 2026-10-10: "소리는 … 뮤직에셋 가져왔습니다. 이걸 알맞게 배치해보고 추후 제가 어색한게있으면 말해드릴게요"
--  어느 곡을 어디에 트는지 · 곡마다의 크기는 shared/lune/data/music.generated.luau(공방의 js/lune/design/music.js — 배치는 모두 제안이다).
--  배경 음악: 장면이 바뀌면 그 장면의 곡으로 천천히(fade초) 넘어간다. 같은 곡이면 끊지 않고 이어 튼다(마을 → 건물 안).
--  징글: 배경 음악을 잠깐 줄이고(duck) 한 번 튼다.
--  크기: 배경 음악과 효과음(타격 · 줍기 · 징글)을 따로 0~steps칸으로(한 칸 10%) — 메뉴 → 「소리 설정」(ui/soundWindow.luau). 계정에 저장된다.
--   사용자 2026-10-13: "소리조절 있어야합니다." — 그 앞에는 「소리 끄기 / 켜기」뿐이었고 저장되지 않았다.
--  올린 오디오의 번호(id)가 아직 없는 곡은 조용히 건너뛴다 — 오디오는 사용자가 로블록스에 올린다(공방의 tools/build_lune_music.mjs).
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MUSIC = require(ReplicatedStorage.shared.lune.data["music.generated"])
local SOUND = require(ReplicatedStorage.shared.lune.data["ui.generated"]).layout.sound -- 칸 수(steps) · 처음 크기(start)

local Music = {}
Music.on = true -- 모두 켰는가(소리 설정의 「모두 끄기 / 켜기」)
Music.MAX = SOUND.steps
Music.level = { music = SOUND.start, sfx = SOUND.start } -- 크기(0~MAX칸): music = 배경 음악 · sfx = 효과음과 징글
Music.now = nil :: string? -- 지금 트는 곡의 이름표

local folder: Folder? = nil
local playing = {} -- [이름표] = { sound, want(가려는 크기 0~1), at(지금 크기 0~1), base(그 곡의 크기) }
local duckT = 0 -- 징글이 끝날 때까지 남은 시간(초)

-- 그 갈래의 크기(0~1): 모두 껐으면 0
local function gain(kind: string): number
	return if Music.on then Music.level[kind] / Music.MAX else 0
end
Music.gain = gain

local function ensure()
	if folder then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "LuneMusic"
	f.Parent = SoundService
	folder = f
	-- 크기를 장마다 조금씩 옮긴다(넘어가기 · 징글 동안 줄이기)
	RunService.Heartbeat:Connect(function(dt)
		duckT = math.max(0, duckT - dt)
		local duck = if duckT > 0 then MUSIC.duck else 1
		local master = gain("music")
		for key, p in playing do
			local step = dt / MUSIC.fade
			if p.at < p.want then
				p.at = math.min(p.want, p.at + step)
			elseif p.at > p.want then
				p.at = math.max(p.want, p.at - step)
			end
			p.sound.Volume = p.base * p.at * duck * master
			if p.want == 0 and p.at == 0 then
				p.sound:Destroy()
				playing[key] = nil
			end
		end
	end)
end

-- 그 이름표의 곡을 배경 음악으로 튼다(nil이면 끈다). 번호가 없는 곡이면 지금 곡만 잦아든다
function Music.play(key: string?)
	ensure()
	if key == Music.now then
		return
	end
	Music.now = key
	for k, p in playing do
		p.want = if k == key then 1 else 0
	end
	local def = if key then MUSIC.tracks[key] else nil
	if not key or not def or def.id == "" or playing[key] then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = def.id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = folder
	sound:Play()
	playing[key] = { sound = sound, want = 1, at = 0, base = def.volume }
end

-- 그 장면의 곡을 튼다
function Music.scene(sceneKey: string)
	Music.play(MUSIC.scene[sceneKey] or MUSIC.scene[string.match(sceneKey, "^(.-)#%d+$") or ""]) -- 토벌의 방(rf1#3)은 그 장면(rf1)의 곡
end

-- 짧은 징글을 한 번 튼다(배경 음악은 그동안 줄인다)
function Music.jingle(key: string)
	ensure()
	local def = MUSIC.jingles[key]
	if not def or def.id == "" or gain("sfx") <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Jingle_" .. key
	sound.SoundId = def.id
	sound.Volume = def.volume * gain("sfx")
	sound.Parent = folder
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	duckT = math.max(duckT, def.sec)
end

-- 효과음을 한 번 낸다(줍기 · 완료 · 수락 … — 공방 music.js의 sfx). 올린 번호가 없으면 아무 소리도 나지 않는다.
--  같은 소리는 gap초 안에 다시 내지 않는다(연타 · 여럿을 한꺼번에 칠 때 뭉개지지 않게). 돌려주는 것: 소리를 냈는가
--  whole = upto가 있는 소리도 끝까지 튼다(데미지 소리: 줄마다는 짧게 다다다다, 그 타의 마지막 줄만 끝까지 — 사용자 2026-10-14)
local sfxAt: { [string]: number } = {}
function Music.sfx(key: string, whole: boolean?): boolean
	local def = MUSIC.sfx and MUSIC.sfx[key]
	if not def or def.id == "" or gain("sfx") <= 0 then
		return false
	end
	local now = os.clock()
	if now - (sfxAt[key] or -9) < def.gap then
		return false
	end
	sfxAt[key] = now
	ensure()
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. key
	sound.SoundId = def.id
	sound.Volume = def.volume * gain("sfx")
	if def.upto and not whole then
		-- 앞에서부터 upto초까지만 튼다(데미지 소리 — 사용자 2026-10-14: "이 음성파일의 절반 만 재생합니다")
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(0, def.upto)
		task.delay(def.upto + 0.5, function()
			if sound.Parent then
				sound:Destroy() -- 구간 끝에서 Ended가 오지 않아도 치운다
			end
		end)
	end
	sound.Parent = folder
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	return true
end

-- 모두 켜고 끈다(소리 설정). 돌려주는 것: 지금 켜져 있는가
function Music.toggle(): boolean
	ensure()
	Music.on = not Music.on
	return Music.on
end

-- 그 갈래("music" · "sfx")의 크기를 n칸으로. 돌려주는 것: 바뀌었는가(범위 밖 · 같은 값이면 false)
function Music.setLevel(kind: string, n: number): boolean
	if typeof(n) ~= "number" or Music.level[kind] == nil or n ~= math.floor(n) or n < 0 or n > Music.MAX or Music.level[kind] == n then
		return false
	end
	Music.level[kind] = n
	return true
end

-- 저장된 설정을 얹는다(서버가 준 계정의 것 — 꼴은 서버가 이미 봤다) · 저장할 꼴로 내놓는다
function Music.import(sound: any)
	if typeof(sound) ~= "table" then
		return
	end
	Music.setLevel("music", sound.music)
	Music.setLevel("sfx", sound.sfx)
	Music.on = sound.on ~= false
end
function Music.export()
	return { music = Music.level.music, sfx = Music.level.sfx, on = Music.on }
end

return Music
