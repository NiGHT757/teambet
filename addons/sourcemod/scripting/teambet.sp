#pragma semicolon 1
#pragma newdecls required;

#include <sourcemod>

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
	version = "0.7",
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
	int iWinner = event.GetInt("winner");
	if(iWinner == 2 || iWinner == 3)
	{
		int iAmount, iClientBalance;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || g_iPlayerBet[i][BET_TEAM] == 0)
				continue;
			
			iClientBalance = GetEntProp(i, Prop_Send, "m_iAccount");

			if(iWinner == g_iPlayerBet[i][BET_TEAM])
			{
				iAmount = iClientBalance + g_iPlayerBet[i][BET_SUM] > g_iMaxMoney ? g_iMaxMoney - iClientBalance + g_iPlayerBet[i][BET_SUM] : iClientBalance + g_iPlayerBet[i][BET_SUM];
				PrintToChat(i, "[\x02TeamBet\x01] You won \x04$%d\x01.", iAmount - iClientBalance);
				SetEntProp(i, Prop_Send, "m_iAccount", iAmount);
			}
			else{
				PrintToChat(i, "[\x02TeamBet\x01] You lost \x02$%d\x01.", g_iPlayerBet[i][BET_SUM]);
				SetEntProp(i, Prop_Send, "m_iAccount", iClientBalance - g_iPlayerBet[i][BET_SUM]);
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
	if(!client || !IsClientInGame(client))
		return;

	if(!sArgs[2] || sArgs[0] == '!' || sArgs[0] == '/')
		return;
	char sExploded[3][8];
	ExplodeString(sArgs, " ", sExploded, 3, 8);
	if(strcmp(sExploded[0], "bet", false) == 0)
	{
		if(g_iPlayerBet[client][BET_SUM] != 0 || g_iPlayerBet[client][BET_TEAM] != 0)
		{
			PrintToChat(client, " \x02ERROR:\x01 You already bet, your bet: %s \x04$%d\x01.", g_iPlayerBet[client][BET_TEAM] == 2 ? "\x02T\x01" : "\x0BCT\x01", g_iPlayerBet[client][BET_SUM]);
			return;
		}

		if(restrict)
		{
			PrintToChat(client, " \x02ERROR:\x01 You cannot bet right now.");
			return;
		}

		if(GetClientTeam(client) <= 1)
		{
			PrintToChat(client, " \x02ERROR:\x01 You need to be in a playable team to bet.");
			return;
		}

		if(IsPlayerAlive(client))
		{
			PrintToChat(client, " \x02ERROR:\x01 You need to be dead to bet.");
			return;
		}

		if(!HasTeamPlayersAlive(2) || !HasTeamPlayersAlive(3))
		{
			PrintToChat(client, " \x02ERROR:\x01 No players alive found in your or enemy team.");
			return;
		}

		switch(sExploded[1][0])
		{
			case 't': g_iPlayerBet[client][BET_TEAM] = 2;
			case 'c': g_iPlayerBet[client][BET_TEAM] = 3;
			default:
			{
				PrintToChat(client, " \x02ERROR:\x01 Invalid team, syntax example: \x04bet ct/t all/amount\x01.");
				g_iPlayerBet[client][BET_SUM] = 0;
				g_iPlayerBet[client][BET_TEAM] = 0;

				return;
			}
		}
		if(!sExploded[2][0])
		{
			PrintToChat(client, " \x02ERROR:\x01 Invalid amount, syntax example: \x04bet ct/t all/amount\x01.");
			g_iPlayerBet[client][BET_SUM] = 0;
			g_iPlayerBet[client][BET_TEAM] = 0;

			return;
		}
		if(strcmp(sExploded[2], "all", false) == 0)
		{
			int iValue = GetEntProp(client, Prop_Send, "m_iAccount");
			if(iValue > g_iMaxBet)
				g_iPlayerBet[client][BET_SUM] = g_iMaxBet;
			else
				g_iPlayerBet[client][BET_SUM] = iValue;
		}
		else
		{
			int iValue = StringToInt(sExploded[2]);
			if(iValue < g_iMinBet || iValue > g_iMaxBet || GetEntProp(client, Prop_Send, "m_iAccount") < iValue)
			{
				PrintToChat(client, " \x02ERROR:\x01 Invalid amount, minimum to bet: \x04%d\x01, maximum: \x02%d\x01.", g_iMinBet, g_iMaxBet);
				g_iPlayerBet[client][BET_SUM] = 0;
				g_iPlayerBet[client][BET_TEAM] = 0;
				return;
			}
			g_iPlayerBet[client][BET_SUM] = iValue;
		}
		PrintToChat(client, "[\x02TeamBet\x01] You bet %s \x04$%d\x01.", g_iPlayerBet[client][BET_TEAM] == 2 ? "\x02T\x01" : "\x0BCT\x01", g_iPlayerBet[client][BET_SUM]);
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