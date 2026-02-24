-- @noindex

if not reaper.ImGui_CreateContext then
  reaper.MB("Please install the ReaImGui extension via ReaPack.", "Error", 0)
  return
end

local ctx = reaper.ImGui_CreateContext('o61iqz Monitor Control - Surround')
local master_track = reaper.GetMasterTrack(0)
local fx_name = "o61iqz Monitor Control (Surround)"
local MONITOR_FX_OFFSET = 0x1000000

local PARAM = { 
  GAIN = 0, DIM = 1, MUTE = 2, SURROUND = 3, PHASE = 4, FLIP = 5, MONO = 6,
  ML = 7, MR = 8, MC = 9, MLFE = 10, MLRS = 11, MRRS = 12, MLS = 13, MRS = 14,
  MLTM = 15, MRTM = 16, MLTR = 17, MRTR = 18,
  LMCROSS = 19, MHCROSS = 20, LSOLO = 21, MSOLO = 22, HSOLO = 23, DIMLV = 24
}

local ch_state = {}
for i = PARAM.ML, PARAM.MRTR do
  ch_state[i] = { muted = false, soloed = false, safe = false }
end

local band_state = {}
for _, p in ipairs({PARAM.LSOLO, PARAM.MSOLO, PARAM.HSOLO}) do
  band_state[p] = { muted = false, soloed = false }
end

local initialized = false

local function UpdateChannels(fx_idx)
  local any_solo = false
  for p = PARAM.ML, PARAM.MRTR do
    if ch_state[p].soloed then any_solo = true break end
  end

  for p = PARAM.ML, PARAM.MRTR do
    local should_mute = ch_state[p].muted
    if any_solo and not ch_state[p].soloed and not ch_state[p].safe then
      should_mute = true
    end
    reaper.TrackFX_SetParam(master_track, fx_idx, p, should_mute and 1 or 0)
  end
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

local function DrawChannelButton(label, fx_idx, param_id)
  local state = ch_state[param_id]
  local btn_color, hover_color, active_color
  
  if state.muted then
    btn_color = 0xCC0000FF -- Red
    hover_color = 0xDD0000FF
    active_color = 0xFF0000FF
  elseif state.soloed then
    btn_color = 0xCCCC00FF -- Yellow
    hover_color = 0xDDDD00FF
    active_color = 0xFFFF00FF
  elseif state.safe then
    btn_color = 0x666666FF -- Grey
    hover_color = 0x777777FF
    active_color = 0x888888FF
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
    local is_shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())

    if is_ctrl and is_shift then
      state.safe = not state.safe
    elseif is_ctrl and not is_alt then
      for p = PARAM.ML, PARAM.MRTR do
        ch_state[p].muted = false
        ch_state[p].soloed = false
      end
    elseif is_alt and not is_ctrl and not is_shift then
      state.soloed = not state.soloed
    elseif not is_ctrl and not is_alt and not is_shift then
      state.muted = not state.muted
    end
    
    UpdateChannels(fx_idx)
  end

  reaper.ImGui_PopID(ctx)
  
  if reaper.ImGui_IsItemHovered(ctx) then
    reaper.ImGui_SetTooltip(ctx, "Click: Toggle Mute\nAlt/Opt+Click: Toggle Solo\nCmd/Ctrl+Click: Clear All Mute/Solo\nCmd/Ctrl+Shift+Click: Toggle Solo Safe")
  end

  if btn_color then
    reaper.ImGui_PopStyleColor(ctx, 3)
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

function loop()
  local window_flags = reaper.ImGui_WindowFlags_AlwaysAutoResize()
  local visible, open = reaper.ImGui_Begin(ctx, 'o61iqz Monitor Control - Surround', true, window_flags)

  if visible then
    local raw_idx = reaper.TrackFX_AddByName(master_track, fx_name, true, 1)
    local fx_idx = raw_idx + MONITOR_FX_OFFSET

    if raw_idx >= 0 then
      if not initialized then
        for p = PARAM.ML, PARAM.MRTR do
          ch_state[p].muted = (reaper.TrackFX_GetParam(master_track, fx_idx, p) == 1)
        end
        for _, p in ipairs({PARAM.LSOLO, PARAM.MSOLO, PARAM.HSOLO}) do
          band_state[p].soloed = (reaper.TrackFX_GetParam(master_track, fx_idx, p) == 1)
        end
        initialized = true
      end

      local cur_gain = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.GAIN)
      local cur_dim = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.DIM)
      local cur_mute = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.MUTE)
      local cur_surround = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.SURROUND)
      local cur_phase = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.PHASE)
      local cur_flip = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.FLIP)
      local cur_mono = reaper.TrackFX_GetParam(master_track, fx_idx, PARAM.MONO)
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
      DrawToggleButton('Mono', fx_idx, PARAM.MONO, cur_mono, 1)

      -- Channels
      reaper.ImGui_Text(ctx, "| Channels:")
      reaper.ImGui_SameLine(ctx)
      DrawChannelButton('L', fx_idx, PARAM.ML)
      DrawChannelButton('R', fx_idx, PARAM.MR)
      if cur_surround == 0 then
        DrawChannelButton('Lr', fx_idx, PARAM.MC)
        DrawChannelButton('Rr', fx_idx, PARAM.MLFE)
      else
        DrawChannelButton('C', fx_idx, PARAM.MC)
        DrawChannelButton('LFE', fx_idx, PARAM.MLFE)
      end
      if cur_surround >= 1 then
        DrawChannelButton('Lrs', fx_idx, PARAM.MLRS)
        DrawChannelButton('Rrs', fx_idx, PARAM.MRRS)
      end
      if cur_surround >= 2 then
        DrawChannelButton('Ls', fx_idx, PARAM.MLS)
        DrawChannelButton('Rs', fx_idx, PARAM.MRS)
      end
      if cur_surround == 3 then
        DrawChannelButton('Ltm', fx_idx, PARAM.MLTM)
        DrawChannelButton('Rtm', fx_idx, PARAM.MRTM)
      elseif cur_surround == 4 then
        DrawChannelButton('Ltf', fx_idx, PARAM.MLTM)
        DrawChannelButton('Rtf', fx_idx, PARAM.MRTM)
        DrawChannelButton('Ltr', fx_idx, PARAM.MLTR)
        DrawChannelButton('Rtr', fx_idx, PARAM.MRTR)
      end
      reaper.ImGui_SameLine(ctx)

      -- Band Solo
      reaper.ImGui_Text(ctx, "| Bands:")
      reaper.ImGui_SameLine(ctx)
      DrawBandButton('Low', fx_idx, PARAM.LSOLO)
      DrawBandButton('Mid', fx_idx, PARAM.MSOLO)
      DrawBandButton('High', fx_idx, PARAM.HSOLO)
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

        reaper.ImGui_TextDisabled(ctx, "Surround Mode")

        if reaper.ImGui_MenuItem(ctx, "Quadraphonic (4 Channels)", nil, cur_surround == 0) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.SURROUND, 0)
        end
        if reaper.ImGui_MenuItem(ctx, "5.1 (6 Channels)", nil, cur_surround == 1) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.SURROUND, 1)
        end
        if reaper.ImGui_MenuItem(ctx, "7.1 (8 Channels)", nil, cur_surround == 2) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.SURROUND, 2)
        end
        if reaper.ImGui_MenuItem(ctx, "7.1.2 (10 Channels)", nil, cur_surround == 3) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.SURROUND, 3)
        end
        if reaper.ImGui_MenuItem(ctx, "7.1.4 (12 Channels)", nil, cur_surround == 4) then
          reaper.TrackFX_SetParam(master_track, fx_idx, PARAM.SURROUND, 4)
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
        reaper.ImGui_PopStyleVar(ctx, 1)

        reaper.ImGui_EndPopup(ctx)
      end

      reaper.ImGui_PopStyleVar(ctx, 1)
      
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) and not reaper.ImGui_IsAnyItemActive(ctx) then
        reaper.Main_OnCommand(40044, 0)
      end
      
    else
      reaper.ImGui_Text(ctx, "o61iqz Monitor Control FX missing.")
    end

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
