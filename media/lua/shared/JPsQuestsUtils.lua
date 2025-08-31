JPsQuestsUtils = JPsQuestsUtils or {}

function JPsQuestsUtils:timer(minutes, cb)
    local count = 0
    local function cbfunc()
        count = count + 1
        if (count >= minutes) then
            Events.EveryOneMinute.Remove(cbfunc)
            cb()
        end
    end
    Events.EveryOneMinute.Add(cbfunc)
end