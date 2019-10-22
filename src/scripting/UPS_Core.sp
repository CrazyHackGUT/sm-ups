/**
 * This file is a part of "Unified Punishment System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#include <sourcemod>
#include <dbi>
#include <ups>

bool    g_bReady = false;

KeyValues   g_hConfiguration;
Database    g_hDB;

#undef REQUIRE_PLUGIN
#tryinclude <adminmenu>
#define REQUIRE_PLUGIN

// Enable this if you have something problems with queries and you want profile him.
// #define _UPS_DEBUG 1

#if defined _UPS_DEBUG
#define SQL_ExecuteQuery(%0,%1,%2,%3,%4)    LogMessage(%4), g_hDB.Query(%0,%1,%2,%3)
#else
#define SQL_ExecuteQuery(%0,%1,%2,%3,%4)    g_hDB.Query(%0,%1,%2,%3)
#endif

public Plugin myinfo = {
    description = "Punishments loader",
    version     = "0.0.0.1",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UPS] Core",
    url         = "https://kruzya.me"
};

/**
 * @section API
 */
public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szBuffer, int iBufferLength)
{
    // Natives
    CreateNative("UPS_GetDatabase",                 Native_GetDatabase);
    CreateNative("UPS_GetConfiguration",            Native_GetConfiguration);
    CreateNative("UPS_RegisterPunishmentType",      Native_RegisterPunishmentType);
    CreateNative("UPS_UnregisterPunishmentType",    Native_UnregisterPunishmentType);

    RegPluginLibrary("ups");
}

public int Native_GetDatabase(Handle hPlugin, int iNumParams)
{
    return view_as<int>(APIUTIL_CloneHandle(g_hDB, hPlugin));
}

public int Native_GetConfiguration(Handle hPlugin, int iNumParams)
{
    return view_as<int>(APIUTIL_CloneHandle(g_hConfiguration, hPlugin));
}

Handle APIUTIL_CloneHandle(Handle hHandle, Handle hPlugin)
{
    return hHandle ? CloneHandle(hHandle, hPlugin) : null;
}

public int Native_RegisterPunishmentType() {}

/**
 * @section Startup logic
 */
public void OnPluginStart()
{
    g_bReady = false; // need to be sure...

    // Load configuration file.
    char szPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szPath, sizeof(szPath), "configs/ups.cfg");

    g_hConfiguration = new KeyValues("ups");
    if (!g_hConfiguration)
    {
        SetFailState("Configuration failure: Cannot allocate memory for KeyValues handle");
        return;
    }

    if (!g_hConfiguration.ImportFromFile(szPath))
    {
        SetFailState("Configuration failure: Cannot read configuration (%s)", szPath);
        return;
    }

    // Initialize database connection.
    //
    // We can use SQL_TConnect(), but i want guarantee
    // connection existing in OnAllPluginsLoaded().
    // Without forwards like UPS_OnDatabaseConnected().
    char szConnectionName[64];
    g_hConfiguration.GetString("connection_name", szConnectionName, sizeof(szConnectionName), "ups");

    char szError[256];
    g_hDB = SQL_Connect(szConnectionName, true, szError, sizeof(szError));
    if (!g_hDB)
    {
        SetFailState("Database failure (connection %s): %s", szConnectionName, szError);
        return;
    }

    g_hDB.SetCharset("utf8");
    QueryServer();
}

/**
 * @section Client event handlers
 */
public void OnClientAuthorized(int iClient, const char[] szAuthId)
{
    if (!g_hDB || !g_hConfiguration) return;

    int iSteam = GetSteamAccountID(iClient);
    if (!iSteam)
    {
        return;
    }

    // Build server query.
    char szServer[64], szServerQuery[128];
    g_hConfiguration.GetString("load_servers", szServer, sizeof(szServer));
    if (szServer[0])
    {
        FormatEx(szServerQuery, sizeof(szServerQuery), "AND `ups_punishment`.`server_id` IN(%s)", szServer);
    }

    // Build database query.
    char szQuery[1536];
    g_hDB.FormatEx(szQuery, sizeof(szQuery),
    "\
        SELECT \
            `ups_punishment_type`.`type_name` AS `punishment_type`, \
            `ups_punishment`.`admin_id` AS `admin_id`, \
            IFNULL(`admin`.`username`, `ups_punishment`.`admin_username`) AS `admin_username`, \
            `ups_punishment`.`admin_ip` AS `admin_ip`, \
            `ups_punishment`.`player_id` AS `player_id`, \
            IFNULL(`player`.`username`, `ups_punishment`.`player_username`) AS `player_username`, \
            `ups_punishment`.`player_ip` AS `player_ip`, \
            `created`, \
            `ends`, \
            `length`, \
            INET_NTOA(`ups_server`.`address`) AS `server_address`, \
            `ups_server`.`port` AS `server_port`, \
            `ups_server`.`hostname` AS `server_hostname` \
        \
        FROM \
            `ups_punishment` \
            INNER JOIN `ups_punishment_type` \
                ON `ups_punishment`.`punishment_type_id` = `ups_punishment_type`.`punishment_type_id` \
            INNER JOIN `ups_player` `admin` \
                ON `ups_punishment`.`admin_id` = `admin`.`account_id` \
            INNER JOIN `ups_player` `player` \
                ON `ups_punishment`.`player_id` = `player`.`account_id` \
            INNER JOIN `ups_server` \
                ON `ups_punishment`.`server_id` = `ups_server`.`server_id` \
        \
        WHERE \
            `ups_punishment`.`player_id` = %d AND \
            `ups_punishment`.`deleted_at` IS NULL AND \
            (`ups_punishment`.`length` IS NULL OR `ups_punishment`.`ends` < UNIX_TIMESTAMP()) \
            %!s \
    ", iSteam, szServerQuery);
    SQL_ExecuteQuery(SQL_QueryBans, szQuery, GetClientUserId(iClient), DBPrio_High, "QueryBans()");
}

/**
 * @section Query builders
 */
void QueryServer()
{
    g_bReady = false;
    char szAddress[32], szHostname[256];

    g_hConfiguration.JumpToKey("server", true);
    g_hConfiguration.GetString("address",   szAddress,  sizeof(szAddress),  "0.0.0.0");
    g_hConfiguration.GetString("hostname",  szHostname, sizeof(szHostname), "");
    int iPort = g_hConfiguration.GetNum("port", 0);
    int iServerID = g_hConfiguration.GetNum("id", -1);
    g_hConfiguration.Rewind();

    // Autodetect any unset value.
    if (iPort == 0) iPort = UTIL_GetServerPort();
    if (!strcmp(szAddress, "0.0.0.0")) UTIL_GetServerAddress(szAddress, sizeof(szAddress));
    if (szHostname[0] == 0) UTIL_GetServerHostname(szHostname, sizeof(szHostname));

    // If server id is not filled - drop plugin.
    if (iServerID < 0)
    {
        SetFailState("Configuration problems: Server ID cannot be less than 0!");
        return;
    }

    DataPack hPack = new DataPack();
    hPack.WriteCell(iPort);
    hPack.WriteCell(iServerID);
    hPack.WriteString(szAddress);
    hPack.WriteString(szHostname);

    char szQuery[256];
    // TODO: rework query and handler.
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `server_id` FROM `ups_server` WHERE `address` = INET_ATON('%s') AND `port` = %d", szAddress, iPort);
    SQL_ExecuteQuery(SQL_QueryServer, szQuery, hPack, DBPrio_High, "QueryServer()");
}

void QueryUpdateServer()
{
    if (!g_hDB) return;

    char szQuery[512];
    char szHostname[256];

    g_hConfiguration.JumpToKey("server", true);
    g_hConfiguration.GetString("hostname",  szHostname, sizeof(szHostname), "");
    g_hConfiguration.Rewind();

    if (szHostname[0] == 0) UTIL_GetServerHostname(szHostname, sizeof(szHostname));

    g_hDB.Format(szQuery, sizeof(szQuery), "UPDATE `ups_server` SET `hostname` = '%s' WHERE `server_id` = %d", szHostname, g_iServerID);
    SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 101, DBPrio_High, "QueryUpdateServer())");
}

/**
 * @section Query responsers.
 */
public void SQL_GlobalResultHandle(Database hDb, DBResultSet hResults, const char[] szError, int iQueryId)
{
    /**
     * Query ID definitions:
     *
     * 101  <-> Update hostname
     * 102  <-> Update Server ID
     */
    if (hResults)
    {
        // All OK.
        return;
    }

    LogError("SQL_GlobalResultHandle: query %d -> %s", iQueryId, szError);
}

public void SQL_QueryServer(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{
    hPack.Reset();
    char szAddress[32], szHostname[256];

    int iPort = hPack.ReadCell();
    int iServerID = hPack.ReadCell();
    hPack.ReadString(szAddress, sizeof(szAddress));
    hPack.ReadString(szHostname, sizeof(szHostname));
    hPack.Close();

    if (!hResults)
    {
        SetFailState("SQL_QueryServer: %s", szError);
        return;
    }

    char szQuery[512];
    if (hResults.HasResults && hResults.RowCount > 0 && hResults.FetchRow())
    {
        int iFetchedServerID = hResults.FetchInt(0);
        if (iServerID != iFetchedServerID)
        {
            // Update Server ID.
            hDB.Format(szQuery, sizeof(szQuery), "UPDATE `ups_server` SET `server_id` = %d WHERE `server_id` = %d", iServerID, iFetchedServerID);
            SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 102, DBPrio_High, "SQL_QueryServer(ServerID)");
        }

        g_iServerID = iServerID;

        // Update hostname.
        g_bReady = true;

        QueryUpdateServer();
        CheckLateLoad();
        return;
    }

    // Create server.
    hDB.Format(szQuery, sizeof(szQuery), "INSERT INTO `ups_server` (`server_id`, `address`, `port`, `hostname`) VALUES (%d, INET_ATON('%s'), %d, '%s')", iServerID, szAddress, iPort, szHostname);
    SQL_ExecuteQuery(SQL_CreateServer, szQuery, iServerID, DBPrio_High, "SQL_QueryServer(NewEntry)");
}

public void SQL_CreateServer(Database hDB, DBResultSet hResults, const char[] szError, int iServerID)
{
    if (!hResults)
    {
        SetFailState("SQL_CreateServer: %s", szError);
        return;
    }

    g_iServerID = iServerID;
    g_bReady = true;

    CheckLateLoad();
}

/**
 * @section Late load
 */
void CheckLateLoad()
{
    for (int iClient = MaxClients; iClient > 0; --iClient)
    {
        if (IsClientInGame(iClient) IsClientAuthorized(iClient))
        {
            OnClientAuthorized(iClient, NULL_STRING);
        }
    }
}

/**
 * @section Server determine functions.
 */
int UTIL_GetServerPort()
{
    static ConVar hostport = null;
    if (hostport == null)
    {
        hostport = FindConVar("hostport");
    }

    return hostport.IntValue;
}

void UTIL_GetServerAddress(char[] szBuffer, int iBufferSize)
{
    static ConVar hostip = null;
    if (hostip == null)
    {
        hostip = FindConVar("hostip");
    }

    int iIp = hostip.IntValue;
    FormatEx(
        szBuffer, iBufferSize, "%d.%d.%d.%d",
        (iIp >> 24)     & 0xFF,
        (iIp >> 16)     & 0xFF,
        (iIp >> 8 )     & 0xFF,
        (iIp      )     & 0xFF
    );
}

void UTIL_GetServerHostname(char[] szBuffer, int iBufferSize)
{
    static ConVar hostname = null;
    if (hostname == null)
    {
        hostname = FindConVar("hostname");
    }

    hostname.GetString(szBuffer, iBufferSize);
}