#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1.0"

int g_VocalCalled[MAXPLAYERS+1];
float g_LastVocalTime[MAXPLAYERS+1];
static ConVar cEnabled, cAdminsImmune, cVocalLimit, cVocalDelay, cBanTime;

public Plugin myinfo = 
{
	name = "[L4D&L4D2]人物语言限制(新语法)",
	author = "Crimson - TeddyRuxpin && ヾ藤野深月ゞ(汉化更新语法)",
	description = "限制玩家滥用生还者人物语言, 阻止生还者发声并对玩家进行相应惩罚",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=742071"
}

public void OnPluginStart()
{
	RegConsoleCmd("vocalize", Command_CallVocal);
	CreateConVar("sm_vocalize_guard_version", PLUGIN_VERSION, "[L4D&L4D2]人物语言限制插件版本", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cEnabled = CreateConVar("sm_vocalize_guard_enabled", "1", "是否启用L4D人物语言限制?[0=关 1=开]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cAdminsImmune = CreateConVar("sm_vocalize_guard_adminimmune", "1", "是否对过滤管理员?[0=否 1=是]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cVocalLimit = CreateConVar("sm_vocalize_guard_vlimit", "10", "最多允许多少次人物语言[0=无限制]", FCVAR_NOTIFY, true, 0.0);
	cVocalDelay = CreateConVar("sm_vocalize_guard_vdelay", "3", "玩家持续使用人物语言的延迟限制[0=关闭]", FCVAR_NOTIFY, true, 0.0);
	cBanTime = CreateConVar("sm_vocalize_guard_bantime", "5", "设置滥发人物语言的封禁时间[0=踢出玩家]", FCVAR_NOTIFY, true, 0.0);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_VocalCalled[i] = 0;
		g_LastVocalTime[i] = 0.0;
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_VocalCalled[client] = 0;
	g_LastVocalTime[client] = 0.0;
}

public Action Command_CallVocal(int client, int args)
{
	int iMaxVotes = cVocalLimit.IntValue;
	int flTimeDelay = cVocalDelay.IntValue;
	char sVoteType[32], sTarget[12];
	GetCmdArg(1, sVoteType, sizeof(sVoteType));
	GetCmdArg(2, sTarget, sizeof(sTarget));
	int target = GetClientOfUserId(StringToInt(sTarget));
	if(strcmp(sVoteType, "kick") == 0)
	{
		if(IsAdmin(target))
		{
			char sKickerName[32];
			GetClientName(client, sKickerName, sizeof(sKickerName));
			PrintToChat(client, "\x04[提示]\x03你不能对该玩家发起投票踢出!");
			PrintToChat(target, "\x04[提示]\x03玩家 \x04%s\x03 试图将你从服务器中踢出!", sKickerName);
			return Plugin_Handled;
		}
	}
	if(g_VocalCalled[client] == 0)
	{
		g_LastVocalTime[client] = GetEngineTime();
		g_VocalCalled[client]++;
	}
	else if(g_LastVocalTime[client] < (GetEngineTime() - flTimeDelay))
	{
		g_LastVocalTime[client] = GetEngineTime();
		if(cEnabled.BoolValue)
		{
			if((g_VocalCalled[client] == iMaxVotes) && (iMaxVotes != 0))
			{
				if(!IsAdmin(client))
				{
					RemovePlayer(client);
				}
			}
			else if(g_VocalCalled[client] == (iMaxVotes-1))
			{
				PrintToChat(client, "\x04[提示]\x03你已达到 \x04人物语音\x03 的最大发送量!");
				g_VocalCalled[client]++;
			}
			else
			{
				g_VocalCalled[client]++;
			}
		}
	}
	else
	{
		int iTimeLeft = RoundToNearest(flTimeDelay - (GetEngineTime() - g_LastVocalTime[client]));
		PrintToChat(client, "\x04[提示]\x03你必须等待 \x04%d\x03 秒后才能继续发人物语音", iTimeLeft);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool IsAdmin(int client)
{
	bool IsAdminCvar = cAdminsImmune.BoolValue;
	if(!IsAdminCvar) return false;
	AdminId admin = GetUserAdmin(client);
	if(admin == INVALID_ADMIN_ID) return false;
	return true;
}

void RemovePlayer(int client)
{
	int iBanTime = cBanTime.IntValue;
	if(!IsClientConnected(client) || !IsClientInGame(client)) return;
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	if(iBanTime == 0)
	{
		PrintToChatAll("\x04[提示]\x03%s 因滥用人物语音被踢出服务器!", sName);
		KickClient(client, "因滥用人物语音被踢出服务器!");
	}
	else if(iBanTime > 0)
	{
		PrintToChatAll("\x04[提示]\x03%s 因滥用人物语音被禁言 %d 分钟!", sName, iBanTime);
		BanClient(client, iBanTime, BANFLAG_AUTO, "Banned", "Banned", _, client);
	}
}