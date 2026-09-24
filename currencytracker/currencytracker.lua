addon.name    = 'currencytracker';
addon.author  = 'Spongeh';
addon.version = '1.0.0';
addon.desc    = 'Shows Conquest Points, Allied Notes, Beastmen Seals, and Kindred Seals/Crests in a small draggable window.';
addon.link    = '';

require('common');
local settings = require('settings');
local chat     = require('chat');
local imgui    = require('imgui');

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

local function draw_row(label, value)
    imgui.Text(label);
    imgui.SameLine(180);
    imgui.Text(tostring(value));
end

local function render_window()
    imgui.SetNextWindowSize({ 260, 0 }, ImGuiCond_FirstUseEver);

    local is_open = { currencytracker.settings.visible };
    if (imgui.Begin('Currency Tracker', is_open, ImGuiWindowFlags_AlwaysAutoResize)) then
        if (not currencytracker.settings.received) then
            imgui.TextWrapped('No data yet - open the in-game Currency menu once to populate this.');
        else
            local own_nation = get_own_nation();
            local cp_values = { currencytracker.settings.cp_sandoria, currencytracker.settings.cp_bastok, currencytracker.settings.cp_windurst };

            imgui.Text('Conquest Points');
            imgui.Separator();
            for nation_id = 0, 2 do
                local label = NATION_NAMES[nation_id];
                if (nation_id == own_nation) then
                    label = label .. ' (home)';
                end
                draw_row(label, cp_values[nation_id + 1]);
            end

            imgui.Spacing();
            imgui.Text('Other Currencies');
            imgui.Separator();
            draw_row('Allied Notes', currencytracker.settings.allied_notes);
            draw_row('Beastmen Seals', currencytracker.settings.beastmen_seals);
            draw_row('Kindred Seals', currencytracker.settings.kindred_seals);
            draw_row('Kindred Crests', currencytracker.settings.kindred_crests);
            draw_row('High Kindred Crests', currencytracker.settings.high_kindred_crests);
            draw_row('Sacred Kindred Crests', currencytracker.settings.sacred_kindred_crests);
        end
    end
    imgui.End();

    if (is_open[1] ~= currencytracker.settings.visible) then
        currencytracker.settings.visible = is_open[1];
        settings.save();
    end
end

local function print_help()
    print(chat.header(addon.name):append(chat.message('Commands:')));
    print(chat.header(addon.name):append(chat.message('/currencytracker on|off|toggle - show/hide the window')));
end

ashita.events.register('load', 'load_cb', function ()
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

    if (sub == 'on') then
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
    end
    settings.save();
end);
