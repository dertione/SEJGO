/****************************************************************************************************
Version 0.1 : 
		Dertione - 08/07/2015
			-Ajout de la nouvelle syntaxe Sourcemod 1.7
			-Ajout de la commande ft qui permet de swaper un joueur avec logs
			-Ajout de la commande knive qui permet de donner un couteau à la personne ciblé
			-Utilisation de l'include selib
****************************************************************************************************/

#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <selib>

#pragma newdecls required

#define terrorist 			2
#define counterTerrorist 	3


public Plugin myinfo =
{
	name = "CommandAdmin",
	description = "JailBreak Mod",
	author = "Dertione",
	version = "1.0",
	url = "http://forum.supreme-elite.fr"
};



public void OnPluginStart()
{
	RegAdminCmd("sm_ft", CMD_FT, ADMFLAG_SLAY, "sm_ft <#userid|name> [team]");
	RegAdminCmd("sm_knive", CMD_knive, ADMFLAG_SLAY, "sm_knive <#userid|name>");
}


public Action CMD_FT(int client, int args)
{
	if (args < 2 )
	{
		ReplyToCommand(client, "[SM] Usage : sm_ft <name> <team>");
		return Plugin_Handled ;
	}
	int Alive;
	int ThePlayer;
	char sArg1[64];
	char sArg2[64];
	
	GetCmdArg(1, sArg1, sizeof(sArg2));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	if (IsSeAdmin(client)||IsSeStaff(client))
	{
		if (!StrEqual(sArg1, "", true))
		{
			ThePlayer = FindTarget(client,sArg1, false, false);
			if (IsPlayerAlive(ThePlayer))
			{
				Alive = 1;
			}
			if (ThePlayer)
			{
				char name[64];
				GetClientName(ThePlayer, name, 64);
				if (StrEqual(sArg2, "1", true))
				{
					ChangeClientTeam(ThePlayer, 1);
					PrintToChatAll("\x09[JAILBEAK-SE]\x05 Le jouer %s a été swapé en spectateur ", name);
					LogAction(client, ThePlayer, "\"%L\" a ft \"%L\" (team : \"%s\")", client, ThePlayer, sArg2);
				}
				if (StrEqual(sArg2, "2", true))
				{
					ChangeClientTeam(ThePlayer, 2);
					PrintToChatAll("\x09[JAILBEAK-SE]\x05 Le jouer %s a été swapé en terroriste ", name);
					if (Alive == 1)
					{
						CS_RespawnPlayer(ThePlayer);
						LogAction(client, ThePlayer, "\"%L\" a ft \"%L\" (team : \"%s\") (la personne est toujours en vie)", client, ThePlayer, sArg2);
					}
					else
					{
						LogAction(client, ThePlayer, "\"%L\" a ft \"%L\" (team : \"%s\") (la personne est morte)", client, ThePlayer, sArg2);
					}
				}
				if (StrEqual(sArg2, "3", true))
				{
					ChangeClientTeam(ThePlayer, 3);
					PrintToChatAll("\x09[JAILBEAK-SE]\x05 Le jouer %s a été swapé en anti-terroriste ", name);
					if (Alive == 1)
					{
						CS_RespawnPlayer(ThePlayer);
						LogAction(client, ThePlayer, "\"%L\" a ft \"%L\" (team : \"%s\") (la personne est toujours en vie)", client, ThePlayer, sArg2);
					}
					else
					{
						LogAction(client, ThePlayer, "\"%L\" a ft \"%L\" (team : \"%s\") (la personne est morte)", client, ThePlayer, sArg2);
					}
				}
			}
			else
			{
				PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Joueur introuvable", sArg1);
			}
		}
		else
		{
			PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Erreur");
		}
		return Plugin_Handled;
	}
	PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Tu n'as pas les droits necessaires ");
	return Plugin_Handled;
}

public Action CMD_knive(int client, int args)
{
	if (args < 1 )
	{
		ReplyToCommand(client, "[SM] Usage : sm_knive <name>");
		return Plugin_Handled;
	}
	//Nouvelle déclaration sourcemod 1.7
	int ThePlayer;
	char sArg1[64];
	
	//Récupération de l'argument donc du nom du joueur
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (IsSeAdmin(client))
	{
		ThePlayer = FindTarget(client,sArg1, false, false);
		if (ThePlayer)
		{
			GivePlayerItem(ThePlayer, "weapon_knife", 0);
		}
	}
	else
	{
		PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Tu n'as pas le droit de donner des couteaux ! ");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}