/**
 * This file is a part of "Unified Punishment System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#include <sourcemod>
#include <ups>

char g_szFooter[512];
char g_szFormat[32];

public Plugin myinfo = {
    description = "Basic implementation for ban",
    version     = "0.0.0.1",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UPS Punishment] Ban",
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
        UPS_UnregisterPunishmentType("ban");
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
        LogError("Can't initialize ban module: configuration file is not retrieved from core.");
        return;
    }

    hConfiguration.GetString("ban.footer", g_szFooter, sizeof(g_szFooter), NULL_STRING);
    hConfiguration.GetString("ban.format", g_szFormat, sizeof(g_szFormat), "%d.%m.%Y %H:%M");
    hConfiguration.Close();

    UPS_RegisterPunishmentType("ban", OnBanPunishmentLoaded);
}

/**
 * @section UPS punishment event
 */
public Action OnBanPunishmentLoaded(int iClient, UPSPunishment hPunishmentRow)
{
    char szAdminUsername[64], szHostname[256], szExpires[64], szReason[256];
    hPunishmentRow.GetAdministratorName(szAdminUsername, sizeof(szAdminUsername));
    hPunishmentRow.GetServerHostname(szHostname, sizeof(szHostname));
    hPunishmentRow.GetReason(szReason, sizeof(szReason));

    if (hPunishmentRow.Length)
        FormatTime(szExpires, sizeof(szExpires), g_szFormat, hPunishmentRow.Ends);
    else
        FormatEx(szExpires, sizeof(szExpires), "%T", "UPS.NeverExpire", iClient);

    if (!IsClientInKickQueue(iClient))
        KickClient(iClient, "%t\n \n%t\n%t\n%t\n%t\n%s", "UPS.YouRePunished", "UPS.AdministratorName", szAdminUsername, "UPS.Expires", szExpires, "UPS.Reason", szReason, "UPS.BannedOnServer", szHostname, g_szFooter);

    return Plugin_Handled;
}