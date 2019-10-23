/**
 * This file is a part of "Unified Punishment System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#include <sourcemod>
#include <basecomm>
#include <ups>

#define COMM_VOICE  0
#define COMM_TEXT   1

stock const char g_szChatPrefix[]   = "UPS.ChatPrefix";

char g_szFormat[32];

public Plugin myinfo = {
    description = "Basic implementation for comm punishments",
    version     = "0.0.0.1",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UPS Punishment] Communications",
    url         = "https://kruzya.me"
};

/**
 * @section Generic SM events
 */
public void OnPluginStart()
{
    LoadTranslations("ups_common.phrases");
}

public void OnPluginEnd()
{
    if (LibraryExists("ups"))
    {
        UPS_UnregisterPunishmentType("comm_text");
        UPS_UnregisterPunishmentType("comm_voice");
    }
}

public void OnLibraryAdded(const char[] szLibrary)
{
    if (!strcmp(szLibrary, "ups"))
    {
        UPS_ModInit();
    }
}

/**
 * @section UPS loader
 */
void UPS_ModInit()
{
    KeyValues hConfiguration = UPS_GetConfiguration();
    if (!hConfiguration)
    {
        LogError("Can't initialize comm module: configuration file is not retrieved from core.");
        return;
    }

    hConfiguration.GetString("comm.format", g_szFormat, sizeof(g_szFormat), "%d.%m.%Y %H:%M");
    hConfiguration.Close();

    UPS_RegisterPunishmentType("comm_text",     OnTextPunishmentLoaded);
    UPS_RegisterPunishmentType("comm_voice",    OnVoicePunishmentLoaded);
}

/**
 * @section UPS punishment event
 */
public Action OnTextPunishmentLoaded(int iClient, UPSPunishment hPunishmentRow)
{
    OnPunishmentLoaded(iClient, hPunishmentRow, COMM_TEXT);
}

public Action OnVoicePunishmentLoaded(int iClient, UPSPunishment hPunishmentRow)
{
    OnPunishmentLoaded(iClient, hPunishmentRow, COMM_VOICE);
}

void OnPunishmentLoaded(int iClient, UPSPunishment hPunishment, int iType)
{
    char szCommType[20];

    UTIL_UpdateCommunicationsState(iClient, iType, false);
    UTIL_IntTypeToPhraseName(iType, szCommType, sizeof(szCommType));

    char szAdministratorName[64], szExpires[32], szReason[256];
    hPunishment.GetAdministratorName(szAdministratorName, sizeof(szAdministratorName));
    hPunishment.GetReason(szReason, sizeof(szReason));
    if (hPunishment.Length)
    {
        FormatTime(szExpires, sizeof(szExpires), g_szFormat, hPunishment.Ends);
        UTIL_MakeExpireTimer(iClient, iType, hPunishment.Ends);
    }
    else
    {
        FormatEx(szExpires, sizeof(szExpires), "%T", "UPS.NeverExpire", iClient);
    }

    PrintToChat(iClient, " ");
    PrintToChat(iClient, "%t %t", g_szChatPrefix, "UPS.YouRePunished.Comm", szCommType);
    PrintToChat(iClient, "%t %t", g_szChatPrefix, "UPS.Administrator", szAdministratorName);
    PrintToChat(iClient, "%t %t", g_szChatPrefix, "UPS.Expires", szExpires);
    PrintToChat(iClient, "%t %t", g_szChatPrefix, "UPS.Reason", szReason);
    PrintToChat(iClient, " ");
}

/**
 * @section UTIL
 */
void UTIL_IntTypeToPhraseName(int iType, char[] szCommType, int iBufferLength)
{
    if (iBufferLength < 20)
    {
        return;
    }

    int iStartPos = strcopy(szCommType, iBufferLength, "UPS.Type.comm_");
    switch (iType)
    {
        case COMM_TEXT:     strcopy(szCommType[iStartPos], iBufferLength - iStartPos, "text");
        case COMM_VOICE:    strcopy(szCommType[iStartPos], iBufferLength - iStartPos, "voice");
    }
}
void UTIL_UpdateCommunicationsState(int iClient, int iType, bool bEnabled)
{
    bEnabled = !bEnabled;
    switch (iType)
    {
        case COMM_TEXT:     BaseComm_SetClientGag(iClient, bEnabled);
        case COMM_VOICE:    BaseComm_SetClientMute(iClient, bEnabled);
    }
}

void UTIL_MakeExpireTimer(iClient, int iType, int iLength)
{
    DataPack hPack;
    CreateDataTimer(5.0, OnTimerTicked, hPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

    hPack.WriteCell(GetClientUserId(iClient));
    hPack.WriteCell(iLength);
    hPack.WriteCell(iType);
}

/**
 * @section Timer
 */
public Action OnTimerTicked(Handle hTimer, DataPack hPack)
{
    hPack.Reset();

    int iClient = GetClientOfUserId(hPack.ReadCell());
    if (!iClient)
    {
        return Plugin_Stop;
    }

    int iExpireTime = hPack.ReadCell();
    if (iExpireTime > GetTime())
    {
        return Plugin_Continue;
    }

    char szCommType[20];
    int iType = hPack.ReadCell();

    UTIL_IntTypeToPhraseName(iType, szCommType, sizeof(szCommType));
    UTIL_UpdateCommunicationsState(iClient, iType, true);
    PrintToChat(iClient, "%t %t", g_szChatPrefix, "UPS.PunishmentExpired.Comm", szCommType);

    return Plugin_Stop;
}