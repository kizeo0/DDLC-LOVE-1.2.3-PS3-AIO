function bgUpdate(bgx, forceload) --background changes
	if bgx == 'club_day2' then
		local bgclub_day = math.random(1,6)
		if bgclub_day == 6 then
			bgx = 'club-skill'
		else
			bgx = 'club'
		end
	end
	
	-- no recargar el mismo fondo (evita re-decode durante skip y transiciones)
	-- bgloaded = nombre del fondo REALMENTE cargado (bg1 se actualiza tambien sin cargar)
	if bgx == bgloaded and not forceload and bgch then
		return
	end
	
	if (xaload == 0 and not (autoskip and autoskip > 0 and g_system == 'PS3')) or forceload then
		-- Durante skip, solo saltar si NO hay cambio real (xaload != 0 y no forceload)
		if autoskip and autoskip > 0 and g_system == 'PS3' and not forceload and xaload ~= 0 then
			bg1 = bgx
			return
		end
		if autoskip == 0 and not forceload then
			bgch2 = bgch
		else
			if type(bgch) == "number" and not (autoskip and autoskip > 0 and g_system == 'PS3') then Graphics.freeImage(bgch) end
			bgch = nil
		end
		
		bgch = lgnewImage('assets/images/bg/'..bgx..'.png')
		bgloaded = bgx
	end	
	bg1 = bgx
end

function cgUpdate(cgx, forceload) --cg changes
	if (cg1 ~= cgx and not (autoskip and autoskip > 0 and g_system == 'PS3')) or forceload then
		-- Durante skip, solo saltar si NO hay cambio real
		if autoskip and autoskip > 0 and g_system == 'PS3' and not forceload and cg1 == cgx then
			cg1 = cgx
			return
		end
		if autoskip == 0 and not forceload then
			cgch2 = cgch
		else
			if type(cgch) == "number" and not (autoskip and autoskip > 0 and g_system == 'PS3') then Graphics.freeImage(cgch) end
			cgch = nil
		end
		cgch = nil
		cgch = lgnewImage('assets/images/cg/'..cgx..'.png')
	end	
	cg1 = cgx
end

function cgHide()
	cgUpdate('blank')
end

function loaderGame()
	if bgch2 then
		bgalpha = math.max(bgalpha - 15, 0)
		if bgalpha == 0 then
			bgalpha = 255
			if type(bgch2) == "number" then Graphics.freeImage(bgch2) end
			bgch2 = nil
		end
	end
	
	if cgch2 then
		cgalpha = math.max(cgalpha - 15, 0)
		if cgalpha == 0 then
			cgalpha = 255
			if type(cgch2) == "number" then Graphics.freeImage(cgch2) end
			cgch2 = nil
		end
	end
end