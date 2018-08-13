local name, addon = ...
local db = VilinkasInsanityBar.db.profile

local LSM = LibStub("LibSharedMedia-3.0")

addon.optionsTable.args.animations = {
    type = "group",
    childGroups = "tab",
    name = "Animations",
    order = 4,
    get = function(info) return db.animations[info[#info]] end,
    set = function(info, value) 
        db.animations[info[#info]] = value
        VilinkasInsanityBar:UpdateSettings()
    end,
    args = {
        ooc = {
            type ="group",
            name = "OOC",
            order = 1,
            get = function(info) return db.animations.ooc[info[#info]] end,
            set = function(info, value) 
                db.animations.ooc[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header1 = {
                    type = "header",
                    name = "Out of combat animation",
                    order = 1,
                },
                duration = {
                    type = "range",
                    name = "Duration",
                    order = 2,
                    min = 0,
                    softMax = 5,
                    step = 0.1,
                },
                startdelay = {
                    type = "range",
                    name = "Start delay",
                    order = 3,
                    min = 0,
                    softMax = 5,
                    step = 0.1,
                },
            },
        },
        animatedborder = {
            type ="group",
            name = "Border",
            order = 2,
            get = function(info) return db.animations.animatedborder[info[#info]] end,
            set = function(info, value) 
                db.animations.animatedborder[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header1 = {
                    type = "header",
                    name = "Animated border",
                    order = 1,
                },
                pulseduration = {
                    type = "range",
                    name = "Pulse duration",
                    order = 2,
                    min = 0,
                    softMax = 5,
                    step = 0.1,
                },
            },
        },
    },
}