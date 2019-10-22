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

forward void UPS_OnLoaded();
native bool UPS_IsLoaded();
native void UPS_RegisterPunishmentHandler(const char[] szPunishmentType);
