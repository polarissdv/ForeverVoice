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

local function ChannelTypes()
    return Enum and Enum.ChatChannelType or {}
end

-- Short label for the window
function Voice.ChannelLabel(channel)
    local L, types = ns.L, ChannelTypes()
    if channel.channelType == types.Communities then return L.CHANNEL_GUILD end
    if channel.channelType == types.Private_Party then return L.CHANNEL_PARTY end
    if channel.channelType == types.Public_Party then return L.CHANNEL_INSTANCE end
    return channel.name or L.CHANNEL_OTHER
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

-- Joins guild voice when possible, else the group's. Returns the label of
-- what it tried to join, or nil.
function Voice.Join()
    if not Voice.Available() then return nil end
    if not Voice.IsConnected() and VC.Login then Call("Login") end

    local clubId, streamId = GuildStream()
    if clubId then
        local channel = Call("GetChannelForCommunityStream", clubId, streamId)
        if channel then
            Call("ActivateChannel", channel.channelID)
        else
            Call("RequestJoinAndActivateCommunityStreamChannel", clubId, streamId)
        end
        return ns.L.CHANNEL_GUILD
    end

    if IsInGroup() then
        local types = ChannelTypes()
        local kind = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and types.Public_Party or types.Private_Party
        local channel = kind and Call("GetChannelForChannelType", kind)
        if channel then
            Call("ActivateChannel", channel.channelID)
        elseif kind then
            Call("RequestJoinChannelByChannelType", kind, nil, true)
        end
        return ns.L.CHANNEL_PARTY
    end
    return nil
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

-- The member volume scale isn't documented the same way everywhere
-- (0-1 or 0-100): the first volume read tells which one this client uses.
local volumeScale
local function Scale(location)
    if volumeScale then return volumeScale end
    local current = Call("GetMemberVolume", location)
    if type(current) == "number" then
        volumeScale = current > 1.01 and 100 or 1
    end
    return volumeScale or 1
end
function Voice.GetScale() return volumeScale end

-- volume: 0 to 1. Only the volume is changed, never the Blizzard mute:
-- the client may remember a mute, and nobody should stay muted if the
-- addon is removed.
function Voice.SetMemberVolume(guid, volume)
    local location = Location(guid)
    if not location then return end
    Call("SetMemberVolume", location, volume * Scale(location))
end
