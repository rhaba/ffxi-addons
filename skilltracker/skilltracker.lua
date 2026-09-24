addon.name    = 'skilltracker';
addon.author  = 'Spongeh';
addon.version = '1.0.0';
addon.desc    = 'Shows your currently relevant combat/magic skill levels in a small draggable window.';
addon.link    = '';

require('common');
local settings = require('settings');
local chat     = require('chat');
local imgui    = require('imgui');

-- Ashita combat-skill index -> display name. Index 0 and the two unused
-- gaps (13-21, 46-47) are intentionally absent. Crafts use a separate
-- GetCraftSkill() array and aren't covered by this addon.
local skill_names = {
    [1]  = 'H2H',      [2]  = 'Dagger',   [3]  = 'Sword',      [4]  = 'Gr. Sword',
    [5]  = 'Axe',      [6]  = 'Gr. Axe',  [7]  = 'Scythe',     [8]  = 'Polearm',
    [9]  = 'Katana',   [10] = 'Gr. Katana', [11] = 'Club',     [12] = 'Staff',
    [25] = 'Archery',  [26] = 'Marksmanship', [27] = 'Throwing',
    [28] = 'Guarding', [29] = 'Evasion', [30] = 'Shield',     [31] = 'Parrying',
    [32] = 'Divine',   [33] = 'Healing',  [34] = 'Enhancing',  [35] = 'Enfeebling',
    [36] = 'Elemental', [37] = 'Dark',    [38] = 'Summoning',  [39] = 'Ninjutsu',
    [40] = 'Singing',  [41] = 'String Instr.', [42] = 'Wind Instr.',
    [43] = 'Blue Magic', [44] = 'Geomancy', [45] = 'Handbell',
};

local DEFENSE_IDS = T{ 28, 29, 30, 31 };
local MAGIC_IDS = T{ 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45 };

local ENTITY_STATUS_ENGAGED = 1;

local default_settings = T{
    visible        = true,
    hide_in_combat = true,
};

local skilltracker = {
    settings     = settings.load(default_settings),
    is_engaged   = false,
    last_refresh = 0,
    melee_rows   = T{},
    defense_rows = T{},
    magic_rows   = T{},
};

-- Resolves the skill id(s) for whatever weapon(s) are currently equipped.
-- Slot 0 = main hand, slot 2 = ranged (ammo/slot 3 has no combat skill).
local function get_equipped_weapon_skill_ids()
    local ids = T{};
    local ok = pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();

        for _, slot in ipairs({ 0, 2 }) do
            local eq = inv:GetEquippedItem(slot);
            if (eq ~= nil and eq.Index ~= 0) then
                local container = math.floor(eq.Index / 0x100);
                local index = eq.Index % 0x100;
                local item = inv:GetContainerItem(container, index);
                if (item ~= nil and item.Id ~= 0) then
                    local item_res = res:GetItemById(item.Id);
                    if (item_res ~= nil and item_res.Skill ~= nil and item_res.Skill ~= 0) then
                        ids:append(item_res.Skill);
                    end
                end
            end
        end
    end);
    if (not ok) then
        return T{};
    end
    return ids;
end

local function refresh_skills()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil or party:GetMemberIsActive(0) ~= 1) then
        skilltracker.melee_rows   = T{};
        skilltracker.defense_rows = T{};
        skilltracker.magic_rows   = T{};
        return;
    end

    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return;
    end

    local melee_ids = T{};
    local added = {};
    for _, id in ipairs(get_equipped_weapon_skill_ids()) do
        if (not added[id]) then
            melee_ids:append(id);
            added[id] = true;
        end
    end

    -- Bare-handed (no weapon in main hand) still trains H2H.
    if (not added[1]) then
        local h2h = player:GetCombatSkill(1);
        if (h2h ~= nil and h2h:GetSkill() > 0) then
            melee_ids:append(1);
            added[1] = true;
        end
    end

    local melee_rows = T{};
    for _, id in ipairs(melee_ids) do
        local skill = player:GetCombatSkill(id);
        if (skill ~= nil) then
            melee_rows:append({ name = skill_names[id] or ('Skill ' .. id), value = skill:GetSkill(), capped = skill:IsCapped() });
        end
    end

    local function nonzero_rows(ids)
        local rows = T{};
        for _, id in ipairs(ids) do
            local skill = player:GetCombatSkill(id);
            if (skill ~= nil and skill:GetSkill() > 0) then
                rows:append({ name = skill_names[id], value = skill:GetSkill(), capped = skill:IsCapped() });
            end
        end
        return rows;
    end

    skilltracker.melee_rows   = melee_rows;
    skilltracker.defense_rows = nonzero_rows(DEFENSE_IDS);
    skilltracker.magic_rows   = nonzero_rows(MAGIC_IDS);
end

local function update_combat_state()
    local ok = pcall(function ()
        local party = AshitaCore:GetMemoryManager():GetParty();
        local entity = AshitaCore:GetMemoryManager():GetEntity();
        local player_index = party:GetMemberTargetIndex(0);
        skilltracker.is_engaged = entity:GetStatus(player_index) == ENTITY_STATUS_ENGAGED;
    end);
    if (not ok) then
        skilltracker.is_engaged = false;
    end
end

local function draw_row(row)
    imgui.Text(row.name);
    imgui.SameLine(140);
    imgui.Text(tostring(row.value) .. (row.capped and ' (MAX)' or ''));
end

local function render_window()
    imgui.SetNextWindowSize({ 240, 0 }, ImGuiCond_FirstUseEver);

    local is_open = { skilltracker.settings.visible };
    if (imgui.Begin('Skill Tracker', is_open, ImGuiWindowFlags_AlwaysAutoResize)) then
        if (#skilltracker.melee_rows == 0 and #skilltracker.defense_rows == 0 and #skilltracker.magic_rows == 0) then
            imgui.Text('No trained skills detected.');
        end

        for _, row in ipairs(skilltracker.melee_rows) do
            draw_row(row);
        end

        if (#skilltracker.melee_rows > 0 and #skilltracker.defense_rows > 0) then
            imgui.Separator();
        end

        for _, row in ipairs(skilltracker.defense_rows) do
            draw_row(row);
        end

        if ((#skilltracker.melee_rows > 0 or #skilltracker.defense_rows > 0) and #skilltracker.magic_rows > 0) then
            imgui.Separator();
        end

        for _, row in ipairs(skilltracker.magic_rows) do
            draw_row(row);
        end
    end
    imgui.End();

    if (is_open[1] ~= skilltracker.settings.visible) then
        skilltracker.settings.visible = is_open[1];
        settings.save();
    end
end

local function print_help()
    print(chat.header(addon.name):append(chat.message('Commands:')));
    print(chat.header(addon.name):append(chat.message('/skilltracker on|off|toggle - show/hide the window')));
    print(chat.header(addon.name):append(chat.message('/skilltracker combat <on|off> - hide the window while engaged')));
end

ashita.events.register('load', 'load_cb', function ()
    print(chat.header(addon.name):append(chat.message(('v%s loaded. Use /skilltracker help for commands.'):format(addon.version))));
end);

ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    update_combat_state();

    local now = os.clock();
    if (now - skilltracker.last_refresh >= 1.0) then
        skilltracker.last_refresh = now;
        pcall(refresh_skills);
    end

    if (not skilltracker.settings.visible) then
        return;
    end
    if (skilltracker.settings.hide_in_combat and skilltracker.is_engaged) then
        return;
    end

    render_window();
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1]:lower() ~= '/skilltracker' and args[1]:lower() ~= '/stk')) then
        return;
    end
    e.blocked = true;

    local sub = args[2] and args[2]:lower() or 'help';

    if (sub == 'on') then
        skilltracker.settings.visible = true;
        settings.save();
    elseif (sub == 'off') then
        skilltracker.settings.visible = false;
        settings.save();
    elseif (sub == 'toggle') then
        skilltracker.settings.visible = not skilltracker.settings.visible;
        settings.save();
    elseif (sub == 'combat' and args[3] ~= nil) then
        skilltracker.settings.hide_in_combat = args[3]:lower() == 'on';
        settings.save();
        print(chat.header(addon.name):append(chat.message('Hide in combat: ' .. (skilltracker.settings.hide_in_combat and 'on' or 'off'))));
    else
        print_help();
    end
end);

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        skilltracker.settings = s;
    end
    settings.save();
end);
