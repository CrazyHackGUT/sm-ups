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
#include <ups_util/callable>

bool    g_bReady = false;

int         g_iServerID;
StringMap   g_hHandlers;
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
    version     = "1.0.0.0",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UPS] Core",
    url         = "https://kruzya.me"
};

/**
 * @section API
 */
#define _NATIVECALL(%0)         public int %0(Handle hPlugin, int iNumParams)
#define _NATIVE_SIMPLE(%0)      _NATIVECALL(Native_%0)
#define _NATIVE_METHODMAP(%0)   _NATIVECALL(Methodmap_%0)

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szBuffer, int iBufferLength)
{
    // Natives
    CreateNative("UPS_GetDatabase",                 Native_GetDatabase);
    CreateNative("UPS_GetConfiguration",            Native_GetConfiguration);
    CreateNative("UPS_RegisterPunishmentType",      Native_RegisterPunishmentType);
    CreateNative("UPS_UnregisterPunishmentType",    Native_UnregisterPunishmentType);

    // Methodmap "UPSPunishment"
    CreateNative("UPSPunishment.PunishmentId.get",      Methodmap_UPSPunishment_PunishmentId_get);
    CreateNative("UPSPunishment.AdministratorId.get",   Methodmap_UPSPunishment_AdministratorId_get);
    CreateNative("UPSPunishment.PlayerId.get",          Methodmap_UPSPunishment_PlayerId_get);
    CreateNative("UPSPunishment.Created.get",           Methodmap_UPSPunishment_Created_get);
    CreateNative("UPSPunishment.Ends.get",              Methodmap_UPSPunishment_Ends_get);
    CreateNative("UPSPunishment.Length.get",            Methodmap_UPSPunishment_Length_get);
    CreateNative("UPSPunishment.ServerPort.get",        Methodmap_UPSPunishment_ServerPort_get);
    CreateNative("UPSPunishment.GetAdministratorIP",    Methodmap_UPSPunishment_GetAdministratorIP);
    CreateNative("UPSPunishment.GetPlayerIP",           Methodmap_UPSPunishment_GetPlayerIP);
    CreateNative("UPSPunishment.GetServerIP",           Methodmap_UPSPunishment_GetServerIP);
    CreateNative("UPSPunishment.GetAdministratorName",  Methodmap_UPSPunishment_GetAdministratorName);
    CreateNative("UPSPunishment.GetPlayerName",         Methodmap_UPSPunishment_GetPlayerName);
    CreateNative("UPSPunishment.GetServerHostname",     Methodmap_UPSPunishment_GetServerHostname);
    CreateNative("UPSPunishment.GetReason",             Methodmap_UPSPunishment_GetReason);

    g_hHandlers = new StringMap();

    RegPluginLibrary("ups");
}

_NATIVE_SIMPLE(GetDatabase)
{
    return view_as<int>(APIUTIL_CloneHandle(g_hDB, hPlugin));
}

_NATIVE_SIMPLE(GetConfiguration)
{
    return view_as<int>(APIUTIL_CloneHandle(g_hConfiguration, hPlugin));
}

Handle APIUTIL_CloneHandle(Handle hHandle, Handle hPlugin)
{
    return hHandle ? CloneHandle(hHandle, hPlugin) : null;
}

_NATIVE_SIMPLE(RegisterPunishmentType)
{
    char szPunishmentType[64];
    GetNativeString(1, szPunishmentType, sizeof(szPunishmentType));

    Callable hCallable;
    if (g_hHandlers.GetValue(szPunishmentType, hCallable))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Handler for this punishment type (%s) already registered", szPunishmentType);
    }

    g_hHandlers.SetValue(szPunishmentType, new Callable(hPlugin, GetNativeFunction(2)));

    if (g_bReady)
    {
        QueryCheckPunishmentType(szPunishmentType);
    }

    return 0;
}

_NATIVE_SIMPLE(UnregisterPunishmentType)
{
    char szPunishmentType[64];
    GetNativeString(1, szPunishmentType, sizeof(szPunishmentType));

    Callable hCallable;
    if (!g_hHandlers.GetValue(szPunishmentType, hCallable))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Handler for this punishment type (%s) is not registered", szPunishmentType);
    }

    if (hCallable.Plugin != hPlugin)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Unregistration for this punishment type (%s) is unavailable with this security identifier", szPunishmentType);
    }

    hCallable.Close();
    g_hHandlers.Remove(szPunishmentType);
    return 0;
}

/**
 * @section Methodmap "UPSPunishment"
 */
int MethodmapGeneric(int iFieldId, int iIfNull = 0)
{
    DBResultSet hResults = GetNativeCell(1);

    if (!hResults.IsFieldNull(iFieldId))
        return hResults.FetchInt(iFieldId);
    return iIfNull;
}

int MethodmapString(int iFieldId, int iLength = 32, const char[] szDefaultValue = NULL_STRING)
{
    DBResultSet hResults = GetNativeCell(1);
    char[] szBuffer = new char[iLength];

    if (!hResults.IsFieldNull(iFieldId))
    {
        hResults.FetchString(iFieldId, szBuffer, iLength);
    }
    else
    {
        strcopy(szBuffer, iLength, szDefaultValue);
    }

    int iSize;
    SetNativeString(2, szBuffer, GetNativeCell(3), true, iSize);
    return iSize;
}

_NATIVE_METHODMAP(UPSPunishment_PunishmentId_get)       { return MethodmapGeneric(0);       }
_NATIVE_METHODMAP(UPSPunishment_AdministratorId_get)    { return MethodmapGeneric(2);       }
_NATIVE_METHODMAP(UPSPunishment_GetAdministratorName)   { return MethodmapString(3);        }
_NATIVE_METHODMAP(UPSPunishment_GetAdministratorIP)     { return MethodmapString(4);        }
_NATIVE_METHODMAP(UPSPunishment_PlayerId_get)           { return MethodmapGeneric(5);       }
_NATIVE_METHODMAP(UPSPunishment_GetPlayerName)          { return MethodmapString(6);        }
_NATIVE_METHODMAP(UPSPunishment_GetPlayerIP)            { return MethodmapString(7);        }
_NATIVE_METHODMAP(UPSPunishment_Created_get)            { return MethodmapGeneric(8);       }
_NATIVE_METHODMAP(UPSPunishment_Ends_get)               { return MethodmapGeneric(9);       }
_NATIVE_METHODMAP(UPSPunishment_Length_get)             { return MethodmapGeneric(10);      }
_NATIVE_METHODMAP(UPSPunishment_GetServerIP)            { return MethodmapString(11);       }
_NATIVE_METHODMAP(UPSPunishment_ServerPort_get)         { return MethodmapGeneric(12);      }
_NATIVE_METHODMAP(UPSPunishment_GetServerHostname)      { return MethodmapString(13, 256);  }
_NATIVE_METHODMAP(UPSPunishment_GetReason)              { return MethodmapString(14, 256);  }

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
    if (!g_bReady || !g_hDB || !g_hConfiguration || IsFakeClient(iClient)) return;

    ProcessClient(iClient);
}

void ProcessClient(int iClient)
{
    QueryInsertClient(iClient);

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
    char szQuery[2048];
    g_hDB.Format(szQuery, sizeof(szQuery),
    "\
        SELECT \
            `ups_punishment`.`punishment_id` AS `punishment_id`, \
            `ups_punishment_type`.`type_name` AS `punishment_type`, \
            `ups_punishment`.`admin_id` AS `admin_id`, \
            IFNULL(`admin`.`username`, `ups_punishment`.`admin_username`) AS `admin_username`, \
            INET_NTOA(`ups_punishment`.`admin_ip`) AS `admin_ip`, \
            `ups_punishment`.`player_id` AS `player_id`, \
            IFNULL(`player`.`username`, `ups_punishment`.`player_username`) AS `player_username`, \
            INET_NTOA(`ups_punishment`.`player_ip`) AS `player_ip`, \
            `created`, \
            `ends`, \
            `length`, \
            INET_NTOA(`ups_server`.`address`) AS `server_address`, \
            `ups_server`.`port` AS `server_port`, \
            `ups_server`.`hostname` AS `server_hostname`, \
            `ups_punishment`.`reason` AS `reason` \
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

public Action OnQueueTriggered(Handle hTimer, int iClient)
{
    if ((iClient = GetClientOfUserId(iClient)) == 0)
    {
        return;
    }

    ProcessClient(iClient);
}

void RequeuePunishmentLoading(int iClient, int iCooldown)
{
    CreateTimer(float(iCooldown), OnQueueTriggered, GetClientUserId(iClient));
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

    char szQuery[128];
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
    SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 101, DBPrio_High, "QueryUpdateServer()");
}

void QueryCheckPunishmentType(const char[] szPunishmentType)
{
    char szQuery[148];
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `punishment_type_id` FROM `ups_punishment_type` WHERE `type_name` = '%s'", szPunishmentType);

    DataPack hPack = new DataPack();
    hPack.WriteString(szPunishmentType);

    SQL_ExecuteQuery(SQL_CheckPunishmentType, szQuery, hPack, DBPrio_Normal, "QueryCheckPunishmentType()");
}

void QueryCreatePunishmentType(const char[] szPunishmentType)
{
    char szQuery[164];
    g_hDB.Format(szQuery, sizeof(szQuery), "INSERT INTO `ups_punishment_type` (`type_name`, `registered_at`) VALUES('%s', UNIX_TIMESTAMP())", szPunishmentType);

    SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 201, DBPrio_High, "QueryCreatePunishmentType()");
}

void QueryInsertClient(int iClient)
{
    int iSteam = GetSteamAccountID(iClient);
    if (!iSteam)
    {
        return;
    }

    char szQuery[512];
    g_hDB.Format(szQuery, sizeof(szQuery), "INSERT IGNORE INTO `ups_player` (`account_id`, `username`, `last_activity`) VALUES (%d, '%N', UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE `username` = '%N', `last_activity` = UNIX_TIMESTAMP()", iSteam, iClient, iClient);
    SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 301, DBPrio_High, "QueryInsertClient()");
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
     * 201  <-> Create punishment type
     * 301  <-> Create player
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

public void SQL_CheckPunishmentType(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{
    char szPunishmentType[64];
    hPack.Reset();
    hPack.ReadString(szPunishmentType, sizeof(szPunishmentType));
    hPack.Close();

    if (!hResults)
    {
        LogError("Couldn't verify punishment type '%s' in database: %s", szPunishmentType, szError);
        return;
    }

    if (!hResults.FetchRow())
    {
        QueryCreatePunishmentType(szPunishmentType);
    }
}

public void SQL_QueryBans(Database hDB, DBResultSet hResults, const char[] szError, int iClient)
{
    if ((iClient = GetClientOfUserId(iClient)) == 0)
    {
        return;
    }

    if (!hResults)
    {
        LogError("Database failure when fetching punishments for %L: %s", iClient, szError);
        RequeuePunishmentLoading(iClient, 45);
        return;
    }

    if (hResults.HasResults && hResults.RowCount)
    {
        char szPunishmentType[64];
        Callable hHandler;
        Action eAction;

        while (hResults.FetchRow())
        {
            // First, check punishment type handler.
            hResults.FetchString(1, szPunishmentType, sizeof(szPunishmentType));
            if (!g_hHandlers.GetValue(szPunishmentType, hHandler))
            {
                LogError("Can't handle punishment type (%s) for %L (punishment id - %d): Handler is not registered.", szPunishmentType, iClient, hResults.FetchInt(0));
                continue;
            }

            // Call handler.
            hHandler.Start();
            Call_PushCell(iClient);
            Call_PushCell(hResults);
            Call_Finish(eAction);

            if (eAction <= Plugin_Handled)
            {
                break;
            }
        }
    }
}

/**
 * @section Late load
 */
void CheckLateLoad()
{
    // First, check all punishment types.
    StringMapSnapshot hShot = g_hHandlers.Snapshot();
    int iLength = hShot.Length;
    char szPunishmentType[64];
    for (int iPunishmentTypeId; iPunishmentTypeId < iLength; ++iPunishmentTypeId)
    {
        hShot.GetKey(iPunishmentTypeId, szPunishmentType, sizeof(szPunishmentType));
        QueryCheckPunishmentType(szPunishmentType);
    }
    hShot.Close();

    // Second, check all players.
    for (int iClient = MaxClients; iClient > 0; --iClient)
    {
        if (IsClientInGame(iClient) && IsClientAuthorized(iClient))
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
    UTIL_FormatIP(iIp, szBuffer, iBufferSize);
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

void UTIL_FormatIP(int iIp, char[] szBuffer, int iBufferSize)
{
    FormatEx(
        szBuffer, iBufferSize, "%d.%d.%d.%d",
        (iIp >> 24)     & 0xFF,
        (iIp >> 16)     & 0xFF,
        (iIp >> 8 )     & 0xFF,
        (iIp      )     & 0xFF
    );
}
