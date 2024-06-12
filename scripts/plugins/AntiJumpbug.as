float g_flVelocityToStartJumpbugCheckingAt = 580.f; //the velocity we start to check the player for jumpbug
float g_flMaxSafeForPlayerFallVelocity = 1024.f; //IIRC it's the fall velocity at which player dies outta fall damage, ain't sure tho
const Cvar@ g_pFallDamageConVar = null;

bool g_bEnableSvenInternalSpecificHeuristic = false; //Enable a specific heuristic of sven_internal hack where the hack automatically holds +duck at 500 fall velocity (can be easily bypassed by manually holding +duck or with fakelag)

string g_pszPlayerFallSound = "player/pl_fallpain3.wav"; //Player fall sound. Can be changed to something strange to make jumpbug hackers emit funny sound. Don't forget to precache that in MapInit if you change the sound!

class CPlayerData {
    float m_flPreviousFrameFallVelo;
    bool m_bHasDuckedOnceReachedFiveHundredFallVelo;
    int m_afPreviousFrameButtons;
    float m_flPreviousFrameHealthVal;
    bool m_bJumpbugSpecificButtonsWerePressed;
    bool m_bJumpbugSpecificButtonsWerePressed2;
    float m_flPreviousFrameZVelo;
    bool m_bHasJumpedOffSomethingMidAir;
    
    bool m_bWasntOnGroundPreviousFramePreThink;
    bool m_bWasntOnGroundPreviousFramePostPreThink;
    bool m_bWasntOnGroundPreviousFramePostThink;
    bool m_bWasntOnGroundPreviousFrameWatchdog;
    
    bool m_bHasReceivedOnGroundFlagInPreThink;
    bool m_bHasReceivedOnGroundFlagInPostPreThink;
    bool m_bHasReceivedOnGroundFlagInPostThink;
    bool m_bHasReceivedOnGroundFlagInWatchdog;
    
    CPlayerData() {
        m_flPreviousFrameFallVelo = -1.f;
        m_bHasDuckedOnceReachedFiveHundredFallVelo = false;
        m_afPreviousFrameButtons = 0;
        m_flPreviousFrameHealthVal = -1.f;
        m_bJumpbugSpecificButtonsWerePressed = false;
        m_bJumpbugSpecificButtonsWerePressed2 = false;
        m_flPreviousFrameZVelo = -1.f;
        m_bHasJumpedOffSomethingMidAir = false;
        m_bHasReceivedOnGroundFlagInPreThink = false;
        m_bHasReceivedOnGroundFlagInPostPreThink = false;
        m_bHasReceivedOnGroundFlagInPostThink = false;
        m_bHasReceivedOnGroundFlagInWatchdog = false;
        m_bWasntOnGroundPreviousFramePreThink = false;
        m_bWasntOnGroundPreviousFramePostPreThink = false;
        m_bWasntOnGroundPreviousFramePostThink = false;
        m_bWasntOnGroundPreviousFrameWatchdog = false;
    }
}

array<CPlayerData@> g_apPlayerData;
array<CScheduledFunction@> g_rgpfnPostPreThinkScheds;
array<CScheduledFunction@> g_rgpfnPostPostThinkScheds;
array<CScheduledFunction@> g_rgpfnWatchdogScheds;

void PluginInit() {
    g_Module.ScriptInfo.SetAuthor("xWhitey");
    g_Module.ScriptInfo.SetContactInfo("@tyabus at Discord");
    
    g_apPlayerData.resize(0);
    g_apPlayerData.resize(33);
    g_rgpfnPostPreThinkScheds.resize(0);
    g_rgpfnPostPreThinkScheds.resize(33);
    g_rgpfnPostPostThinkScheds.resize(0);
    g_rgpfnPostPostThinkScheds.resize(33);
    g_rgpfnWatchdogScheds.resize(0);
    g_rgpfnWatchdogScheds.resize(33);
    
    g_Hooks.RegisterHook(Hooks::Player::PlayerPreThink, @HOOKED_PlayerPreThink);
    g_Hooks.RegisterHook(Hooks::Player::PlayerPostThink, @HOOKED_PlayerPostThink);
}

void MapInit() {
    g_apPlayerData.resize(0);
    g_apPlayerData.resize(33);
    for (uint idx = 0; idx < g_rgpfnPostPreThinkScheds.length(); idx++) {
        CScheduledFunction@ pfnSched = @g_rgpfnPostPreThinkScheds[idx];
        if (pfnSched !is null && !pfnSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pfnSched);
        }
    }
    for (uint idx = 0; idx < g_rgpfnPostPostThinkScheds.length(); idx++) {
        CScheduledFunction@ pfnSched = @g_rgpfnPostPostThinkScheds[idx];
        if (pfnSched !is null && !pfnSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pfnSched);
        }
    }
    for (uint idx = 0; idx < g_rgpfnWatchdogScheds.length(); idx++) {
        CScheduledFunction@ pfnSched = @g_rgpfnWatchdogScheds[idx];
        if (pfnSched !is null && !pfnSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pfnSched);
        }
    }
    
    if (g_pFallDamageConVar is null) {
        @g_pFallDamageConVar = g_EngineFuncs.CVarGetPointer("mp_falldamage");
    }
    
    g_rgpfnPostPreThinkScheds.resize(0);
    g_rgpfnPostPreThinkScheds.resize(33);
    g_rgpfnPostPostThinkScheds.resize(0);
    g_rgpfnPostPostThinkScheds.resize(33);
    g_rgpfnWatchdogScheds.resize(0);
    g_rgpfnWatchdogScheds.resize(33);
    
    for (uint idx = 1; idx < g_rgpfnWatchdogScheds.length(); idx++) {
        @g_rgpfnWatchdogScheds[idx] = g_Scheduler.SetTimeout("Watchdog", 0.1f, idx);
    }
}

void Watchdog(int _PlayerIdx) {
    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(_PlayerIdx);
    if (pPlayer is null) {
        @g_rgpfnWatchdogScheds[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    CPlayerData@ pData = @g_apPlayerData[_PlayerIdx];
    if (pData is null) {
        @g_rgpfnWatchdogScheds[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    if (!pData.m_bHasDuckedOnceReachedFiveHundredFallVelo && g_bEnableSvenInternalSpecificHeuristic) {
        @g_rgpfnWatchdogScheds[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    if (!pData.m_bWasntOnGroundPreviousFrameWatchdog && (pPlayer.pev.flags & FL_ONGROUND) == 0) {
        pData.m_bWasntOnGroundPreviousFrameWatchdog = true;
        pData.m_bHasReceivedOnGroundFlagInWatchdog = false;
    }
    if (pData.m_bWasntOnGroundPreviousFrameWatchdog && (pPlayer.pev.flags & FL_ONGROUND) != 0) {
        pData.m_bHasReceivedOnGroundFlagInWatchdog = true;
        pData.m_bWasntOnGroundPreviousFrameWatchdog = false;
    }
}

HookReturnCode HOOKED_PlayerPreThink(CBasePlayer@ _Player, uint& out _Flags) {
    int nPlayerIdx = _Player.entindex();
    CPlayerData@ pData = @g_apPlayerData[nPlayerIdx];
    if (pData is null) {
        @pData = CPlayerData();
        @g_apPlayerData[nPlayerIdx] = @pData;
    }
    pData.m_bJumpbugSpecificButtonsWerePressed2 = ((pData.m_afPreviousFrameButtons ^ _Player.pev.button) & (IN_JUMP | IN_DUCK)) != 0;
    if (((pData.m_afPreviousFrameButtons & IN_DUCK) == 0 || (_Player.pev.oldbuttons & IN_DUCK) == 0) && (_Player.pev.button & IN_DUCK) != 0 && pData.m_flPreviousFrameFallVelo < 500.f && _Player.pev.flFallVelocity >= 500.f) {
        pData.m_bHasDuckedOnceReachedFiveHundredFallVelo = true;
    }
    if (!pData.m_bWasntOnGroundPreviousFramePreThink && (_Player.pev.flags & FL_ONGROUND) == 0) {
        pData.m_bWasntOnGroundPreviousFramePreThink = true;
        pData.m_bHasReceivedOnGroundFlagInPreThink = false;
        pData.m_bHasDuckedOnceReachedFiveHundredFallVelo = false;
    }
    if (pData.m_bWasntOnGroundPreviousFramePreThink && (_Player.pev.flags & FL_ONGROUND) != 0) {
        pData.m_bHasReceivedOnGroundFlagInPreThink = true;
        pData.m_bWasntOnGroundPreviousFramePreThink = false;
    }
    pData.m_flPreviousFrameHealthVal = _Player.pev.health;
    pData.m_afPreviousFrameButtons = _Player.pev.button;
    pData.m_flPreviousFrameFallVelo = _Player.pev.flFallVelocity;

    @g_rgpfnPostPreThinkScheds[nPlayerIdx] = g_Scheduler.SetTimeout("PostPlayerPreThink", 0.f, EHandle(_Player), nPlayerIdx, @pData);

    return HOOK_CONTINUE;
}

void PostPlayerPreThink(EHandle _Player, int _PlayerIndex, CPlayerData@ _Data) {
    if (!_Player.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Player.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    
    if (!_Data.m_bWasntOnGroundPreviousFramePostPreThink && (pPlayer.pev.flags & FL_ONGROUND) == 0) {
        _Data.m_bWasntOnGroundPreviousFramePostPreThink = true;
        _Data.m_bHasReceivedOnGroundFlagInPostPreThink = false;
    }
    if (_Data.m_bWasntOnGroundPreviousFramePostPreThink && (pPlayer.pev.flags & FL_ONGROUND) != 0) {
        _Data.m_bHasReceivedOnGroundFlagInPostPreThink = true;
        _Data.m_bWasntOnGroundPreviousFramePostPreThink = false;
    }
    
    _Data.m_bJumpbugSpecificButtonsWerePressed = ((pPlayer.pev.oldbuttons ^ pPlayer.pev.button) & (IN_JUMP | IN_DUCK)) != 0;
    _Data.m_flPreviousFrameZVelo = pPlayer.pev.velocity.z;
}

HookReturnCode HOOKED_PlayerPostThink(CBasePlayer@ _Player) {
    int nPlayerIdx = _Player.entindex();
    CPlayerData@ pData = @g_apPlayerData[nPlayerIdx];
    if (pData is null) {
        return HOOK_CONTINUE;
    }
    
    if (!pData.m_bWasntOnGroundPreviousFramePostThink && (_Player.pev.flags & FL_ONGROUND) == 0) {
        pData.m_bWasntOnGroundPreviousFramePostThink = true;
        pData.m_bHasReceivedOnGroundFlagInPostThink = false;
    }
    if (pData.m_bWasntOnGroundPreviousFramePostThink && (_Player.pev.flags & FL_ONGROUND) != 0) {
        pData.m_bHasReceivedOnGroundFlagInPostThink = true;
        pData.m_bWasntOnGroundPreviousFramePostThink = false;
    }
    
    pData.m_bHasJumpedOffSomethingMidAir = (pData.m_flPreviousFrameZVelo < (g_flVelocityToStartJumpbugCheckingAt * -1.f) && _Player.pev.velocity.z > 128.f /* jump velo */) && (!pData.m_bHasReceivedOnGroundFlagInPreThink && !pData.m_bHasReceivedOnGroundFlagInPostPreThink && !pData.m_bHasReceivedOnGroundFlagInPostThink);

    @g_rgpfnPostPostThinkScheds[nPlayerIdx] = g_Scheduler.SetTimeout("PostPlayerPostThink", 0.f, EHandle(_Player), nPlayerIdx, @pData);

    return HOOK_CONTINUE;
}

float fabsf(float _Value) {
    return _Value < 0.f ? (_Value * -1.f) : _Value;
}

void PostPlayerPostThink(EHandle _Player, int _PlayerIndex, CPlayerData@ _Data) {
    if (!_Player.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Player.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    
    bool bHasEscapedFallDamage = (pPlayer.pev.health == _Data.m_flPreviousFrameHealthVal) && (pPlayer.pev.waterlevel == WATERLEVEL_DRY) && (pPlayer.pev.takedamage != DAMAGE_NO) && (!_Data.m_bHasReceivedOnGroundFlagInWatchdog /* player's last resort? I'm unsure this actually does anything, lol */);
    bool bShouldCheckSvenInternalHeuristic = !g_bEnableSvenInternalSpecificHeuristic || _Data.m_bHasDuckedOnceReachedFiveHundredFallVelo;
    bool bJumpbugButtonsPressed = _Data.m_bJumpbugSpecificButtonsWerePressed || _Data.m_bJumpbugSpecificButtonsWerePressed2;
    if (bHasEscapedFallDamage && _Data.m_bHasJumpedOffSomethingMidAir && bShouldCheckSvenInternalHeuristic && bJumpbugButtonsPressed) {
        if (g_pFallDamageConVar.value == -1.f)
            return;
            
        CBaseEntity@ pWorldSpawn = g_EntityFuncs.Instance(0);
        if (pWorldSpawn is null) @pWorldSpawn = @pPlayer;
        
        if (g_pFallDamageConVar.value == 2.f) {
            if (_Data.m_flPreviousFrameFallVelo > g_flVelocityToStartJumpbugCheckingAt) {
                g_SoundSystem.EmitSound(pPlayer.edict(), CHAN_BODY, g_pszPlayerFallSound, 1.f, ATTN_NORM);
                pPlayer.TakeDamage(pWorldSpawn.pev, pWorldSpawn.pev, 10.f, DMG_FALL);
            }
            
            return;
        }
    
        if (_Data.m_flPreviousFrameFallVelo > g_flVelocityToStartJumpbugCheckingAt /* max safe fall velo (no damage) */) {
            float flDamage = (_Data.m_flPreviousFrameFallVelo - g_flVelocityToStartJumpbugCheckingAt /* <- min safe fall velo when fall damage calc starts */) * (100.f /* <- some magic value from hlsdk I believe */ / (g_flMaxSafeForPlayerFallVelocity - g_flVelocityToStartJumpbugCheckingAt));
            if (flDamage > 0.f && _Data.m_flPreviousFrameFallVelo > g_flVelocityToStartJumpbugCheckingAt) {
                g_SoundSystem.EmitSound(pPlayer.edict(), CHAN_BODY, g_pszPlayerFallSound, 1.f, ATTN_NORM);
                pPlayer.TakeDamage(pWorldSpawn.pev, pWorldSpawn.pev, flDamage, DMG_FALL);
            }
        }
    }
}
