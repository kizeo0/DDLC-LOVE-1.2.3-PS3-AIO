dversion = 'v1.2.3'
dvertype = '' --put 'Test' for test mode
print("DDLC-LOVE "..dversion..' '..dvertype)

if lutro then
	love = lutro
	function love.conf(t)
		t.width = 480
		t.height = 272
	end
end
global_os = love.system.getOS()
g_system = love._console_name

-- ============================================================
-- P1 INSTRUMENTACION PS3: logger a savedata/logfile.txt
-- Registra cada textura nueva, transicion de estado, cambio de
-- BGM y evento. Tras un congelamiento en PS3 real, el archivo
-- muestra exactamente cual fue la ultima operacion antes del
-- freeze y cuantas texturas unicas se habian acumulado.
-- El log se reinicia en cada arranque (write) y luego appendea.
-- ============================================================
ps3_logon = (g_system == 'PS3')
ps3_logn = 0
if ps3_logon then
	pcall(function()
		love.filesystem.write('logfile.txt', '=== BOOT DDLC-LOVE '..dversion..' '..dvertype..' diag ===')
		love.filesystem.append('logfile.txt', 'mode='..tostring(lv1lua and lv1lua.mode)..' console='..tostring(love._console_name))
	end)
end
function ps3log(tag)
	if not ps3_logon then return end
	ps3_logn = ps3_logn + 1
	pcall(function()
		love.filesystem.append('logfile.txt', '#'..ps3_logn..' '..tostring(tag))
	end)
end
-- ===== FIN P1 =====

-- ============================================================
-- P2 FRAMESPREAD PS3: cola cooperativa de carga.
-- Las transiciones pesadas encolan pasos (un personaje, un fondo,
-- el audio...) y love.update ejecuta UNO por frame, de modo que el
-- juego nunca vuelve a decodificar 10+ PNG en un solo frame.
-- Mientras la cola esta activa: la logica del estado no corre y el
-- input se ignora; draw sigue corriendo (los draws toleran nil).
-- ============================================================
ps3_loadqueue = nil

function ps3_enqueue(fn)
	if not ps3_loadqueue then ps3_loadqueue = {} end
	ps3_loadqueue[#ps3_loadqueue+1] = fn
end

function ps3_queueActive()
	return ps3_loadqueue ~= nil and #ps3_loadqueue > 0
end

function ps3_stepLoadQueue()
	if not ps3_queueActive() then return false end
	local fn = table.remove(ps3_loadqueue, 1)
	if fn then
		local ok, err = pcall(fn)
		if not ok and ps3log then ps3log('QUEUE ERR '..tostring(err)) end
	end
	if not ps3_queueActive() then
		ps3_loadqueue = nil
	end
	return true
end
-- ===== FIN P2 =====

if g_system == 'Switch' then
	joysticks = love.joystick.getJoysticks()
	joystick = joysticks[1]
end
if global_os == 'Horizon' and g_system ~= 'Switch' and global_os ~= 'LOVE-WrapLua' then
	branch = '3ds'
else
	branch = 'ddlclove'
end

os_timecheck = os.time()
if os_timecheck then
	if branch == 'ddlclove' then
		love.math.setRandomSeed(os.time())
	end
	math.randomseed(os.time())
	math.random()
	math.random()
	math.random()
end

local require_old = require
function require(req)
	print('require: '..req)
	return require_old(req)
end

require('loader/characters')
require(branch..'/loader/audio')
require(branch..'/loader/images')
require('loader/states')
require(branch..'/main')
require(branch..'/menu')
require('saveload')
require('draw')
require('scripts/script')

-- ============================================================
-- P4 STRESSTEST PS3: diagnostico de memoria de texturas.
-- Se activa manteniendo L1 al arrancar el juego. Usa una sola imagen
-- (bg/club.png ~1.11 MB ya decodificada) cargada DIRECTAMENTE por el
-- motor (sin pasar por la cache de lgnewImage):
--   Fase B: carga + suelta referencia + collectgarbage(), 150 veces,
--           sondeando getRes cada 20 -> si sobrevive completa, el __gc
--           del binario LIBERA la memoria nativa (habilita caché débil).
--           Si muere en la iteración K, el GC NO libera y además nos da
--           el presupuesto aproximado (K * 1.11 MB).
--   Fase A: carga acumulando referencias hasta morir o llegar a 300 ->
--           mide el presupuesto duro del heap de texturas del RSX.
-- Todo queda registrado en savedata/logfile.txt y en pantalla.
-- ============================================================
function ps3_stresstest()
	local MB = 1.11 -- bytes decodificados de club.png / 1MB
	local function show(y,txt)
		pcall(function() DrawText(30,y,txt) end)
	end
	local function flip()
		pcall(function() FlipGFX() end)
	end
	pcall(function()
		StartGFX()
		show(30,'PS3 STRESS TEST - no apagues la consola')
		flip()
	end)
	ps3log('STRESS begin')

	-- ---- Fase B: GC libera? ----
	local survivedB = true
	for i = 1, 150 do
		local ok, img = pcall(love.graphics.newImage, 'assets/images/bg/club.png')
		if not ok then
			ps3log('STRESS B fail(newImage) iter='..i..' err='..tostring(img))
			survivedB = false
			break
		end
		img = nil
		collectgarbage()
		if i % 20 == 0 then
			local ok2, res = pcall(function()
				local probe = love.graphics.newImage('assets/images/bg/club.png')
				local w,h = probe:getRes()
				return w
			end)
			ps3log('STRESS B iter='..i..' probe='..tostring(ok2))
		end
		if i % 10 == 0 then
			pcall(function()
				StartGFX()
				show(60,'Fase B (soltar refs + GC): '..i..'/150')
				flip()
			end)
			ps3log('STRESS B alive iter='..i)
		end
	end
	if survivedB then
		ps3log('STRESS B SURVIVED => __gc SI libera texturas')
	else
		ps3log('STRESS B DIED => __gc NO libera texturas')
	end

	-- ---- Fase A: presupuesto duro acumulando refs ----
	local keep = {}
	local na = 0
	for i = 1, 300 do
		local ok, img = pcall(love.graphics.newImage, 'assets/images/bg/club.png')
		if not ok then
			ps3log('STRESS A fail(newImage) iter='..i..' err='..tostring(img))
			break
		end
		keep[#keep+1] = img
		na = i
		if i % 5 == 0 then
			ps3log('STRESS A alive iter='..i..' (~'..math.floor(i*MB)..' MB)')
			pcall(function()
				StartGFX()
				show(90,'Fase A (acumular refs): '..i..' texturas ~= '..math.floor(i*MB)..' MB')
				flip()
			end)
		end
	end
	ps3log('STRESS RESULT B_survived='..tostring(survivedB)..' A_reached='..na..' (~'..math.floor(na*MB)..' MB)')
	pcall(function()
		StartGFX()
		show(120,'TEST COMPLETO - guarda logfile.txt y reinicia')
		show(150,'Fase B sobrevivio: '..tostring(survivedB)..' | Fase A llego a: '..na)
		flip()
	end)
end
-- ===== FIN P4 =====

function love.load()
	-- P4: modo test de estrés (mantener L1 al arrancar el juego)
	local l1held = false
	if g_system == 'PS3' and pad ~= nil then
		pcall(function() l1held = (pad.L1(0) or 0) > 0 end)
	end
	if l1held then
		ps3_stresstest()
		return
	end
	lg.setBackgroundColor(0,0,0)
	if lutro then
		dfnt = love.graphics.newImageFont('FontMedium.png', " 0123456789abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVXYZ!-.,$")
	end
	getTime = 0
	startTime = getTime
	last_text = ''
	print_full_text = false
	autotimer = 0
	autoskip = 0
	sectimer = 0
	xaload = 0
	alpha = 255
	posX = -40
	posY = 0
	menu_enabled = false
	textbox_enabled = true
	bgimg_disabled = false
	
	if pcall (lg.set3D, true) == true then
		lg.set3D(true)
	end
	
	if global_os ~= 'Horizon' and global_os ~= 'LOVE-WrapLua' and not lutro then
		love.window.setFullscreen(true)
		love.window.setTitle('DDLC-LOVE')
		love.keyboard.setTextInput(false)
		dwidth, dheight = love.window.getDesktopDimensions()
	end
	
	changeState('load')
end

function love.draw()
	--for pc stuff
	if dwidth and dheight then
		lg.scale(dwidth/1280,dheight/720)
	end
	
	if event_enabled then
		event_draw()
	elseif state == 'language' then
		lang_draw()
	elseif state == 'load' then
		drawLoad()
	elseif state == 'splash' or state == 'splash2' or state == 'title' then
		drawSplash()
	elseif state == 'game' or state == 'newgame' then
		drawGame()
	elseif state == 'poemgame' then
		drawPoemGame()
	elseif state == 's_kill_early' or state == 'ghostmenu' then
		drawSplashspec()
	elseif state == 'poem_special' then
		drawpoem_special()
	elseif state == 'credits' then
		drawCredits()
	end
end

function love.update()
	dt = love.timer.getDelta()
	sectimer = sectimer + dt
	if sectimer >= 1 then sectimer = 0 end

	-- P2: mientras haya cola de carga, UN paso por frame y nada mas
	-- (el dibujo de este frame ya se hizo; el estado espera en negro)
	if ps3_stepLoadQueue() then
		return
	end

	main_update()
	
	--update depending on gamestate
	if state == 'load' then
		updateLoad()
	elseif state == 'splash' or state == 'splash2' or state == 'title' then
		updateSplash()
	elseif state == 'game' or state == 'newgame' then
		updateGame()
	elseif state == 'poemgame' then
		updatePoemGame()
	elseif state == 'poem_special' then
		updatepoem_special()
	elseif state == 's_kill_early' or state == 'ghostmenu' then
		updateSplashspec()
	elseif state == 'credits' then
		updateCredits()
	end
	if menu_enabled then
		menu_update()
	end
end

function love.keypressed(key)
	-- P2: ignorar input mientras se reparte una carga pesada
	if ps3_queueActive() then return end
	if menu_enabled ~= true then
		if state == 'splash' or state == 'splash2' then
			splash_keypressed(key)
		elseif state == 'game' then
			game_keypressed(key)
		elseif state == 'newgame' then
			newgame_keypressed(key)
		elseif state == 'poemgame' then
			poemgamekeypressed(key)
		elseif state == 'poem_special' then
			poem_special_keypressed(key)
		elseif state == 'load' then
			loadkeypressed(key)
		elseif (state == 's_kill_early' or state == 'ghostmenu') and key == 'y' then
			love.event.quit()
		end
	elseif keyboard then
		keyboard_keypressed(key)
	elseif menu_enabled then
		menu_keypressed(key)
	end
end

function love.textinput(text)
	if text ~= '' and m_selected ~= 3 then 
		player = text
		savepersistent()
		cl = 1
		changeState('game',1)
	elseif m_selected == 3 then
		player = text
		savepersistent()
	else
		changeState('title')
	end
end
