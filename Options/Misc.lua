local name, addon = ...
local db = VilinkasInsanityBar.db.profile

local LSM = LibStub("LibSharedMedia-3.0")

addon.optionsTable.args.misc = {
    type = "group",
    childGroups = "tab",
    name = "Misc",
    order = 5,
    get = function(info) return db.misc[info[#info]] end,
    set = function(info, value) 
        db.misc[info[#info]] = value
        VilinkasInsanityBar:UpdateSettings()
    end,
    args = {
        voidfromreports = {
            type ="group",
            name = "Reports",
            order = 1,
            get = function(info) return db.misc.voidfromreports[info[#info]] end,
            set = function(info, value) 
                db.misc.voidfromreports[info[#info]] = value
                VilinkasInsanityBar:UpdateSettings()
            end,
            args = {
                header = {
                    type = "header",
                    name = "Voidform reports",
                    order = 1,
                },
                description = {
                    type = "description",
                    name = "At the end of voidform optionally display and save a report. To access saved reports use command |cFF9370DB/vilins vf|r.",
                    order = 2,
                },
                enable = {
                    type = 'select',
                    name = "Dispaly options",
                    order = 3,
                    values = {
                        [0] = "Disable",
                        [1] = "Display only STM",
                        [2] = "Always display",
                    },
                },
                save = {
                    type = 'select',
                    name = "Save options",
                    order = 4,
                    values = {
                        [0] = "Disable",
                        [1] = "Save only STM",
                        [2] = "Always save",
                    },
                },
                maxsaved = {
                    type = 'range',
                    name = "Maximum number of saved reports",
                    order = 5,
                    --width = "full",
                    min = 1,
                    max = 7,
                    step = 1,
                },
                clear = {
                    type = "execute",
                    name = "Clear saved reports",
                    order = 6,
                    func = function() VilinkasInsanityBar:ClearSavedVfReps() end,
                },
            },
        },
    },
}