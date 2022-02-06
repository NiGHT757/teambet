#pragma semicolon 1
#pragma newdecls required;

#include <sourcemod>
#include <smlib>
#include <multicolors>

#define BET_SUM 1
#define BET_TEAM 2

int g_iPlayerBet[MAXPLAYERS+1][3];

bool restrict = false;

ConVar mp_maxmoney;
ConVar g_cvMaxBet;
ConVar g_cvMinBet;

int g_iMaxMoney;
int g_iMaxBet;
int g_iMinBet;

public Plugin myinfo = 
{
	name = "TeamBet",
	author = "ferret, NiGHT",
	description = "Bet on Team to Win",
	version = "0.4",
	url = "https://github.com/NiGHT757/teambet"
};

public void OnPluginStart()
{
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	g_cvMaxBet = CreateConVar("sm_teambet_maxbet", "16000", "The maximum amount to bet");
	g_cvMinBet = CreateConVar("sm_teambet_minbet", "1", "Minimum bet amount");

	mp_maxmoney = FindConVar("mp_maxmoney");
	mp_maxmoney.AddChangeHook(OnSettingsChanged);

	g_cvMaxBet.AddChangeHook(OnSettingsChanged);
	g_cvMinBet.AddChangeHook(OnSettingsChanged);

	LoadTranslations("teambet.phrases");
	AutoExecConfig(true, "teambet");
}

public void OnConfigsExecuted()
{
	g_iMaxMoney = mp_maxmoney.IntValue;
	g_iMaxBet = g_cvMaxBet.IntValue;
	g_iMinBet = g_cvMinBet.IntValue;
}

public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_cvMaxBet)
		g_iMaxBet = g_cvMaxBet.IntValue;
	else if(convar == g_cvMinBet)
		g_iMinBet = g_cvMinBet.IntValue;
	else if(convar == mp_maxmoney)
		g_iMaxMoney = mp_maxmoney.IntValue;
}

public void Event_RoundEnd(Event event, const char[] name, bool db)
{
	int team_win = event.GetInt("winner");
	if(team_win == 2 || team_win == 3)
	{
		int amount;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || g_iPlayerBet[i][BET_TEAM] == 0)
				continue;
			
			if(team_win == g_iPlayerBet[i][BET_TEAM])
			{
				amount = Client_GetMoney(i) + g_iPlayerBet[i][BET_SUM] > g_iMaxMoney ? g_iMaxMoney - Client_GetMoney(i) + g_iPlayerBet[i][BET_SUM] : Client_GetMoney(i) + g_iPlayerBet[i][BET_SUM];
				CPrintToChat(i, "%T", "Win", i, amount - Client_GetMoney(i));
				Client_SetMoney(i, amount);
			}
			else{
				Client_SetMoney(i, Client_GetMoney(i) - g_iPlayerBet[i][BET_SUM]);
				CPrintToChat(i, "%T", "Lost", i, g_iPlayerBet[i][BET_SUM]);
			}
		}
	}
	restrict = true;
}

public void Event_RoundStart(Event event, const char[] name, bool db)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iPlayerBet[i][BET_SUM] = 0;
		g_iPlayerBet[i][BET_TEAM] = 0;
	}
	restrict = false;
}

public void OnClientDisconnect(int client)
{
	g_iPlayerBet[client][BET_SUM] = 0;
	g_iPlayerBet[client][BET_TEAM] = 0;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(!IsClientInGame(client))
		return;

	if(!sArgs[2] || sArgs[0] == '!' || sArgs[0] == '/')
		return;
	char sExploded[3][8];
	ExplodeString(sArgs, " ", sExploded, 3, 8);
	if(strcmp(sExploded[0], "bet", false) == 0)
	{
		if(g_iPlayerBet[client][BET_SUM] != 0 || g_iPlayerBet[client][BET_TEAM] != 0)
		{
			CPrintToChat(client, "%T", "Already bet", client, g_iPlayerBet[client][BET_TEAM] == 2 ? "T" : "CT", g_iPlayerBet[client][BET_SUM]);
			return;
		}

		if(restrict)
		{
			CPrintToChat(client, "%T", "Cannot bet", client);
			return;
		}

		if(GetClientTeam(client) <= 1)
		{
			CPrintToChat(client, "%T", "Invalid team", client);
			return;
		}

		if(IsPlayerAlive(client))
		{
			CPrintToChat(client, "%T", "Player alive", client);
			return;
		}

		if(!HasTeamPlayersAlive(2) || !HasTeamPlayersAlive(3))
		{
			CPrintToChat(client, "%T", "No Players Alive", client);
			return;
		}

		switch(sExploded[1][0])
		{
			case 't': g_iPlayerBet[client][BET_TEAM] = 2;
			case 'c': g_iPlayerBet[client][BET_TEAM] = 3;
			default:
			{
				CPrintToChat(client, "%T", "Invalid Bet Team", client);
				g_iPlayerBet[client][BET_SUM] = 0;
				g_iPlayerBet[client][BET_TEAM] = 0;

				return;
			}
		}
		if(!sExploded[2][0])
		{
			CPrintToChat(client, "%T", "Invalid Bet Amount", client);
			g_iPlayerBet[client][BET_SUM] = 0;
			g_iPlayerBet[client][BET_TEAM] = 0;

			return;
		}
		if(strcmp(sExploded[2], "all", false) == 0)
		{
			int iValue = Client_GetMoney(client);
			if(iValue > g_iMaxBet)
				g_iPlayerBet[client][BET_SUM] = g_iMaxBet;
			else
				g_iPlayerBet[client][BET_SUM] = Client_GetMoney(client);
		}
		else
		{
			int iValue = StringToInt(sExploded[2]);
			if(iValue < g_iMinBet || iValue > g_iMaxBet || Client_GetMoney(client) < iValue)
			{
				CPrintToChat(client, "%T", "Invalid Amount", client, g_iMinBet, g_iMaxBet);
				g_iPlayerBet[client][BET_SUM] = 0;
				g_iPlayerBet[client][BET_TEAM] = 0;
				return;
			}
			g_iPlayerBet[client][BET_SUM] = iValue;
		}
		CPrintToChat(client, "%T", "Bet", client, g_iPlayerBet[client][BET_TEAM] == 2 ? "T" : "CT", g_iPlayerBet[client][BET_SUM]);
	}
	return;
}

stock bool HasTeamPlayersAlive(int team)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != team)
			continue;
		
		if(IsPlayerAlive(i))
			return true;
	}
	return false;
}