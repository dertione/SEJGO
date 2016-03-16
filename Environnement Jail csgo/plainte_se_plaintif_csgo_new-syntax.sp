#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define	PLUGIN_NAME			"plainte_se"
#define	PLUGIN_AUTHOR		"Dertione"
#define	PLUGIN_DESCRIPTION	"susteme plainte pour jailbreak"
#define	PLUGIN_VERSION		"0.1"
#define	PLUGIN_URL			"http://www.supreme-elite.fr/"
#define DATABASE_NAME "dertione"

int g_IsWaitingForChatReason[MAXPLAYERS+1];
Handle g_hTimerPlainte[MAXPLAYERS+1];
Handle g_hDatabase = INVALID_HANDLE;

public Plugin myinfo =
{
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url			= PLUGIN_URL,
};

public void OnClientPutInServer(int client)
{
	g_IsWaitingForChatReason[client] = false;
	g_hTimerPlainte[client] = CreateTimer(60.0, Timer_Plainte, client, TIMER_REPEAT);
}

public void OnClientDisconnect(int client)
{
	if (g_hTimerPlainte[client] != INVALID_HANDLE)
	{
		KillTimer(g_hTimerPlainte[client])
		g_hTimerPlainte[client] = INVALID_HANDLE
	}
}

public void OnPluginStart()
{
	RegConsoleCmd("plainte", Command_Plainte, "", 0);
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
}

public void OnMapStart()
{
	ConnectBDD();
	//PrecacheSound("supremeelite/beep.mp3", true);
	//AddFileToDownloadsTable("sound/supremeelite/beep.mp3");
}

public void OnMapEnd()
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	if(CheckSQL())
	{
		// Requete SQL
		Format(sQuery, sizeof(sQuery), "TRUNCATE TABLE `plainte_se`");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		CloseHandle(hQuery);
	}
	DisconnectSQL();
}

public Action Timer_Plainte(Handle timer, int client)
{
	PrintToChat(client, "\x02[Plainte-SE]\x06 Toute plainte devra passer par la commande /plainte ou !plainte");
	PrintToChat(client, "\x02[Plainte-SE]\x06 Pour compléter votre plainte, il suffit d'écrire dans le chat le supplément");
	PrintToChat(client, "\x02[Plainte-SE]\x06 Si aucune information supplémentaire n'est écrite, votre plainte ne sera pas traitée !");
}

public Action Command_Plainte(int client, int args)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	Menu menu = CreateMenu(MenuHandler_DebutPlainte);
	char sAuth[20];
	if(GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth)) == false)
	{
		ThrowNativeError(2, "User auth ID not availlable yet, please try later.");
	}
	if(CheckSQL())
	{
		// Requete SQL
		Format(sQuery, sizeof(sQuery), "SELECT `name_plaignant` FROM `plainte_se` WHERE `authid_plaignant`='%s' ", sAuth);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		if(g_hDatabase == INVALID_HANDLE)
		{
			LogError("Query failed! ");
		}
		else if(!SQL_GetRowCount(hQuery))
		{
			menu.SetTitle("Plainte menu");
			
			menu.AddItem("0", "Nouvelle Plainte");
			menu.AddItem("1", "Annuler");
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			PrintToChat(client, "\x02[Plainte-SE]\x06 Une plainte est deja en cours, veuillez attendre que celle-ci soit regle !");
			delete menu;
		}
	}
	else
	{
		DisconnectSQL();
	}
	CloseHandle(hQuery);
}


public int MenuHandler_DebutPlainte(Menu menu, MenuAction action, int client, int param2)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	if (action == MenuAction_Cancel)
	{

	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if(param2==0)
		{
			DisplayBanTypeMenu(client);
			char sAuth[20];
			char szClientName[50];
			char szClientNameSQL[50];
			GetClientName(client, szClientName, sizeof(szClientName));
			SQL_EscapeString(g_hDatabase, szClientName, szClientNameSQL, sizeof(szClientNameSQL));
			if(GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth)) == false)
			{
				ThrowNativeError(2, "User auth ID not availlable yet, please try later.");
			}
			//determination de l'heure de la plainte
			char buffer[20];
			FormatTime(buffer, sizeof(buffer), "%H", GetTime());
			char hour[10];
			Format(hour, 10, buffer);
			FormatTime(buffer, sizeof(buffer), "%M", GetTime());
			char minute[10];
			Format(minute, 10, buffer);
			Format(buffer, 20, "%s%s00", hour, minute);
			if(CheckSQL())
			{
				// Requete SQL
				Format(sQuery, sizeof(sQuery), "INSERT INTO `plainte_se` (`authid_plaignant`, `name_plaignant`, `authid_freekilleur`, `name_freekilleur`, `type`, `lieu`, `info`, `date`) VALUES ('%s', '%s', '0', '0', '0', '0', '0', '%s')", sAuth, szClientNameSQL, buffer);
				hQuery = SQL_Query(g_hDatabase, sQuery);
			}
			else
			{
				DisconnectSQL();
			}
			CloseHandle(hQuery);
		}
		else if(param2==1)
		{

		}
	}
	return 0;
}

void DisplayBanTypeMenu(int client)
{
	Menu menu2 = CreateMenu(MenuHandler_Type);
	/* :TODO: we should either remove this or make it configurable */
	menu2.SetTitle("Type de plainte");
	
	menu2.AddItem("Freekill", "Freekill");
	menu2.AddItem("Freeshot", "Freeshot");
	menu2.AddItem("Insulte", "Insulte");
	menu2.AddItem("Autre", "Autre");
	
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Type(Menu menu, MenuAction action, int client, int param2)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	if (action == MenuAction_End)
	{
		char steamid_plaignant[20];
		if(IsClientInGame(client))
		{
			GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
			if(CheckSQL())
			{
				Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
				hQuery = SQL_Query(g_hDatabase, sQuery);CloseHandle(hQuery);
			}
			else
			{
				DisconnectSQL();
			}
		}
		CloseHandle(hQuery);
		
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		char steamid_plaignant[20];
		
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);CloseHandle(hQuery);
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
	}
	else if (action == MenuAction_Select)
	{
		char info[50];
		DisplayBanClientMenu(client);
		menu.GetItem(param2,info, sizeof(info));
		char steamid_plaignant[20];
		char szClientNameSQL[50];
		char szClientTypeSQL[50];
		
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		
		SQL_EscapeString(g_hDatabase, info, szClientTypeSQL, sizeof(szClientTypeSQL));
		SQL_EscapeString(g_hDatabase, steamid_plaignant, szClientNameSQL, sizeof(szClientNameSQL));
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "UPDATE `plainte_se` SET `type`='%s' WHERE `authid_plaignant`='%s'", 
			szClientTypeSQL, steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
		
	}
	return 0;
}



void DisplayBanClientMenu(int client)
{
	Menu menu2 = CreateMenu(MenuHandler_Freekilleur);

	char sUserId[12];
	char sName[MAX_NAME_LENGTH];
	char sDisplay[MAX_NAME_LENGTH+15];
	/* :TODO: we should either remove this or make it configurable */
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==3)
		{
			IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));     
			GetClientName(i, sName, sizeof(sName));
			Format(sDisplay, sizeof(sDisplay), "%s", sName);
			menu2.AddItem(sUserId,sDisplay);
		}
	}
	menu2.SetTitle("Freekilleur");
	menu2.ExitButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Freekilleur(Menu menu, MenuAction action, int client, int param2)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	if (action == MenuAction_End)
	{
		char steamid_plaignant[20];
		
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);
			
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		char steamid_plaignant[20];
		
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
	}
	else if (action == MenuAction_Select)
	{
		char info[50];
		DisplayBanLieuMenu(client);
		menu.GetItem(param2,info, sizeof(info));
		int userid_freekilleur = StringToInt(info);
		int freekilleur = GetClientOfUserId(userid_freekilleur);
		char steamid_plaignant[20];
		char steamid_freekilleur[20];
		char name_freekilleur[60];
		char szClientNameSQL[50];
		
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		GetClientAuthId(freekilleur, AuthId_Steam2, steamid_freekilleur,20);
		GetClientName(freekilleur, name_freekilleur, 60);
		
		SQL_EscapeString(g_hDatabase, name_freekilleur, szClientNameSQL, sizeof(szClientNameSQL));
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "UPDATE `plainte_se` SET `authid_freekilleur`='%s', `name_freekilleur`='%s' WHERE `authid_plaignant`='%s'", 
			steamid_freekilleur, name_freekilleur, steamid_plaignant);
			//PrintToChat(client, "%s  :  %s  :  %s", freekilleur, szClientNameSQL, steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
		
	}
	return 0;
}

void DisplayBanLieuMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_BanLieuList);

	
	menu.SetTitle("Lieu du freekill");
	
	menu.ExitButton = true;
	
	
	
	/* :TODO: we should either remove this or make it configurable */
	menu.AddItem("Insulte", "Dans le chat (pour insulte)");
	menu.AddItem("Piscine", "Piscine");
	menu.AddItem("Armurerie", "Armurerie apres 7:30");
	menu.AddItem("Jail", "Jail");
	menu.AddItem("Foot", "Foot");
	menu.AddItem("Disco", "Disco");
	menu.AddItem("Climb", "Climb");
	menu.AddItem("Simon Say", "Simon Say");
	menu.AddItem("Toilette", "Toilette");
	menu.AddItem("Infirmerie", "Infirmerie");
	menu.AddItem("Big Jail", "Big Jail");
	menu.AddItem("Refectoire", "Refectoire");
	menu.AddItem("Salle des commandes", "Salle des commandes");
	menu.AddItem("Isoloire", "Isoloire");
	menu.AddItem("Labyrinthes", "Labyrinthes");
	menu.AddItem("Jeux des canapes", "Jeux des canapes");
	menu.AddItem("Jeux de course", "Jeux de course");
	menu.AddItem("Autre", "Autre preciser dans le chat");

	menu.Display(client, MENU_TIME_FOREVER);
}


public int MenuHandler_BanLieuList(Menu menu, MenuAction action, int client, int param2)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	if (action == MenuAction_End)
	{
		char steamid_plaignant[20];
		if(client)
		{
			if(IsClientInGame(client))
			{
				GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
				if(CheckSQL())
				{
					Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
					hQuery = SQL_Query(g_hDatabase, sQuery);
				}
				else
				{
					DisconnectSQL();
				}
				CloseHandle(hQuery);
			}
		}
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		char steamid_plaignant[20];
		
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
	}
	else if (action == MenuAction_Select)
	{
		char info[40];
		menu.GetItem(param2, info, sizeof(info));
		g_IsWaitingForChatReason[client] = true;
		PrintToChat(client, "\x02[Plainte-SE]\x06 Tapez plus en details votre plainte dans le chat, ce sera enregistré, merci de patienter par la suite");
		PrintToChat(client, "\x02[Plainte-SE]\x06  Tapez /annuler pour annuler votre plainte !");
		char steamid_plaignant[20];
		GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "UPDATE `plainte_se` SET `lieu`='%s' WHERE `authid_plaignant`='%s'", 
			info, steamid_plaignant);
			hQuery = SQL_Query(g_hDatabase, sQuery);
		}
		else
		{
			DisconnectSQL();
		}
		CloseHandle(hQuery);
	}
	return 0;
}

public Action Command_Say(int client, int args)
{
	char Cmd[128];
	GetCmdArgString(Cmd, 127);
	StripQuotes(Cmd);
	TrimString(Cmd);
	char sText[192];
	int Start = 0;

	GetCmdArgString(sText, sizeof(sText));

	if (sText[strlen(sText)-1] == '"')
	{
		sText[strlen(sText)-1] = '\0';
		Start = 1;
	}

	if(g_IsWaitingForChatReason[client])
	{
		g_IsWaitingForChatReason[client] = false;
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		if (strcmp(sText[Start], "/annuler", false) == 0)
		{
			char steamid_plaignant[20];
			GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
			if(CheckSQL())
			{
				Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant='%s'", steamid_plaignant);
				hQuery = SQL_Query(g_hDatabase, sQuery);
			}
			else
			{
				DisconnectSQL();
			}
			CloseHandle(hQuery);
			return Plugin_Handled;
		}
		else
		{
			char steamid_plaignant[20];
			char szClientNameSQL[255];
			GetClientAuthId(client, AuthId_Steam2, steamid_plaignant,20);
			SQL_EscapeString(g_hDatabase, Cmd, szClientNameSQL, sizeof(szClientNameSQL));
			if(CheckSQL())
			{
				Format(sQuery, sizeof(sQuery), "UPDATE `plainte_se` SET `info`='%s' WHERE `authid_plaignant`='%s'", szClientNameSQL, steamid_plaignant);
				ServerCommand("say_team @UNE PLAINTE VIENT D'ETRE POSTER !!! /listeplainte pour la voir. Merci");
				hQuery = SQL_Query(g_hDatabase, sQuery);
			}
			else
			{
				DisconnectSQL();
			}
			CloseHandle(hQuery);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}




public void ConnectBDD()
{
	// On check la config présente dans database.cfg
	if (SQL_CheckConfig(DATABASE_NAME))
	{
		char error[255];
		// On créé une connexion à la base de donné via la config présente dans database.cfg
		g_hDatabase = SQL_Connect(DATABASE_NAME,true,error, sizeof(error));
		if (g_hDatabase == INVALID_HANDLE)
		{
			LogMessage("Erreur de connexion: %s", error);
		}
		else
		{
			LogMessage("Connexion à la BDD MySQL réussie");
		}
	}
	else
	{
		LogError("Impossible de trouvé <%s> dans le fichier databases.cfg", DATABASE_NAME);
	}

}


public bool DisconnectSQL()
{
	if(g_hDatabase != INVALID_HANDLE)
	{
		CloseHandle(g_hDatabase);
		g_hDatabase = INVALID_HANDLE;
	}
	
	return true;
}

public bool CheckSQL()
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		ConnectBDD();
		return false ;
	}
	
	return true;
}