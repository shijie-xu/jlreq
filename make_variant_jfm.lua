kpse.set_program_name("texlua","lualatex")
require('lualibs')

function burasage(t)
	t = table.fastcopy(t)
	-- 句読点の幅を0にして，句読点に続くglueを0.5増やす．
	for _,class in ipairs({6,7}) do
		local width = t[class].width
		t[class].width = 0
		if t[class].glue ~= nil then
			for key,_ in pairs(t[class].glue) do
				t[class].glue[key][1] = t[class].glue[key][1] + width
			end
		end
		if t[class].kern ~= nil then
			for key,val in pairs(t[class].kern) do
				if type(val) == "table" then
					t[class].glue[key][1] = t[class].glue[key][1] + width
				else
					t[class].glue[key] = t[class].glue[key] + width
				end
			end
		end
	end
	return t
end

function zenkaku_kakko(t)
	t = table.fastcopy(t)
	-- 開き括弧のwidthを0.5増やす
	t[1].width = t[1].width + 0.5
	for cls,val in pairs(t) do
		if type(cls) ~= "number" then goto continue end
		if t[cls].glue ~= nil and t[cls].glue[1] ~= nil then
			t[cls].glue[1][1] = t[cls].glue[1][1] - 0.5
		end
		if t[cls].kern ~= nil and t[cls].kern[1] ~= nil then
			if type(t[cls].kern[1]) == "table" then
				t[cls].kern[1][1] = t[cls].kern[1][1] - 0.5
			else
				t[cls].kern[1] = t[cls].kern[1] - 0.5
			end
		end
		::continue::
	end
	return t
end

function tate(t)
	t = table.fastcopy(t)
	t.dir = 'tate'
	for key,_ in pairs(t) do
		if type(key) == "number" then
			t[key].height = 0.5
			t[key].depth = 0.5
		end
	end
	return t
end

-- jfmのテーブル，ファイル名
function make_jfmfile(t,f)
	table.tofile(f,t,"local jfm")
	local fp = io.open(f,"a")
	fp:write("luatexja.jfont.define_jfm(jfm)\n")
end

local originaljfm = "jlreq"

local jfmfile = kpse.find_file("jfm-" .. originaljfm .. ".lua")
if jfmfile == nil then
	print("JFM " .. originaljfm .. " is not found")
	os.exit(1)
end

jfm = nil
luatexja = {}
luatexja.jfont = {}

function luatexja.jfont.define_jfm(j)
	jfm = j
end

dofile(jfmfile)

make_jfmfile(burasage(jfm),"jfm-b" .. originaljfm .. ".lua")
make_jfmfile(zenkaku_kakko(jfm),"jfm-z" .. originaljfm .. ".lua")
make_jfmfile(burasage(zenkaku_kakko(jfm)),"jfm-bz" .. originaljfm .. ".lua")
make_jfmfile(burasage(tate(jfm)),"jfm-b" .. originaljfm .. "v.lua")
make_jfmfile(zenkaku_kakko(tate(jfm)),"jfm-z" .. originaljfm .. "v.lua")
make_jfmfile(burasage(zenkaku_kakko(tate(jfm))),"jfm-bz" .. originaljfm .. "v.lua")

local jfm = tate(jfm)
local file = "jfm-" .. originaljfm .. "v.lua"
table.tofile(file,jfm,"local jfm")
local fp = io.open(file,"a")
fp:write([[
local function add_space(before,after,glueorkern,space,ratio)
	if jfm[before][glueorkern] == nil then jfm[before][glueorkern] = {} end
	if jfm[before][glueorkern][after] == nil then jfm[before][glueorkern][after] = {0} end
	local origratio = jfm[before][glueorkern][after].ratio
	if origratio == nil then origratio = 0.5 end
	jfm[before][glueorkern][after].ratio = (jfm[before][glueorkern][after][1] * origratio + space * ratio) /  (jfm[before][glueorkern][after][1] + ratio)
	jfm[before][glueorkern][after][1] = jfm[before][glueorkern][after][1] + space
end

if jlreq ~= nil then
	if type(jlreq.open_bracket_pos) == "string" then
		local r = jlreq.open_bracket_pos:find("_")
		local danraku = jlreq.open_bracket_pos:sub(1,r - 1)
		local orikaeshi = jlreq.open_bracket_pos:sub(r + 1)

		-- 折り返し行頭の開き括弧を二分下げる……つもり
		if orikaeshi == "nibu" then
			-- widthを二分増やし，その代わりJFMグルーを二分減らす
			jfm[1].width = jfm[1].width + 0.5
			for k,v in pairs(jfm) do
				if type(k) == "number" then
					add_space(k,1,"glue",-0.5,1)
				end
			end
		end

		-- 段落行頭の下げ
		if danraku == "zenkakunibu" then
			add_space(90,1,"glue",0.5,1)
		elseif danraku == "nibu" then
			add_space(90,1,"glue",-0.5,1)
		end
	end

	-- ぶら下げ組を有効にする．
	if jlreq.burasage == true then
		for _,class in ipairs({6,7}) do
			table.insert(jfm[class].end_adjust,-0.5)
		end
	end
end
luatexja.jfont.define_jfm(jfm)
]])
fp:close()


