local Menu = { -- the config table

    colors = { 
        -- Local = {},
        blu = {255,255,255},
        red = {255, 255, 255},
        gradientblu = {255, 255, 255},
        gradientred = {255, 255, 255},
    },

    tabs = {
        global = false, 
        players = true, 
        colors = false,
        config = false,
    },

    global_tab = {
        active = true,
    },

    players_tab = {
        active = true,
        max_distance = 2500,
        alpha = 10,
        ignore = {
            friends = true,
            enemies = false,
            teammates = true,
            invisible = false
        },
        draw = {
            health_bar = true, 
            bars_thickness = 2,
            health_bar_pos = {"Left", "Bottom"},
            selected_health_bar_pos = 1,
        },
    },

    
    colors_tab = {
        colors = {"Blu", "Gradient Blu", "Red", "Gradient Red"},
        selected_color = 1,
    }
}



local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

local lastToggleTime = 0
local Lbox_Menu_Open = true
local function toggleMenu()
    local currentTime = globals.RealTime()
    if currentTime - lastToggleTime >= 0.1 then
        if Lbox_Menu_Open == false then
            Lbox_Menu_Open = true
        elseif Lbox_Menu_Open == true then
            Lbox_Menu_Open = false
        end
        lastToggleTime = currentTime
    end
end

local s_width, s_height = draw.GetScreenSize()

local function ColorCalculator(index) -- best name
    local colors = {
        [1] = Menu.colors.blu,
        [2] = Menu.colors.gradientblu,
        [3] = Menu.colors.red,
        [4] = Menu.colors.gradientred,
    }
    return colors[index]
end

local gradientBarMaskdownup = (function()
    local chars = {}

    for i = 0, 255 do
        chars[i * 4 + 1] = 255 - i
        chars[i * 4 + 2] = 255 - i
        chars[i * 4 + 3] = 255 - i 
        chars[i * 4 + 4] = 255
    end

    return draw.CreateTextureRGBA(string.char(table.unpack(chars)), 1, 256)
end)()


local function distance_check(entity, local_player)
    if vector.Distance( entity:GetAbsOrigin(), local_player:GetAbsOrigin()) > Menu.players_tab.max_distance then 
        return false 
    end 
    return true
end

local function IsFriend(idx, inParty)
    if idx == client.GetLocalPlayerIndex() then return true end

    local playerInfo = client.GetPlayerInfo(idx)
    if steam.IsFriend(playerInfo.SteamID) then return true end
    if playerlist.GetPriority(playerInfo.UserID) < 0 then return true end

    if inParty then
        local partyMembers = party.GetMembers()
        if partyMembers == true then
            for _, member in ipairs(partyMembers) do
                if member == playerInfo.SteamID then return true end
            end
        end
    end

    return false
end

local function Get2DBoundingBox(entity)
    local hitbox = entity:HitboxSurroundingBox()
    local corners = {
        Vector3(hitbox[1].x, hitbox[1].y, hitbox[1].z),
        Vector3(hitbox[1].x, hitbox[2].y, hitbox[1].z),
        Vector3(hitbox[2].x, hitbox[2].y, hitbox[1].z),
        Vector3(hitbox[2].x, hitbox[1].y, hitbox[1].z),
        Vector3(hitbox[2].x, hitbox[2].y, hitbox[2].z),
        Vector3(hitbox[1].x, hitbox[2].y, hitbox[2].z),
        Vector3(hitbox[1].x, hitbox[1].y, hitbox[2].z),
        Vector3(hitbox[2].x, hitbox[1].y, hitbox[2].z)
    }
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, corner in pairs(corners) do
        local onScreen = client.WorldToScreen(corner)
        if onScreen then
            minX, minY = math.min(minX, onScreen[1]), math.min(minY, onScreen[2])
            maxX, maxY = math.max(maxX, onScreen[1]), math.max(maxY, onScreen[2])
        else
            return false
        end
    end
    return minX, minY, maxX, maxY
end

local function CreateCFG(folder_name, table)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.txt")
    local file = io.open(filepath, "w")
    
    if file then
        local function serializeTable(tbl, level)
            level = level or 0
            local result = string.rep("    ", level) .. "{\n"
            for key, value in pairs(tbl) do
                result = result .. string.rep("    ", level + 1)
                if type(key) == "string" then
                    result = result .. '["' .. key .. '"] = '
                else
                    result = result .. "[" .. key .. "] = "
                end
                if type(value) == "table" then
                    result = result .. serializeTable(value, level + 1) .. ",\n"
                elseif type(value) == "string" then
                    result = result .. '"' .. value .. '",\n'
                else
                    result = result .. tostring(value) .. ",\n"
                end
            end
            result = result .. string.rep("    ", level) .. "}"
            return result
        end
        
        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()
        printc( 255, 183, 0, 255, "["..os.date("%H:%M:%S").."] Saved to ".. tostring(fullPath))
    end
end

local function LoadCFG(folder_name)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.txt")
    local file = io.open(filepath, "r")
    
    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            printc( 0, 255, 140, 255, "["..os.date("%H:%M:%S").."] Loaded from ".. tostring(fullPath))
            return chunk()
        else
            print("Error loading configuration:", err)
        end
    end
end


callbacks.Register( "Draw", "gradient healthbar", function()

    if input.IsButtonPressed( KEY_END ) or input.IsButtonPressed( KEY_INSERT ) or input.IsButtonPressed( KEY_F11 ) then 
        toggleMenu()
    end

    if Lbox_Menu_Open == true and ImMenu.Begin("Custom Gradient Healthbar", true) then -- managing the menu

        ImMenu.BeginFrame(1) -- tabs

        if ImMenu.Button("Players") then
            Menu.tabs.players = true
            Menu.tabs.colors = false
            Menu.tabs.config = false
        end


        if ImMenu.Button("Colors") then
            Menu.tabs.players = false
            Menu.tabs.colors = true
            Menu.tabs.config = false
        end

        if ImMenu.Button("Config") then
            Menu.tabs.players = false
            Menu.tabs.colors = false
            Menu.tabs.config = true
        end

        ImMenu.EndFrame()


        if Menu.tabs.players then 
            ImMenu.BeginFrame(1)
            Menu.players_tab.active =  ImMenu.Checkbox("Active", Menu.players_tab.active)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.players_tab.max_distance = ImMenu.Slider("Max Distance", Menu.players_tab.max_distance , 100, 6000)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.players_tab.alpha = ImMenu.Slider("Alpha", Menu.players_tab.alpha , 0, 10)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            ImMenu.Text("Ignore List")
            ImMenu.EndFrame()
            ImMenu.BeginFrame(1)
            Menu.players_tab.ignore.enemies =  ImMenu.Checkbox("Enemies", Menu.players_tab.ignore.enemies)
            Menu.players_tab.ignore.invisible =  ImMenu.Checkbox("Invisible", Menu.players_tab.ignore.invisible)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            ImMenu.Text("Health bar Customization")
            ImMenu.EndFrame()
            ImMenu.BeginFrame(1)
            Menu.players_tab.draw.bars_thickness = ImMenu.Slider("Health Bar Thickness", Menu.players_tab.draw.bars_thickness , 1, 10)
            ImMenu.EndFrame()

        end

      

        if Menu.tabs.colors then

            ImMenu.BeginFrame(1)
            ImMenu.Text("Selected Color")
            Menu.colors_tab.selected_color = ImMenu.Option(Menu.colors_tab.selected_color, Menu.colors_tab.colors)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            ColorCalculator(Menu.colors_tab.selected_color)[1] = ImMenu.Slider("Red", ColorCalculator(Menu.colors_tab.selected_color)[1] , 0, 255)
            ImMenu.EndFrame()
            ImMenu.BeginFrame(1)
            ColorCalculator(Menu.colors_tab.selected_color)[2] = ImMenu.Slider("Green", ColorCalculator(Menu.colors_tab.selected_color)[2] , 0, 255)
            ImMenu.EndFrame()
            ImMenu.BeginFrame(1)
            ColorCalculator(Menu.colors_tab.selected_color)[3] = ImMenu.Slider("Blue", ColorCalculator(Menu.colors_tab.selected_color)[3] , 0, 255)
            ImMenu.EndFrame()
        end

        if Menu.tabs.config then 
            ImMenu.BeginFrame(1)
            if ImMenu.Button("Create/Save CFG") then
                CreateCFG( [[gradient healthbar config]] , Menu )
            end

            if ImMenu.Button("Load CFG") then
                Menu = LoadCFG( [[gradient healthbar config]] )
            end

            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            ImMenu.Text("Dont load a config if you havent saved one.")
            ImMenu.EndFrame()
        end

        ImMenu.End()
    end

    --=====================--
    -- starting drawing esp 
    local localPlayer = entities.GetLocalPlayer()
    


        if Menu.players_tab.active then 
            local players = entities.FindByClass( "CTFPlayer" )
            for i,p in pairs(players) do 
                if p:IsAlive() and not p:IsDormant() and distance_check(p, localPlayer) and p ~= localPlayer then 
                    local pIndex = p:GetIndex()
                    local localTeam = localPlayer:GetTeamNumber()
                    local enemyTeam = p:GetTeamNumber()
                    local espColor = nil
                    local gradientColor = nil   


                    if Menu.players_tab.ignore.friends and IsFriend(pIndex, true) then
                        goto esp_continue
                    end
                    
                    if Menu.players_tab.ignore.teammates and enemyTeam == localTeam then 
                        if IsFriend(pIndex, true) and not Menu.players_tab.ignore.friends then 
                            goto friends_vip_ignore_check_bypass -- was ignoring friends when ignoring teammates
                        end
                        goto esp_continue
                    end
                    
                    if Menu.players_tab.ignore.enemies and enemyTeam ~= localTeam then 
                        goto esp_continue
                    end
                    
                    if Menu.players_tab.ignore.invisible and p:InCond(4) then 
                        if IsFriend(pIndex, true) and not Menu.players_tab.ignore.friends then 
                            goto friends_vip_ignore_check_bypass
                        end
                        goto esp_continue
                    end
                    
                    ::friends_vip_ignore_check_bypass::

                        if entities.GetLocalPlayer():GetTeamNumber() == 2 then
                            gradientColor = Menu.colors.gradientblu
                            espColor = Menu.colors.blu
                        else
                            gradientColor = Menu.colors.gradientred
                            espColor = Menu.colors.red
                        end

                    local x,y,x2,y2 = Get2DBoundingBox(p)
                    if not x or not y or not x2 or not y2 then goto esp_continue end
                    local h, w = y2 - y, x2 - x

                    local alpha = math.floor(255 * (Menu.players_tab.alpha / 10))

                    local text_pos_table = {}


                    if Menu.players_tab.draw.health_bar then 
                        health = p:GetHealth()
                        maxHealth = p:GetMaxHealth()
                        percentageHealth = math.floor(health / maxHealth * 100)
                        local healthBarSize = nil
                        local maxHealthBarSize = nil

                        local health_bar_pos = nil
                        local health_bar_backround_pos = nil

                        if Menu.players_tab.draw.selected_health_bar_pos == 1 then -- left
                            healthBarSize = math.floor(h * (health / maxHealth))
                            maxHealthBarSize = math.floor(h)
                            if percentageHealth > 100 then 
                                healthBarSize = maxHealthBarSize
                            end
                            health_bar_pos = {x - (4 + Menu.players_tab.draw.bars_thickness), (y + h) - healthBarSize, x - 4, (y + h)}

                            if not Menu.players_tab.draw.bars_static_bacrkound then
                                health_bar_backround_pos = {health_bar_pos[1] - 1, health_bar_pos[2] - 1, health_bar_pos[3] + 1, health_bar_pos[4] + 1}
                            else
                                health_bar_backround_pos = {x - (5 + Menu.players_tab.draw.bars_thickness), y - 1, x - 3, (y + h) + 1}
                            end
                        end

                        if Menu.players_tab.draw.selected_health_bar_pos == 2 then -- down
                            healthBarSize = math.floor(w * (health / maxHealth))
                            maxHealthBarSize = math.floor(w)
                            if percentageHealth > 100 then 
                                healthBarSize = maxHealthBarSize
                            end
                            health_bar_pos = {x + 1, y + h + 3, x - 1 + healthBarSize, y + h + 3 + Menu.players_tab.draw.bars_thickness}

                            if not Menu.players_tab.draw.bars_static_bacrkound then
                                health_bar_backround_pos = {health_bar_pos[1] - 1, health_bar_pos[2] - 1, health_bar_pos[3] + 1, health_bar_pos[4] + 1}
                            else
                                health_bar_backround_pos = {x, y + h + 2, x + w, y + h + 4 + Menu.players_tab.draw.bars_thickness}
                            end
                        end

                        draw.Color(0,0,0,alpha)
                        draw.FilledRect(health_bar_backround_pos[1], health_bar_backround_pos[2], health_bar_backround_pos[3], health_bar_backround_pos[4]) -- backround

                        draw.Color(espColor[1],espColor[2],espColor[3], alpha)
                        draw.FilledRect( health_bar_pos[1], health_bar_pos[2], health_bar_pos[3], health_bar_pos[4]) -- healthbar

                        draw.Color(gradientColor[1], gradientColor[2], gradientColor[3], math.floor(math.sin(globals.CurTime()*0) * 255 + 200))
                        draw.TexturedRect(gradientBarMaskdownup, health_bar_pos[1], health_bar_pos[2], health_bar_pos[3], health_bar_pos[4])
            
                    end

                   

    
                end
                ::esp_continue::
            end 
        end



end)

callbacks.Register( "Unload", function() 
    local entities = entities.FindByClass( "CBaseAnimating" )
    for i, entity in pairs(entities) do 
        entity:SetPropFloat( 1, "m_flPlaybackRate" )
    end
end)

callbacks.Register("Unload", function()
    draw.DeleteTexture(gradientBarMaskdownup)
end)