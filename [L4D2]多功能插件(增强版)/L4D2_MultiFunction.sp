

#pragma semicolon 1
#pragma dynamic 231072
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION					"1.2_NewCode"
#define LineNext 								"▬▬▬▬▬▬▬▬▬▬"
#define IsValidClient(%1)				(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsSurvivalClient(%1)		(IsValidClient(%1) && GetClientTeam(%1) == 2)
#define IsInfectedClient(%1)		(IsValidClient(%1) && GetClientTeam(%1) == 3)
#define GetCurrentHealth(%1)		(GetEntProp(%1, Prop_Data, "m_iHealth"))
#define GetMaxHealth(%1)				(GetEntProp(%1, Prop_Data, "m_iMaxHealth"))
#define IsIncapacitated(%1)			(GetEntProp(%1, Prop_Send, "m_isIncapacitated") == 1)

static char GetHitGroup[][] = {"Unknown", "头部", "胸部", "腹部", "左手", "右手", "左脚"};
static char WeaponNames[][] =
{
	"weapon_pumpshotgun", "weapon_autoshotgun", "weapon_rifle", "weapon_smg", "weapon_hunting_rifle", 
	"weapon_sniper_scout", "weapon_sniper_military", "weapon_sniper_awp", "weapon_smg_silenced", "weapon_smg_mp5",
	"weapon_shotgun_spas", "weapon_shotgun_chrome", "weapon_rifle_sg552", "weapon_rifle_desert", "weapon_rifle_ak47",
	"weapon_grenade_launcher", "weapon_rifle_m60", "weapon_pistol", "weapon_pistol_magnum", "weapon_chainsaw",
	"weapon_melee", "weapon_pipe_bomb", "weapon_molotov", "weapon_vomitjar", "weapon_first_aid_kit", "weapon_defibrillator",
	"weapon_upgradepack_explosive", "weapon_upgradepack_incendiary", "weapon_pain_pills", "weapon_adrenaline",
	"weapon_gascan", "weapon_propanetank", "weapon_oxygentank", "weapon_gnome", "weapon_cola_bottles", "weapon_fireworkcrate"
};

static float g_iPlayerTeamTimer, PlayeChangeTimer[MAXPLAYERS+1];
static char GetMapName[64], g_cAttackCurrentChar[8], g_cAttackDamagesChar[8];
static int g_iPlayerTeamCount, PlayeChangeCount[MAXPLAYERS+1], RoundFailCount, g_iAttackHealthSetMode, g_iAttackHealthMaxLeng, g_iCharLength;
static bool g_bPlayerAwayEnable, g_bPlayerJoinEnable, g_bPlayerKillEnable, g_bPlayerBotsEnable, g_bPlayerTeamEnable, g_bPlayerChangeName, g_bOnReStartServer, 
	g_bReStarLevelMaps, g_bReStarRoundEnable, g_bConnectedEnable, g_bReSurvivalHealth, g_bSurvivalWeaponDrop, g_bAttackHealthDisplay;
ConVar g_hPlayerAwayEnable, g_hPlayerJoinEnable, g_hPlayerKillEnable, g_hPlayerBotsEnable, g_hPlayerTeamEnable, g_hPlayerTeamCount, 
	g_hPlayerTeamTimer, g_hPlayerChangeName, g_hOnReStartServer, g_hReStarLevelMaps, g_hReStarRoundEnable, g_hConnectedEnable, g_hReSurvivalHealth, 
	g_hSurvivalWeaponDrop, g_hAttackHealthDisplay, g_hAttackHealthSetMode, g_hAttackHealthMaxLeng, g_hAttackCurrentChar, g_hAttackDamagesChar;


public Plugin myinfo = 
{
	name = "[L4D2]多功能插件(增强版)",
	author = "ヾ藤野深月ゞ",
	description = "该插件包含闲置、自杀、加入游戏等多功能整合插件, 具体详情请查阅CFG文件",
	version = PLUGIN_VERSION,
	url = "https://github.com/az1422/Tysy_Other"
}

public void OnPluginStart()
{
	/* CFG参数 */
	CreateConVar("L4D2_MultiFunction_Version", PLUGIN_VERSION, "[L4D2]多功能插件版本(增强版)");
	g_hPlayerAwayEnable				= CreateConVar("L4D2_MultiFunction_AwayEnable",				"1",		"是否开启玩家使用闲置功能？ [0=禁用 1=启用] (闲置指令：!away)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hPlayerJoinEnable				= CreateConVar("L4D2_MultiFunction_JoinEnable",				"1",		"是否开启玩家使用加入功能？ [0=禁用 1=启用] (加入指令：!jg & !join & !joingame)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hPlayerKillEnable				= CreateConVar("L4D2_MultiFunction_KillEnable",				"1",		"是否开启玩家使用自杀功能？[0=禁用 1=启用] (自杀指令：!kill & !zs)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hPlayerBotsEnable				= CreateConVar("L4D2_MultiFunction_BotsEnable",				"1",		"是否开启玩家使用增删电脑玩家功能？[0=禁用 1=启用](增加：!jdn & !addbot 踢出：!tdn & !kickallbot)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hPlayerTeamEnable				= CreateConVar("L4D2_MultiFunction_TeamEnable",				"1",		"是否开启玩家使用换队功能？[0=禁用 1=启用] (换队指令：!team 对抗专用)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hPlayerTeamCount				= CreateConVar("L4D2_MultiFunction_TeamCount",				"3",		"设置玩家使用功能换队次数(0=无限制)", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hPlayerTeamTimer				= CreateConVar("L4D2_MultiFunction_TeamTimer",				"30.0",	"设置玩家使用转换队伍CD时间(秒)", FCVAR_NOTIFY, true, 8.0, true, 1800.0);
	g_hPlayerChangeName				= CreateConVar("L4D2_MultiFunction_ChangeName",				"1",		"是否开启服务器禁止玩家更名功能？ [0=禁用 1=启用]", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hOnReStartServer				= CreateConVar("L4D2_MultiFunction_ReServers",				"1",		"是否开启服务器重启功能？ [0=禁用 1=启用] (管理员指令：!restart & !res)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hReStarLevelMaps				= CreateConVar("L4D2_MultiFunction_ReLevelMap",				"1",		"是否开启重启当前地图功能？ [0=禁用 1=启用] (管理员指令：!restartmap & !rem)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hReStarRoundEnable			= CreateConVar("L4D2_MultiFunction_RestarRound",			"1",		"是否开启在团灭时显示团灭次数功能？ [0=禁用 1=启用]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hConnectedEnable				= CreateConVar("L4D2_MultiFunction_Connected",				"0",		"是否开启玩家连接(断开)服务器时的提示功能？ [0=禁用 1=启用]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hReSurvivalHealth				= CreateConVar("L4D2_MultiFunction_ReSurHealth",			"1",		"是否开启过关幸存者自动补充生命值？ [0=禁用 1=启用]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSurvivalWeaponDrop			= CreateConVar("L4D2_MultiFunction_WeaponDrop",				"1",		"是否开启过幸存者丢弃当前武器功能？ [0=禁用 1=启用] (丢弃指令：!d & !g & !drop)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hAttackHealthDisplay		= CreateConVar("L4D2_MultiFunction_HealthDisplay",		"1",		"是否开启攻击者显示受害者血量功能？ [0=禁用 1=启用]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hAttackHealthSetMode		= CreateConVar("L4D2_MultiFunction_HealthSetMode",		"0",		"设置攻击者显示受害者血量的显示模式？ [0=图形 1=文字]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hAttackHealthMaxLeng		= CreateConVar("L4D2_MultiFunction_HealthMaxLeng",		"50",		"设置攻击者显示受害者血量的显示长度？", FCVAR_NOTIFY, true, 10.0, true, 200.0);
	g_hAttackCurrentChar			= CreateConVar("L4D2_MultiFunction_HealthCurrent",		"#",		"设置攻击者显示受害者血量的健康血量符号");
	g_hAttackDamagesChar			= CreateConVar("L4D2_MultiFunction_HealthDamages",		"=",		"设置攻击者显示受害者血量的显受伤血量符号");
	ChangeConVarExecuted();
	/* 注册指令 */
	RegConsoleCmd("sm_away",			Command_PlayerAway,		"玩家闲置");
	RegConsoleCmd("sm_jg",				Command_PlayerJoin,		"加入游戏");
	RegConsoleCmd("sm_join",			Command_PlayerJoin,		"加入游戏");
	RegConsoleCmd("sm_joingame",	Command_PlayerJoin,		"加入游戏");
	RegConsoleCmd("sm_kill",			Command_PlayerKill,		"玩家自杀");
	RegConsoleCmd("sm_zs",				Command_PlayerKill,		"玩家自杀");
	RegConsoleCmd("sm_tdn",				Command_KickAllBot,		"踢电脑");
	RegConsoleCmd("sm_kickbot",		Command_KickAllBot,		"踢电脑");
	RegConsoleCmd("sm_addbot",		Command_AddOneBot,		"加电脑");
	RegConsoleCmd("sm_jdn",				Command_AddOneBot,		"加电脑");
	RegConsoleCmd("sm_Team",			Command_PlayerTeam,		"选择团队");
	RegConsoleCmd("sm_g",					Command_WeaponDrop,		"丢弃武器");
	RegConsoleCmd("sm_d",					Command_WeaponDrop,		"丢弃武器");
	RegConsoleCmd("sm_drop",			Command_WeaponDrop,		"丢弃武器");
	RegAdminCmd("sm_restart", 		Command_ReStartServer,		ADMFLAG_ROOT,		"重启服务器");
	RegAdminCmd("sm_res", 				Command_ReStartServer,		ADMFLAG_ROOT,		"重启服务器");
	RegAdminCmd("sm_restartmap", 	Command_ReStartLevelMaps,	ADMFLAG_ROOT,		"重启当前地图");
	RegAdminCmd("sm_rem", 				Command_ReStartLevelMaps,	ADMFLAG_ROOT,		"重启当前地图");
	/* Hook */
	HookEvent("infected_hurt",						Event_InfectedHurt,				EventHookMode_Post);
	HookEvent("player_hurt",							Event_PlayerHurt,					EventHookMode_Post);
	HookEvent("player_changename",				Event_PlayerChangeName,		EventHookMode_Post);
	HookEvent("round_start",							Event_RoundStart,					EventHookMode_PostNoCopy);
	HookEvent("round_start",							Event_SaveMapsInfo,				EventHookMode_PostNoCopy);
	HookEvent("mission_lost",							Event_MissionLost,				EventHookMode_PostNoCopy);
	HookEvent("map_transition", 					Event_RoundWin,						EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving",		Event_RoundWin,						EventHookMode_PostNoCopy);
	HookUserMessage(GetUserMessageId("SayText2"), Message_ChangeUserName, true);
	/* 创建Config */
	AutoExecConfig(true, "L4D2_MultiFunction");
}

/* -----------------------------------------------------------
					ConfigsExecuted
----------------------------------------------------------- */
public void OnConfigsExecuted()
{
	LoadAllowedCvar();
	LoadConVarString();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	LoadAllowedCvar();
	LoadConVarString();
}

public void ChangeConVarExecuted()
{
	g_hPlayerAwayEnable.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerJoinEnable.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerKillEnable.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerBotsEnable.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerTeamEnable.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerTeamCount.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerTeamTimer.AddChangeHook(ConVarChanged_Allow);
	g_hPlayerChangeName.AddChangeHook(ConVarChanged_Allow);
	g_hOnReStartServer.AddChangeHook(ConVarChanged_Allow);
	g_hReStarLevelMaps.AddChangeHook(ConVarChanged_Allow);
	g_hReStarRoundEnable.AddChangeHook(ConVarChanged_Allow);
	g_hConnectedEnable.AddChangeHook(ConVarChanged_Allow);
	g_hReSurvivalHealth.AddChangeHook(ConVarChanged_Allow);
	g_hSurvivalWeaponDrop.AddChangeHook(ConVarChanged_Allow);
	g_hAttackHealthDisplay.AddChangeHook(ConVarChanged_Allow);
	g_hAttackHealthSetMode.AddChangeHook(ConVarChanged_Allow);
	g_hAttackHealthMaxLeng.AddChangeHook(ConVarChanged_Allow);
	g_hAttackCurrentChar.AddChangeHook(ConVarChanged_Allow);
	g_hAttackDamagesChar.AddChangeHook(ConVarChanged_Allow);
}

public void LoadAllowedCvar()
{
	g_bPlayerAwayEnable	=	g_hPlayerAwayEnable.BoolValue;
	g_bPlayerJoinEnable	=	g_hPlayerJoinEnable.BoolValue;
	g_bPlayerKillEnable	=	g_hPlayerKillEnable.BoolValue;
	g_bPlayerBotsEnable	=	g_hPlayerBotsEnable.BoolValue;
	g_bPlayerTeamEnable	=	g_hPlayerTeamEnable.BoolValue;
	g_bPlayerChangeName = g_hPlayerChangeName.BoolValue;
	g_bOnReStartServer	=	g_hOnReStartServer.BoolValue;
	g_bReStarLevelMaps	=	g_hReStarLevelMaps.BoolValue;
	g_iPlayerTeamCount	=	g_hPlayerTeamCount.IntValue;
	g_iPlayerTeamTimer	=	g_hPlayerTeamTimer.FloatValue;
	g_bReStarRoundEnable=	g_hReStarRoundEnable.BoolValue;
	g_bConnectedEnable	=	g_hConnectedEnable.BoolValue;
	g_bReSurvivalHealth	=	g_hReSurvivalHealth.BoolValue;
	g_bSurvivalWeaponDrop = g_hSurvivalWeaponDrop.BoolValue;
	g_bAttackHealthDisplay = g_hAttackHealthDisplay.BoolValue;
	g_iAttackHealthSetMode = g_hAttackHealthSetMode.IntValue;
	g_iAttackHealthMaxLeng = g_hAttackHealthMaxLeng.IntValue;
}

public void LoadConVarString()
{
	GetConVarString(g_hAttackCurrentChar, g_cAttackCurrentChar, sizeof(g_cAttackCurrentChar));
	GetConVarString(g_hAttackDamagesChar, g_cAttackDamagesChar, sizeof(g_cAttackDamagesChar));
	g_iCharLength = strlen(g_cAttackCurrentChar);
	if(!g_iCharLength || g_iCharLength != strlen(g_cAttackDamagesChar)){
		g_iCharLength = 1;
	}
}
/* -----------------------------------------------------------
					Connected
----------------------------------------------------------- */
public void OnClientConnected(int client)
{
	if(IsFakeClient(client)) return;
	ReSetPlayerChangeData(client);
	if(g_bConnectedEnable)
		PrintToChatAll("\x04[提示]\x03当前人数为:\x04(%d/%d)\x03, 玩家\x05 %N \x03正在加入游戏...", GetAllPlayerCount(), GetMaxPlayerCount(), client);
}

/* 玩家离开游戏 */
public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client)) return;
	ReSetPlayerChangeData(client);
	if(g_bConnectedEnable)
		PrintToChatAll("\x04[提示]\x03当前人数为:\x04(%d/%d)\x03, 玩家\x05 %N \x03已经离开游戏...", GetAllPlayerCount(), GetMaxPlayerCount(), client);
}

public void ReSetPlayerChangeData(int client)
{
	if(!g_bPlayerTeamEnable) return;
	PlayeChangeCount[client] = 0;
	PlayeChangeTimer[client] = 0.0;
}

public void ReSurvivalHealthStart(int client)
{
	if(!IsSurvivalClient(client) || !g_bReSurvivalHealth) return;
	CheatCommand(client, "give", "health");
	L4D_SetPlayerTempHealth(client, 0);
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsSurvivalClient(i) || !IsPlayerAlive(i)) continue;
		ReSurvivalHealthStart(i);
	}
	return Plugin_Continue;
}

/* -----------------------------------------------------------
					Event
----------------------------------------------------------- */
public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bAttackHealthDisplay) return;
	int victim = event.GetInt("entityid");
	int client = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsSurvivalClient(client) || IsFakeClient(client) || !IsValidEntity(victim)) return;
	static char ClassName[64];
	GetEdictClassname(victim, ClassName, sizeof(ClassName));
	int Damage = event.GetInt("dmg_health");
	int GetHealthCount = GetCurrentHealth(victim) - Damage;
	if(g_iAttackHealthSetMode == 0)
	{
		PrintShowHealth(client, victim, g_iAttackHealthMaxLeng, GetHealthCount, GetMaxHealth(victim), ClassName);
		return;
	}
	if(g_iAttackHealthSetMode == 1)
	{
		PrintCenterText(client,"你的攻击对 (%d)%s 造成了 %d 伤害, HP: [%d / %d]", victim, ClassName, Damage, GetHealthCount, GetMaxHealth(victim));
		return;
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bAttackHealthDisplay) return;
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int client = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(client) || !IsValidClient(victim) || IsFakeClient(client)) return;
	if(g_iAttackHealthSetMode == 0)
	{
		static char ClassName[64];
		GetClientName(victim, ClassName, sizeof(ClassName));
		PrintShowHealth(client, victim, g_iAttackHealthMaxLeng, GetCurrentHealth(victim), GetMaxHealth(victim), ClassName);
		return;
	}
	if(g_iAttackHealthSetMode == 1)
	{
		if(GetClientTeam(victim) == GetClientTeam(client))
		{
			int iHitGroup = event.GetInt("hitgroup");
			if(client == victim || !IsFakeClient(victim)) return;
			PrintHintText(client, "你攻击队友 %N 的%s, 请注意小心开火.", victim, GetHitGroup[iHitGroup]);
			PrintHintText(victim, "你受到队友 %N 的攻击, 注意躲避队友伤害.", client);
			return;
		}else
		{
			int Damage = event.GetInt("dmg_health");
			PrintCenterText(client,"你的攻击对 %N 造成了 %d 伤害, HP: [%d / %d]", victim, Damage, GetCurrentHealth(victim), GetMaxHealth(victim));
			return;
		}
	}
}

public void Event_PlayerChangeName(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bPlayerChangeName) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client)) return;
	static char GetOldName[128];
	event.GetString("oldname", GetOldName, sizeof GetOldName);
	SetClientInfo(client, "name", GetOldName);
	PrintToChatAll("\x04[提示]\x03玩家\x04 %N \x03尝试更改名字, 但是服务器禁止改名!", client);
}

public Action Message_ChangeUserName(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!g_bPlayerChangeName) return Plugin_Continue;
	static char UserMess[128];
	msg.ReadString(UserMess, sizeof(UserMess));
	msg.ReadString(UserMess, sizeof(UserMess));
	if(StrContains(UserMess, "Cstrike_Name_Change", true) != -1) return Plugin_Handled;
	return Plugin_Continue;
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		ReSetPlayerChangeData(i);
		ReSurvivalHealthStart(i);
	}
	//PrintToChatAll("\x04[提示]\x03回合结束, 正在");
}

public void Event_SaveMapsInfo(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bReStarRoundEnable) return;
	if(strcmp(GetMapName, NULL_STRING) == 0 || strcmp(GetMapName, GetMapsName()) != 0)
	{
		if(!g_bReStarRoundEnable) return;
		RoundFailCount = 0;
		strcopy(GetMapName, sizeof(GetMapName), GetMapsName());
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bPlayerTeamEnable) return;
	for(int i = 1; i <= MaxClients; i++)
		ReSetPlayerChangeData(i);
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bReStarRoundEnable) return;
	RoundFailCount += 1;
	RemoveCommonInfected();
	RemoveSpecialInfected();
	PrintToChatAll("\x04[提示]\x03这是你们第:\x04 %d \x03次团灭, 请继续努力哦~(ง •̀_•́)ง‼", RoundFailCount);
}

/* -----------------------------------------------------------
					Command
----------------------------------------------------------- */
public Action Command_ReStartServer(int client, int args)
{
	if(!IsValidClient(client) || !g_bOnReStartServer) return Plugin_Handled;
	AutoReStartServer();
	PrintToChatAll("\x04[提示]\x03正在执行\x05 服务器 \x03重启功能, 请稍后.....");
	return Plugin_Continue;
}

public Action Command_ReStartLevelMaps(int client, int args)
{
	if(!IsValidClient(client) || !g_bReStarLevelMaps) return Plugin_Handled;
	AutoReStartLevelMaps();
	PrintToChatAll("\x04[提示]\x03正在执行\x05 当前地图 \x03重启功能, 请稍后.....");
	return Plugin_Continue;
}

public Action Command_AddOneBot(int client, int args)
{
	if(!IsValidClient(client) || !g_bPlayerBotsEnable) return Plugin_Handled;
	CreateFakeClientFunction();
	PrintToChatAll("\x04[提示]\x03正在执行创建\x05 幸存者Bot \x03玩家!");
	return Plugin_Continue;
}

public Action Command_KickAllBot(int client, int args)
{
	if(!IsValidClient(client) || !g_bPlayerBotsEnable) return Plugin_Handled;
	if(IsSurvivorTeamFull() && !IsFakeClient(client))
	{
		PrintToChat(client, "\x04[提示]\x03未发现其他\x05 幸存者Bot \x03玩家, 请勿重复使用!");
		return Plugin_Handled;
	}
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsSurvivalClient(i) || !IsFakeClient(i)) continue;
		KickClient(i, "正在执行清除所有幸存者电脑Bot玩家....");
	}
	PrintToChatAll("\x04[提示]\x03已踢出所有\x05 幸存者Bot \x03玩家!");
	return Plugin_Continue;
}

public Action Command_PlayerAway(int client, int args)
{
	if(!IsValidClient(client) || !g_bPlayerAwayEnable) return Plugin_Handled;
	if(GetClientTeam(client) == 1) {
		PrintToChat(client, "\x04[提示]\x03你已经在\x05 旁观者 \x03阵营, 无须再次加入!");
		return Plugin_Handled;
	}
	if(IsInfectedControl(client)) {
		PrintToChat(client, "\x04[提示]\x03你正在被\x05 特感控制 \x03中, 禁止使用闲置!");
		return Plugin_Handled;
	}
	ChangeClientTeam(client, 1);
	PrintToChatAll("\x04[提示]\x03玩家\x05 %N \x03感到通关无望已逃跑至\x05 旁观者 \x03！", client);
	return Plugin_Continue;
}

public Action Command_PlayerJoin(int client, int args)
{
	if(!IsValidClient(client) || !g_bPlayerJoinEnable) return Plugin_Handled;
	if(GetClientTeam(client) == 2 && IsClientIdle(client) == 0 && GetBotIdlePlayer(client) == 0) {
		MenuFunc_SelectPlayerRole(client);
		PrintToChat(client, "\x04[提示]\x03请选择你需要继承的\x05 幸存者Bot \x03!");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) == 1 && IsClientIdle(client) != 0 || GetBotIdlePlayer(client) != 0) {
		PrintToChat(client, "\x04[提示]\x03你已经在\x05 幸存者 \x03阵营, 无须再次加入!");
		return Plugin_Handled;
	}
	if(IsSurvivorTeamFull() && !CreateFakeClientFunction()) {
		PrintToChat(client, "\x04[提示]\x03添加\x05 幸存者Bot \x03失败! 请重新尝试加入!");
		return Plugin_Handled;
	}
	ClientCommand(client, "jointeam 2");
	PrintToChat(client, "\x04[提示]\x03正在加入\x05 幸存者 \x03阵营, 无反应则\x05 幸存者Bot \x03处于死亡状态!");
	return Plugin_Continue;
}

public Action Command_PlayerKill(int client, int args)
{
	if(!IsValidClient(client) || !g_bPlayerKillEnable) return Plugin_Handled;
	if(GetClientTeam(client) != 2 || IsFakeClient(client)) {
		PrintToChat(client, "\x04[提示]\x03当前功能仅供\x05 幸存者 \x03使用!");
		return Plugin_Handled;
	}
	if(!IsPlayerAlive(client)) {
		PrintToChat(client, "\x04[提示]\x03你当前已经处于\x05 死亡状态 \x03, 请勿重复使用!");
		return Plugin_Handled;
	}
	ForcePlayerSuicide(client);
	PrintToChatAll("\x04[提示]\x03玩家\x05 %N \x03感到生还无望已\x05 自尽而死 \x03！", client);
	return Plugin_Continue;
}

public Action Command_PlayerTeam(int client, int args)
{
	if(!IsValidClient(client) || !g_bPlayerTeamEnable) return Plugin_Handled;
	if(!StrEqual(GetGameMode(), "versus", false)){
		PrintToChat(client, "\x04[提示]\x03当前功能仅供\x05 对抗模式 \x03使用!");
		return Plugin_Handled;
	}
	if(g_iPlayerTeamCount != 0 && PlayeChangeCount[client] >= g_iPlayerTeamCount) {
		PrintToChat(client, "\x04[提示]\x03换队达到\x05 最大使用次数 \x03, 禁止使用该功能!");
		return Plugin_Handled;
	}
	if(PlayeChangeTimer[client] > 0.0) {
		PrintToChat(client, "\x04[提示]\x03换队功能x05 正在冷却 \x03中, 请在\x04 %.1f \x03秒后重试!", PlayeChangeTimer[client]);
		return Plugin_Handled;
	}
	MenuFunc_SelectPlayerTeam(client);
	PrintToChat(client, "\x04[提示]\x03请选择你所要加入的队伍!");
	return Plugin_Continue;
}

public Action Command_WeaponDrop(int client, int args)
{
	if(!IsValidClient(client) || !g_bSurvivalWeaponDrop) return Plugin_Handled;
	if(GetClientTeam(client) != 2 || IsFakeClient(client)) {
		PrintToChat(client, "\x04[提示]\x03当前功能仅供\x05 幸存者 \x03使用!");
		return Plugin_Handled;
	}
	if(!IsPlayerAlive(client) || IsIncapacitated(client)) {
		PrintToChat(client, "\x04[提示]\x03当前状态禁止该使用丢弃武器功能!");
		return Plugin_Handled;
	}
	char sWeapon[128];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));
	int iWeapon = GetPlayerWeaponSlot(client, GetWeaponDropCount(sWeapon));
	if(!IsValidEntity(iWeapon) && 0 < iWeapon > 4)
	{
		PrintToChat(client, "\x04[提示]\x03你当前已经没有武器可以丢弃了!");
		return Plugin_Handled;
	}
	float vecAngles[3], vecVelocity[3];
	GetClientEyeAngles(client, vecAngles);
	GetAngleVectors(vecAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
	SDKHooks_DropWeapon(client, iWeapon, NULL_VECTOR, vecVelocity);
	if(!StrEqual(sWeapon, "weapon_defibrillator")) return Plugin_Handled;
	SetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex", PrecacheModel("models/w_models/weapons/w_eq_defibrillator.mdl", true));
	return Plugin_Continue;
}

/* -----------------------------------------------------------
					SelectTeam Menu
----------------------------------------------------------- */
public Action MenuFunc_SelectPlayerTeam(int client)
{
	if(!IsValidClient(client) || !g_bPlayerTeamEnable) return Plugin_Handled;
	Menu menu = new Menu(MenuHandler_SelectPlayerTeam);
	menu.SetTitle("请选择你所需加入的队伍：\n%s", LineNext);
	menu.AddItem("1", "旁观者");
	menu.AddItem("2", "幸存者");
	menu.AddItem("3", "感染者");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_SelectPlayerTeam(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sType[64];
			GetMenuItem(menu, param2, sType, sizeof(sType));
			if(GetClientTeam(client) == StringToInt(sType)) {
				MenuFunc_SelectPlayerTeam(client);
				PrintToChat(client, "\x04[提示]\x03你已经在\x04 选择的阵营 \x03中, 请重新选择!");
				return 0;
			}
			ChangeClientTeam(client, StringToInt(sType));
			PlayeChangeTimer[client] = g_iPlayerTeamTimer;
			if(g_iPlayerTeamCount != 0) PlayeChangeCount[client] += 1;
			CreateTimer(1.0, Timer_SelectPlayerTeam, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return 0;
}

public Action MenuFunc_SelectPlayerRole(int client)
{
	if(!IsValidClient(client) || !g_bPlayerJoinEnable) return Plugin_Handled;
	Menu menu = new Menu(MenuHandler_SelectPlayerRole);
	menu.SetTitle("请选择喜欢的人物：\n%s", LineNext);
	// 添加 Bot 到菜单中
	int SurvivalCount;
	static char line[2][256], Binfo[2][56];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsSurvivalClient(i) || !IsFakeClient(i) || !IsPlayerAlive(client)) continue;
		GetClientAuthId(i, AuthId_Steam2, Binfo[0], sizeof Binfo[]);
		if(strcmp(Binfo[0], "BOT", false) != 0 || IsClientIdle(i) != 0 || GetBotIdlePlayer(i) != 0) continue;
		GetClientName(i, Binfo[1], sizeof Binfo[]);
		FormatEx(line[0], sizeof line[], "%d", GetClientUserId(i));
		FormatEx(line[1], sizeof line[], "%s", Binfo[1]);
		menu.AddItem(line[0], line[1]);
		SurvivalCount += 1;
	}
	if(SurvivalCount <= 0) menu.AddItem("not", "暂无可选幸存者Bot", ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_SelectPlayerRole(Menu menu, MenuAction action, int client, int param2)
{
	if(!IsValidClient(client) || IsFakeClient(client)) return 0;
	switch(action)
	{
		case MenuAction_Select:
		{
			if(GetClientTeam(client) == 1 && IsClientIdle(client) != 0 || GetBotIdlePlayer(client) != 0) {
				PrintToChat(client, "\x04[提示]\x03你已经在\x05 幸存者 \x03阵营, 无须再次加入!");
				return 0;
			}
			char item[32], botname[32];
			menu.GetItem(param2, item, sizeof(item), _, botname, sizeof(botname));
			//GetMenuItem(menu, param2, item, sizeof(item), _, botname, sizeof(botname));
			int target = GetClientOfUserId(StringToInt(item));
			if(!IsSurvivalClient(target) || !IsFakeClient(target) || GetBotIdlePlayer(target) != 0){
				MenuFunc_SelectPlayerRole(client);
				PrintToChat(client, "\x04[提示]\x03当前\x05 幸存者Bot \x03不在有效状态, 请重新选择!");
				return 0;
			}
			ChangeClientTeam(client, 1);
			ClientCommand(client, "jointeam survivor %s", botname);
		}
	}
	return 0;
}
//GetMenuItem(menu, param2, botname, sizeof(botname));
//菜单 位置 信息区缓存 信息区长度 绘图标志 显示区信息 显示区长度 客户端索引(无效且为-1)
//GetMenuItem(Handle menu, int position, char[] infoBuf, int infoBufLen, int& style, char[] dispBuf, int dispBufLen, int client)
/* -----------------------------------------------------------
					Timer
----------------------------------------------------------- */
public Action Timer_SelectPlayerTeam(Handle timer, any client)
{
	if(!IsValidClient(client) || PlayeChangeTimer[client] < 1.0) return Plugin_Handled;
	PlayeChangeTimer[client] -= 1.0;
	return Plugin_Continue;
}

/* -----------------------------------------------------------
					Function
----------------------------------------------------------- */
public void PrintShowHealth(int client, int victim, int MaxLength, int GetHealth, int MaxHealth, char[] clName)
{
	int i, GetLength = MaxLength * g_iCharLength + 2;
	int Percent = RoundToCeil(float(GetHealth) / float(MaxHealth) * MaxLength);
	char[] ShowHealth = new char[GetLength];
	//ShowHealth[0] = '\0';
	for(i = 0; i < Percent && i < MaxLength; i++){
		StrCat(ShowHealth, GetLength, g_cAttackCurrentChar);
	}
	for(; i < MaxLength; i++){
		StrCat(ShowHealth, GetLength, g_cAttackDamagesChar);
	}
	PrintCenterText(client, "HP: |-%s-|  [%d / %d]  %s", ShowHealth, GetCurrentHealth(victim), GetMaxHealth(victim), clName);
}

public bool CreateFakeClientFunction()
{
	int bot = CreateFakeClient("MultiBot");
	if(bot == 0) return false;
	ChangeClientTeam(bot, 2);
	DispatchKeyValue(bot, "classname", "SurvivorBot");
	DispatchSpawn(bot);
	L4D_RespawnPlayer(bot);
	SurvivalTeleport(bot);
	KickClient(bot, "自动踢出Bot玩家！");
	return true;
}

public void SurvivalTeleport(int client)
{
	if(!IsSurvivalClient(client) || !IsPlayerAlive(client)) return;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsSurvivalClient(i) || !IsPlayerAlive(i) || i == client) continue;
		float VecOrigin[3];
		GetClientAbsOrigin(i, VecOrigin);
		TeleportEntity(client, VecOrigin, NULL_VECTOR, NULL_VECTOR);
		break;
	}
}

public bool IsSurvivorTeamFull()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsSurvivalClient(i) && IsFakeClient(i))
			return false;
	}
	return true;
}

public int GetAllPlayerCount()
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i))
			count++;
	}
	return count;
}

public int GetMaxPlayerCount()
{
	static Handle g_hGetMaxPlayers;
	g_hGetMaxPlayers = FindConVar("sv_maxplayers");
	if(g_hGetMaxPlayers == null) return GetAllPlayerCount();
	int g_iGetMaxPlayers = GetConVarInt(g_hGetMaxPlayers);
	if(g_iGetMaxPlayers <= 0) return GetAllPlayerCount();
	return g_iGetMaxPlayers;
}

//幸存者Bot即将被继承(例如：闲置:xxx)		幸存者Bot获取真实玩家索引时不为 0
public int GetBotIdlePlayer(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsSurvivalClient(i) && IsFakeClient(i) && IsClientIdle(i) == client)
			return i;
	}
	return 0;
}

//幸存者Bot即将被继承(例如：闲置:xxx)		获取真实玩家闲置用户ID时不为 0
public int IsClientIdle(int client)
{
	if(!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;
	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

public void RemoveCommonInfected()
{
	for(int i = MaxClients; i <= GetMaxEntities(); i++)
	{
		if(!IsCommonWitch(i) && !IsCommonInfected(i)) continue;
		AcceptEntityInput(i, "kill");
	}
}

public void RemoveSpecialInfected()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsInfectedClient(i) && IsFakeClient(i))
			ForcePlayerSuicide(i);
	}
}

stock bool IsCommonInfected(int iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		static char ClassName[64];
		GetEdictClassname(iEntity, ClassName, sizeof(ClassName));
		if(StrContains(ClassName, "infected") >= 0) return true;
	}
	return false;
}

stock bool IsCommonWitch(int iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		static char ClassName[64];
		GetEdictClassname(iEntity, ClassName, sizeof(ClassName));
		if(StrContains(ClassName, "witch") >= 0) return true;
	}
	return false;
}

stock bool IsInfectedControl(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)	return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)	return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)	return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)	return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)		return true;
	return false;
}

public void AutoReStartServer()
{
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	SetCommandFlags("sv_crash", GetCommandFlags("sv_crash") &~ FCVAR_CHEAT);
	ServerCommand("sv_crash");
}

public void AutoReStartLevelMaps()
{
	static char sMapName[16];
	GetCurrentMap(sMapName, sizeof(sMapName));
	ServerCommand("changelevel %s", sMapName);
}

stock char[] GetMapsName()
{
	static char MapsName[64];
	GetCurrentMap(MapsName, sizeof(MapsName));
	return MapsName;
}

stock char[] GetGameMode()
{
	static char GameMode[56];
	GetConVarString(FindConVar("mp_gamemode"), GameMode, sizeof(GameMode));
	return GameMode;
}

stock int GetWeaponDropCount(const char[] sWeapon)
{
	int iSlot;
	for(int count=0; count<=35; count++)
	{
		switch(count)
		{
			case 17: iSlot = 1;
			case 21: iSlot = 2;
			case 24: iSlot = 3;
			case 28: iSlot = 4;
			case 30: iSlot = 5;
		}
		if(StrEqual(sWeapon, WeaponNames[count]))
			return iSlot;
	}
	return 0;
}

stock void CheatCommand(int client, char[] command, char[] arguments)
{
	if(!client) return;
	int admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}