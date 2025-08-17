local effectDuration  = 30
local speedMultiplier = 2
local jumpMultiplier = 2

local active = {} 
local effectsActivationsTrack = 0
local function now() return minetest.get_us_time() / 1e6 end

local applyEffect
local clearEffect

-- HUD timer

local function add_timer_hud(player, seconds, label)
    return player:hud_add({
        hud_elem_type = "text",
        position = {x=0.5, y=0.1},
        text = label .. " (" .. seconds .. "s)",
        number = 0xFFFFFF,
        alignment = {x=0, y=0},
        scale = {x=100, y=20},
    })
end

local function schedule_hud_tick(player, effect_id)
    local name = player:get_player_name()
    minetest.after(1, function()
        local real = minetest.get_player_by_name(name)
        if not real or not real:is_player() then return end
        local st = active[name]
        if not st or st.id ~= effect_id then return end
        local left = math.max(0, math.floor(st.expires - now()))
        if left <= 0 then return end
        pcall(function()
            real:hud_change(st.hud_id, "text", (st.label or "Ефект") .. " (" .. left .. "s)")
        end)
        schedule_hud_tick(real, effect_id)
    end)
end

-- Speed Multiplier Scroll

minetest.register_craftitem("magic_scrolls:speed_scroll",{
    description = "Speed Multiplier Scroll",
    inventory_image = "speed2X_scroll.png",
    on_use = function (itemstack, user)
        if not user or not user:is_player() then return itemstack end
        applyEffect(user, "speed", effectDuration)
        if not minetest.is_creative_enabled(user:get_player_name()) then
            itemstack:take_item(1)
        end
        return itemstack
    end
})

-- Jump Multiplier Scroll

minetest.register_craftitem("magic_scrolls:jump_scroll", {
    description = "Jump Multiplier Scroll",
    inventory_image = "jump2X_scroll.png",
    on_use = function(itemstack, user)
        if not user or not user:is_player() then return itemstack end
        applyEffect(user, "jump", effectDuration)
        if not minetest.is_creative_enabled(user:get_player_name()) then
            itemstack:take_item(1)
        end
        return itemstack
    end,
})

-- Invulnerable Scroll

minetest.register_craftitem("magic_scrolls:invuln_scroll", {
    description = "Invulnerable Scroll",
    inventory_image = "inviolate_scroll.png",
    on_use = function(itemstack, user)
        if not user or not user:is_player() then return itemstack end
        applyEffect(user, "invulnerable", effectDuration)
        if not minetest.is_creative_enabled(user:get_player_name()) then
            itemstack:take_item(1)
        end
        return itemstack
    end,
})

-- Applying effect function

applyEffect = function(player, effectName, effectDuration)
    local playerName = player:get_player_name()
    if active[playerName] then clearEffect(player, "replace") end
    
    -- effect id
    effectsActivationsTrack = effectsActivationsTrack +1
    local id = effectsActivationsTrack

    local label = (effectName == "speed" and "Speed")
        or (effectName == "jump"  and "Jump")
        or "Invulnerable"

    -- Saving previous physics
    local prev = player:get_physics_override()
    local newPhysics = table.copy(prev)
    local invulnerable = false

    -- Selecting effect
    if effectName == "speed" then
    newPhysics.speed = (prev.speed or 1.0) * speedMultiplier
    player:set_physics_override(newPhysics)

    elseif effectName == "jump" then
    newPhysics.jump = (prev.jump or 1.0) * jumpMultiplier
    player:set_physics_override(newPhysics)

    elseif effectName == "invulnerable" then
    invulnerable = true
    end

    local hud_id = add_timer_hud(player, effectDuration, label)
    schedule_hud_tick(player, id)

    -- Saving effect 
    active[playerName] = {
    kind = effectName,
    label = label,
    expires = now() + effectDuration,
    id = id,
    hud_id = hud_id,
    prev_phys = (effectName == "speed" or effectName == "jump") and prev or nil,
    invulnerable = invulnerable,
}

    -- Auto end of effect
    minetest.after(effectDuration, function()
    local effectStatus = active[playerName]
    if not effectStatus or effectStatus.id ~= id then return end
    local p = minetest.get_player_by_name(playerName)
    if not p then
    active[playerName] = nil
    return
    end
    clearEffect(p)
    end)
end

-- Deactivate effect

clearEffect = function(player, reason)
    if not player or not player:is_player() then return end
    local playerName = player:get_player_name()
    local effectStatus = active[playerName]
    if not effectStatus then return end
    if effectStatus.prev_phys then
        player:set_physics_override(effectStatus.prev_phys)
    end
    if effectStatus.hud_id then
        pcall(function() player:hud_remove(effectStatus.hud_id) end)
    end
      active[playerName] = nil
end

-- Invulnerable logic

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if not player or not player.is_player or not player:is_player() then
        return hp_change
    end

    if hp_change >= 0 then return hp_change end
    local effectStatus = active[player:get_player_name()]
    if effectStatus and effectStatus.invulnerable and effectStatus.expires > now() then
        return 0
    end
    return hp_change
end, true)

-- Reset effects when player leaves / respawns

minetest.register_on_leaveplayer(function(player) clearEffect(player) end)
minetest.register_on_respawnplayer(function(player) clearEffect(player) return false end)

-- Craft for each effect

minetest.register_craft({
    output = "magic_scrolls:speed_scroll",  
    recipe = {{"default:dirt", "default:dirt"}}
})

minetest.register_craft({
    output = "magic_scrolls:jump_scroll",
    recipe = {{"default:sand", "default:sand"}}
})

minetest.register_craft({
    output = "magic_scrolls:invuln_scroll",
     recipe = {{"default:stick", "default:stick"}}
})