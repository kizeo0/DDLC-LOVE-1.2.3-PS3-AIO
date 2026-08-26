function changeState(cstate,x)
	print("loading state: "..cstate)
	if ps3log then ps3log('STATE->'..cstate..' x='..tostring(x)) end
	menu_alpha = 0
	menu_previous = nil
	history = {}
	
	if cstate ~= 's_kill_early' and cstate ~= 'ghostmenu' and cstate ~= 'newgame' and cstate ~= 'title' then
		require(branch..'/states/'..cstate)
	elseif cstate == 'title' and not drawSplash then
		require(branch..'/states/splash')
	end
	
	if g_system == 'PS3' and cstate ~= 'game' and cstate ~= 'newgame' then
		-- PS3: liberar personajes y fondo/CG antes de cargar assets de otro estado
		-- (ningun otro estado los dibuja; se recargan al volver a game)
		unloadAll()
		if type(bgch) == "number" then Graphics.freeImage(bgch) end
		if type(bgch2) == "number" then Graphics.freeImage(bgch2) end
		if type(cgch) == "number" then Graphics.freeImage(cgch) end
		if type(cgch2) == "number" then Graphics.freeImage(cgch2) end
		bgch = nil
		bgch2 = nil
		cgch = nil
		cgch2 = nil
		bgloaded = nil
		bgalpha = 255
		cgalpha = 255
		collectgarbage()
		-- PS3: al salir de game, detener el skip y descartar el BGM diferido
		-- (si no, el defer se filtra a title/menus con el buffer viejo retenido)
		if autoskip and autoskip > 0 then
			autoskip = 0
			audioClearPending()
		end
	end
	
	if cstate == 'game' then
		hideAll()
	end
	
	if cstate == 'splash' then
		splash = lgnewImage('assets/images/bg/splash.png')
		alpha = 0
		audioUpdate('1')
	elseif cstate == 'title' and branch == 'ddlclove' then
		alpha = 0		
		--sayori
		if (persistent.ptr == 1 or persistent.ptr == 2) and not menu_art_s_break then
			menu_art_s_break = lgnewImage("assets/images/gui/menu_art_s_break.png")
		elseif not menu_art_s then
			menu_art_s = lgnewImage("assets/images/gui/menu_art_s.png")
		end		
		--new game gui image
		if g_system == 'PSP' then
			if persistent.ptr == 1 and not gui.newgame1 then
				gui.newgame1 = lgnewImage("assets/images/gui/overlay/newgame1.png")
			elseif not gui.newgame1 then
				gui.newgame = lgnewImage("assets/images/gui/overlay/newgame.png")
			end
		else
			if persistent.ptr == 1 and not gui.newgame1 then
				gui.newgame1 = lgnewImage("assets/images/gui/overlay/"..settings.lang.."/newgame1.png")
			elseif not gui.newgame1 then
				gui.newgame = lgnewImage("assets/images/gui/overlay/"..settings.lang.."/newgame.png")
			end
		end		
		--monika
		if persistent.ptr == 4 and not menu_art_m then
			menu_art_m = lgnewImage("assets/images/cg/blank.png")
		elseif not menu_art_m then
			menu_art_m = lgnewImage("assets/images/gui/menu_art_m.png")
		end		
		--natsuki and yuri image
		if not menu_art_n then menu_art_n = lgnewImage("assets/images/gui/menu_art_n.png") end
		if not menu_art_y then menu_art_y = lgnewImage("assets/images/gui/menu_art_y.png") end
		--other stuff
		poem_enabled = false
		audioUpdate('1')
		menu_enable('title')
		y_timer = 0
		titlebg_ypos = -240
		tlp = {yx=525,nx=670,sx=470,mx=680,yy=850,ny=850,sy=850,my=850,scale=0.75}
		z_timer = {0,0}
	elseif cstate == 'title' and branch == '3ds' then
		alpha = 0
		if persistent.ptr == 0 then
			titlebg = lgnewImage('assets/images/gui/bg.png')
		elseif persistent.ptr <= 2 then
			titlebg = lgnewImage('assets/images/gui/bg2.png')
		elseif persistent.ptr == 4 then
			titlebg = lgnewImage('assets/images/gui/bg3.png')
		end
		poem_enabled = false
		audioUpdate('1')
		menu_enable('title')
		y_timer = 0
		titlebg_ypos = -240
	elseif cstate == 'game' and x == 1 then -- new game
		cl = 1
		chapter = persistent.ptr * 10
		if persistent.ptr == 0 then
			justmonika_title = nil -- partida nueva desde cero: titulo normal
		end
		audioPreloadChapter(chapter)  -- PRECARGA INTELIGENTE POR CAPÍTULO
		if persistent.ptr == 0 and persistent.chr.m == 0 then
			cl = 10001
		end
	elseif cstate == 'game' and (x == 2 or x == 3) then 
		if x == 2 then -- load game
			loadgame()
			audioPreloadChapter(chapter)  -- PRECARGA AL CARGAR PARTIDA
		elseif x == 3 then -- poemgame to game
			cl = cl + 2
			-- restaurar BGM del capitulo (poemgame lo sobrescribio con '4')
			audio1 = poemgame_audio1 or audio1
		end
		if global_os == 'LOVE-WrapLua' and g_system ~= 'PS3' and persistent.ptr <= 2 and chapter < 23 then
			if chapter <= 5 then
				persistent.chr.m = 2
			else
				savevalue = persistent.chr.m
				persistent.chr.m = 2
			end
			savegame('autoload')
			savepersistent()
			love.event.quit('restart')
		end
	elseif cstate == 'game' and x == 'autoload' then
		loadgame('autoload')
		if chapter <= 5 then
			persistent.chr.m = 1
			savepersistent()
		elseif chapter < 23 then
			persistent.chr.m = savevalue
			savepersistent()
		end
	elseif cstate == 'newgame' then -- first run
		require(branch..'/states/game')
		cl = 10016
		justmonika_title = nil
	elseif cstate == 'poemgame' and branch == 'ddlclove' then --load poemgame assets and state
		if g_system == 'PS3' then
			unloadAll('poemgame')
			collectgarbage()
		end
		-- recordar BGM del capitulo para restaurarlo al volver a game
		poemgame_audio1 = audio1
		if not halogenfont then halogenfont = lg.newFont('assets/fonts/Halogen.ttf',28) end --poem game font
		if persistent.ptr <= 2 then --acts 1 and 2
			audioUpdate('4',true)
			audioPreload({'4g'})  -- PRECARGA 4g para glitch poem
			bg1 = 'notebook'
		elseif persistent.ptr == 3 then --act 3
			audioUpdate('ghostmenu')
		end

		if g_system == 'PS3' then
			-- ============================================================
			-- P2b FRAMESPREAD (PS3): la entrada al minijuego cargaba hasta
			-- ~12 imágenes en un solo frame. Se reparte: cuaderno, pantalla
			-- de instrucciones, y stickers por grupos; poemgame() corre al
			-- final para dejar el estado listo. La pantalla queda negra
			-- (alpha heredado del fade) hasta el último paso.
			-- drawPoemGame tiene guards para dibujar con la lista vacía.
			-- ============================================================
			if persistent.ptr <= 2 then
				ps3_enqueue(function()
					if not notebook then notebook = lgnewImage('assets/images/bg/notebook.png') end
				end)
			else
				ps3_enqueue(function()
					notebook_glitch = lgnewImage('assets/images/bg/notebook-glitch.png')
				end)
			end
			ps3_enqueue(function()
				if poemstate == 0 and not poemtime then --first time poemgame
					poemtime = lgnewImage('assets/images/gui/poemgame/poemtime.png')
					poemtime2 = lgnewImage('assets/images/gui/poemgame/poemtime2.png')
				end
			end)
			if persistent.ptr <= 2 then
				ps3_enqueue(function()
					if persistent.ptr == 0 and not s_sticker_1 then --sayori stickers
						s_sticker_1 = lgnewImage('assets/images/gui/poemgame/s_sticker_1.png')
						s_sticker_2 = lgnewImage('assets/images/gui/poemgame/s_sticker_2.png')
					elseif not eyes then --act 2 only stickers
						eyes = lgnewImage('assets/images/bg/eyes.png')
						m_sticker_2 = lgnewImage('assets/images/gui/poemgame/m_sticker_2.png')
						y_sticker_1_broken = lgnewImage('assets/images/gui/poemgame/y_sticker_1_broken.png')
						y_sticker_2g = lgnewImage('assets/images/gui/poemgame/y_sticker_2g.png')
					end
				end)
				ps3_enqueue(function()
					if chapter == 22 then --yuri stickers with cuts
						y_sticker_1 = lgnewImage('assets/images/gui/poemgame/y_sticker_cut_1.png')
						y_sticker_2 = lgnewImage('assets/images/gui/poemgame/y_sticker_cut_2.png')
					elseif not y_sticker_1 then --yuri stickers normal
						y_sticker_1 = lgnewImage('assets/images/gui/poemgame/y_sticker_1.png')
						y_sticker_2 = lgnewImage('assets/images/gui/poemgame/y_sticker_2.png')
					end
				end)
				ps3_enqueue(function()
					if not n_sticker_1 then --natsuki stickers
						n_sticker_1 = lgnewImage('assets/images/gui/poemgame/n_sticker_1.png')
						n_sticker_2 = lgnewImage('assets/images/gui/poemgame/n_sticker_2.png')
					end
					poemgame()
					alpha = 255
					if ps3log then ps3log('FRAMESPREAD poemgame done') end
				end)
			else
				ps3_enqueue(function()
					if not m_sticker_1 then --monika sticker
						m_sticker_1 = lgnewImage('assets/images/gui/poemgame/m_sticker_1.png')
					end
					poemgame()
					alpha = 255
					if ps3log then ps3log('FRAMESPREAD poemgame done') end
				end)
			end
		else
			if persistent.ptr <= 2 then --acts 1 and 2
				if not notebook then notebook = lgnewImage('assets/images/bg/notebook.png') end
			elseif persistent.ptr == 3 then --act 3
				notebook_glitch = lgnewImage('assets/images/bg/notebook-glitch.png')
			end

			if poemstate == 0 and not poemtime then --first time poemgame
				poemtime = lgnewImage('assets/images/gui/poemgame/poemtime.png')
				poemtime2 = lgnewImage('assets/images/gui/poemgame/poemtime2.png')
			end

			if persistent.ptr <= 2 then
				if persistent.ptr == 0 and not s_sticker_1 then --sayori stickers
					s_sticker_1 = lgnewImage('assets/images/gui/poemgame/s_sticker_1.png')
					s_sticker_2 = lgnewImage('assets/images/gui/poemgame/s_sticker_2.png')
				elseif not eyes then --act 2 only stickers
					eyes = lgnewImage('assets/images/bg/eyes.png')
					m_sticker_2 = lgnewImage('assets/images/gui/poemgame/m_sticker_2.png')
					y_sticker_1_broken = lgnewImage('assets/images/gui/poemgame/y_sticker_1_broken.png')
					y_sticker_2g = lgnewImage('assets/images/gui/poemgame/y_sticker_2g.png')
				end

				if chapter == 22 then --yuri stickers with cuts
					y_sticker_1 = lgnewImage('assets/images/gui/poemgame/y_sticker_cut_1.png')
					y_sticker_2 = lgnewImage('assets/images/gui/poemgame/y_sticker_cut_2.png')
				elseif not y_sticker_1 then --yuri stickers normal
					y_sticker_1 = lgnewImage('assets/images/gui/poemgame/y_sticker_1.png')
					y_sticker_2 = lgnewImage('assets/images/gui/poemgame/y_sticker_2.png')
				end

				if not n_sticker_1 then --natsuki stickers
					n_sticker_1 = lgnewImage('assets/images/gui/poemgame/n_sticker_1.png')
					n_sticker_2 = lgnewImage('assets/images/gui/poemgame/n_sticker_2.png')
				end

			elseif not m_sticker_1 then --monika sticker
				m_sticker_1 = lgnewImage('assets/images/gui/poemgame/m_sticker_1.png')
			end
			poemgame()
			alpha = 255
		end
	elseif cstate == 'poemgame' and branch == '3ds' then
		if persistent.ptr <= 2 then
			if persistent.ptr == 0 then
				s_sticker_1 = lgnewImage('assets/images/gui/poemgame/s_sticker_1.png')
				s_sticker_2 = lgnewImage('assets/images/gui/poemgame/s_sticker_2.png')
			else
				eyes = lgnewImage('assets/images/bg/eyes.png')
			end
			y_sticker_1 = lgnewImage('assets/images/gui/poemgame/y_sticker_1.png')
			y_sticker_2 = lgnewImage('assets/images/gui/poemgame/y_sticker_2.png')
			n_sticker_1 = lgnewImage('assets/images/gui/poemgame/n_sticker_1.png')
			n_sticker_2 = lgnewImage('assets/images/gui/poemgame/n_sticker_2.png')
		else
			m_sticker_1 = lgnewImage('assets/images/gui/poemgame/m_sticker_1.png')
		end
		poemgame()
		alpha = 255
	elseif cstate == 's_kill_early' and branch == 'ddlclove' then
		require('ddlclove/states/splash')
		require('scripts/event')
		loadNoise()
		lg.setBackgroundColor(0,0,0)
		endbg = lgnewImage('assets/images/gui/'..settings.lang..'/end.png')
		s_killearly = lgnewImage('assets/images/cg/s_kill/s_kill_early.png')
		audioUpdate('s_kill_early')
		y_timer = 0
		alpha = 0
	elseif cstate == 's_kill_early' and branch == '3ds' then
		require('3ds/states/splash')
		endbg = lgnewImage('assets/images/gui/end.png')
		s_killearly = lgnewImage('assets/images/cg/s_kill/s_kill_early.png')
		audioUpdate('s_kill_early')
		alpha = 0
	elseif cstate == 'ghostmenu' and branch == 'ddlclove' then
		require('ddlclove/states/splash')
		endbg = lgnewImage('assets/images/gui/'..settings.lang..'/end.png')
		menu_art_m = lgnewImage("assets/images/gui/menu_art_m_ghost.png")
		menu_art_s = lgnewImage("assets/images/gui/menu_art_s_ghost.png")
		menu_art_n = lgnewImage("assets/images/gui/menu_art_n_ghost.png")
		menu_art_y = lgnewImage("assets/images/gui/menu_art_y_ghost.png")
		y_timer = 0.7
		tlp = {yx=525,nx=670,sx=470,mx=680,yy=850,ny=850,sy=850,my=850,scale=0.75}
		z_timer = {0,0}
		audioUpdate('ghostmenu')
		alpha = 0
	elseif cstate == 'ghostmenu' and branch == '3ds' then
		require('3ds/states/splash')
		endbg = lgnewImage('assets/images/gui/end.png')
		titlebg = lgnewImage('assets/images/gui/bg_ghost.png')
		audioUpdate('ghostmenu')
		alpha = 0
	elseif cstate == 'poem_special' then
		poem_special_i(x)
	elseif cstate == 'credits' then
		loadCredits(x)
	elseif cstate == 'language' then
		menu_enable('language')
	end
	
	--load game state and scripts
	if cstate == 'game' or cstate == 'newgame' then
		if (bg1 == 'notebook' and (x == 2 or x == 'autoload')) or x == 0 then
			alpha = 20
			audioFlushPending()
		elseif g_system == 'PS3' then
			-- ============================================================
			-- P2 FRAMESPREAD (PS3): esta transición era la ráfaga más pesada
			-- del juego (liberar poemgame + cargar 4 personajes + fondo +
			-- audio + CG, todo en UN frame). Pasa al volver del poemgame
			-- (x==3) y al cargar partida (x==2/'autoload'). Ahora se reparte:
			-- un personaje por frame, luego fondo, luego audio, luego CG.
			-- Mientras la cola corre, love.update no avanza el estado y el
			-- input está bloqueado; la pantalla queda en negro (alpha 0)
			-- hasta que el último paso revela la escena completa.
			-- ============================================================
			autoskip = 0
			collectgarbage()
			if x == 3 then unloadAll('poemgame') end
			alpha = 0
			ps3_enqueue(loadSayori)
			ps3_enqueue(loadNatsuki)
			ps3_enqueue(loadYuri)
			ps3_enqueue(loadMonika)
			ps3_enqueue(function()
				changeX.s.y = s_Set.x
				changeX.y.y = y_Set.x
				changeX.n.y = n_Set.x
				changeX.m.y = m_Set.x
				bgUpdate(bg1, true)
			end)
			ps3_enqueue(function()
				local flushed = audioFlushPending()
				if not flushed and (audio_bgm == nil or audio_cur ~= audio1) then
					audioUpdate(audio1, true)
				end
			end)
			ps3_enqueue(function()
				cgUpdate(cg1, true)
				collectgarbage()
				alpha = 255
				if ps3log then ps3log('FRAMESPREAD game done') end
			end)
		else
			alpha = 255
			loadAll()
			if branch == 'ddlclove' then
				changeX.s.y = s_Set.x
				changeX.y.y = y_Set.x
				changeX.n.y = n_Set.x
				changeX.m.y = m_Set.x
			else
				unloadAll('poemgame')
			end
			bgUpdate(bg1, true)
			local flushed = audioFlushPending()
			if not flushed and (audio_bgm == nil or audio_cur ~= audio1) then
				audioUpdate(audio1, true)
			end
			cgUpdate(cg1, true)
		end
		poem_enabled = false
		menu_enabled = false
		xaload = -1
		require('scripts/'..settings.lang..'/script-ch'..chapter)
		if persistent.ptr == 0 then
			if poemwinner[chapter] == 'Sayori' then
				require('scripts/'..settings.lang..'/script-exclusives-sayori')
			elseif poemwinner[chapter] == 'Natsuki' then
				require('scripts/'..settings.lang..'/script-exclusives-natsuki')
			elseif poemwinner[chapter] == 'Yuri' then
				require('scripts/'..settings.lang..'/script-exclusives-yuri')
			end
		elseif persistent.ptr == 2 and chapter > 20 then
			if poemwinner[chapter-20] == 'Natsuki' and chapter == 21 then
				require('scripts/'..settings.lang..'/script-exclusives2-natsuki')
			elseif poemwinner[chapter-20] == 'Yuri' or chapter > 21 then
				require('scripts/'..settings.lang..'/script-exclusives2-yuri')
			end
		end
	end
	
	state = cstate
	print("loaded state: "..cstate)
	if ps3log then ps3log('STATE OK '..cstate) end
end
