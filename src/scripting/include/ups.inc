/**
 * This file is a part of "Unified Punishment System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#if defined _ups_included
  #endinput
#endif // defined _ups_included
#define _ups_included

methodmap UPSPunishment < Handle {
    property int PunishmentId
    {
        public native get();
    }

    property int AdministratorId 
    {
        public native get();
    }

    property int PlayerId
    {
        public native get();
    }

    property int Created
    {
        public native get();
    }

    property int Ends
    {
        public native get();
    }

    property int Length
    {
        public native get();
    }

    property int ServerPort
    {
        public native get();
    }

    public native int GetAdministratorIP(char[] szBuffer, int iBufferLength);
    public native int GetPlayerIP(char[] szBuffer, int iBufferLength);
    public native int GetServerIP(char[] szBuffer, int iBufferLength);

    public native int GetAdministratorName(char[] szBuffer, int iBufferLength);
    public native int GetPlayerName(char[] szBuffer, int iBufferLength);

    public native int GetServerHostname(char[] szBuffer, int iBufferLength);

    public native int GetReason(char[] szBuffer, int iBufferLength);

    public native int GetType(char[] szBuffer, int iBufferLength);
}

/**
 * Called when punishment loaded from database.
 *
 * @return Plugin_Handled or higher - stop handling punishments.
 */
typeset UPSHandler {
    /**
     * @param   iClient     Client identifier.
     * @param   hPunishment Punishment wrapped by core.
     */
    function Action(int iClient, UPSPunishment hPunishment);

    /**
     * @param   iClient     Client identifier.
     * @param   hPunishment Punishment result set (DON'T CHANGE ROW).
     */
    function Action(int iClient, DBResultSet hPunishment);

    // Implemented in v1.0.0.1
    /**
     * @param   iClient     Client identifier.
     * @param   hPunishment Punishment wrapped by core.
     * @param   szType      Punishment type.
     */
    function Action(int iClient, UPSPunishment hPunishment, const char[] szType);

    /**
     * @param   iClient     Client identifier.
     * @param   hPunishment Punishment result set (DON'T CHANGE ROW).
     * @param   szType      Punishment type.
     */
    function Action(int iClient, DBResultSet hPunishment, const char[] szType);
}

/**
 * Returns the database handle.
 *
 * NOTE: you receive a database clone.
 * You should close this.
 *
 * @return  Database connection handle, or null if connection is not established.
 */
native Database UPS_GetDatabase();

/**
 * Returns the configuration handle.
 *
 * NOTE: you receive a configuration clone.
 * You should close this.
 *
 * @return  Configuration handle, or null if configuration isn't ready yet.
 */
native KeyValues UPS_GetConfiguration();

/**
 * Registers a new punishment type handler.
 * If punishment type isn't exists in database - registers.
 *
 * @noreturn
 * @error     Handler for this punishment type already registered.
 */
native void UPS_RegisterPunishmentType(const char[] szPunishmentType, UPSHandler ptrFunction);

/**
 * Removes a punishment type handler from core.
 *
 * @noreturn
 * @error     Handler for this punishment type isn't registered or handler registered isn't this plugin.
 */
native void UPS_UnregisterPunishmentType(const char[] szPunishmentType);

public SharedPlugin __pl_ups = {
    name        = "ups",
    file        = "UPS/Core.smx",
#if defined REQUIRE_PLUGIN
    required    = 1,
#else // defined REQUIRE_PLUGIN
    required    = 0,
#endif // defined REQUIRE_PLUGIN
};

#if !defined REQUIRE_PLUGIN
public void __pl_ups_SetNTVOptional()
{
    // v0.0.0.1
    MarkNativeAsOptional("UPS_GetDatabase");
    MarkNativeAsOptional("UPS_GetConfiguration");
    MarkNativeAsOptional("UPS_RegisterPunishmentType");
    MarkNativeAsOptional("UPS_UnregisterPunishmentType");

    // v0.0.0.2, Methodmap "UPSPunishment"
    MarkNativeAsOptional("UPSPunishment.AdministratorId.get");
    MarkNativeAsOptional("UPSPunishment.PlayerId.get");
    MarkNativeAsOptional("UPSPunishment.Created.get");
    MarkNativeAsOptional("UPSPunishment.Ends.get");
    MarkNativeAsOptional("UPSPunishment.Length.get");
    MarkNativeAsOptional("UPSPunishment.ServerPort.get");
    MarkNativeAsOptional("UPSPunishment.GetAdministratorIP");
    MarkNativeAsOptional("UPSPunishment.GetPlayerIP");
    MarkNativeAsOptional("UPSPunishment.GetServerIP");
    MarkNativeAsOptional("UPSPunishment.GetAdministratorName");
    MarkNativeAsOptional("UPSPunishment.GetPlayerName");
    MarkNativeAsOptional("UPSPunishment.GetServerHostname");

    // v0.0.0.3, Methodmap "UPSPunishment"
    MarkNativeAsOptional("UPSPunishment.PunishmentId.get");
    MarkNativeAsOptional("UPSPunishment.GetReason");

    // v1.0.0.1
    MarkNativeAsOptional("UPSPunishment.GetType");
}
#endif // defined REQUIRE_PLUGIN
