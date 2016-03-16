#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

#define	PLUGIN_NAME			"plainte_se"
#define	PLUGIN_AUTHOR		"Dertione"
#define	PLUGIN_DESCRIPTION	"susteme plainte pour jailbreak"
#define	PLUGIN_VERSION		"0.1"
#define	PLUGIN_URL			"http://www.supreme-elite.fr/"
#define DATABASE_NAME "dertione"

//Handle hTopMenu = INVALID_HANDLE;

Handle g_hDatabase = INVALID_HANDLE;
char Steam_id[20];

public Plugin myinfo =
{
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url			= PLUGIN_URL,
};



public void OnPluginStart()
{
	RegConsoleCmd("listeplainte", Command_Plainte, "", 0);
}

public void OnMapStart()
{
	ConnectBDD();
}

public void OnMapEnd()
{
	DisconnectSQL();
}


public Action Command_Plainte(int client, int args)
{
	if (IsAdmin(client) || IsRoot(client))
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		char NameOfP[50];
		char PlainteDe[65];
		char SteamIdOfP[4];
		int id;
		/* :TODO: we should either remove this or make it configurable */
		if(CheckSQL())
		{
			Format(sQuery, sizeof(sQuery), "SELECT id, name_plaignant FROM plainte_se ORDER BY date DESC");
			hQuery = SQL_Query(g_hDatabase, sQuery);
			if(g_hDatabase == INVALID_HANDLE)
			{
				LogError("Query failed! ");
			}
			else if(!SQL_GetRowCount(hQuery))
			{
				SendPanelToAll(client,"Aucune plainte");
			}
			else
			{
				Menu menu2 = CreateMenu(MenuHandler_Plaintif);
				while(SQL_FetchRow(hQuery))
				{
					id = SQL_FetchInt(hQuery,0);
					//SQL_FetchString(hQuery, 0, SteamIdOfP, sizeof(SteamIdOfP));
					SQL_FetchString(hQuery, 1, NameOfP, sizeof(NameOfP));
					Format(PlainteDe, 65, "Plainte de %s", NameOfP);
					IntToString(id, SteamIdOfP,4);
					menu2.AddItem(SteamIdOfP, PlainteDe);
				}
				menu2.SetTitle("Plaignant");
				menu2.ExitButton = true;
				menu2.Display(client, MENU_TIME_FOREVER);
			}
			CloseHandle(hQuery);
		}
		else
		{
			DisconnectSQL();
		}
	}
	else
	{
		PrintToChat(client,"\x02[Plainte-SE]\x06 Cette commande est restreind aux admins");
	}
}

public int MenuHandler_Plaintif(Menu menu, MenuAction action, int client, int param2)
{
	/*Handle hQuery = INVALID_HANDLE;
	char sQuery[255];*/
	if (action == MenuAction_End)
	{
		delete menu;
		menu = null;
		/*char steamid_plaignant[20];
		GetClientAuthString(client, steamid_plaignant,20);
		
		Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant=%s", steamid_plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);*/
	}
	else if (action == MenuAction_Cancel)
	{
		/*char steamid_plaignant[20];
		GetClientAuthString(client, steamid_plaignant,20);
		
		Format(sQuery, sizeof(sQuery), "DELETE FROM plainte_se WHERE authid_plaignant=%s", steamid_plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);*/
	}
	else if (action == MenuAction_Select)
	{
		char info[4];
		menu.GetItem(param2, info, sizeof(info));
		DisplayPlainteMenu(client, info);
	}
	return 0;
}

static void DisplayPlainteMenu(int client,char [] id_Plaignant)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	char NameOfP[50];
	char NameOfTitle[65];
	char Info[128];
	Panel hPanel = CreatePanel();
	if(CheckSQL())
	{
		Format(sQuery, sizeof(sQuery), "SELECT `name_plaignant` FROM `plainte_se` WHERE `id`='%s'",id_Plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);	
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, NameOfP, sizeof(NameOfP));
		Format(NameOfTitle, 65, "Plainte de %s", NameOfP);
		hPanel.SetTitle(NameOfP);
		hPanel.DrawItem("Close");
		
		Format(Steam_id, 20, id_Plaignant);
		
		Format(sQuery, sizeof(sQuery), "SELECT `type` FROM `plainte_se` WHERE `id`='%s'",id_Plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);	
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, NameOfP, sizeof(NameOfP));
		Format(NameOfTitle, 65, "Type : %s", NameOfP);
		hPanel.DrawText(NameOfTitle);
		Format(sQuery, sizeof(sQuery), "SELECT `name_freekilleur` FROM `plainte_se` WHERE `id`='%s'",id_Plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);	
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, NameOfP, sizeof(NameOfP));
		Format(NameOfTitle, 65, "Suspect : %s", NameOfP);
		hPanel.DrawText(NameOfTitle);
		
		Format(sQuery, sizeof(sQuery), "SELECT `lieu` FROM `plainte_se` WHERE `id`='%s'",id_Plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);	
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, NameOfP, sizeof(NameOfP));
		Format(NameOfTitle, 65, "Lieu : %s", NameOfP);
		hPanel.DrawText(NameOfTitle);
		
		DrawPanelText(hPanel, "Information supplementaire :");
		Format(sQuery, sizeof(sQuery), "SELECT `info` FROM `plainte_se` WHERE `id`='%s'",id_Plaignant);
		hQuery = SQL_Query(g_hDatabase, sQuery);	
		SQL_FetchRow(hQuery);
		SQL_FetchString(hQuery, 0, Info, sizeof(Info));
		hPanel.DrawText(Info);
		
		hPanel.DrawItem("Plainte traité");
		hPanel.DrawItem("Plainte bidon");
		hPanel.Send(client, PanelHandler1, MENU_TIME_FOREVER);
		CloseHandle(hQuery);
	}
	delete hPanel;
}

public int PanelHandler1(Handle menu, MenuAction action, int client, int param2)
{
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	if (action == MenuAction_Select)
	{
		if(CheckSQL())
		{
			if(param2 == 2)
			{

				Format(sQuery, sizeof(sQuery), "DELETE FROM `plainte_se` WHERE `id`='%s'", Steam_id);
				hQuery = SQL_Query(g_hDatabase, sQuery);
				CloseHandle(hQuery);
			}
			if(param2 == 3)
			{
				PrintToChatAll("\x02[Plainte-SE]\x06 Les plaintes bidons sont sévérement punis, ne l'oubliez pas !!!!!");
				Format(sQuery, sizeof(sQuery), "DELETE FROM `plainte_se` WHERE `id`='%s'", Steam_id);
				hQuery = SQL_Query(g_hDatabase, sQuery);
				CloseHandle(hQuery);
			}
		}
		else
		{
			DisconnectSQL();
		}
	}
	return true;
}


static bool IsRoot(int client)
{
	char steamId[30];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	if (GetUserFlagBits(client) & ADMFLAG_ROOT) return true;
	else return false;
}

static bool IsAdmin(int client)
{
	char steamId[30];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	if (GetUserFlagBits(client) & ADMFLAG_SLAY) return true;
	else if (GetUserFlagBits(client) & ADMFLAG_GENERIC) return true;
	else if (GetUserFlagBits(client) & ADMFLAG_BAN) return true;
	else return false;
}

void SendPanelToAll(int from, char [] message)
{	
	ReplaceString(message, 192, "\\n", "\n");
	
	Panel mSayPanel = CreatePanel();
	mSayPanel.SetTitle("Liste Plainte");
	mSayPanel.DrawItem( "", ITEMDRAW_SPACER);
	mSayPanel.DrawText(message);
	mSayPanel.DrawItem("", ITEMDRAW_SPACER);
	mSayPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
	mSayPanel.Send(from, Handler_DoNothing, 10);

	CloseHandle(mSayPanel);
}

public int Handler_DoNothing(Handle menu, MenuAction action, int param1, int param2)
{
	/* Do nothing */
	return 0;
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


static bool DisconnectSQL()
{
	if(g_hDatabase != INVALID_HANDLE)
	{
		CloseHandle(g_hDatabase);
		g_hDatabase = INVALID_HANDLE;
	}
	
	return true;
}

static bool CheckSQL()
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		ConnectBDD();
		return false ;
	}
	
	return true;
}