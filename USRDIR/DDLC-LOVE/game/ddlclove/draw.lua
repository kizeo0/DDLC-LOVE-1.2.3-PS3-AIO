local xps = {c=260,ct=285,textbox=230,namebox=260}
local yps = {c={593,623,653,683},ct=532,textbox=565,namebox=526}
local gui_ctc_x = 1015
local xh
local yh

local with_r = {'1','1b','2','2b','3','3b','4','4b'}
local with_yr = {'1','1b','2','2b','3','3b'}
changeX = {s={x=0,y=0,z=0},y={x=0,y=0,z=0},n={x=0,y=0,z=0},m={x=0,y=0,z=0}}
unitimer = 0
uniduration = 0.25

function outlineText(text,x,y,type,arg1)
	if g_system == 'PSP' or g_system == 'PS3' or settings.o == 1 or lutro then
		lgsetColor(0,0,0,alpha)
	else
		local addm = 1.5
		if type == 'ct' then
			lgsetColor(187,85,153,alpha)
			addm = 2.35
		elseif style_edited and (type == 'c_disp' or type == 'printf') then
			lgsetColor(255,255,255,alpha)
		elseif type == 'poemgame' then
			lgsetColor(255,175,255,alpha)
		else
			lgsetColor(0,0,0,alpha)
		end
		if type == 'printf' and global_os ~= 'LOVE-WrapLua' then
			lg.printf(text,x-addm,y,arg1)
			lg.printf(text,x,y-addm,arg1)
			lg.printf(text,x+addm,y,arg1)
			lg.printf(text,x,y+addm,arg1)
		else
			lg.print(text,x-addm,y)
			lg.print(text,x,y-addm)
			lg.print(text,x+addm,y)
			lg.print(text,x,y+addm)
		end
		if style_edited and (type == 'c_disp' or type == 'printf') then
			lgsetColor(0,0,0,alpha)
		else
			lgsetColor(255,255,255,alpha)
		end
	end
	if type == 'printf' and global_os ~= 'LOVE-WrapLua' then
		lg.printf(text,x,y,arg1)
	else
		local printtext = lg.print(text,x,y)
		pcall(printtext)
	end
end

function easeQuadInOut(t,b,c,d)
	t = t/(d/2)
	if (t < 1) then
		return c/2*t*t + b
	else
		return -c/2 * ((t-1) * (t-3) - 1) + b
	end
end
	
function easeCubicInOut(t,b,c,d)
	t = t/(d/2)
	if (t < 1) then
		return c/2*t*t*t + b
	else
		t = t - 2
		return c/2*(t*t*t + 2) + b
	end
end

function drawTextBox()
	if sectimer >= 0.5 then
		gui_ctc_x = math.max(gui_ctc_x - 0.1, 1015)
	else
		gui_ctc_x = math.min(gui_ctc_x + 0.1, 1020)
	end
	
	if menu_type ~= 'choice' and not poem_enabled then
		lgsetColor(255,255,255,alpha)
		if ct ~= '' then lg.draw(namebox, xps.namebox, yps.namebox) end
		lg.draw(textbox, xps.textbox, yps.textbox)
		if print_full_text then lg.draw(gui.ctc, gui_ctc_x, 685) end
		
		lgsetColor(0,0,0,alpha)
		lg.setFont(rifficfont)
		outlineText(ct,xps.ct,yps.ct,'ct')
		
		if style_edited then
			lg.setFont(dfnt)
		else
			lg.setFont(allerfont)
		end
		if g_system == 'PSP' then
			xps.c = 240
		end
		if c_disp[1] and g_system == 'PS3' then
			for i = 1, #c_disp do
				outlineText(c_disp[i],xps.c,yps.c[i],'c_disp')
			end
		elseif c_disp[1] then
			outlineText(c_disp[1],xps.c,yps.c[1],'c_disp')
		end
	end
end

-- ============================================================
-- P9: AJUSTE DE LINEA DE POEMAS (PS3).
-- El texto de los poemas (spa y eng) tiene lineas mas largas que la
-- hoja (bg/poem.png, ~800 unidades logicas de ancho desde x=240) y
-- drawPoem imprimia cada linea sin partir nada => se salian por el
-- borde derecho de la hoja. Se reutiliza wrap() de scripts/script.lua
-- (la misma calibracion del dialogo PS3, que corta ~65 chars) con un
-- limite conservador, y se comprime levemente el interlineado cuando
-- el poema crece en filas para que no se corte por abajo.
-- Solo afecta PS3; el resto de plataformas queda intacto.
-- ============================================================
local POEM_WRAP_LIMIT = 60
local poembg_cache_src = nil
local poembg_cache_disp = nil

local function poemWrapLine(line)
	if not line or line == '' then
		return {line}
	end
	-- v2: primero separar por ORACIONES (terminadas en . ! ?). Asi una
	-- oracion que termina con punto baja a la fila siguiente en lugar de
	-- seguir al costado dentro de la misma fila empaquetada.
	local rows = {}
	local rest = line
	while #rest > 0 do
		local piece
		local s, e = rest:find('^([^%.%!%?]+[%.%!%?]+)%s*')
		if s then
			piece = rest:sub(s, e)
			rest = rest:sub(e + 1)
		else
			piece = rest
			rest = ''
		end
		piece = piece:gsub('^%s+', ''):gsub('%s+$', '')
		if piece ~= '' then
			if #piece <= POEM_WRAP_LIMIT then
				rows[#rows+1] = piece
			else
				-- la oracion sola excede el ancho: partir por palabras
				local wrapped = wrap(piece, POEM_WRAP_LIMIT)
				for seg in (wrapped.."\n"):gmatch("(.-)\n") do
					rows[#rows+1] = seg
				end
			end
		end
	end
	if #rows == 0 then rows[1] = line end
	return rows
end

local function poemBuildDisplay()
	local disp = {}
	for i = 1, #poemtext do
		local line = poemtext[i]
		if line then
			local parts = poemWrapLine(line)
			for j = 1, #parts do
				disp[#disp+1] = parts[j]
			end
		else
			disp[#disp+1] = ''
		end
	end
	return disp
end

function drawPoem()
	if poembg then
		lg.draw(poembg, 240, 0)
	elseif yuri_3 then
		lgsetColor(255,0,0,192)
		lg.rectangle('fill',240,0,800,725)
	else
		lgsetColor(243,243,243)
		lg.rectangle('fill',240,0,800,725)
	end
	if poem_author == 'monika' then
		lg.setFont(m1)
	elseif poem_author == 'yuri' and not yuri_3 then
		lg.setFont(y1)
	elseif poem_author == 'sayori' then
		lg.setFont(s1)
	elseif poem_author == 'natsuki' then
		lg.setFont(n1)
	end
	lgsetColor(0,0,0)
	if poemtext and poem_scroll then
		if g_system == 'PS3' then
			-- cache por identidad de tabla: poemtext se reasigna en cada
			-- lectura de poema, asi que esto reconstruye solo al cambiar
			if not rawequal(poembg_cache_src, poemtext) then
				poembg_cache_disp = poemBuildDisplay()
				poembg_cache_src = poemtext
			end
			local disp = poembg_cache_disp
			-- interlineado dinamico: 35 normal; si hay muchas filas (por
			-- el reajuste o por poemas largos), comprimir hasta que la
			-- ultima fila quede dentro de pantalla (presupuesto vertical
			-- ~690 unidades logicas desde la fila 1)
			local rows = #disp
			local step = 35
			if rows > 19 then
				step = math.max(22, math.floor(690 / math.max(rows - 1, 1)))
			end
			for i = 1, rows do
				lg.print(disp[i],250+(poem_scroll.x*30)-30,((poem_scroll.y*24)+(i*step))-25)
			end
		else
			for i = 1, #poemtext do
				if poemtext[i] then
					lg.print(poemtext[i],250+(poem_scroll.x*30)-30,((poem_scroll.y*24)+(i*35))-25)
				end
			end
		end
	end
end

function drawConsole()
	if console_enabled then
		lgsetColor(51,51,51,191)
		lg.rectangle('fill',0,0,500,180)
		lgsetColor(255,255,255)
		lg.setFont(consolefont)
		lg.print('> '..console_text1,0,0)
		lg.print(console_text2,15,30)
		lg.print(console_text3,15,50)
		lg.print(console_text4,15,70)
	end
end

function nearest(a,b)
	local n = 3
	if (a >= b - n) and (a <= b + n) then
		return true
	else
		return false
	end
end

--Character draw functions in 1.0.2

function updateCharacter(set,a,b,px,py,chset)
	if not b then b = '' end
	set.a = a
	set.b = b
	
	if px and xaload == 0 then
		chset.x = set.x
		chset.y = px*3.2
		if chset.x < chset.y then
			chset.z = chset.y - chset.x
		elseif chset.x > chset.y then
			chset.z = chset.x - chset.y
		else
			chset.z = 0
		end
	end
	if py then set.y = py end
end

function updateSayori(a,b,px,py)
	updateCharacter(s_Set,a,b,px,py,changeX.s)
	if xaload == 0 and not (autoskip and autoskip > 0 and g_system == 'PS3') then loadSayori() end
end

function updateYuri(a,b,px,py)
	updateCharacter(y_Set,a,b,px,py,changeX.y)
	if xaload == 0 and not (autoskip and autoskip > 0 and g_system == 'PS3') then loadYuri() end
end

function updateNatsuki(a,b,px,py)
	updateCharacter(n_Set,a,b,px,py,changeX.n)
	if xaload == 0 and not (autoskip and autoskip > 0 and g_system == 'PS3') then loadNatsuki() end
end

function updateMonika(a,b,px,py)
	updateCharacter(m_Set,a,b,px,py,changeX.m)
	if xaload == 0 and not (autoskip and autoskip > 0 and g_system == 'PS3') then loadMonika() end
end

function hideCharacter(set,chset)
	if xaload == 0 then
		chset.x = set.x
		chset.y = -675
		chset.z = chset.x - chset.y
	end
end

function hideSayori()
	hideCharacter(s_Set,changeX.s)
end

function hideYuri()
	hideCharacter(y_Set,changeX.y)
end

function hideNatsuki()
	hideCharacter(n_Set,changeX.n)
end

function hideMonika()
	hideCharacter(m_Set,changeX.m)
end

function hideAll()
	s_Set = {a='',b='',x=-675,y=4}
	y_Set = {a='',b='',x=-675,y=4}
	n_Set = {a='',b='',x=-675,y=4}
	m_Set = {a='',b='',x=-675,y=4}
	unloadAll()
end

function drawCharacter(l,r,a,set,chset)
	if set.b~='' then
		if set == n_Set and (n_Set.a=='5' or n_Set.a=='5b') then --set natsuki's head x and y pos
			xh = set.x + 14
			yh = set.y + 18
		else
			xh = set.x
			yh = set.y
		end
		if global_os == 'LOVE-WrapLua' then
			yh = yh + 2
		end
		if a then lg.draw(a,xh,yh) end
	end
	
	lg.draw(l, set.x, set.y)
	
	local with_set = with_r
	if set == y_Set then
		with_set = with_yr
	end
	for i = 1, #with_set do
		if set.a == with_set[i] and global_os == 'LOVE-WrapLua' then
			lg.draw(r,set.x-1,set.y)
		elseif set.a == with_set[i] then
			lg.draw(r,set.x,set.y)
		end
	end
	
	if set.x ~= chset.y and (autoskip >= 1 or unitimer >= uniduration) then
		set.x = chset.y
	elseif set.x < chset.y and not nearest(set.x,chset.y) then
		set.x = math.ceil(chset.x + easeQuadInOut(unitimer,0,chset.z,uniduration))
	elseif set.x > chset.y and not nearest(set.x,chset.y) then
		set.x = math.floor(chset.x - easeQuadInOut(unitimer,0,chset.z,uniduration))
	end
end

function drawSayori()
	drawCharacter(sl,sr,s_a,s_Set,changeX.s)
end

function drawYuri()
	drawCharacter(yl,yr,y_a,y_Set,changeX.y)
end

function drawNatsuki()
	drawCharacter(nl,nr,n_a,n_Set,changeX.n)
end

function drawMonika()
	drawCharacter(ml,mr,m_a,m_Set,changeX.m)
end
