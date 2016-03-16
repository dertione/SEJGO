#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <selib>

#pragma newdecls required
#pragma semicolon 1


enum WantToLead {
	WantToLead_Ask = 0,
	WantToLead_No   = 1,
	WantToLead_Yes      = 2,
	WantToLead_YesVip   = 3,
	WantToLead_YesAdmin = 4,
};

/***************************
 * Plugin static variables *
 ***************************/

static WantToLead default_choice[MAXPLAYERS+1];

static WantToLead want_to_lead[MAXPLAYERS+1];

static int ct_leader;
static char ct_leader_name[MAX_NAME_LENGTH];
static char clan_tag_leader[MAX_NAME_LENGTH];

static bool used_vip[MAXPLAYERS+1];

static Handle ask_wtl_timer;
static Handle choose_leader_timer;
//Noblock
static int g_offsCollisionGroup;
//Timer affichage chef
static Handle g_hTimerMenuJail[MAXPLAYERS+1];

static Menu ask_wtl_menu[MAXPLAYERS+1];
static bool menu_displayed[MAXPLAYERS+1];



/*************************
 * Plugin entries points *
 *************************/

public Plugin myinfo =
{
	name = "SE/JB CT Leader",
	author = "Supreme-Elite (Sleris, Dertione)",
	description = "Supreme-Elite CT Team Leader for JailBreak Server",
	version = "1.0",
	url = "http://supreme-elite.fr/"
};

public void OnPluginStart()
{
	bool success = true;

	success &= HookEventEx("round_poststart", Event_RoundPostStart, EventHookMode_PostNoCopy);
	success &= HookEventEx("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	success &= HookEventEx("player_spawned", Event_PlayerSpawned, EventHookMode_Post);
	success &= HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post);
	success &= HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Post);

	RegConsoleCmd("wtl", Command_WantToLead, "Choose default CT team leader choice: ask, no, yes, vip");
	
	//-----------------------------------------
	// Create our ConVars
	//-----------------------------------------
	
	CreateConVar( "sm_jt", "1", "Enables the jail team ratio plugin.", FCVAR_PLUGIN );
	CreateConVar( "sm_jt_ratio", "2", "The ratio of terrorists to counter-terrorists. (Default: 1CT = 3T)", FCVAR_PLUGIN );
	CreateConVar( "sm_jt_version", "1.0.3", "There is no need to change this value.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY );
	AutoExecConfig( true, "sm_jailteams" );
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	//-----------------------------------------
	// No block
	//-----------------------------------------
	
	g_offsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");

	if(success) {
		PrintToServer("SE/JB CT Leader plugin successfully loaded !");
		LogMessage("Successfull loading");
	} else {
		SetFailState("Unable to Hook the required events or create the hud Timer");
	}

}


/**************************
 * Other plugin callbacks *
 **************************/

public void OnMapStart()
{
	for(int client = 1; client <= MaxClients; client++) {
		used_vip[client] = true;
		default_choice[client] = WantToLead_Ask;
		ask_wtl_menu[client]   = null;
		menu_displayed[client] = false;
		want_to_lead[client] = WantToLead_Ask;
	}

	if(ask_wtl_timer) {
		KillTimer(ask_wtl_timer);
		ask_wtl_timer = null;
	}

	if(choose_leader_timer) {
		KillTimer(choose_leader_timer);
		choose_leader_timer = null;
	}
}

public void OnMapEnd()
{
	// OnMapEnd is paired with OnMapStart, so keep it even empty or OnMapStart will never be called again
	
	if(ask_wtl_timer) {
		KillTimer(ask_wtl_timer);
		ask_wtl_timer = null;
	}

	if(choose_leader_timer) {
		KillTimer(choose_leader_timer);
		choose_leader_timer = null;
	}

}

public void OnClientConnected(int client)
{
	default_choice[client] = WantToLead_Ask;
	want_to_lead[client] = WantToLead_Ask;	
	ask_wtl_menu[client]   = null;
	menu_displayed[client] = false;
}

public void OnClientDisconnect(int client)
{
	default_choice[client] = WantToLead_Ask;	
	want_to_lead[client] = WantToLead_Ask;
	
	CloseWantToLead(client);
	
	if(client == ct_leader) {
		ChooseLeader(true);	
	}
}

public void OnClientPutInServer(int client)
{
	if(IsSeAdmin(client))
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}
	else
	{
		SetClientListeningFlags(client, VOICE_MUTED);
	}
	g_hTimerMenuJail[client] = CreateTimer(1.0, TimerSec , client, TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client)
{
	// TODO: Verifier que ce callback est bien appelé après chaque changement de map
	if(IsSeVip(client))
		used_vip[client] = false;
}


/************
 * Commands *
 ************/
 
public Action Command_JoinTeam(int client, char [] command, int argc) 
{
	//-----------------------------------------
	// Get the CVar T:CT ratio
	//-----------------------------------------

	int teamRatio = 2 ;
	
	//-----------------------------------------
	// Is it a human?
	//-----------------------------------------
	
	if ( ! client || ! IsClientInGame( client ) || IsFakeClient( client ) )
	{
		return Plugin_Continue;
	}
	
	//-----------------------------------------
	// Get new and old teams
	//-----------------------------------------
	
	char teamString[3];
	GetCmdArg( 1, teamString, sizeof( teamString ) );
	
	int newTeam = StringToInt(teamString);
	int oldTeam = GetClientTeam(client);
	
	//-----------------------------------------
	// Bypass for SM admins
	//-----------------------------------------
	
	if ( IsSeAdmin(client))
	{
		PrintToChat( client, "\x09[JAILBEAK-SE]\x05 Admin, Bypass", teamRatio );
		//PrintCenterText(client, "Admin, Bypass");
		return Plugin_Continue;
	}
	
	if(newTeam == 0)
	{
		PrintToChat( client, "\x09[JAILBEAK-SE]\x05 Choix automatique DESACTIVER !!", teamRatio );
		//PrintCenterText(client, "Choix automatique DESACTIVER !!");
		return Plugin_Handled;
	}
	
	
	//-----------------------------------------
	// Are we trying to switch to CT?
	//-----------------------------------------
	
	if ( newTeam == counterTerrorist && oldTeam != counterTerrorist )
	{
		int countTs 	= 0;
		int countCTs 	= 0;
		
		//-----------------------------------------
		// Count up our players!
		//-----------------------------------------
		
		countTs=Team_GetClientCountAll(2,0);
		countCTs=Team_GetClientCountAll(3,0);
		
		//-----------------------------------------
		// Are we trying to unbalance the ratio?
		//-----------------------------------------

		if ( countCTs < ( ( countTs ) / teamRatio ) || ! countCTs || IsSeStaff(client) || IsSeAdmin(client))
		{
			return Plugin_Continue;
		}
		else
		{
			//-----------------------------------------
			// Send client sound
			//-----------------------------------------
			
			ClientCommand( client, "play ui/freeze_cam.wav" );
			
			//-----------------------------------------
			// Show client message
			//-----------------------------------------
			
			//PrintCenterText(client, "l'equipe est pleine !");

			//-----------------------------------------
			// Kill the team change request
			//-----------------------------------------

			return Plugin_Handled;
		}		
	}
	
	return Plugin_Continue;
}


public Action Command_WantToLead(int client, int num_args)
{
	char choice[8];

	if(num_args != 1) {
		ReplyToCommand(client, "Need exactly one parameter");
	} else {
		GetCmdArg(1, choice, 7);
		switch(CharToLower(choice[0])) {
			case 'a': 
			{
				default_choice[client] = WantToLead_Ask;
				ReplyToCommand(client, "You will be asked if you want to lead every round start");
			}
			case 'n':
			{
				default_choice[client] = WantToLead_No;
				ReplyToCommand(client, "You will never be team leader, unless every one asked not to be also");
			}
			case 'y':
			{
				default_choice[client] = WantToLead_Yes;
				ReplyToCommand(client, "You will always participate in the team leader choice");
			}
			case 'v':
			{
				default_choice[client] = WantToLead_YesVip;
				ReplyToCommand(client, "You will always participate in the team leader choice as a vip (work only once)");
			}
			default:
			{
				ReplyToCommand(client, "Invalid choice, valid values are: ask,no,yes,vip");
			}
		}
	}

	if(default_choice[client] && GetClientTeam(client) == CS_TEAM_CT && IsPlayerAliveSafe(client)) {
		want_to_lead[client] = default_choice[client];
		if(default_choice[client] == WantToLead_YesVip && used_vip[client])
			want_to_lead[client] = WantToLead_Yes;
	}

	return Plugin_Handled;
}

/**********
 * Timers *
 **********/

public Action Timer_ChooseLeader(Handle timer)
{
	choose_leader_timer = null;

	for(int client = 1; client <= MaxClients; client++)
		CloseWantToLead(client);
	
	ChooseLeader(false);
}

public Action Timer_AskWantToLead(Handle timer)
{
	ask_wtl_timer = null;
	
	for(int client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) && GetClientTeam(client) == CS_TEAM_CT && !ct_leader && want_to_lead[client] == WantToLead_Ask) {
			want_to_lead[client] = default_choice[client];
	
			if(default_choice[client] == WantToLead_YesVip && used_vip[client])
				want_to_lead[client] = WantToLead_Yes;
	
			if(default_choice[client] == WantToLead_Ask)
			 	AskWantToLead(client);
		}
	}
}


/*****************
 * Hooked Events *
 *****************/

public void Event_RoundPostStart(Event event, const char[] name, bool dontBroadcast)
{
	ct_leader = 0;
	ct_leader_name = "...";
	
	for(int client = 1; client <= MaxClients; client++) {
		want_to_lead[client] = WantToLead_Ask;
		CloseWantToLead(client);
	}

	ask_wtl_timer = CreateTimer(1.0, Timer_AskWantToLead);
	choose_leader_timer = CreateTimer(21.0, Timer_ChooseLeader);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(ct_leader && IsClientInGame(ct_leader)) {
		CS_SetClientClanTag(ct_leader, clan_tag_leader);
		ct_leader = 0;
		ct_leader_name = "...";	
	}
	
	for(int client = 1; client <= MaxClients; client++) {
		CloseWantToLead(client);
	}

	if(ask_wtl_timer) {
		KillTimer(ask_wtl_timer);
		ask_wtl_timer = null;
	}

	if(choose_leader_timer) {
		KillTimer(choose_leader_timer);
		choose_leader_timer = null;
	}
}

public void Event_PlayerSpawned(Event event, const char[] name, bool dontBroadcast)
{
	int client;

	client = GetClientOfUserId(event.GetInt("userid"));
	
	SetEntData(client, g_offsCollisionGroup, 2, 4, true);
	
	if(GetClientTeam(client) == CS_TEAM_CT && !ct_leader) {
		want_to_lead[client] = default_choice[client];

		if(default_choice[client] == WantToLead_YesVip && used_vip[client])
			want_to_lead[client] = WantToLead_Yes;

		if(default_choice[client] == WantToLead_Ask)
		 	AskWantToLead(client);
	} else {
		want_to_lead[client] = WantToLead_No;
	}
	
	
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client;
	int killer;

	client = GetClientOfUserId(event.GetInt("userid"));
	
	if(GetClientTeam(client) == CS_TEAM_CT) {
		// This player can't be team leader any more
		want_to_lead[client] = WantToLead_No;

		if(client == ct_leader) {
			CS_SetClientClanTag(client, clan_tag_leader);
			killer = GetClientOfUserId(event.GetInt("attacker"));
			ChooseLeader(true, killer);
		}
	}

}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client;
	int team;

	client = GetClientOfUserId(event.GetInt("userid"));
	
	default_choice[client] = WantToLead_Ask;	
	want_to_lead[client] = WantToLead_Ask;

	CloseWantToLead(client);
	
	team = event.GetInt("oldteam");
	
	if(team == CS_TEAM_CT && ct_leader == client) {
		CS_SetClientClanTag(client, clan_tag_leader);		
		ChooseLeader(true);
	}
}


/*********
 * Menus *
 *********/

static bool AskWantToLead(int client)
{
	bool success = true;
	Menu menu;

	menu = CreateMenu(MenuHandler_AskWantToLead, MenuAction_Display);

	if(menu) {
		SetMenuTitle(menu, "Voulez vous être le chef ?");
		SetMenuExitButton(menu, false);
		success &= AddMenuItem(menu, "no", "Non");
		success &= AddMenuItem(menu, "yes", "Oui");
		if(!used_vip[client])
			success &= AddMenuItem(menu, "vip", "Oui (VIP)");
		if(IsSeAdmin(client))
			success &= AddMenuItem(menu, "admin", "Oui (Admin)");

		if(success)
			success &= DisplayMenu(menu, client, MENU_TIME_FOREVER);

		if(success)
			ask_wtl_menu[client] = menu;
		else
			CloseHandle(menu);
	}

	return success;
}

public int MenuHandler_AskWantToLead(Menu menu, MenuAction action, int client, int param)
{
	bool success;
	char option[8];
	char name[MAX_NAME_LENGTH];

	switch(action){
		case MenuAction_Display:
		{
			menu_displayed[client] = true;
		}
		case MenuAction_Select:
		{
			success = GetMenuItem(menu, param, option, sizeof(option));

			if(success) {
				switch(option[0]) {
					case 'n':
					{
						want_to_lead[client] = WantToLead_No;
						PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Vous ne serez probablement pas chef, mais sait on jamais");
					}
					case 'y':
					{
						want_to_lead[client] = WantToLead_Yes;
						PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Veuillez patienter, tirage au sort bientôt");
					}
					case 'v':
					{
						if(!used_vip[client]) {
							want_to_lead[client] = WantToLead_YesVip;
							PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Veuillez patienter, vous augmentez vos chances d'être chef");
							
						} else {
							want_to_lead[client] = WantToLead_Yes;
							PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Veuillez patienter, tirage au sort bientôt");
						}
					}
					case 'a':
					{
						if(IsSeAdmin(client)) {
							want_to_lead[client] = WantToLead_YesAdmin;
							PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Merci de ne pas abuser du \"Oui (Admin)\"...");
							GetClientName(client, name, sizeof(name));
							PrintToChatAll("\x09[JAILBEAK-SE]\x05 %s n'est qu'un tricheur, il a truqué le vote du chef !");
							LogAction(client, -1, "\"%s\" a sélectionné le \"Oui (Admin)\"", name);
						} else {
							want_to_lead[client] = WantToLead_Yes;
							PrintToChat(client, "\x09[JAILBEAK-SE]\x05 Veuillez patienter, tirage au sort bientôt");
						}
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			switch(param) {
				case MenuCancel_Interrupted, MenuCancel_NoDisplay:
				{
					menu_displayed[client] = false;
					DisplayMenu(menu, client, MENU_TIME_FOREVER);
				}
				default:
				{
					CloseWantToLead(client);
				}
			}
		}
	}
}

static void CloseWantToLead(int client) {
	if(ask_wtl_menu[client]) {
		if(menu_displayed[client])
			CancelClientMenu(client);
		CloseHandle(ask_wtl_menu[client]);
		ask_wtl_menu[client] = null;
		menu_displayed[client] = false;		
	}
}



/********************
 * Plugin functions *
 ********************/

static void ChooseLeader(bool death = false, int killer = 0)
{
	int num_yes_vip = 0;
	int num_yes     = 0;
	int num_alive = 0;
	int rand;
	char text_info[512];	
	char killer_name[MAX_NAME_LENGTH];

	ct_leader = 0;
	ct_leader_name = "...";

	for(int client = 1; client <= MaxClients; client++) {
		if(IsPlayerAliveSafe(client) && GetClientTeam(client) == CS_TEAM_CT) {
			num_alive++;
			if(want_to_lead[client] == WantToLead_YesAdmin)
				ct_leader = client;
			else if(want_to_lead[client] == WantToLead_YesVip)
				num_yes_vip++;
			else if(want_to_lead[client] == WantToLead_Yes)
				num_yes++;
		}
	}

	// Recursive function needs to terminate
	if(!num_alive)
		return;

	if(!ct_leader) {
		if(num_yes_vip && !death) {
			rand = GetRandomInt(1,num_yes_vip);
			for(int client = 1; client <= MaxClients; client++) {
				if(IsPlayerAliveSafe(client) && GetClientTeam(client) == CS_TEAM_CT && want_to_lead[client] == WantToLead_YesVip && !--rand) {
					ct_leader = client;
					break;
				}
			}
			used_vip[ct_leader] = true;
		} else if (num_yes || num_yes_vip) {
			rand = GetRandomInt(1,num_yes+num_yes_vip);
			for(int client = 1; client <= MaxClients; client++) {
				if(IsPlayerAliveSafe(client) && GetClientTeam(client) == CS_TEAM_CT && want_to_lead[client] > WantToLead_No && !--rand) {
					ct_leader = client;
					break;
				}
			}
		} else {
			rand = GetRandomInt(1,num_alive);
			for(int client = 1; client <= MaxClients; client++) {
				if(IsPlayerAliveSafe(client) && GetClientTeam(client) == CS_TEAM_CT && !--rand) {
					ct_leader = client;
					break;
				}
			}
		}
	}

	// Player might have died or disconnect
	if(ct_leader && IsPlayerAliveSafe(ct_leader)) {
		GetClientName(ct_leader, ct_leader_name, sizeof(ct_leader_name));
		if(death) {
			text_info  = "Le chef des gardiens est mort,\n";
			if(killer && GetURandomFloat() > 0.5){
				GetClientName(killer, killer_name, sizeof(killer_name));
				Format(text_info, sizeof(text_info), "%slâchement tué par %s après enquête,\n", text_info, killer_name);
			}
			StrCat(text_info, sizeof(text_info), "le nouveau chef est ");
		} else
			text_info = "Le chef des gardiens est ";
		StrCat(text_info, sizeof(text_info), ct_leader_name);
		SendHintTextAllInGame(text_info);
		CS_GetClientClanTag(ct_leader, clan_tag_leader, sizeof(clan_tag_leader));
		CS_SetClientClanTag(ct_leader,"Chef");
	} else {
		ChooseLeader(death, killer);
	}
}


public Action TimerSec(Handle timer, int client)
{
        int totalCT;
        int totalT;
        int totalCTAlive;
        int totalTAlive;
		
        totalTAlive = Team_GetPlayerAlive(2,0);
        totalCTAlive = Team_GetPlayerAlive(3,0);
        totalT = Team_GetClientCountAll(2,0);
        totalCT = Team_GetClientCountAll(3,0);
		
        if (totalTAlive <= 5 && totalTAlive >= 4)
        {
                int r = 1;
                while (GetMaxClients() >= r)
                {
                        if (IsClientInGame(r)&&IsPlayerAlive(r))
                        {
                                SetClientListeningFlags(r, 0);
                                r++;
                        }
                        r++;
                }
        }
        if (IsClientConnected(client))
        {
                char Text[256];
                Format(Text, 254, "");
                if(ct_leader)
                {
                        if(IsClientInGame(ct_leader))
                        {
                                Format(Text, 254, "%Chef Gardiens : %s\n", ct_leader_name);
                        }
                        else
                        {
                                Format(Text, 254, "Chef Gardiens : ...\n");
                        }
                }
                else
                {
                        Format(Text, 254, "Chef Gardiens : ...\n");
                }
                Format(Text, 254, "%sGardiens : %i / %i\n", Text, totalCTAlive, totalCT);
                Format(Text, 254, "%sPrisonniers : %i / %i\n", Text, totalTAlive, totalT);
                int Talk = GetClientListeningFlags(client);
                if (Talk == VOICE_MUTED)
                {
                        Format(Text, 254, "%sMicrophone [MUTE]\n", Text);
                }
                else
                {
                        Format(Text, 254, "%sMicrophone [ACTIF]\n", Text);
                }
				
                PrintHintText(client, "%s", Text);
        }
        else
        {
                if (g_hTimerMenuJail[client] != INVALID_HANDLE)
                {
                        KillTimer(g_hTimerMenuJail[client]);
                        g_hTimerMenuJail[client] = INVALID_HANDLE;
                }
        }
}

static int  Team_GetPlayerAlive(int team, int flags=0)
{
	flags |= ( 1	<< 7  );

	int numClients = 0;
	for (int client=1; client <= MaxClients; client++) {

		if (!Client_MatchesFilter(client, flags)) {
			continue;
		}

		if (GetClientTeam(client) == team&&IsPlayerAlive(client)) {
			numClients++;
		}
	}

	return numClients;
}

static int  Team_GetClientCountAll(int team, int flags=0)
{
	flags |= ( 1	<< 7  );

	int numClients = 0;
	for (int client=1; client <= MaxClients; client++) {

		if (!Client_MatchesFilter(client, flags)) {
			continue;
		}

		if (GetClientTeam(client) == team) {
			numClients++;
		}
	}

	return numClients;
}

static bool Client_MatchesFilter(int client, int flags)
{
	bool isIngame = false;

	if (!IsClientConnected(client)) {
		return false;
	}

	if (!flags) {
		return true;
	}

	if (flags & CLIENTFILTER_INGAMEAUTH) {
		flags |= CLIENTFILTER_INGAME | CLIENTFILTER_AUTHORIZED;
	}

	if (flags & CLIENTFILTER_BOTS && !IsFakeClient(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_NOBOTS && IsFakeClient(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_AUTHORIZED && !IsClientAuthorized(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_NOTAUTHORIZED && IsClientAuthorized(client)) {
		return false;
	}

	if (isIngame) {

		if (flags & CLIENTFILTER_ALIVE && !IsPlayerAlive(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_DEAD && IsPlayerAlive(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_SPECTATORS && GetClientTeam(client) != TEAM_SPECTATOR) {
			return false;
		}

		if (flags & CLIENTFILTER_NOSPECTATORS && GetClientTeam(client) == TEAM_SPECTATOR) {
			return false;
		}

		if (flags & CLIENTFILTER_OBSERVERS && !IsClientObserver(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_NOOBSERVERS && IsClientObserver(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_TEAMONE && GetClientTeam(client) != TEAM_ONE) {
			return false;
		}

		if (flags & CLIENTFILTER_TEAMTWO && GetClientTeam(client) != TEAM_TWO) {
			return false;
		}
	}

	return true;
}

