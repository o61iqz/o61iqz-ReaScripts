-- @noindex

if not reaper.ImGui_CreateContext then
  reaper.MB("Please install the ReaImGui extension via ReaPack.", "Error", 0)
  return
end

local ctx = reaper.ImGui_CreateContext('o61iqz Monitor Control - MMQL')
local master_track = reaper.GetMasterTrack(0)
local fx_name = "o61iqz Monitor Control (Stereo)"
local mm_fx_name = "MiniMeters - Audio-Server"
local MONITOR_FX_OFFSET = 0x1000000

local PARAM = {
  GAIN = 0, DIM = 1, MUTE = 2, SOLO = 3, PHASE = 4, FLIP = 5, SIP = 6,
  LMCROSS = 7, MHCROSS = 8, LSOLO = 9, MSOLO = 10, HSOLO = 11, DIMLV = 12
}

local mm_path = reaper.GetExtState("MonitorControl", "MiniMetersPath")
local mm_set = tonumber(reaper.GetExtState("MonitorControl", "MiniMetersSet")) or 0

local band_state = {}
for _, p in ipairs({PARAM.LSOLO, PARAM.MSOLO, PARAM.HSOLO}) do
  band_state[p] = { muted = false, soloed = false }
end

local initialized = false

local function FileExists(path)
  local f = io.open(path, "r")
  if f then f:close() return true else return false end
end

local function UpdateBands(fx_idx)
  local any_solo = false
  local any_muted = false
  
  for _, p in ipairs({PARAM.LSOLO, PARAM.MSOLO, PARAM.HSOLO}) do
    if band_state[p].soloed then any_solo = true end
    if band_state[p].muted then any_muted = true end
  end

  for _, p in ipairs({PARAM.LSOLO, PARAM.MSOLO, PARAM.HSOLO}) do
    local send_solo = 0
    
    if any_solo then
      if band_state[p].soloed and not band_state[p].muted then
        send_solo = 1
      end
    elseif any_muted then
      if not band_state[p].muted then
        send_solo = 1
      end
    end
    
    reaper.TrackFX_SetParam(master_track, fx_idx, p, send_solo)
  end
end

local function DrawToggleButton(label, fx_idx, param_id, cur_val, active_val)
  local is_active = (cur_val == active_val)
  
  if is_active then
    local active_col = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_ButtonActive())
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), active_col)
  end
  
  reaper.ImGui_PushID(ctx, param_id)
  
  if reaper.ImGui_Button(ctx, label) then
    local new_val = is_active and 0 or active_val
    reaper.TrackFX_SetParam(master_track, fx_idx, param_id, new_val)
  end
  
  reaper.ImGui_PopID(ctx)
  
  if is_active then
    reaper.ImGui_PopStyleColor(ctx, 1)
  end
  
  reaper.ImGui_SameLine(ctx)
end

local function DrawBandButton(label, fx_idx, param_id)
  local state = band_state[param_id]
  local btn_color, hover_color, active_color
  
  if state.muted then
    btn_color = 0xCC0000FF -- Red
    hover_color = 0xDD0000FF
    active_color = 0xFF0000FF
  elseif state.soloed then
    btn_color = 0xCCCC00FF -- Yellow
    hover_color = 0xDDDD00FF
    active_color = 0xFFFF00FF
  end

  if btn_color then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), active_color)
  end

  reaper.ImGui_PushID(ctx, param_id)

  if reaper.ImGui_Button(ctx, label) then
    local is_ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) or 
                    reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Super())
    local is_alt = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
    
    if is_ctrl and not is_alt then
      for p = PARAM.LSOLO, PARAM.HSOLO do
        band_state[p].muted = false
        band_state[p].soloed = false
      end
    elseif is_alt and not is_ctrl then
      state.muted = not state.muted
    elseif not is_ctrl and not is_alt then
      state.soloed = not state.soloed
    end
    
    UpdateBands(fx_idx)
  end

  reaper.ImGui_PopID(ctx)
  
  if reaper.ImGui_IsItemHovered(ctx) then
    reaper.ImGui_SetTooltip(ctx, "Click: Toggle Solo\nAlt/Opt+Click: Toggle Mute\nCmd/Ctrl+Click: Clear All Mute/Solo")
  end

  if btn_color then
    reaper.ImGui_PopStyleColor(ctx, 3)
  end

  reaper.ImGui_SameLine(ctx)
end

local function SetMiniMetersPosition(set_post)
  local mm_raw = reaper.TrackFX_AddByName(master_track, mm_fx_name, true, 0)
  local mon_raw = reaper.TrackFX_AddByName(master_track, fx_name, true, 0)
  
  if mm_raw >= 0 and mon_raw >= 0 then
    
    if set_post and mm_raw > mon_raw then return end
    if not set_post and mm_raw < mon_raw then return end
    
    reaper.TrackFX_CopyToTrack(
      master_track,
      MONITOR_FX_OFFSET + mm_raw,
      master_track,
      MONITOR_FX_OFFSET + mon_raw,
      true
    )
  end
end

function loop()
  local window_flags = reaper.ImGui_WindowFlags_AlwaysAutoResize()
  local visible, open = reaper.ImGui_Begin(ctx, 'o61iqz Monitor Control', true, window_flags)

  if visible then
    local raw_idx = reaper.TrackFX_AddByName(master_track, fx_name, true, 1)
    local fx_idx = raw_idx + MONITOR_FX_OFFSET

    if raw_idx >= 0 then
      if not initialized then
        for _, p in ipairs({PARAM.LSOLO, PARAM.MSOLO, PARAM.HSOLO}) do
          band_state[p].soloed = (reaper.TrackFX_GetParam(master_track, fx_idx, p) == 1)
        end
        initialized = true
      end

      local cur_gain = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.GAIN)
      local cur_dim = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.DIM)
      local cur_mute = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.MUTE)
      local cur_solo = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.SOLO)
      local cur_phase = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.PHASE)
      local cur_flip = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.FLIP)
      local cur_sip = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.SIP)
      local cur_dimlv = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.DIMLV)

      local cross_lm = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.LMCROSS)
      local cross_mh = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.MHCROSS)

      reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 0)
      
      -- Gain Slider
      reaper.ImGui_SetNextItemWidth(ctx, 120) 
      local chg_gain, new_gain = reaper.ImGui_SliderDouble(ctx, '##gain', cur_gain, -60.0, 12.0, '%.1f dB')
      if chg_gain then reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.GAIN, new_gain) end
      
      if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
         reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.GAIN, 0.0)
      end
      reaper.ImGui_SameLine(ctx)

      -- Modifiers
      DrawToggleButton('Dim', fx_idx, PARAM.DIM, cur_dim, 1)
      DrawToggleButton('Mute', fx_idx, PARAM.MUTE, cur_mute, 1)
      DrawToggleButton('Ø', fx_idx, PARAM.PHASE, cur_phase, 1)
      DrawToggleButton('L/R', fx_idx, PARAM.FLIP, cur_flip, 1)

      -- Channels
      reaper.ImGui_Text(ctx, "| Channels:")
      reaper.ImGui_SameLine(ctx)

      DrawToggleButton('Left', fx_idx, PARAM.SOLO, cur_solo, 1)
      DrawToggleButton('Right', fx_idx, PARAM.SOLO, cur_solo, 2)
      DrawToggleButton('Mid', fx_idx, PARAM.SOLO, cur_solo, 3)
      DrawToggleButton('Side', fx_idx, PARAM.SOLO, cur_solo, 4)
      reaper.ImGui_Text(ctx, "-")
      reaper.ImGui_SameLine(ctx)
      DrawToggleButton('SIP', fx_idx, PARAM.SIP, cur_sip, 1)

      -- Band Solo
      reaper.ImGui_Text(ctx, "| Bands:")
      reaper.ImGui_SameLine(ctx)
      DrawBandButton('Low', fx_idx, PARAM.LSOLO)
      DrawBandButton('Mid', fx_idx, PARAM.MSOLO)
      DrawBandButton('High', fx_idx, PARAM.HSOLO)
      reaper.ImGui_SameLine(ctx)
      
      -- MiniMeters
      reaper.ImGui_Text(ctx, "| MiniMeters:")
      reaper.ImGui_SameLine(ctx)
      
      local mm_raw = reaper.TrackFX_AddByName(master_track, mm_fx_name, true, 0)
      local mon_raw = raw_idx
      local path_exists = FileExists(mm_path)
      
      if reaper.ImGui_Button(ctx, "Launch") then
        if mm_set == 1 and path_exists then
          local os_name = reaper.GetOS()
          if os_name:match("Win") then
            os.execute('start "" "' .. mm_path .. '"')
          else
            os.execute('open "' .. mm_path .. '" &')
          end
          
          if mm_raw < 0 then
            local new_mm = reaper.TrackFX_AddByName(master_track, mm_fx_name, true, 1)
            if new_mm == -1 then
               reaper.MB("MiniMeters - Audio-Server plugin not found.", "Error", 0)
            else
               SetMiniMetersPosition(false)
            end
          end
        else
          local retval, filename = reaper.GetUserFileNameForRead(mm_path, "Select MiniMeters Application", "")
          if retval then
            mm_path = filename
            mm_set = 1
            reaper.SetExtState("MonitorControl", "MiniMetersPath", mm_path, true)
            reaper.SetExtState("MonitorControl", "MiniMetersSet", "1", true)
          end
        end
      end
      
      if mm_set == 1 and not path_exists then
        if reaper.ImGui_IsItemHovered(ctx) then
          reaper.ImGui_SetTooltip(ctx, "Invalid path! Click to re-locate MiniMeters.")
        end
      end
      
      reaper.ImGui_SameLine(ctx)

      -- Options
      reaper.ImGui_Text(ctx, "|")
      reaper.ImGui_SameLine(ctx)
      
      if reaper.ImGui_Button(ctx, "Options") then
        reaper.ImGui_OpenPopup(ctx, "OptionsPopup")
      end
      
      if reaper.ImGui_BeginPopup(ctx, "OptionsPopup") then
      
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 0, 4)
      
        reaper.ImGui_SetNextItemWidth(ctx, 200)
        local chg_dimlv, new_dimlv = reaper.ImGui_SliderDouble(ctx, 'Dim Level', cur_dimlv, -24.0, -6.0, '%.0f dB')
        if chg_dimlv then reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.DIMLV, new_dimlv) end
        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.DIMLV, -12.0)
        end
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextDisabled(ctx, "Filter Crossover Frequencies")
        
        reaper.ImGui_SetNextItemWidth(ctx, 200)
        local chg_lm, new_lm = reaper.ImGui_SliderDouble(ctx, 'Low/Mid', cross_lm, 20.0, 2000.0, '%.0f Hz', reaper.ImGui_SliderFlags_Logarithmic())
        if chg_lm then reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.LMCROSS, new_lm) end
        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.LMCROSS, 200.0)
        end
        
        reaper.ImGui_SetNextItemWidth(ctx, 200)
        local chg_mh, new_mh = reaper.ImGui_SliderDouble(ctx, 'Mid/High', cross_mh, 200.0, 15000.0, '%.0f Hz', reaper.ImGui_SliderFlags_Logarithmic())
        if chg_mh then reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.MHCROSS, new_mh) end
        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.MHCROSS, 2000.0)
        end
        
        reaper.ImGui_Dummy(ctx, 0, 2)
        reaper.ImGui_SeparatorText(ctx, " MiniMeters ")
        
        if reaper.ImGui_MenuItem(ctx, "Set MiniMeters Path...") then
          local retval, filename = reaper.GetUserFileNameForRead(mm_path, "Select MiniMeters Application", "")
          if retval then
            mm_path = filename
            mm_set = 1
            reaper.SetExtState("MonitorControl", "MiniMetersPath", mm_path, true)
            reaper.SetExtState("MonitorControl", "MiniMetersSet", "1", true)
          end
        end
        
        local is_pre = mm_raw >= 0 and mm_raw < mon_raw
        local is_post = mm_raw >= 0 and mm_raw > mon_raw
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextDisabled(ctx, "MiniMeters FX Position")
        
        if reaper.ImGui_MenuItem(ctx, "Pre-Monitor Control", nil, is_pre, mm_raw >= 0) then
          SetMiniMetersPosition(false)
        end
        if reaper.ImGui_MenuItem(ctx, "Post-Monitor Control", nil, is_post, mm_raw >= 0) then
          SetMiniMetersPosition(true)
        end
        
        reaper.ImGui_PopStyleVar(ctx, 1)
        
        reaper.ImGui_EndPopup(ctx)
      end
      
      reaper.ImGui_PopStyleVar(ctx, 1)
      
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) and not reaper.ImGui_IsAnyItemActive(ctx) then
        reaper.Main_OnCommand(40044, 0)
      end
      
    else
      reaper.ImGui_Text(ctx, "o61iqz Monitor Control FX missing. Try rescan FX browser and reopen monitoring FX window.")
    end

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
