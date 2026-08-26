local skipspeed = 4
-- P8 (PS3 real): el auto-avance original (una linea cada 4 frames +
-- collectgarbage() por linea) resulto demasiado agresivo para la PS3:
-- ~7.5 GC completos por segundo durante saltos largos con R1. Se hace
-- mas pausado (una linea cada 8 frames) y el GC se espacia a 1 de cada 4
-- lineas. EXCEPCION: la secuencia de muerte de Yuri (fin de ch23,
-- aproximacion y arranque de yuri_kill) conserva el ritmo original
-- porque la velocidad del texto ES parte de la escena.
local skipspeed_ps3 = 8
local skip_gc_counter = 0
local manual_skip_cooldown = 48
local manual_skip_timer = 0
local textboxd = true
bgalpha = 255
cgalpha = 255

function drawGame()
	lg.setBackgroundColor(0,0,0)
	
	if menu_enabled and menu_type ~= 'pause' and menu_type ~= 'choice' and menu_type ~= 'dialog' then
		menu_draw()
		return
	end
	
	lg.setColor(255,255,255,alpha)
	lg.draw(bgch)
	lg.draw(cgch)
	lg.setColor(255,255,255,bgalpha)
	lg.draw(bgch2)
	lg.setColor(255,255,255,cgalpha)
	lg.draw(cgch2)
	
	lg.setColor(255,255,255,alpha)
	drawSayori()
	drawYuri()
	drawNatsuki()
	drawMonika()
	
	if poem_enabled then drawPoem()	end
	if textboxd then
		drawTextBox()
	end
	
	lg.setFont(allerfont)
	lg.setColor(255,255,255,alpha)
	if dvertype == 'Test' then lg.print(cl,5,690) end
	if autotimer > 0 then
		lg.draw(gui.skip,0,27)
		lg.setColor(0,0,0)
		outlineText(tr.auto,5,35)
	elseif autoskip > 0 then
		local skiptext
		if sectimer >= 0.75 then
			skiptext = tr.skip..' >>>'
		elseif sectimer >= 0.5 then
			skiptext = tr.skip..' >>'
		elseif sectimer >= 0.25 then
			skiptext = tr.skip..' >'
		else
			skiptext = tr.skip
		end
		lg.draw(gui.skip,0,27)
		lg.setColor(0,0,0)
		outlineText(skiptext,5,35)
	end
	if menu_enabled then
		menu_draw()
	end
end

function updateGame()
	scriptCheck()
	--timercheck
	if xaload == 0 then
		startTime = getTime
		print('cl: '..cl)
	end
	xaload = xaload + 1
	if unitimer < uniduration then
		unitimer = unitimer + dt
	end
	
	--bgch2 and cgch2 stuff
	loaderGame()
	
	--auto next script
	if autotimer == 0 then
		autotimer = 0
	elseif autotimer > 0 then
		autotimer = autotimer + dt
	end
	
if menu_enabled == false and cl ~= 666 then
		local spd = skipspeed
		if g_system == 'PS3' then
			spd = skipspeed_ps3
			-- Zona yuri_kill (fin ch23): ritmo original, la escena lo requiere
			if chapter == 23 and cl >= 1850 and cl <= 2100 then
				spd = 4
			end
		end
		if autoskip > 0 and autoskip < spd then
				autoskip = autoskip + 1
			elseif autoskip >= spd then
				autotimer = 0
				cl = cl + 1
				xaload = 0
				if g_system == 'PS3' then
					-- P8: GC espaciado (1 de cada 4 lineas) en vez de por linea
					skip_gc_counter = skip_gc_counter + 1
					if skip_gc_counter >= 4 then
						skip_gc_counter = 0
						collectgarbage()
					end
				else
					collectgarbage()
				end
				autoskip = 1
			end
		end
		
if manual_skip_timer > 0 then
		manual_skip_timer = manual_skip_timer - dt
		if manual_skip_timer < 0 then manual_skip_timer = 0 end
	end
	
	if poem_enabled and poem_scroll and not menu_enabled then
		if g_system == 'Switch' then
			if joystick:isGamepadDown('dpup') then
				poem_scroll.y = poem_scroll.y + dt*25
			elseif joystick:isGamepadDown('dpdown') then
				poem_scroll.y = poem_scroll.y - dt*25
			end
		else
			if love.keyboard.isDown('up') and poem_scroll.y < 1 then
				poem_scroll.y = poem_scroll.y + dt*25
			elseif love.keyboard.isDown('down') then
				poem_scroll.y = poem_scroll.y - dt*25
			end
		end
	end
	
	if event_enabled then event_update() end
end

function game_keypressed(key)
	if event_enabled then
		event_keypressed(key)
	elseif key == 'y' then --pause menu
		menu_mchance = math.random(1,50)
		autotimer = 0
		menu_enable('pause')
	elseif key == 'start' or key == 'return' then --auto on/off
		if global_os ~= 'LOVE-WrapLua' then sfxplay2(sfx1) end
		if autotimer == 0 then autotimer = 0.01 else autotimer = 0 end		
	elseif key == 'rightshoulder' or key == 'r' then
		if global_os ~= 'LOVE-WrapLua' then sfxplay2(sfx1) end
		if not event_enabled then
			if autoskip < 1 then
				autoskip = 1
			elseif autoskip > 0 then
				autoskip = 0
				audioFlushPending()
			end
		end
	else
		newgame_keypressed(key)
	end
end

function newgame_keypressed(key)
	if (key == 'a' or key == 'leftshoulder') and unitimer >= uniduration then 
		textboxd = true
		if print_full_text then
			if autoskip > 0 then
				-- X durante autoskip: avanzar YA si cooldown permite
				if manual_skip_timer <= 0 then
					autoskip = 1
					manual_skip_timer = manual_skip_cooldown / 60
					autotimer = 0
					cl = cl + 1
					xaload = 0
					unitimer = 0
				end
			else
				-- AudioDefer: si el autoskip se frenó por un cambio de
				-- canción próximo y quedó algo pendiente, esta presión
				-- manual de X es la que lo dispara -- no pasa solo.
				audioFlushPending()
				autotimer = 0
				cl = cl + 1
				xaload = 0
				unitimer = 0
			end
		else
			print_full_text = true
		end
		collectgarbage()
	elseif key == 'b' then
		textboxd = not textboxd
	elseif key == 'back' or key == '-' then
		if settings.o ~= 1 then
			settings.o = 1
		else
			settings.o = 0
		end
		savesettings()
	end
end
