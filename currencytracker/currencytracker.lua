addon.name    = 'currencytracker';
addon.author  = 'Spongeh';
addon.version = '1.1.0';
addon.desc    = 'Shows Conquest Points, Allied Notes, Beastmen Seals, and Kindred Seals/Crests in a small draggable window.';
addon.link    = '';

require('common');
local settings = require('settings');
local chat     = require('chat');
local imgui    = require('imgui');
local ui       = require('phxui');

--[[
    These values have no dedicated Ashita memory API - they only arrive over
    the network as packet 0x113 ("Currency Info"). Offsets below are
    1-indexed (Ashita's e.data is a 1-indexed Lua string), taken from the
    packet's known field layout:
        0x05 CP San d'Oria (i32)   0x11 Beastmen Seals (u16)
        0x09 CP Bastok (i32)       0x13 Kindred Seals (u16)
        0x0D CP Windurst (i32)     0x15 Kindred Crests (u16)
        0xA5 Allied Notes (i32)    0x17 High Kindred Crests (u16)
                                   0x19 Sacred Kindred Crests (u16)
    It's not clear exactly what makes the server send this packet (login,
    zone, and/or opening the in-game Currency menu all plausibly do it), so
    values are cached and persisted rather than assumed to refresh on a timer.
]]
local NATION_NAMES = { [0] = "San d'Oria", [1] = 'Bastok', [2] = 'Windurst' };

local default_settings = T{
    theme = 'Farplane9',  -- window theme (phxui); right-click the window or /currencytracker theme <name>
    visible                = true,
    received               = false,
    cp_sandoria            = 0,
    cp_bastok              = 0,
    cp_windurst            = 0,
    allied_notes           = 0,
    beastmen_seals         = 0,
    kindred_seals          = 0,
    kindred_crests         = 0,
    high_kindred_crests    = 0,
    sacred_kindred_crests  = 0,
};

local currencytracker = {
    settings = settings.load(default_settings),
};

local function get_own_nation()
    local ok, nation = pcall(function ()
        return AshitaCore:GetMemoryManager():GetPlayer():GetNation();
    end);
    if (ok) then
        return nation;
    end
    return nil;
end

local function format_number(value)
    local text = tostring(math.floor(tonumber(value) or 0));
    while true do
        local replaced, count = text:gsub('^(-?%d+)(%d%d%d)', '%1,%2');
        text = replaced;
        if (count == 0) then
            return text;
        end
    end
end

local function draw_rows(id, rows)
    if (imgui.BeginTable('##cur_' .. id, 2, ImGuiTableFlags_SizingStretchProp)) then
        imgui.TableSetupColumn('Name', ImGuiTableColumnFlags_WidthStretch, 1.0);
        imgui.TableSetupColumn('Value', ImGuiTableColumnFlags_WidthFixed, 70);
        for _, row in ipairs(rows) do
            imgui.TableNextRow();
            imgui.TableNextColumn();
            imgui.TextColored(row.home and ui.color.peach or ui.color.secondary, row.label);
            if (row.home) then
                imgui.SameLine();
                imgui.TextColored(ui.color.muted, 'home');
            end
            imgui.TableNextColumn();
            local value = tonumber(row.value) or 0;
            imgui.TextColored(value > 0 and ui.color.text or ui.color.faint, format_number(value));
        end
        imgui.EndTable();
    end
end

local function draw_body()
    local s = currencytracker.settings;
    if (not s.received) then
        imgui.TextColored(ui.color.faint, 'No data yet. Open the in-game Currency menu once to fill this in.');
        return;
    end

    local own_nation = get_own_nation();
    local cp_values = { s.cp_sandoria, s.cp_bastok, s.cp_windurst };
    local cp_rows = {};
    for nation_id = 0, 2 do
        cp_rows[#cp_rows + 1] = { label = NATION_NAMES[nation_id], value = cp_values[nation_id + 1], home = (nation_id == own_nation) };
    end
    ui.section('Conquest points');
    draw_rows('cp', cp_rows);

    ui.section('Other currencies');
    draw_rows('other', {
        { label = 'Allied Notes', value = s.allied_notes },
        { label = 'Beastmen Seals', value = s.beastmen_seals },
        { label = 'Kindred Seals', value = s.kindred_seals },
        { label = 'Kindred Crests', value = s.kindred_crests },
        { label = 'High Kindred Crests', value = s.high_kindred_crests },
        { label = 'Sacred Kindred Crests', value = s.sacred_kindred_crests },
    });
end

local function render_window()
    imgui.SetNextWindowSize({ 260, 0 }, ImGuiCond_FirstUseEver);

    local is_open = { currencytracker.settings.visible };
    local token = ui.push();
    if (imgui.Begin('Currency Tracker', is_open, bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse))) then
        local ok, err = pcall(draw_body);
        if (not ok) then
            imgui.TextColored(ui.color.bad, 'Error: ' .. tostring(err));
        end
        if (ui.themeMenu(currencytracker.settings.theme)) then
            currencytracker.settings.theme = ui.theme;
            settings.save();
        end
    end
    imgui.End();
    ui.pop(token);

    if (is_open[1] ~= currencytracker.settings.visible) then
        currencytracker.settings.visible = is_open[1];
        settings.save();
    end
end

local function print_help()
    print(chat.header(addon.name):append(chat.message('Commands:')));
    print(chat.header(addon.name):append(chat.message('/currencytracker on|off|toggle - show/hide the window')));
    print(chat.header(addon.name):append(chat.message('/currencytracker theme <name> - window theme: ' .. table.concat(ui.THEMES, ', ') .. ' (or right-click the window)')));
end

ashita.events.register('load', 'load_cb', function ()
    if ui.adoptPackTheme(currencytracker.settings, 'theme') then settings.save(); end
    ui.setTheme(currencytracker.settings.theme);
    print(chat.header(addon.name):append(chat.message(('v%s loaded. Use /currencytracker help for commands.'):format(addon.version))));
end);

ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id ~= 0x113) then
        return;
    end

    local ok = pcall(function ()
        currencytracker.settings.cp_sandoria           = struct.unpack('i', e.data, 0x05);
        currencytracker.settings.cp_bastok             = struct.unpack('i', e.data, 0x09);
        currencytracker.settings.cp_windurst           = struct.unpack('i', e.data, 0x0D);
        currencytracker.settings.beastmen_seals        = struct.unpack('H', e.data, 0x11);
        currencytracker.settings.kindred_seals         = struct.unpack('H', e.data, 0x13);
        currencytracker.settings.kindred_crests        = struct.unpack('H', e.data, 0x15);
        currencytracker.settings.high_kindred_crests   = struct.unpack('H', e.data, 0x17);
        currencytracker.settings.sacred_kindred_crests = struct.unpack('H', e.data, 0x19);
        currencytracker.settings.allied_notes          = struct.unpack('i', e.data, 0xA5);
        currencytracker.settings.received              = true;
    end);

    if (ok) then
        settings.save();
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    if (not currencytracker.settings.visible) then
        return;
    end
    render_window();
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1]:lower() ~= '/currencytracker' and args[1]:lower() ~= '/curr')) then
        return;
    end
    e.blocked = true;

    local sub = args[2] and args[2]:lower() or 'help';

    if (sub == 'theme') then
        local name = ui.findTheme(args[3]);
        if (name == nil) then
            print(chat.header(addon.name):append(chat.message('Themes: ' .. table.concat(ui.THEMES, ', ') .. '. Use /currencytracker theme <name>, or right-click the window.')));
        else
            currencytracker.settings.theme = ui.setTheme(name);
            settings.save();
            print(chat.header(addon.name):append(chat.message('Theme: ' .. name)));
        end
    elseif (sub == 'on') then
        currencytracker.settings.visible = true;
        settings.save();
    elseif (sub == 'off') then
        currencytracker.settings.visible = false;
        settings.save();
    elseif (sub == 'toggle') then
        currencytracker.settings.visible = not currencytracker.settings.visible;
        settings.save();
    else
        print_help();
    end
end);

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        currencytracker.settings = s;
        if ui.adoptPackTheme(currencytracker.settings, 'theme') then settings.save(); end
        ui.setTheme(currencytracker.settings.theme);
    end
    settings.save();
end);
