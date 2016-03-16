/****************************************************************************************************
Version 0.1 : 
		Dertione - 08/07/2015
			-Ajout de la nouvelle syntaxe Sourcemod 1.7
			-Ajout du mute au spawn
			-Ajout de demute selon un paramètre
			-Utilisation de l'include selib
****************************************************************************************************/

#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <selib>

#pragma newdecls required

#define terrorist 			2
#define counterTerrorist 	3

Handle sm_mt_terro;


public Plugin myinfo =
{
	name = "Gestion du mute des terroristes",
	description = "JailBreak Mod",
	author = "Dertione",
	version = "0.1",
	url = "http://forum.supreme-elite.fr"
};



public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	//-----------------------------------------
	// Creation des ConVars
	//-----------------------------------------

	sm_mt_terro = CreateConVar( "sm_mt_ratio", "5", "En dessous de ce nombre de terro en vie, les terroristes vivants sont démutés", FCVAR_PLUGIN );

	//-----------------------------------------
	// Generate config file
	//-----------------------------------------
	
	AutoExecConfig( true, "sm_muteTerro" );
}



public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	SetClientListeningFlags(client, VOICE_MUTED);

	if (IsSeAdmin(client))
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}
	else if (GetClientTeam(client) == 3)
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if(!IsSeAdmin(client))
	{
		SetClientListeningFlags(client, VOICE_MUTED);
	}
	
	if(Team_CountPlayer(2,true) <= GetConVarInt(sm_mt_terro))
	{
		for (int player = 1; player <= GetMaxClients(); player ++)
		{
			if (IsClientInGame(player) && GetClientTeam(player) == 2 && IsPlayerAlive(player))
			{
				SetClientListeningFlags(player, VOICE_NORMAL);
			}
		}
	}
	
	return Plugin_Handled;
}