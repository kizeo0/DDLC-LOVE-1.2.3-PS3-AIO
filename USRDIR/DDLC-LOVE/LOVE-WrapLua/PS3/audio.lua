-- ============================================================
-- LOVE-WrapLua/PS3/audio.lua -- P6 v2: ruta BGM nativa AUTO-VALIDANTE.
--
-- Historia: la migracion a SetBGMusic/PlayBGMusic/StopBGMusic/
-- FreeBGMusic detecto las funciones en el binario y las llamo sin
-- errores de Lua, pero en PS3 real quedo MUTE (logfile 24/08: todas
-- las entradas "(bgm api)", cero audio). Conclusion: las funciones
-- existen bajo snd.* pero por firma/estado interno no reproducen.
--
-- Esta version hace PROBE AUTOMATICO con la primera cancion real:
--   1) Arranca por la ruta BGM y sondea GetTimeBGMusic cada frame.
--   2) Si el tiempo AVANZA en <=180 frames (~3s): ruta validada, se
--      sigue usando (sin leak, sin lag de snd.Init).
--   3) Si NO avanza (o las llamadas de tiempo fallan): marca la ruta
--      como muerta, cambia a la via legada SetVoice AL VUELO y
--      relanza la cancion actual para recuperar el audio al instante.
-- El veredicto queda en savedata/logfile.txt ("P6 PROBE OK/FAIL").
-- ============================================================
snd.Init()

local audioplaying = {}
local audiostarted = {}

-- deteccion estatica de la API BGM en el binario
local HAS_BGM_STATIC = false
if snd and snd.SetBGMusic and snd.PlayBGMusic and snd.StopBGMusic and snd.FreeBGMusic then
	HAS_BGM_STATIC = true
end

-- flags VIVAS: pueden caer a false en runtime si el probe fracasa.
-- USE_BGM_API la usa este wrapper; HAS_BGM la usa ddlclove/loader/audio.lua
local function setRoute(active)
	lv1lua.USE_BGM_API = active
	lv1lua.HAS_BGM = active
end

-- ------------------------------------------------------------
-- MEMORIA PERSISTENTE del veredicto del probe (P6 v3).
-- El resultado se guarda en savedata para no repetir el periodo de
-- validacion en cada arranque: solo el primer boot de la vida del
-- juego puede pagar silencio; los siguientes entran directo por la
-- ruta que ya funciono.
-- NOTA: este archivo corre ANTES que LOVE-WrapLua/filesystem.lua,
-- por eso se usa io.open directo sobre lv1lua.dataloc.."savedata/".
-- ------------------------------------------------------------
local FLAG_LEGACY = lv1lua.dataloc.."savedata/ps3_audio_legacy_v3"
local FLAG_BGMOK = lv1lua.dataloc.."savedata/ps3_audio_bgmok_v3"

local function flagWrite(path)
	pcall(function()
		local fh = io.open(path, "w")
		if fh then fh:write("1") fh:close() end
	end)
end

local function flagClear(path)
	pcall(function() os.remove(path) end)
end

local function flagExists(path)
	local okr, fh = pcall(io.open, path, "r")
	if okr and fh then fh:close() return true end
	return false
end

local remembered = nil
if flagExists(FLAG_LEGACY) then
	remembered = 'legacy'
elseif flagExists(FLAG_BGMOK) then
	remembered = 'bgm'
end

setRoute(HAS_BGM_STATIC)

local probe_state = HAS_BGM_STATIC and 'armed' or nil  -- nil => modo legado puro

if remembered == 'legacy' and HAS_BGM_STATIC then
	-- sesiones anteriores probaron la ruta BGM y NO sonaba: usar legado sin probe
	setRoute(false)
	probe_state = nil
	if ps3log then ps3log('P6 memoria: ruta BGM invalidada en arranque previo => legado directo') end
elseif remembered == 'bgm' and HAS_BGM_STATIC then
	-- sesiones anteriores validaron la ruta: confiar sin re-probar
	probe_state = 'ok'
	if ps3log then ps3log('P6 memoria: ruta BGM validada en arranque previo') end
end

if not lv1lua.USE_BGM_API then
	if snd.SetVolumeBGMusic then pcall(snd.SetVolumeBGMusic, 127) end
end

function lv1lua.bgmVolume()
	local mv = (settings and settings.masvol) or 80
	local bv = (settings and settings.bgmvol) or 80
	local v = math.floor(127 * (bv / 100) * (mv / 100) + 0.5)
	if v > 127 then v = 127 end
	if v < 0 then v = 0 end
	return v
end

-- estado del resto del probe y ultima ruta pedida (para relanzar en fallback)
-- (probe_state ya fue declarado/inicializado arriba con la memoria persistente)
local probe_frames = 0
local probe_last = nil
local probe_logged_first = 0   -- cuenta logs de firma (maximo 2)
local lastpath = nil
local lasthid = nil            -- handle devuelto por SetBGMusic (firma v3)
local lastsong = nil           -- nombre base de la cancion actual

-- P11: pistas que NO deben repetirse en bucle (igual que el branch
-- original no las marcaba looping): la voz final y los creditos suenan
-- UNA vez; antes, el sondeo de loop las relanzaba (end-voice sonaba 2+).
local NO_LOOP = { credits = true, ['end-voice'] = true, ['6r'] = true }

local function songNoLoop()
	if not lastsong then return false end
	local key = lastsong:match('([%a%d%-_]+)%.%a+$')
	return key and NO_LOOP[key] or false
end

local function bgmApiActive()
	return lv1lua.USE_BGM_API == true
end

function lv1lua.playsound()
	if bgmApiActive() then
		-- ---- PROBE: validar que la ruta BGM realmente reproduce ----
		-- SOLO mientras hay una cancion en reproduccion (si no, el probe
		-- daria "fail" falso durante el silencio de los menus).
		if probe_state == 'armed' and audioplaying[1] == 1 then
			probe_frames = probe_frames + 1
			-- diagnostico crudo en 2 momentos: que dice el motor sobre
			-- estado/tiempos mientras (intentamos) reproducir
			if probe_frames == 15 or probe_frames == 60 then
				local sok, st = pcall(snd.StatusBGMusic)
				local tok, tt = pcall(snd.GetTimeBGMusic)
				local totok, totv = pcall(snd.GetTotalTimeBGMusic)
				if ps3log then ps3log('P6 sig fr='..probe_frames..' status='..tostring(st)..' t='..tostring(tt)..' total='..tostring(totv)) end
			end
			local okc, cur = pcall(snd.GetTimeBGMusic)
			if okc and type(cur) == 'number' then
				if probe_last ~= nil and cur ~= probe_last then
					probe_state = 'ok'
					flagWrite(FLAG_BGMOK)
					flagClear(FLAG_LEGACY)
					if ps3log then ps3log('P6 PROBE OK (t '..tostring(probe_last)..'->'..tostring(cur)..' fr='..probe_frames..')') end
				else
					probe_last = cur
				end
			else
				-- llamadas de tiempo inexistentes/fallando: no se puede validar
				probe_frames = probe_frames + 30 -- acelera el veredicto negativo
			end
			if probe_state == 'armed' and probe_frames > 120 then
				probe_state = 'fail'
				setRoute(false)
				flagWrite(FLAG_LEGACY)
				flagClear(FLAG_BGMOK)
				if ps3log then ps3log('P6 PROBE FAIL => fallback legado SetVoice') end
				-- recuperar YA la musica por la via legada
				pcall(snd.StopBGMusic)
				pcall(snd.FreeBGMusic)
				if snd.SetVolumeBGMusic then pcall(snd.SetVolumeBGMusic, 127) end
				if lastpath and audioplaying[1] == 1 then
					pcall(snd.SetVoice, 1, lastpath)
					audiostarted[1] = nil -- playsound disparara PlayVoice al toque
				end
			end
		end
		-- ---- LOOP por sondeo (solo con ruta validada) ----
		-- Respaldo por si el argumento de PlayBGMusic no fuera el flag de
		-- loop: cuando el tiempo alcanza la duracion total, se relanza.
		-- Excluye las pistas de NO_LOOP (end-voice/credits/6r suenan una vez).
		if probe_state == 'ok' and audioplaying[1] == 1 and not songNoLoop() then
			local oktot, tot = pcall(snd.GetTotalTimeBGMusic)
			local okcur, cur = pcall(snd.GetTimeBGMusic)
			if oktot and okcur and type(tot) == 'number' and type(cur) == 'number' and tot > 0 and cur >= tot then
				pcall(snd.PlayBGMusic, tonumber(lasthid) or 0, 1)
			end
		end
	else
		for i = 1, #audioplaying do
			if audioplaying[i] == 1 and audiostarted[i] ~= 1 then
				pcall(snd.PlayVoice, i, 0, 0, 200, 200, 0)
				audiostarted[i] = 1
			end
		end
	end
end

function love.audio.newSource(source,sourcetype)
    local ch

    if sourcetype == "stream" then
        ch = 1
        audioplaying[ch] = 0
        if not bgmApiActive() then
            ret = snd.SetVoice(ch,lv1lua.dataloc.."game/"..source)
        end
    end

    local table = {
        channel = ch;
        path = source;
        type = sourcetype;
        play = function(self)
            love.audio.play(self)
        end;
        stop = function(self)
            love.audio.stop(self)
        end;
        getVolume = function(self)
            --if self.loadsound then return (Sound.getVolume(self.loadsound))/100 end
        end;
        setVolume = function(self,vol)
            if self.channel == 1 and bgmApiActive() and snd.SetVolumeBGMusic then
                local v = math.floor(vol * 127 + 0.5)
                if v > 127 then v = 127 end
                if v < 0 then v = 0 end
                pcall(snd.SetVolumeBGMusic, v)
            end
        end;
        setLooping = function(self,setloop)
            --all voices are looping in PS3 Lua Player unless stopped
        end;
        isPlaying = function(self)
            --if self.loadsound then return Sound.isPlaying(self.loadsound) end;
        end;
        isLooping = function(self)
            --if self.loadsound then return self.loop end;
        end;
        }
    return table
end

function love.audio.play(source)
    if source.channel then
        if bgmApiActive() then
            pcall(snd.StopBGMusic)
            pcall(snd.FreeBGMusic)
            if snd.SetVolumeBGMusic then pcall(snd.SetVolumeBGMusic, lv1lua.bgmVolume()) end
            lastpath = lv1lua.dataloc.."game/"..source.path
            lastsong = source.path
            local oks, hid = pcall(snd.SetBGMusic, lastpath)
            -- Si SetBGMusic ya fallo al cargar el archivo, no tiene sentido
            -- esperar el probe completo: fallback inmediato a la via legada.
            if oks == false then
                setRoute(false)
                flagWrite(FLAG_LEGACY)
                flagClear(FLAG_BGMOK)
                if ps3log then ps3log('P6 SetBGMusic fail ('..tostring(hid)..') => fallback legado') end
                pcall(snd.StopVoice, 1)
                pcall(snd.FreeVoice, 1)
                ret = snd.SetVoice(1, lastpath)
                audiostarted[1] = nil
                audioplaying[1] = 1
                return
            end
            -- FIRMA CONFIRMADA EN PS3 REAL (logs 24-25/08):
            --   SetBGMusic(ruta) -> true, handle(0)   [FUNCIONA]
            --   PlayBGMusic()    -> ERROR arg #1 number expected
            --   PlayBGMusic(1)   -> ERROR arg #2 number expected
            -- CONCLUSION v3: PlayBGMusic(handle_de_Set, numero). El handle es
            -- el segundo retorno de SetBGMusic; el segundo numero se asume
            -- flag de loop (patron soundlib). Si aun asi falla, el probe
            -- reporta los valores crudos de Status/tiempos para iterar.
            local okp, retp
            if snd.PlayBGMusic then
                okp, retp = pcall(snd.PlayBGMusic, tonumber(hid) or 0, 1)
            end
            lasthid = hid
            audioplaying[1] = 1
            -- re-armar el probe para esta cancion si aun no hay veredicto
            if probe_state == nil then
                probe_state = 'armed'
                probe_frames = 0
                probe_last = nil
            end
            -- log detallado las PRIMERAS 2 veces para confirmar la firma
            if probe_logged_first < 2 then
                probe_logged_first = probe_logged_first + 1
                if ps3log then ps3log('P6 set='..tostring(oks)..' hid='..tostring(hid)..' play='..tostring(okp)..tostring(retp)) end
            end
        else
            audioplaying[source.channel] = 1
            audiostarted[source.channel] = nil
        end
    end
end

function love.audio.stop(source)
    if source.channel then
        if audioplaying[source.channel] ~= 0 then
            audioplaying[source.channel] = 0
            if bgmApiActive() then
                pcall(snd.StopBGMusic)
                pcall(snd.FreeBGMusic)
                -- silencio intencional: desarmar probe hasta el proximo play()
                if probe_state == 'armed' then probe_state = nil; probe_frames = 0 end
            else
                audiostarted[source.channel] = nil
                pcall(snd.StopVoice, source.channel)
                pcall(snd.FreeVoice, source.channel)
            end
        end
    end
end
