local audio_wloop = {'1','2','3','4','4g','5','5_monika','5_natsuki','5_sayori','5_yuri','6','7g','8','10','d','monika-end'}
audio_ext = '.ogg'
if g_system == 'PSP' or g_system == 'PS3' then
	audio_ext = '.mp3'
end

-- AudioDefer: cola de cambios de BGM diferidos durante skip
local audio_pending = nil
audio_cur = nil

function audioUpdate(audiox, forceload) --audio changes
	if audio1 ~= audiox or forceload then
		if audio_bgm and audio1 == audiox and not forceload then
			audio1 = audiox
			return
		end
		-- AudioDefer: si estamos en skip (autoskip > 0) y NO es forceload, encolar
		if autoskip and autoskip > 0 and g_system == 'PS3' and not forceload then
			audio_pending = audiox
			audio1 = audiox
			-- Frenar el autoskip acá mismo: no seguir saltando de largo justo
			-- en el punto donde hay cambio de canción (que es el más pesado).
			-- El jugador nota el freno y retoma manualmente cuando quiera;
			-- ahí se aplica el cambio real (con su lag) vía audioFlushPending().
			autoskip = 0
			return
		end
		if audio_bgm and audio1 == audiox and not forceload then
			audio1 = audiox
			return
		end
		if audio_bgm then audio_bgm:stop() end
		if audio_bgmloop then audio_bgmloop:stop() end
		
		audio_bgm = nil
		audio_bgmloop = nil
		if g_system == 'PS3' then
			-- ============================================================
			-- P6: con la ruta BGM nativa (SetBGMusic + FreeBGMusic) ya NO se
			-- resetea el subsistema por cada cambio de cancion: ese ciclo
			-- snd.Init()/SetVoice era el leak contenido y el punto EXACTO del
			-- freeze en PS3 real (logfile #151, 3ra vuelta de poemgame).
			-- Si el binario no expone la ruta BGM (HAS_BGM false), se conserva
			-- la mitigacion legada completa.
			-- ============================================================
			if not lv1lua.HAS_BGM then
				-- snd.SetVoice needs a large contiguous decode buffer on LuaPlayerPS3.
				collectgarbage()
				snd.Init()
				snd.SetVolumeBGMusic(127)
			end
			if ps3log then ps3log('BGM->'..audiox..(lv1lua.HAS_BGM and ' (bgm api)' or ' (legacy reset)')) end
		end
		
		if audiox ~= '' and audiox ~= '0' then
			if audiox == 'credits' or audiox == 'end-voice' then
				audio_bgm = love.audio.newSource('assets/audio/bgm/'..settings.lang..'/'..audiox..audio_ext, 'stream')
			else
				audio_bgm = love.audio.newSource('assets/audio/bgm/'..audiox..audio_ext, 'stream')
			end

			--custom audio looping load
			if g_system ~= 'PS3' and not lutro then
				if audiox == '2g' then
					audio_bgmloop = love.audio.newSource('assets/audio/bgm/2-loop'..audio_ext, 'stream')
				elseif audiox == '3g' or audiox == '3g2' then
					audio_bgmloop = love.audio.newSource('assets/audio/bgm/3-loop'..audio_ext, 'stream')
				elseif audiox == '7' then
					if persistent.ptr == 2 then
						audio_bgmloop = love.audio.newSource('assets/audio/bgm/7a'..audio_ext, 'stream')
					else
						audio_bgmloop = love.audio.newSource('assets/audio/bgm/7-loop'..audio_ext, 'stream')
					end
				elseif audiox ~= 'credits' and audiox ~= 'end-voice' and audiox ~= '6r' then
					audio_bgm:setLooping(true)
				end
				for i = 1, #audio_wloop do
					if audiox == audio_wloop[i] then
						audio_bgmloop = love.audio.newSource('assets/audio/bgm/'..audiox..'-loop'..audio_ext, 'stream')
					end
				end
				if audio_bgmloop then
					audio_bgm:setLooping(false)
					audio_bgmloop:setLooping(true)
				end
			end
			game_setvolume()
			audio_bgm:play()
		end
	end
	audio1 = audiox
	audio_cur = audiox
end

-- AudioDefer: vaciar cola al terminar el skip
-- Devuelve true si habia algo pendiente (se reprodujo)
function audioFlushPending()
	if audio_pending then
		local px = audio_pending
		audio_pending = nil
		audioUpdate(px, true)
		return true
	end
	return false
end

-- AudioDefer: descartar la cola sin reproducir (al salir del estado game)
function audioClearPending()
	audio_pending = nil
end

function sfxplay(sfx) --sfx stuff
	if xaload == 0 then
		sfxp = nil
		
		if sfx ~= '' then
			sfxp = love.audio.newSource('assets/audio/sfx/'..sfx..audio_ext, 'static')
		end
		if sfxp then
			sfxp:setVolume((settings.sfxvol/100)*(settings.masvol/100))
		end
		sfxp:play()
	end
end

function sfxplay2(sfx)
	local clone
	if global_os == "LOVE-WrapLua" or g_system == "Switch" then
		clone = sfx
	else
		clone = sfx:clone()
	end
	clone:play()
end

-- ============================================================
-- PRECARGA POR CAPÍTULO/EVENTO -- DESACTIVADA en PS3
-- ============================================================
-- Motivo: love.audio.newSource('stream') en el binding de PS3 (SetVoice)
-- no tiene ningún cache real por nombre de archivo -- cada llamada,
-- "precarga" o no, siempre re-lee el archivo de disco y pide un buffer
-- nuevo. Además SetVoice tiene un memory leak nativo confirmado (nunca
-- se libera el buffer alocado). Como consecuencia, audioPreload() no
-- ahorraba ninguna carga futura: solo generaba ráfagas de varias
-- asignaciones de buffer + reproducciones de audio de golpe (con su
-- glitch de sonido) justo en los puntos donde más nos importa evitar
-- presión de memoria (entrada a capítulo, sección de poemas).
--
-- Se dejan las funciones definidas como no-ops para no romper ningún
-- call site existente en los scripts de capítulo.
-- ============================================================
local preload_cache = {}

function audioPreload(list)
	-- no-op en PS3: ver comentario arriba
end

function audioPreloadChapter(ch)
	-- no-op en PS3: ver comentario arriba
end

function audioPreloadEvent(etype)
	-- no-op en PS3: ver comentario arriba
end
