local name, addon = ...
local db = VilinkasInsanityBar.db.profile

local LSM = LibStub("LibSharedMedia-3.0")

local presets = {
    ["1"] = {
        normal = {
            enable = true,
            color = { 0.0, 0.0, 0.0, 0.7 },
            texture = "1 Pixel",
            thickness = 2,
            offset = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            }
        },
        animated = {
            enable = true,
            colorvf = { 0.7, 0.0, 1.0, 0.65 },
            colorstm = { 1, 0.0, 0.0, 0.65 },
            texture = "Vilinka's Insanity Glow",
            animatedontop = false,
            offset = {
                thickness = 6,
                left = 8,
                right = 8,
                top = 8,
                bottom = 8,
            }
        },
    },
    ["2"] = {
        normal = {
            enable = true,
            color = { 1, 1, 1, 1 },
            texture = "Blizzard Dialog",
            thickness = 14,
            offset = {
                left = -9,
                right = -9,
                top = -9,
                bottom = -9,
            },
        },
        animated = {
            enable = true,
            colorvf = { 0.7, 0.0, 1.0, 0.70 },
            colorstm = { 1, 0.0, 0.0, 0.70 },
            texture = "Vilinka's Insanity Glow",
            animatedontop = false,
            offset = {
                thickness = -4,
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
        },
    },
    ["3"] = {
        normal = {
            enable = true,
            color = { 0.62, 0.62, 0.62, 1 },
            texture = "Blizzard Tooltip",
            thickness = 14,
            offset = {
                left = -11,
                right = -11,
                top = -11,
                bottom = -11,
            },
        },
        animated = {
            enable = true,
            colorvf = { 0.7, 0.0, 1.0, 0.70 },
            colorstm = { 1, 0.0, 0.0, 0.70 },
            texture = "Vilinka's Insanity Glow",
            animatedontop = false,
            offset = {
                thickness = -4,
                left = -4,
                right = -4,
                top = -4,
                bottom = -4,
            },
        },
    },
}

function clone (t) -- deep-copy a table
    if type(t) ~= "table" then return t end
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = clone(v)
        else
            target[k] = v
        end
    end
    return target
end

local function SetPreset(presetKey)
    local preset = presets[presetKey]
    db.general.border = clone(preset)
end

addon.optionsTable.args.general = {
    type = "group",
    childGroups = "tab",
    name = "General",
    order = 1,
    get = function(info) return db.general[info[#info]] end,
    set = function(info, value) 
        db.general[info[#info]] = value
        VilinkasInsanityBar:UpdateSettings()
    end,
    args = {
        general = {
            type = "group",
            name = "General",
            order = 3,
            args = {
                header1 = {
                    type = "header",
                    name = "Position",
                    order = 1,
                },
                x = {
                    type = "range",
                    name = "X",
                    order = 5,
                    softMin = -math.floor((UIParent:GetWidth() / 2) + 0.5),
                    softMax = math.floor((UIParent:GetWidth() / 2) + 0.5),
                    step = 1,
                },
                y = {
                    type = "range",
                    name = "Y",
                    order = 5,
                    softMin = -math.floor((UIParent:GetHeight() / 2) + 0.5),
                    softMax = math.floor((UIParent:GetHeight() / 2)  + 0.5),
                    step = 1,
                },
                header2 = {
                    type = "header",
                    name = "Size",
                    order = 6,
                },
                width = {
                    type = "range",
                    name = "Width",
                    order = 7,
                    min=1,
                    softMin = 10,
                    softMax = 500,
                    step = 1,
                },
                height = {
                    type = "range",
                    name = "Height",
                    order = 7,
                    min=1,
                    softMin = 10,
                    softMax = 500,
                    step = 1,
                },
                header3 = {
                    type = "header",
                    name = "Out of combat",
                    order = 8,
                },
                oocalpha = {
                    type = "range",
                    name = "Opacity out of combat",
                    order = 9,
                    min = 0,
                    max = 1,
                    step = 0.01,
                    isPercent = true,
                },
            },
        },
        background = {
            type = "group",
            name = "Background",
            order = 10,
            get = function(info) return db.general.background[info[#info]] end,
            set = function(info, value) db.general.background[info[#info]] = value; VilinkasInsanityBar:UpdateSettings() end,
            args = {
                header = {
                    type = "header",
                    name = "Background",
                    order = 1,
                },
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable background.",
                    width = "full",
                    order = 2,
                },
                color = {
                    type = "color",
                    name = "Color",
                    order = 3,
                    hasAlpha = true,
                    get = function(info) 
                        return unpack(db.general.background[info[#info]])
                    end,
                    set = function(info, r, g, b, a) 
                        db.general.background[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.general.background.enable
                    end,
                },
                texture = {
                    type = "select",
                    dialogControl = 'LSM30_Background',
                    name = "Texture",
                    order = 4,
                    values = LSM:HashTable("background"),
                    disabled = function() 
                        return not db.general.background.enable
                    end,
                },
            },
        },
        border = {
            type = "group",
            name = "Border",
            order = 20,
            get = function(info)
                local category, option = string.split(".", info.arg)
                return db.general.border[category][option]
            end,
            set = function(info, value)
                local category, option = string.split(".", info.arg)
                db.general.border[category][option] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header = {
                    type = "header",
                    name = "Border",
                    order = 1,
                },
                presets = {
                    type = 'select',
                    name = "Presets",
                    order = 2,
                    values = { 
                        ["1"] = "Preset 1",
                        ["2"] = "Preset 2",
                        ["3"] = "Preset 3",
                    },
                    confirm = function()
                        return "Selecting a preset will override your current settings!"
                    end,
                    get = function(info)
                        return nil
                    end,
                    set = function(info, value)
                        SetPreset(value)
                        VilinkasInsanityBar:UpdateSettings()
                        addon:ReloadWindow()
                    end,
                },
                normalHeader = {
                    type = "header",
                    name = "Normal border",
                    order = 3,
                },
                normalEnable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable border.",
                    width = "full",
                    order = 4,
                    arg = "normal.enable"
                },
                normalColor = {
                    type = "color",
                    name = "Color",
                    order = 5,
                    hasAlpha = true,
                    arg = "normal.color",
                    get = function(info)
                        local category, option = string.split(".", info.arg)
                        return unpack(db.general.border[category][option])
                    end,
                    set = function(info, r, g, b, a)
                        local category, option = string.split(".", info.arg)
                        db.general.border[category][option] = {r, g, b, a}
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.general.border.normal.enable
                    end,
                },
                normalTexture = {
                    type = "select",
                    dialogControl = 'LSM30_Border',
                    name = "Texture",
                    order = 6,
                    values = LSM:HashTable("border"),
                    disabled = function() 
                        return not db.general.border.normal.enable
                    end,
                    arg = "normal.texture"
                },
                normalThickness = {
                    type = "range",
                    name = "Global thickness",
                    order = 7,
                    min = 1,
                    softMax = 15,
                    step = 1,
                    disabled = function() 
                        return not db.general.border.normal.enable
                    end,
                    arg = "normal.thickness",
                },
                normalAdvanced = {
					order = 8,
                    type = 'group',
                    name = "Advanced",
                    guiInline = true,
                    get = function(info) return db.general.border.normal.offset[info[#info]] end,
                    set = function(info, value) 
                        db.general.border.normal.offset[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.general.border.normal.enable
                    end,
                    args = {
                        left = {
                            type = "range",
                            name = "Offset left",
                            order = 1,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        right = {
                            type = "range",
                            name = "Offset right",
                            order = 2,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        top = {
                            type = "range",
                            name = "Offset top",
                            order = 3,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        bottom = {
                            type = "range",
                            name = "Offset bottom",
                            order = 4,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                    },
                },
                animatedHeader = {
                    type = "header",
                    name = "Animated border",
                    order = 9,
                },
                animatedEnable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable border.",
                    width = "full",
                    order = 10,
                    arg = "animated.enable",
                },
                display = {
                    type = "execute",
                    name = "Display border",
                    order = 11,
                    func = function()
                        local alpha =  VilinkasInsanityBar.AnimatedBorderFrame:GetAlpha()
                        if (alpha < 0.1) then
                            alpha = db.general.border.animated.colorstm[4]
                            VilinkasInsanityBar.AnimatedBorderFrame:SetAlpha(alpha)
                        else
                            VilinkasInsanityBar.AnimatedBorderFrame:SetAlpha(0)
                        end
                    end,
                    disabled = function() 
                        return not db.general.border.animated.enable
                    end,
                },
                animatedColorvf = {
                    type = "color",
                    name = "Voidform ready",
                    desc = "To hide the border set opacity to zero.",
                    width = "full",
                    order = 12,
                    hasAlpha = true,
                    arg = "animated.colorvf",
                    get = function(info)
                        local category, option = string.split(".", info.arg)
                        return unpack(db.general.border[category][option])
                    end,
                    set = function(info, r, g, b, a)
                        local category, option = string.split(".", info.arg)
                        db.general.border[category][option] = {r, g, b, a}
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.general.border.animated.enable
                    end,
                },
                animatedColorstm = {
                    type = "color",
                    name = "Surrender to maddness debuff.",
                    desc = "To hide the border set opacity to zero.",
                    order = 13,
                    hasAlpha = true,
                    arg = "animated.colorstm",
                    get = function(info)
                        local category, option = string.split(".", info.arg)
                        return unpack(db.general.border[category][option])
                    end,
                    set = function(info, r, g, b, a)
                        local category, option = string.split(".", info.arg)
                        db.general.border[category][option] = {r, g, b, a}
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.general.border.animated.enable
                    end,
                },
                animatedTexture = {
                    type = "select",
                    dialogControl = 'LSM30_Border',
                    name = "Texture",
                    order = 14,
                    values = LSM:HashTable("border"),
                    arg = "animated.texture",
                    disabled = function() 
                        return not db.general.border.animated.enable
                    end,
                },
                animatedAdvanced = {
                    order = 15,
                    type = 'group',
                    name = "Advanced",
                    guiInline = true,
                    get = function(info) return db.general.border.animated.offset[info[#info]] end,
                    set = function(info, value)
                        db.general.border.animated.offset[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.general.border.animated.enable
                    end,
                    args = {
                        animatedontop = {
                            type = "toggle",
                            name = "Display above normal border",
                            desc = "Selecting this will force animated border to be displayed on top of normal border.",
                            order = 1,
                            get = function(info) return db.general.border.animated[info[#info]] end,
                            set = function(info, value)
                                db.general.border.animated[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                        },
                        thickness = {
                            type = "range",
                            name = "Global thickness offset",
                            order = 2,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        spacer = {
                            type = "description",
                            name = "",
                            order = 3,
                        },
                        left = {
                            type = "range",
                            name = "Offset left",
                            order = 4,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        right = {
                            type = "range",
                            name = "Offset right",
                            order = 5,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        top = {
                            type = "range",
                            name = "Offset top",
                            order = 6,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                        bottom = {
                            type = "range",
                            name = "Offset bottom",
                            order = 7,
                            softMin = -15,
                            softMax = 15,
                            step = 1,
                        },
                    },
                },
            },
        },
    },
}