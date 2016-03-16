#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define	PLUGIN_NAME			"terrodumois"
#define	PLUGIN_AUTHOR		"Dertione"
#define	PLUGIN_DESCRIPTION	"terrodumois"
#define	PLUGIN_VERSION		"1.0"
#define	PLUGIN_URL			"http://www.supreme-elite.fr/"
#define DATABASE_NAME "dertione"


int kill_knife[MAXPLAYERS+1];
//new totalT = 0;
//new totalCT = 0;
//new totalJ = 0;
//new teamAlive = 1;
int flag1[MAXPLAYERS+1] = 0;
int id_client[MAXPLAYERS+1];
Handle g_hDatabase = INVALID_HANDLE;

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
	int iFcvar = FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DEMO|FCVAR_DONTRECORD;
	
	CreateConVar("se_point_base_description",		PLUGIN_DESCRIPTION,	"Description",	iFcvar);
	CreateConVar("se_point_base_version",			PLUGIN_VERSION,		"Version",		iFcvar);
	CreateConVar("se_point_base_author",			PLUGIN_AUTHOR,		"Author",		iFcvar);
	CreateConVar("se_point_base_url",				PLUGIN_URL,			"URL",			iFcvar);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	RegConsoleCmd("say", Client_Say, "", 0);
	RegConsoleCmd("rank", Command_Rank, "Commande pour voir le rank, son score");
	RegConsoleCmd("top10", Command_Rank10, "Commande pour voir le top 10 du rank, son score");
}

public void OnMapStart()
{
	//new id;
	ConnectBDD();
	//id = GetClientIdWinner();
	CheckJour();
	PrecacheModel("models/player/slow/50cent/slow.mdl",true);
	//SetWinner(id);
	//ResetTable();
	//CheckJour(id);
}

public void OnMapEnd()
{
	DisconnectSQL();
}

public void OnClientPutInServer(int client)
{
	id_client[client]=GetClientId(client);
	kill_knife[client]=0;
	updatename(client);
	PrintToChat(client, "Votre id client dans la base de donnee est %i", id_client[client]);
	PrintToChat(client, "\x02[RankTerro-SE]\x06 Rank terro activer !");
	PrintToChat(client, "\x02[RankTerro-SE]\x06 Rank terro activer !");
}

public void OnClientDisconnect(int client)
{
	GiveClientPoint(client, kill_knife[client], "ajout quand le joueur se déconnecte");
}
//////////////////////////////////////////////////////////////////////////////
//Detection du dernier terroristes///////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////





public void Event_PlayerHurt(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	int attacker = GetClientOfUserId(GetEventInt(event,"attacker"));
	
	int health = GetClientHealth(client);
	char weapon[10];
	GetEventString(event,"weapon", weapon, sizeof(weapon));

	if (IsClientConnected(client) && IsClientInGame(client) && health<=0)
	if (!(GetClientTeam(client)==2) && StrEqual(weapon, "knife"))
	{
		PrintToChat(attacker,"\x02[RankTerro-SE]\x06 Tu as gagner 1 points grace a ton cut, ton rank s'actualisera a ta deconnexion");
		kill_knife[attacker]++;
	}
}



public void Event_PlayerSpawn(Handle event,char [] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	int idwinner=0;
	flag1[client]=0;
	int team = GetClientTeam(client);
	CheckSQL();
	Handle hQuery = INVALID_HANDLE;
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT id FROM terrodumois_clients WHERE terrodumois=1");
	hQuery = SQL_Query(g_hDatabase, sQuery);
	SQL_FetchRow(hQuery);
	idwinner = SQL_FetchInt(hQuery, 0);
	PrintToChat(client,"\x02[RankTerro-SE]\x06 Tape !rank pour connaitre ton nombre de point et ta position ");
	PrintToChat(client,"\x02[RankTerro-SE]\x06 Tape !top10 pour connaitre le top 10 ");
	if(idwinner==id_client[client]&&team==2)
	{
		CreateTimer(2.0, TimerSpawn, client);
	}
	
	int team2 = Team_GetPlayerAlive(2);
	int all = All_GetPlayer();
	PrintToChat(client, "il y a %i terro", team2);
	PrintToChat(client, "il y a %i joueurs", all);
	
}

public Action TimerSpawn(Handle timer, int client)
{
	SetEntityModel(client, "models/player/slow/50cent/slow.mdl");
	PrintToChat(client,"\x04 TU ES LE NUMBER ONE");
}





public Action Client_Say(int client, int args)
{
	char Cmd[128];
	GetCmdArgString(Cmd, 127);
	StripQuotes(Cmd);
	TrimString(Cmd);
	
	if(Team_GetPlayerAlive(2)==1&&All_GetPlayer()>5)
	{
		if(flag1[client]==0)
		{
			if (StrEqual(Cmd, "!lr", true))
			{
				PrintToChat(client,"\x02[RankTerro-SE]\x06 TU as gagner 3 points grace a ta lr");
				kill_knife[client]=kill_knife[client]+3;
				flag1[client]= 1;
			}
			if (StrEqual(Cmd, "/lr", true))
			{
				kill_knife[client]=kill_knife[client]+3;
				flag1[client]= 1;
			}
		}
	}
}


public int menuHandler1(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}


public Action Command_Rank(int client, int args)
{
	int Nombre_de_point = GetClientPoint(client);
	int Position_total = GetClientTotal(client);
	int Position_joueur = GetClientPosition(client);
	char point[4];
	char point2[10]="vous avez ";
	char point3[10]=" point";
	char point4[24];
	Position_joueur++;
	IntToString(Nombre_de_point,point,sizeof(point));
	Format(point4, sizeof(point4), "%s%s", point2, point);
	Format(point4, sizeof(point4), "%s%s", point4, point3);
	
	Menu menu = CreateMenu(menuHandler1);
	menu.SetTitle("Vous etes : %i/%i", Position_joueur, Position_total);
	menu.AddItem(point4, point4 );
	menu.ExitButton = true;
	menu.Display(client, 20);
	
	return Plugin_Handled;
}

public int menuHandler10(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Command_Rank10(int client, int args)
{
	ShowMOTDPanel(client, "Top10", "http://s.supreme-elite.fr/regle/Rank/index.php", MOTDPANEL_TYPE_URL);
}


public void updatename(int iClient)
{
	if(CheckSQL())
	{
	
		char sAuth[20];
		bool valid = false;
		valid = GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));

		if(valid == false)
		{
			ThrowNativeError(2, "User auth ID not availlable yet, please try later.");
		}

		char szClientName[100];
		char szClientNameSQL[64];
		GetClientName(iClient, szClientName, sizeof(szClientName));
		SQL_EscapeString(g_hDatabase, szClientName, szClientNameSQL, sizeof(szClientNameSQL));

		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET name='%s' WHERE authid='%s'", szClientNameSQL, sAuth);
		SQL_FastQuery(g_hDatabase, sQuery);
	}
}

public void CheckJour()
{
	char buffer[10];
	FormatTime(buffer, sizeof(buffer), "%w", GetTime());
	int day = StringToInt(buffer);
	FormatTime(buffer, sizeof(buffer), "%H", GetTime());
	int hour = StringToInt(buffer);
	FormatTime(buffer, sizeof(buffer), "%M", GetTime());
	int minute = StringToInt(buffer);
	
	
	if(day==5)
	{
		PrintToServer("%i",day);
		if(hour==20)
		{
			PrintToServer("%i",hour);
			if(minute<=45&&minute>=0)
			{
				ResetTerro();
			}
		}
	}
}

public void ResetTerro()
{
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		int id;
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET terrodumois=0 ");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		
		Format(sQuery, sizeof(sQuery), "SELECT id FROM terrodumois_clients ORDER BY credit DESC LIMIT 0,1");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		id = SQL_FetchInt(hQuery, 0);
		
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET terrodumois = 1 WHERE id=%i ", id);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET credit=0 ");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		
		SQL_FetchRow(hQuery);
		delete hQuery;
	}
}

public void SetWinner(int id)
{
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET terrodumois = 1 WHERE id=%i ", id);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		delete hQuery;
	}
}

public void ResetTable()
{
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET credit=0 ");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		delete hQuery;
	}
}


public int GetClientIdWinner()
{
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "SELECT id FROM terrodumois_clients ORDER BY credit DESC LIMIT 0,1");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		return SQL_FetchInt(hQuery, 0);
	}
	return 0;
}

public int GetClientId(int iClient)
{
	char sAuth[20];
	char szClientName[100];
	char szClientNameSQL[100];
	bool valid = false;
	
	GetClientName(iClient, szClientName, sizeof(szClientName));
	SQL_EscapeString(g_hDatabase, szClientName, szClientNameSQL, sizeof(szClientNameSQL));
	
	valid = GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth));
	
	if(valid == false)
	{
		ThrowNativeError(2, "User auth ID not availlable yet, please try later.");
	}
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "SELECT id FROM terrodumois_clients WHERE authid='%s'", sAuth);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		if(SQL_GetRowCount(hQuery) == 0)
		{
			Format(sQuery, sizeof(sQuery), "INSERT INTO terrodumois_clients (authid, name, credit) VALUES('%s', '%s', 0)", sAuth, szClientNameSQL );
			hQuery = SQL_Query(g_hDatabase, sQuery);
			return SQL_GetInsertId(hQuery);
		} else {
			SQL_FetchRow(hQuery);
			return SQL_FetchInt(hQuery, 0);
		}
	}
	return 0;
}



public int GetClientPosition(int iClient)
{
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		int pointjoueur= GetClientPoint(iClient);
		Format(sQuery, sizeof(sQuery), "SELECT count(*) FROM terrodumois_clients WHERE credit > %i ", pointjoueur);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		return SQL_FetchInt(hQuery, 0);
	}
	return 0;
}

public int GetClientTotal(int iClient)
{
	if(CheckSQL())
	{
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "SELECT count(*) FROM terrodumois_clients");
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		return SQL_FetchInt(hQuery, 0);
	}
	return 0;
}


public int GetClientPoint(int iClient)
{
	if(CheckSQL())
	{
		int iClientId = GetClientId(iClient);
		Handle hQuery = INVALID_HANDLE;
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "SELECT credit FROM terrodumois_clients WHERE id=%i", iClientId);
		hQuery = SQL_Query(g_hDatabase, sQuery);
		SQL_FetchRow(hQuery);
		return SQL_FetchInt(hQuery, 0);
	}
	return 0;
}

public bool GiveClientPoint(int iClient, int ipoint, char [] sMessage)
{
	if(CheckSQL())
	{
		int iTotal = ipoint + GetClientPoint(iClient);
		int iClientId = GetClientId(iClient);
		
		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET credit = %i WHERE id=%i", iTotal, iClientId);
		SQL_Query(g_hDatabase, sQuery);
		
		return true;
	}
	return false;
}

public bool TakeClientPoint(int iClient, int ipoint, char [] sMessage)
{
	if(CheckSQL())
	{
		int iTotal = GetClientPoint(iClient) - ipoint;
		if(iTotal < 0)
		{
			iTotal = 0;
		}
		int iClientId = id_client[iClient];
		char sQuery[255];
		char sMessageBuffer[255];
		
		SQL_EscapeString(g_hDatabase, sMessage, sMessageBuffer, strlen(sMessageBuffer));
		Format(sQuery, sizeof(sQuery), "UPDATE terrodumois_clients SET credit = %i WHERE id=%i", iTotal, iClientId);
		SQL_Query(g_hDatabase, sQuery);
		
		Format(sQuery, sizeof(sQuery), "INSERT INTO terrodumois_operations (client_id, amount, date, message) VALUES(%i, %i, -%i, NOW(), '%s')", iClientId, ipoint, sMessageBuffer);
		SQL_Query(g_hDatabase, sQuery);
		
		return true;
	}
	return false;
}

static int Team_GetPlayerAlive( int team)
{
	int count;
	for(int i=1; i <= GetMaxClients(); i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
		{
			count++;
		}
	}
	return count ;
}


static int All_GetPlayer()
{
	int count;
	for(int i=1; i <= GetMaxClients(); i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1)
		{
			count++;
		}
	}
	return count;
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


stock bool DisconnectSQL()
{
	if(g_hDatabase != INVALID_HANDLE)
	{
		CloseHandle(g_hDatabase);
		g_hDatabase = INVALID_HANDLE;
	}
	
	return true;
}

stock bool CheckSQL()
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		ConnectBDD();
		return false ;
	}
	
	return true;
}