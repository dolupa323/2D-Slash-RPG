-- 「달의 계승자」 — 화면 아래 메뉴 단추를 끌어 옮긴 차례(2026-11-06 사용자: "게임내 팝업 ui들 퀘스트, 인벤토리 이런거 버튼있잖아 이런것도 드래그앤 드랍으로 위치 바꿀수있게 해줘").
--  ① 계정에 적는 꼴(Account.setMenu — 영문 소문자 이름표 · 겹치지 않게 · 16개까지) ② 저장했다가 읽어도 그대로 · 캐릭터 고르기 화면에 보낸다
--  ③ 늘어놓기(Layout.menuOrder — 공방 design/ui.js menuOrder와 같은 셈): 적힌 차례 → 적히지 않은 단추는 뒤에 · 없는 이름표는 건너뛴다
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")

-- ① 꼴
local acct = Account.new()
eq(acct.menu, false, "처음 = 차례 없음(설계의 차례)")
expect(Account.setMenu(acct, { "quest", "bag", "more" }), "이름표 목록을 적는다")
eq(table.concat(acct.menu, ","), "quest,bag,more", "적은 차례")
expect(not Account.setMenu(acct, { "bag", "bag" }), "겹친 이름표는 받지 않는다")
expect(not Account.setMenu(acct, { "Bag!" }), "영문 소문자가 아닌 것은 받지 않는다")
expect(not Account.setMenu(acct, { 1, 2 }), "글자가 아닌 것은 받지 않는다")
expect(not Account.setMenu(acct, "bag"), "목록이 아닌 것은 받지 않는다")
local long = {}
for i = 1, 17 do
	long[i] = string.rep("a", i)
end
expect(not Account.setMenu(acct, long), "17개 넘게는 받지 않는다")
eq(table.concat(acct.menu, ","), "quest,bag,more", "받지 않으면 전의 것 그대로")

-- ② 저장 · 읽기 · 보내기
local back = Account.unpack(Account.pack(acct))
eq(table.concat(back.menu, ","), "quest,bag,more", "저장했다가 읽어도 그대로")
eq(table.concat(Account.view(back).menu, ","), "quest,bag,more", "캐릭터 고르기 화면에 보낸다(들어가면 그 차례로)")
local old = Account.pack(Account.new())
old.menu = nil
eq(Account.unpack(old).menu, false, "차례가 생기기 전의 저장 = 설계의 차례")

-- ③ 늘어놓기
local list = {}
for _, id in Layout.MENU.row do
	table.insert(list, { id = id })
end
table.insert(list, { id = "more" })
local out = Layout.menuOrder(list, { "quest", "nothere", "cash", "bag" })
eq(#out, #list, "단추 수는 그대로")
eq(out[1].id, "quest", "적힌 차례 1 = 퀘스트")
eq(out[2].id, "cash", "적힌 차례 2 = 상점(없는 이름표는 건너뛴다)")
eq(out[3].id, "bag", "적힌 차례 3 = 가방")
eq(out[#out].id, "more", "적히지 않은 단추는 설계의 차례대로 뒤에(「메뉴」가 끝)")
eq(Layout.menuOrder(list, nil), list, "차례가 없으면 설계의 차례")
