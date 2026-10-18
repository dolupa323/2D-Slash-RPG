-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_lune_game.mjs).
-- 처음 화면(로딩 화면 · 캐릭터 고르기): 그림(img) · 달 · 언덕(ground = 캐릭터의 발이 닿는 줄) · 제목의 자리 · 글(text). 단위는 게임 세계의 도트.
return {
	name = "달의 계승자",
	moon = { x = 192, y = 112, r = 54 },
	ground = 150,
	ridge = { y = 66, h = 152 },
	logo = { w = 168, h = 50, y = 12 },
	clouds = { w = 384, h = 112 },
	slots = { gap = 54 },
	create = { gap = 60 },
	heroes = { gap = 26, tint = "#1b212d" },
	img = { sky = "title_sky.png", clouds = "title_clouds.png", ridge = "title_ridge.png", logo = "title_logo.png" },
	text = { loading = "불러오는 중", start = "START", startHint = "Enter · Space · 화면을 눌러도 시작합니다", select = "캐릭터 선택", selectHint = "← → 고르기 · Enter 시작", empty = "빈 자리", enter = "게임 시작", create = "캐릭터 만들기", remove = "캐릭터 삭제", back = "뒤로", make = "만들기", createTitle = "캐릭터 만들기", createHint = "← → 직업 고르기", nameLabel = "이름", nameRule = "한글 2~6자 · 영문/숫자 4~12자", namePlaceholder = "이름을 적어 주세요", check = "중복 확인", checking = "확인하는 중 …", nameFree = "쓸 수 있는 이름입니다", needCheck = "이름을 적고 중복 확인을 눌러 주세요", full = "캐릭터를 더 만들 수 없습니다", noName = "이름이 없는 캐릭터입니다 — 이름을 지어야 들어갈 수 있습니다", giveName = "이름 짓기", nameTitle = "이름 짓기", setName = "확인", removeTitle = "캐릭터 삭제", removeWarn = "지운 캐릭터는 되돌릴 수 없습니다. 창고의 물건은 남습니다.", removeAsk = "지우려면 캐릭터의 이름을 그대로 적어 주세요", removeDo = "삭제", cancel = "취소", wait = "잠시만 기다려 주세요 …", failed = "서버가 답하지 않습니다. 잠시 뒤에 다시 해 주세요" },
	show = {
		lead = 0.5,
		rest = 2.4,
		speed = 0.8,
		skill = { axion = "ax_slam", riven = "rv_fan", reaper = "rp_double", mooni = "mn_spin", salamander = "sl_punch" },
	},
}
