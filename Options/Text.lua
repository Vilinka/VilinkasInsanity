local name, addon = ...
local db = VilinkasInsanityBar.db.profile

local LSM = LibStub("LibSharedMedia-3.0")

addon.optionsTable.args.text = {
    type = "group",
    childGroups = "tab",
    name = "Text",
    order = 3,
    get = function(info) return db.text[info[#info]] end,
    set = function(info, value) 
        db.text[info[#info]] = value
        VilinkasInsanityBar:UpdateSettings()
    end,
    args = {
        useMainText = {
            type = "toggle",
            name = "Main text settings for all.",
            desc = "Main text settings for all.",
            width = "full",
            order = 1,
        },
        main = {
            type ="group",
            name = "Main",
            order=2,
            get = function(info) return db.text.main[info[#info]] end,
            set = function(info, value) 
                db.text.main[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header1 = {
                    type = "header",
                    name = "Main text",
                    order = 1,
                },
                file = {
                    type = "select",
                    name = "Font",
                    dialogControl = 'LSM30_Font',
                    order = 2,
                    values = LSM:HashTable("font"),
                },
                flag = {
                    type = 'select',
                    name = "Outline",
                    order = 3,
                    values = { 
                        ["OUTLINE, MONOCHROME"] = "Monochrome Outline",
                        ["THICKOUTLINE, MONOCHROME"] = "Monochrome Thick Outline",
                        ["NONE"] = "None",
                        ["OUTLINE"] = "Outline",
                        ["THICKOUTLINE"] = "Thick Outline",
                    },
                },
                right = {
					order = 4,
                    type = 'group',
                    name = "Right text",
                    guiInline = true,
                    get = function(info) return db.text.main.right[info[#info]] end,
                    set = function(info, value) 
                        db.text.main.right[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable right text.",
                            width = "full",
                            order = 1,
                        },
                        file = {
                            type = "select",
                            name = "Font",
                            dialogControl = 'LSM30_Font',
                            order = 2,
                            values = LSM:HashTable("font"),
                            disabled = function() 
                                return (not db.text.main.right.enable) or db.text.useMainText
                            end,
                        },
                        flag = {
                            type = 'select',
                            name = "Outline",
                            order = 3,
                            values = { 
                                ["OUTLINE, MONOCHROME"] = "Monochrome Outline",
                                ["THICKOUTLINE, MONOCHROME"] = "Monochrome Thick Outline",
                                ["NONE"] = "None",
                                ["OUTLINE"] = "Outline",
                                ["THICKOUTLINE"] = "Thick Outline",
                            },
                            disabled = function() 
                                return (not db.text.main.right.enable) or db.text.useMainText
                            end,
                        },
                        size = {
                            type = "range",
                            name = "Size",
                            order = 4,
                            min = 1,
                            softMax = 20,
                            step = 1,
                            disabled = function() 
                                return not db.text.main.right.enable
                            end,
                        },
                        header1 = {
                            type = "header",
                            name = "Color",
                            order = 5,
                        },
                        colorinsanity = {
                            type = "color",
                            name = "Insanity",
                            order = 6,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.text.main.right[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.text.main.right[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.text.main.right.enable
                            end,
                        },
                        colorcast = {
                            type = "color",
                            name = "Cast gain",
                            order = 7,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.text.main.right[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.text.main.right[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.text.main.right.enable
                            end,
                        },
                        colorpassive = {
                            type = "color",
                            name = "Passive gain",
                            order = 8,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.text.main.right[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.text.main.right[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.text.main.right.enable
                            end,
                        },
                        header2 = {
                            type = "header",
                            name = "Offset",
                            order = 9,
                        },
                        right = {
                            type = "range",
                            name = "Right",
                            order = 10,
                            softMin = -10,
                            softMax = 10,
                            step = 1,
                            get = function(info) return db.text.main.right.offset[info[#info]] end,
                            set = function(info, value) 
                                db.text.main.right.offset[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function()
                                return not db.text.main.right.enable
                            end,
                        },
                        top = {
                            type = "range",
                            name = "Top",
                            order = 11,
                            softMin = -10,
                            softMax = 10,
                            step = 1,
                            get = function(info) return db.text.main.right.offset[info[#info]] end,
                            set = function(info, value) 
                                db.text.main.right.offset[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function()
                                return not db.text.main.right.enable
                            end,
                        },
                    },
                },
                center = {
					order = 5,
                    type = 'group',
                    name = "Center text",
                    guiInline = true,
                    get = function(info) return db.text.main.center[info[#info]] end,
                    set = function(info, value) 
                        db.text.main.center[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable center text.",
                            width = "full",
                            order = 1,
                        },
                        file = {
                            type = "select",
                            name = "Font",
                            dialogControl = 'LSM30_Font',
                            order = 2,
                            values = LSM:HashTable("font"),
                            disabled = function() 
                                return (not db.text.main.center.enable) or db.text.useMainText
                            end,
                        },
                        flag = {
                            type = 'select',
                            name = "Outline",
                            order = 3,
                            values = { 
                                ["OUTLINE, MONOCHROME"] = "Monochrome Outline",
                                ["THICKOUTLINE, MONOCHROME"] = "Monochrome Thick Outline",
                                ["NONE"] = "None",
                                ["OUTLINE"] = "Outline",
                                ["THICKOUTLINE"] = "Thick Outline",
                            },
                            disabled = function() 
                                return (not db.text.main.center.enable) or db.text.useMainText
                            end,
                        },
                        size = {
                            type = "range",
                            name = "Size",
                            order = 4,
                            min = 1,
                            softMax = 20,
                            step = 1,
                            disabled = function() 
                                return not db.text.main.center.enable
                            end,
                        },
                        header1 = {
                            type = "header",
                            name = "Color",
                            order = 5,
                        },
                        color = {
                            type = "color",
                            name = "Color",
                            order = 6,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.text.main.center[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.text.main.center[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.text.main.center.enable
                            end,
                        },
                        header2 = {
                            type = "header",
                            name = "Offset",
                            order = 9,
                        },
                        right = {
                            type = "range",
                            name = "Right",
                            order = 10,
                            softMin = -10,
                            softMax = 10,
                            step = 1,
                            get = function(info) return db.text.main.center.offset[info[#info]] end,
                            set = function(info, value) 
                                db.text.main.center.offset[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function()
                                return not db.text.main.center.enable
                            end,
                        },
                        top = {
                            type = "range",
                            name = "Top",
                            order = 11,
                            softMin = -10,
                            softMax = 10,
                            step = 1,
                            get = function(info) return db.text.main.center.offset[info[#info]] end,
                            set = function(info, value) 
                                db.text.main.center.offset[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function()
                                return not db.text.main.center.enable
                            end,
                        },
                    },
                },
                left = {
					order = 6,
                    type = 'group',
                    name = "Left text",
                    guiInline = true,
                    get = function(info) return db.text.main.left[info[#info]] end,
                    set = function(info, value) 
                        db.text.main.left[info[#info]] = value
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Enable left text.",
                            width = "full",
                            order = 1,
                        },
                        file = {
                            type = "select",
                            name = "Font",
                            dialogControl = 'LSM30_Font',
                            order = 2,
                            values = LSM:HashTable("font"),
                            disabled = function() 
                                return (not db.text.main.left.enable) or db.text.useMainText
                            end,
                        },
                        flag = {
                            type = 'select',
                            name = "Outline",
                            order = 3,
                            values = { 
                                ["OUTLINE, MONOCHROME"] = "Monochrome Outline",
                                ["THICKOUTLINE, MONOCHROME"] = "Monochrome Thick Outline",
                                ["NONE"] = "None",
                                ["OUTLINE"] = "Outline",
                                ["THICKOUTLINE"] = "Thick Outline",
                            },
                            disabled = function() 
                                return (not db.text.main.left.enable) or db.text.useMainText
                            end,
                        },
                        size = {
                            type = "range",
                            name = "Size",
                            order = 4,
                            min = 1,
                            softMax = 20,
                            step = 1,
                            disabled = function() 
                                return not db.text.main.left.enable
                            end,
                        },
                        header1 = {
                            type = "header",
                            name = "Color",
                            order = 5,
                        },
                        color = {
                            type = "color",
                            name = "Color",
                            order = 6,
                            hasAlpha = true,
                            get = function(info) 
                                return unpack(db.text.main.left[info[#info]])
                            end,
                            set = function(info, r, g, b, a) 
                                db.text.main.left[info[#info]] = { r, g, b, a }
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function() 
                                return not db.text.main.left.enable
                            end,
                        },
                        header2 = {
                            type = "header",
                            name = "Offset",
                            order = 9,
                        },
                        left = {
                            type = "range",
                            name = "Left",
                            order = 10,
                            softMin = -10,
                            softMax = 10,
                            step = 1,
                            get = function(info) return db.text.main.left.offset[info[#info]] end,
                            set = function(info, value) 
                                db.text.main.left.offset[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function()
                                return not db.text.main.left.enable
                            end,
                        },
                        top = {
                            type = "range",
                            name = "Top",
                            order = 11,
                            softMin = -10,
                            softMax = 10,
                            step = 1,
                            get = function(info) return db.text.main.left.offset[info[#info]] end,
                            set = function(info, value) 
                                db.text.main.left.offset[info[#info]] = value
                                VilinkasInsanityBar:UpdateSettings()
                            end,
                            disabled = function()
                                return not db.text.main.left.enable
                            end,
                        },
                    },
                },
            },
        },
        shadowfiend = {
            type ="group",
            name = "Shadowfiend",
            order=3,
            get = function(info) return db.text.shadowfiend[info[#info]] end,
            set = function(info, value) 
                db.text.shadowfiend[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header1 = {
                    type = "header",
                    name = "Shadowfiend text",
                    order = 1,
                },
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable shadowfiend text.",
                    width = "full",
                    order = 2,
                },
                file = {
                    type = "select",
                    name = "Font",
                    dialogControl = 'LSM30_Font',
                    order = 3,
                    values = LSM:HashTable("font"),
                    disabled = function() 
                        return (not db.text.shadowfiend.enable) or db.text.useMainText
                    end,
                },
                flag = {
                    type = 'select',
                    name = "Outline",
                    order = 4,
                    values = { 
                        ["OUTLINE, MONOCHROME"] = "Monochrome Outline",
                        ["THICKOUTLINE, MONOCHROME"] = "Monochrome Thick Outline",
                        ["NONE"] = "None",
                        ["OUTLINE"] = "Outline",
                        ["THICKOUTLINE"] = "Thick Outline",
                    },
                    disabled = function() 
                        return (not db.text.shadowfiend.enable) or db.text.useMainText
                    end,
                },
                size = {
                    type = "range",
                    name = "Size",
                    order = 5,
                    min = 1,
                    softMax = 20,
                    step = 1,
                    disabled = function() 
                        return not db.text.shadowfiend.enable
                    end,
                },
                color = {
                    type = "color",
                    name = "Color",
                    order = 6,
                    hasAlpha = true,
                    get = function(info) 
                        return unpack(db.text.shadowfiend[info[#info]])
                    end,
                    set = function(info, r, g, b, a) 
                        db.text.shadowfiend[info[#info]] = { r, g, b, a }
                        VilinkasInsanityBar:UpdateSettings()
                    end,
                    disabled = function() 
                        return not db.text.shadowfiend.enable
                    end,
                },
            },
        },
    },
}