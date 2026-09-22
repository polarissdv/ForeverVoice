local ADDON_NAME, ns = ...

-- =========================================================
-- VOICE: thin layer over Blizzard's C_VoiceChat
-- =========================================================
-- Every call is protected: the Forever client is a beta and some voice
-- functions may be missing or behave differently from Retail.
local Voice = {}
ns.Voice = Voice

local VC = C_VoiceChat

local function Call(fn, ...)
    if not VC or not VC[fn] then return nil end
    local ok, a, b, c = pcall(VC[fn], ...)
    if ok then return a, b, c end
    return nil
end
Voice.Call = Call

function Voice.Available()
    return VC ~= nil and VC.SetMemberVolume ~= nil
end

function Voice.IsConnected()
    if VC and VC.IsLoggedIn then return Call("IsLoggedIn") end
    return Voice.GetActiveChannel() ~= nil
end

-- ---------------------------------------------------------
-- Channels
-- ---------------------------------------------------------
function Voice.GetActiveChannel()
    local id = Call("GetActiveChannelID")
    if not id then return nil end
    return Call("GetChannel", id)
end

-- Channel type values. Blizzard renamed them between clients
-- (Private_Party -> PrivateParty), so both names are read, with the
-- numbers they have always had as a last resort.
local function ChannelTypes()
    local enum = Enum and Enum.ChatChannelType or {}
    return {
        communities = enum.Communities or 4,
        privateParty = enum.PrivateParty or enum.Private_Party or 2,
        publicParty = enum.PublicParty or enum.Public_Party or 3,
    }
end

-- Short label for the window
function Voice.ChannelLabel(channel)
    local L, types = ns.L, ChannelTypes()
    if channel.channelType == types.communities then return L.CHANNEL_GUILD end
    if channel.channelType == types.privateParty then return L.CHANNEL_PARTY end
    if channel.channelType == types.publicParty then return L.CHANNEL_INSTANCE end
    return channel.name or L.CHANNEL_OTHER
end

-- For /fv debug: what this client calls each channel type
function Voice.DebugTypes(print)
    local parts = {}
    for name, value in pairs(Enum and Enum.ChatChannelType or {}) do
        tinsert(parts, name .. "=" .. tostring(value))
    end
    print("channel types: " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
    local types = ChannelTypes()
    local party = Call("GetChannelForChannelType", types.privateParty)
    local instance = Call("GetChannelForChannelType", types.publicParty)
    print(string.format("group channel: %s  ·  instance channel: %s",
        party and tostring(party.channelID) or "none", instance and tostring(instance.channelID) or "none"))
end

-- The guild's voice stream (club id, stream id), or nil
local function GuildStream()
    if not (C_Club and C_Club.GetGuildClubId and C_Club.GetStreams) then return nil end
    local ok, clubId = pcall(C_Club.GetGuildClubId)
    if not ok or not clubId then return nil end
    local okStreams, streams = pcall(C_Club.GetStreams, clubId)
    if not okStreams or not streams then return nil end
    local guildType = Enum and Enum.ClubStreamType and Enum.ClubStreamType.Guild
    for _, stream in ipairs(streams) do
        if stream.streamType == guildType then return clubId, stream.streamId end
    end
    return nil
end

-- "guild", "group" or nil for the active channel
function Voice.ChannelKind(channel)
    if not channel then return nil end
    local types = ChannelTypes()
    if channel.channelType == types.communities then return "guild" end
    if channel.channelType == types.privateParty or channel.channelType == types.publicParty then
        return "group"
    end
    return nil
end

local function JoinGuild()
    local clubId, streamId = GuildStream()
    if not clubId then return false end
    local channel = Call("GetChannelForCommunityStream", clubId, streamId)
    if channel then
        Call("ActivateChannel", channel.channelID)
    else
        Call("RequestJoinAndActivateCommunityStreamChannel", clubId, streamId)
    end
    return true
end

local function JoinGroup()
    if not IsInGroup() then return false end
    local types = ChannelTypes()
    local kind = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and types.publicParty or types.privateParty
    local channel = Call("GetChannelForChannelType", kind)
    if channel then
        -- Same as Blizzard's headset button
        Call("ActivateChannel", channel.channelID)
        -- Not active a moment later: ask the server to join and activate it
        C_Timer.After(2, function()
            if Call("GetActiveChannelID") ~= channel.channelID then
                Call("RequestJoinChannelByChannelType", kind, true)
            end
        end)
    else
        Call("RequestJoinChannelByChannelType", kind, true)
    end
    return true
end

-- mode: "guild", "group" or "auto" (guild when possible, else the group).
-- Returns the label of what it tried to join, or nil plus the reason
-- ("NO_GUILD", "NO_GROUP").
function Voice.Join(mode)
    if not Voice.Available() then return nil, "NO_VOICE" end
    if not Voice.IsConnected() and VC.Login then Call("Login") end
    mode = mode or "auto"

    if mode ~= "group" then
        if JoinGuild() then return ns.L.CHANNEL_GUILD end
        if mode == "guild" then return nil, "NO_GUILD" end
    end
    if JoinGroup() then return ns.L.CHANNEL_PARTY end
    return nil, "NO_GROUP"
end

-- Leaves the active channel. Returns its label, or nil when not in one.
function Voice.Leave()
    local channel = Voice.GetActiveChannel()
    if not channel then return nil end
    Call("DeactivateChannel", channel.channelID)
    Call("LeaveChannel", channel.channelID)
    return Voice.ChannelLabel(channel)
end

-- ---------------------------------------------------------
-- Members
-- ---------------------------------------------------------
-- { guid, memberID, isSpeaking, isActive } for everyone but me.
-- Second return: true when I'm speaking.
function Voice.GetMembers(channel)
    local list = {}
    if not channel or not channel.members then return list, false end
    local me = UnitGUID("player")
    local meSpeaking = false
    for _, member in ipairs(channel.members) do
        local guid = Call("GetMemberGUID", member.memberID, channel.channelID)
        if guid == me then
            meSpeaking = member.isSpeaking
        elseif guid then
            tinsert(list, {
                guid = guid,
                memberID = member.memberID,
                isSpeaking = member.isSpeaking,
                isActive = member.isActive,
            })
        end
    end
    return list, meSpeaking
end

-- Push-to-talk key as shown to the player, or nil. Second return: open mic.
function Voice.TalkKey()
    local modes = Enum and Enum.CommunicationMode
    local mode = Call("GetCommunicationMode")
    if modes and mode == modes.OpenMic then return nil, true end
    local keys = Call("GetPushToTalkBinding")
    if type(keys) ~= "table" or #keys == 0 then return nil, false end
    local names = {}
    for i, key in ipairs(keys) do
        names[i] = GetBindingText and GetBindingText(key) or key
    end
    return table.concat(names, "+"), false
end

local function Location(guid)
    if PlayerLocation and PlayerLocation.CreateFromGUID then
        return PlayerLocation:CreateFromGUID(guid)
    end
    if PlayerLocationMixin and CreateFromMixins then
        local location = CreateFromMixins(PlayerLocationMixin)
        location:SetGUID(guid)
        return location
    end
    return nil
end

-- Member volume goes from 0 to 100, like Blizzard's own slider in the
-- player menu. 100 is the top of that slider, louder than normal.
local VOLUME_SCALE = 100

-- volume: 0 to 1, where 1 is the top of Blizzard's slider. Only the
-- volume is changed, never the Blizzard mute: the client may remember a
-- mute, and nobody should stay muted if the addon is removed.
function Voice.SetMemberVolume(guid, volume)
    local location = Location(guid)
    if not location then return end
    Call("SetMemberVolume", location, volume * VOLUME_SCALE)
end

-- Raw value from the game, for /fv debug
function Voice.GetMemberVolume(guid)
    local location = Location(guid)
    return location and Call("GetMemberVolume", location)
end
