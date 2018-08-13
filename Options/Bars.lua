local name, addon = ...
local db = VilinkasInsanityBar.db.profile

local LSM = LibStub("LibSharedMedia-3.0")

addon.optionsTable.args.bars = {
    type = "group",
    childGroups = "tab",
    name = "Bars",
    order = 2,
    get = function(info) return db.bars[info[#info]] end,
    set = function(info, value) 
        db.bars[info[#info]] = value
        VilinkasInsanityBar:UpdateSettings()
    end,
    args = {
        useMainTexture = {
            type = "toggle",
            name = "Use main bar texture for all bars.",
            desc = "Use main bar texture for all bars.",
            width = "full",
            order = 1,
        },
        main = {
            type ="group",
            name = "Main",
            order=2,
            get = function(info) return db.bars.main[info[#info]] end,
            set = function(info, value) 
                db.bars.main[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header1 = {
                    type = "header",
                    name = "Main bar",
                    order = 1,
                },
                color = {
                    type = "color",
                    name = "Color",
                    order = 2,
                    hasAlpha = true,
                    get = function(info) 
                        return unpack(db.bars.main[info[#info]])
                    end,
                    set = function(info, r, g, b, a) 
                        db.bars.main[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                },
                texture = {
                    type = "select",
                    dialogControl = 'LSM30_Statusbar',
                    name = "Texture",
                    order = 3,
                    values = LSM:HashTable("statusbar")
                },
                header2 = {
                    type = "header",
                    name = "Insanity gain",
                    order = 4,
                },
                castcolor = {
                    type = "color",
                    name = "Casting",
                    order = 5,
                    hasAlpha = true,
                    get = function(info)
                        return unpack(db.bars.main[info[#info]])
                    end,
                    set = function(info, r, g, b, a)
                        db.bars.main[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                },
                passivecolor = {
                    type = "color",
                    name = "Passive",
                    order = 6,
                    hasAlpha = true,
                    get = function(info)
                        return unpack(db.bars.main[info[#info]])
                    end,
                    set = function(info, r, g, b, a)
                        db.bars.main[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                },
                voidformthreshold = {
					order = 7,
                    type = 'group',
                    name = "Voidform threshold",
                    guiInline = true,
                    get = function(info) return db.bars.main.voidformthreshold[info[#info]] end,
                    set = function(info, value) 
                        db.bars.main.voidformthreshold[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable voidform threshold.",
                            width = "full",
                            order = 1,
                        },
                        color = {
                            type = "color",
                            name = "Color",
                            order = 2,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.bars.main.voidformthreshold[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.bars.main.voidformthreshold[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.bars.main.voidformthreshold.enable
                            end,
                        },
                        thickness = {
                            type = "range",
                            name = "Thickness",
                            order = 3,
                            min = 1,
                            softMax = 5,
                            step = 1,
                            disabled = function() 
                                return not db.bars.main.voidformthreshold.enable
                            end,
                        },
                        override = {
                            type = "range",
                            name = "Override",
                            desc = "Override mark position.",
                            order = 4,
                            min = 60,
                            softMax = 100,
                            step = 1,
                            disabled = function() 
                                return not db.bars.main.voidformthreshold.enable
                            end,
                        },
                        hideinvoidfrom = {
                            type = "toggle",
                            name = "Hide in voidform",
                            desc = "Hide mark when in voidform.",
                            width = "full",
                            order = 5,
                        },
                    },
                },
            },
        },
        gcd = {
            type ="group",
            name = "GCD",
            order=3,
            get = function(info) return db.bars.gcd[info[#info]] end,
            set = function(info, value) 
                db.bars.gcd[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header = {
                    type = "header",
                    name = "GCD bar",
                    order = 1,
                },
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable GCD bar.",
                    width = "full",
                    order = 2,
                },
                color = {
                    type = "color",
                    name = "Color",
                    order = 3,
                    hasAlpha = true,
                    get = function(info)
                        return unpack(db.bars.gcd[info[#info]])
                    end,
                    set = function(info, r, g, b, a)
                        db.bars.gcd[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.gcd.enable
                    end,
                },
                texture = {
                    type = "select",
                    dialogControl = 'LSM30_Statusbar',
                    name = "Texture",
                    order = 4,
                    values = LSM:HashTable("statusbar"),
                    disabled = function() 
                        return not db.bars.gcd.enable
                    end,
                },
                background = {
					order = 5,
                    type = 'group',
                    name = "Background",
                    guiInline = true,
                    get = function(info) return db.bars.gcd.background[info[#info]] end,
                    set = function(info, value)
                        db.bars.gcd.background[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.gcd.enable
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable background.",
                            width = "full",
                            order = 1,
                        },
                        color = {
                            type = "color",
                            name = "Color",
                            order = 2,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.bars.gcd.background[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.bars.gcd.background[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return (not db.bars.gcd.background.enable) or (not db.bars.gcd.enable)
                            end,
                        },
                        texture = {
                            type = "select",
                            dialogControl = 'LSM30_Background',
                            name = "Texture",
                            order = 3,
                            values = LSM:HashTable("background"),
                            disabled = function()
                                return (not db.bars.gcd.background.enable) or (not db.bars.gcd.enable)
                            end,
                        },
                    },
                },
            },
        },
        mana = {
            type ="group",
            name = "Mana",
            order=4,
            get = function(info) return db.bars.mana[info[#info]] end,
            set = function(info, value) 
                db.bars.mana[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header = {
                    type = "header",
                    name = "Mana bar",
                    order = 1,
                },
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable Mana bar.",
                    width = "full",
                    order = 2,
                },
                color = {
                    type = "color",
                    name = "Color",
                    order = 3,
                    hasAlpha = true,
                    get = function(info) 
                        return unpack(db.bars.mana[info[#info]])
                    end,
                    set = function(info, r, g, b, a) 
                        db.bars.mana[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.mana.enable
                    end,
                },
                texture = {
                    type = "select",
                    dialogControl = 'LSM30_Statusbar',
                    name = "Texture",
                    order = 4,
                    values = LSM:HashTable("statusbar"),
                    disabled = function() 
                        return not db.bars.mana.enable
                    end,
                },
                threshold = {
                    type = "range",
                    name = "Display threshold",
                    order = 5,
                    min = 0,
                    max = 1,
                    step = 0.1,
                    disabled = function() 
                        return not db.bars.mana.enable
                    end,
                },
                background = {
					order = 6,
                    type = 'group',
                    name = "Background",
                    guiInline = true,
                    get = function(info) return db.bars.mana.background[info[#info]] end,
                    set = function(info, value) 
                        db.bars.mana.background[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.mana.enable
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable background.",
                            width = "full",
                            order = 1,
                        },
                        color = {
                            type = "color",
                            name = "Color",
                            order = 2,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.bars.mana.background[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.bars.mana.background[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return (not db.bars.mana.background.enable) or (not db.bars.mana.enable)
                            end,
                        },
                        texture = {
                            type = "select",
                            dialogControl = 'LSM30_Background',
                            name = "Texture",
                            order = 3,
                            values = LSM:HashTable("background"),
                            disabled = function() 
                                return (not db.bars.mana.background.enable) or (not db.bars.mana.enable)
                            end,
                        },
                    },
                },
            },
        },
        shadowfiend = {
            type ="group",
            name = "Shadowfiend",
            order=5,
            get = function(info) return db.bars.shadowfiend[info[#info]] end,
            set = function(info, value) 
                db.bars.shadowfiend[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header = {
                    type = "header",
                    name = "Shadowfiend bar",
                    order = 1,
                },
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable Shadowfiend bar.",
                    width = "full",
                    order = 2,
                },
                color = {
                    type = "color",
                    name = "Color",
                    order = 3,
                    hasAlpha = true,
                    get = function(info) 
                        return unpack(db.bars.shadowfiend[info[#info]])
                    end,
                    set = function(info, r, g, b, a) 
                        db.bars.shadowfiend[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.shadowfiend.enable
                    end,
                },
                texture = {
                    type = "select",
                    dialogControl = 'LSM30_Statusbar',
                    name = "Texture",
                    order = 4,
                    values = LSM:HashTable("statusbar")
                },
                background = {
					order = 5,
                    type = 'group',
                    name = "Background",
                    guiInline = true,
                    get = function(info) return db.bars.shadowfiend.background[info[#info]] end,
                    set = function(info, value) 
                        db.bars.shadowfiend.background[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.shadowfiend.enable
                    end,
                    args = {
                        color = {
                            type = "color",
                            name = "Color",
                            order = 1,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.bars.shadowfiend.background[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.bars.shadowfiend.background[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                        },
                        texture = {
                            type = "select",
                            dialogControl = 'LSM30_Background',
                            name = "Texture",
                            order = 2,
                            values = LSM:HashTable("background")
                        },
                    },
                },
                nextattack = {
					order = 6,
                    type = 'group',
                    name = "Next attack mark",
                    guiInline = true,
                    get = function(info) return db.bars.shadowfiend.nextattack[info[#info]] end,
                    set = function(info, value) 
                        db.bars.shadowfiend.nextattack[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.bars.shadowfiend.enable
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable next attack mark.",
                            width = "full",
                            order = 1,
                        },
                        color = {
                            type = "color",
                            name = "Color",
                            order = 2,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.bars.shadowfiend.nextattack[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.bars.shadowfiend.nextattack[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.bars.shadowfiend.nextattack.enable
                            end,
                        },
                        thickness = {
                            type = "range",
                            name = "Thickness",
                            order = 3,
                            min = 1,
                            softMax = 5,
                            step = 1,
                            disabled = function() 
                                return not db.bars.shadowfiend.nextattack.enable
                            end,
                        },
                    },
                },
            },
        },
    },
}