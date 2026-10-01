--[[
    phxui - shared look for Spongeh's PhoenixXI addons.

    Design follows Skold's PhoenixFishTrack (https://github.com/Skold177/PhoenixFishTrack): a deep
    ember-red panel, warm off-white text, crimson accents, rounded windows and frames, small
    upper-case section labels, and label-over-value stat cells. Each addon ships its own copy of
    this file so it stays standalone; keep the copies identical.

        local ui = require('phxui');
        local token = ui.push();          -- before imgui.Begin (alpha optional: ui.push(0.9))
        if imgui.Begin(...) then ... end
        imgui.End();
        ui.pop(token);

    Helpers (call inside a window): ui.section, ui.stat, ui.toggle, ui.rightText, ui.labelValue,
    ui.tooltip, ui.textWidth.
]]

local imgui = require('imgui');

local ui = {};

local function rgb(hex, alpha)
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        alpha or 1.0,
    };
end

ui.rgb = rgb;

ui.color = {
    abyss     = rgb('180e0e'),        -- window background
    surface1  = rgb('291c1c'),        -- title bars, popups, alternate rows
    surface2  = rgb('321f1f'),        -- frames, headers, idle buttons
    border    = rgb('d2abab', 0.20),
    subtle    = rgb('d2abab', 0.12),
    text      = rgb('fff8f8'),
    secondary = rgb('eae1e1'),        -- names, list entries
    peach     = rgb('d2abab'),        -- highlighted values, the player
    muted     = rgb('8a6b6b'),        -- labels, hints
    faint     = rgb('5a4545'),        -- empty states, n/a
    royal     = rgb('c55151'),        -- accent: buttons, checks, sliders, bars
    tint      = rgb('c55151', 0.30),  -- hover on frames
    hover     = rgb('d45e5e'),
    ember     = rgb('ff8d79'),        -- attention, headline values
    danger    = rgb('e04040'),
    gold      = rgb('c5a131'),        -- rare / legendary / gil
    success   = rgb('63ba8a'),
    clear     = { 0, 0, 0, 0 },
};

-- Meaning-based names, so addons don't pick palette entries ad hoc.
ui.color.ok     = ui.color.success;
ui.color.warn   = ui.color.ember;
ui.color.bad    = ui.color.danger;
ui.color.info   = ui.color.peach;
ui.color.dim    = ui.color.muted;
ui.color.accent = ui.color.royal;

ui.PADDING = 12;

-- Some ImGui color names changed between versions (TabActive -> TabSelected); nil entries skip.
local function styleColors(alpha)
    local c = ui.color;
    return {
        { ImGuiCol_WindowBg,           { c.abyss[1], c.abyss[2], c.abyss[3], alpha } },
        { ImGuiCol_ChildBg,            c.clear },
        { ImGuiCol_TitleBg,            c.surface1 },
        { ImGuiCol_TitleBgActive,      c.surface2 },
        { ImGuiCol_TitleBgCollapsed,   c.surface1 },
        { ImGuiCol_MenuBarBg,          c.surface1 },
        { ImGuiCol_Border,             c.border },
        { ImGuiCol_Separator,          c.border },
        { ImGuiCol_SeparatorHovered,   c.hover },
        { ImGuiCol_SeparatorActive,    c.royal },
        { ImGuiCol_Text,               c.text },
        { ImGuiCol_TextDisabled,       c.muted },
        { ImGuiCol_FrameBg,            c.surface2 },
        { ImGuiCol_FrameBgHovered,     c.tint },
        { ImGuiCol_FrameBgActive,      c.surface2 },
        { ImGuiCol_SliderGrab,         c.royal },
        { ImGuiCol_SliderGrabActive,   c.hover },
        { ImGuiCol_PlotHistogram,      c.royal },
        { ImGuiCol_Header,             c.surface2 },
        { ImGuiCol_HeaderHovered,      c.tint },
        { ImGuiCol_HeaderActive,       c.royal },
        { ImGuiCol_Tab,                c.surface1 },
        { ImGuiCol_TabHovered,         c.hover },
        { ImGuiCol_TabSelected or ImGuiCol_TabActive, c.royal },
        { ImGuiCol_TabDimmed or ImGuiCol_TabUnfocused, c.surface1 },
        { ImGuiCol_TabDimmedSelected or ImGuiCol_TabUnfocusedActive, c.surface2 },
        { ImGuiCol_TableHeaderBg,      c.surface2 },
        { ImGuiCol_TableBorderLight,   c.subtle },
        { ImGuiCol_TableBorderStrong,  c.border },
        { ImGuiCol_TableRowBg,         c.clear },
        { ImGuiCol_TableRowBgAlt,      c.surface1 },
        { ImGuiCol_PopupBg,            c.surface1 },
        { ImGuiCol_CheckMark,          c.royal },
        { ImGuiCol_Button,             c.royal },
        { ImGuiCol_ButtonHovered,      c.hover },
        { ImGuiCol_ButtonActive,       c.royal },
        { ImGuiCol_ScrollbarBg,        c.abyss },
        { ImGuiCol_ScrollbarGrab,      c.surface2 },
        { ImGuiCol_ScrollbarGrabHovered, c.tint },
        { ImGuiCol_ScrollbarGrabActive, c.royal },
        { ImGuiCol_ResizeGrip,         c.clear },
        { ImGuiCol_ResizeGripHovered,  c.tint },
        { ImGuiCol_ResizeGripActive,   c.royal },
    };
end

local styleVars = {
    { ImGuiStyleVar_WindowRounding, 8.0 },
    { ImGuiStyleVar_ChildRounding,  6.0 },
    { ImGuiStyleVar_FrameRounding,  4.0 },
    { ImGuiStyleVar_PopupRounding,  6.0 },
    { ImGuiStyleVar_GrabRounding,   4.0 },
    { ImGuiStyleVar_TabRounding,    4.0 },
    { ImGuiStyleVar_WindowPadding,  { 12, 10 } },
    { ImGuiStyleVar_ItemSpacing,    { 8, 5 } },
    { ImGuiStyleVar_CellPadding,    { 4, 3 } },
};

-- Push the theme. Returns a token for ui.pop. alpha is the window background opacity.
function ui.push(alpha)
    local token = { colors = 0, vars = 0 };
    for _, entry in ipairs(styleColors(alpha or 0.94)) do
        if entry[1] ~= nil then
            imgui.PushStyleColor(entry[1], entry[2]);
            token.colors = token.colors + 1;
        end
    end
    for _, entry in ipairs(styleVars) do
        if entry[1] ~= nil then
            imgui.PushStyleVar(entry[1], entry[2]);
            token.vars = token.vars + 1;
        end
    end
    return token;
end

function ui.pop(token)
    if token == nil then return; end
    if token.vars > 0 then imgui.PopStyleVar(token.vars); end
    if token.colors > 0 then imgui.PopStyleColor(token.colors); end
end

-- Push / pop around a draw function, with the pop guaranteed even if fn errors.
function ui.wrap(fn, alpha)
    local token = ui.push(alpha);
    local ok, err = pcall(fn);
    ui.pop(token);
    if not ok then error(err, 0); end
end

function ui.textWidth(text)
    local w = imgui.CalcTextSize(text);
    if type(w) == 'table' then return w.x or w[1] or 0; end
    return w or 0;
end

-- Small upper-case section label in the muted color, with a little space above.
function ui.section(label)
    imgui.Spacing();
    imgui.TextColored(ui.color.muted, tostring(label):upper());
end

-- Label-over-value cell, for use inside a table (moves to the next column first).
function ui.stat(label, value, color)
    imgui.TableNextColumn();
    imgui.TextColored(ui.color.muted, label);
    imgui.TextColored(color or ui.color.text, tostring(value));
end

-- "Label  value" on one line: muted label, colored value.
function ui.labelValue(label, value, color, indent)
    imgui.TextColored(ui.color.muted, label);
    if indent then imgui.SameLine(indent); else imgui.SameLine(); end
    imgui.TextColored(color or ui.color.text, tostring(value));
end

-- Text pinned to the right edge of the current content region, on the same line.
function ui.rightText(color, text)
    imgui.SameLine();
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    local w = ui.textWidth(text);
    if avail and avail > w then imgui.SetCursorPosX(imgui.GetCursorPosX() + avail - w); end
    imgui.TextColored(color or ui.color.muted, text);
end

-- A button that reads as on (accent) or off (surface, muted text).
function ui.toggle(label, on, size)
    local c = ui.color;
    imgui.PushStyleColor(ImGuiCol_Button, on and c.royal or c.surface2);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, on and c.hover or c.tint);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, c.royal);
    imgui.PushStyleColor(ImGuiCol_Text, on and c.text or c.muted);
    local clicked = imgui.Button(label, size or { 0, 0 });
    imgui.PopStyleColor(4);
    return clicked;
end

-- A quiet button (surface color) for secondary actions next to an accent one.
function ui.button(label, size)
    local c = ui.color;
    imgui.PushStyleColor(ImGuiCol_Button, c.surface2);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, c.tint);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, c.royal);
    local clicked = imgui.Button(label, size or { 0, 0 });
    imgui.PopStyleColor(3);
    return clicked;
end

function ui.tooltip(text)
    if imgui.IsItemHovered() then imgui.SetTooltip(text); end
end

return ui;
