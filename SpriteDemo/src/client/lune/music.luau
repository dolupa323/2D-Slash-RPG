-- 음악 — 장면마다의 배경 음악과 짧은 징글(퀘스트 완료 · 레벨 업 · 쓰러짐 · 숨은 방).
--  사용자 2026-10-10: "소리는 … 뮤직에셋 가져왔습니다. 이걸 알맞게 배치해보고 추후 제가 어색한게있으면 말해드릴게요"
--  어느 곡을 어디에 트는지 · 곡마다의 크기는 shared/lune/data/music.generated.luau(공방의 js/lune/design/music.js — 배치는 모두 제안이다).
--  배경 음악: 장면이 바뀌면 그 장면의 곡으로 천천히(fade초) 넘어간다. 같은 곡이면 끊지 않고 이어 튼다(마을 → 건물 안).
--  징글: 배경 음악을 잠깐 줄이고(duck) 한 번 튼다.
--  올린 오디오의 번호(id)가 아직 없는 곡은 조용히 건너뛴다 — 오디오는 사용자가 로블록스에 올린다(공방의 tools/build_lune_music.mjs).
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MUSIC = require(ReplicatedStorage.shared.lune.data["music.generated"])

local Music = {}
Music.on = true -- 소리를 켰는가(메뉴의 「소리」)
Music.now = nil :: string? -- 지금 트는 곡의 이름표

local folder: Folder? = nil
local playing = {} -- [이름표] = { sound, want(가려는 크기 0~1), at(지금 크기 0~1), base(그 곡의 크기) }
local duckT = 0 -- 징글이 끝날 때까지 남은 시간(초)

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
		local master = if Music.on then 1 else 0
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
	Music.play(MUSIC.scene[sceneKey])
end

-- 짧은 징글을 한 번 튼다(배경 음악은 그동안 줄인다)
function Music.jingle(key: string)
	ensure()
	local def = MUSIC.jingles[key]
	if not def or def.id == "" or not Music.on then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Jingle_" .. key
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.Parent = folder
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	duckT = math.max(duckT, def.sec)
end

-- 효과음을 한 번 낸다(타격 · 쓰러뜨림 · 맞음 · 줍기 — 공방 music.js의 sfx). 올린 번호가 없으면 아무 소리도 나지 않는다.
--  같은 소리는 gap초 안에 다시 내지 않는다(연타 · 여럿을 한꺼번에 칠 때 뭉개지지 않게). 돌려주는 것: 소리를 냈는가
local sfxAt: { [string]: number } = {}
function Music.sfx(key: string): boolean
	local def = MUSIC.sfx and MUSIC.sfx[key]
	if not def or def.id == "" or not Music.on then
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
	sound.Volume = def.volume
	sound.Parent = folder
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	return true
end

-- 타격의 소리: 셋 가운데 하나를 돌려 가며(같은 소리만 되풀이되지 않게). 센 타격 · 치명타는 제 소리
local hitTurn = 0
function Music.hit(big: boolean?)
	if big then
		Music.sfx("hitBig")
	else
		hitTurn = hitTurn % 3 + 1
		Music.sfx("hit" .. hitTurn)
	end
end

-- 소리를 켜고 끈다(메뉴). 돌려주는 것: 지금 켜져 있는가
function Music.toggle(): boolean
	ensure()
	Music.on = not Music.on
	return Music.on
end

return Music
