/*
* Code by EpicYoshiMaster
*
* GameMod to facilitate replacing the original Taskmaster with a custom one
* to expose additional information that is otherwise hidden.
*/
class Yoshi_TaskmasterDisplay_GameMod extends GameMod;

var transient bool bReplacedMiniMissions;

/* defaultproperties
{
	
} */

event OnModLoaded()
{
	if (!bReplacedMiniMissions)
		ReplaceTaskmasterMissions();
}

event OnModUnloaded()
{
	ReplaceTaskmasterMissions(true);
}

simulated event Tick(float d)
{
	Super.Tick(d);
	
	if (!bReplacedMiniMissions)
		ReplaceTaskmasterMissions();
}

function array<Hat_SeqAct_MiniMission> GetMiniMissionNodes()
{
	local Sequence GameSeq;
	local SequenceObject SeqObj;
	local array<SequenceObject> AllSeq;
	local array<Hat_SeqAct_MiniMission> MiniMissionNodes;
	
	GameSeq = WorldInfo.GetGameSequence();
	if (GameSeq != None)
	{
		GameSeq.FindSeqObjectsByClass(class'Hat_SeqAct_MiniMission', true, AllSeq);
		
		foreach AllSeq(SeqObj)
		{
			if (Hat_SeqAct_MiniMission(SeqObj) != None)
				MiniMissionNodes.AddItem(Hat_SeqAct_MiniMission(SeqObj));
		}
	}
	
	return MiniMissionNodes;
}

function ReplaceTaskmasterMissions(optional bool bRevertToOriginal)
{
	local array<Hat_SeqAct_MiniMission> MiniMissionNodes;
	local Hat_SeqAct_MiniMission MissionSeq;
	local Hat_MiniMissionTaskmaster OldMiniMission, NewMiniMission;
	
	MiniMissionNodes = GetMiniMissionNodes();	
	foreach MiniMissionNodes(MissionSeq)
	{
		if (MissionSeq.IsActivated()) continue;	//Already running
		if (MissionSeq.MiniMission == None) continue;
		if (!MissionSeq.MiniMission.IsA('Hat_MiniMissionTaskmaster')) continue;
		
		if (!bRevertToOriginal)
		{
			if (MissionSeq.MiniMission.IsA('Yoshi_MiniMissionTaskmaster_InfoDisplay')) continue;
			NewMiniMission = new class'Yoshi_MiniMissionTaskmaster_InfoDisplay';
		}
		else
		{
			if (!MissionSeq.MiniMission.IsA('Yoshi_MiniMissionTaskmaster_InfoDisplay')) continue;
			NewMiniMission = new class'Hat_MiniMissionTaskmaster';
		}
		
		OldMiniMission = Hat_MiniMissionTaskmaster(MissionSeq.MiniMission);
		
        NewMiniMission.MissionMode = OldMiniMission.MissionMode;
        NewMiniMission.TaskActors = OldMiniMission.TaskActors;
        NewMiniMission.FirstTask = OldMiniMission.FirstTask;
        NewMiniMission.ScoreTarget = OldMiniMission.ScoreTarget;
        NewMiniMission.ShowHUD = OldMiniMission.ShowHUD;
        NewMiniMission.UseHelperLine = OldMiniMission.UseHelperLine;
        NewMiniMission.DisableUnrelatedInteractions = OldMiniMission.DisableUnrelatedInteractions;
        NewMiniMission.TasksCompletePermanently = OldMiniMission.TasksCompletePermanently;
        NewMiniMission.HaveMercy = OldMiniMission.HaveMercy;
        NewMiniMission.GlobalDifficultyMultiplier = OldMiniMission.GlobalDifficultyMultiplier;
        NewMiniMission.TasksPerMinute = OldMiniMission.TasksPerMinute;
        NewMiniMission.EasyTaskCap = OldMiniMission.EasyTaskCap;
        NewMiniMission.HardTaskCap = OldMiniMission.HardTaskCap;
        NewMiniMission.MinutesUntilDifficult = OldMiniMission.MinutesUntilDifficult;
        NewMiniMission.ScoresUntilDifficult = OldMiniMission.ScoresUntilDifficult;
        NewMiniMission.ContinueTasksInstantly = OldMiniMission.ContinueTasksInstantly;
        NewMiniMission.SpawnInRooms = OldMiniMission.SpawnInRooms;
        NewMiniMission.FavorActiveRooms = OldMiniMission.FavorActiveRooms;
        NewMiniMission.FavorCurrentRoom = OldMiniMission.FavorCurrentRoom;
        NewMiniMission.FavorWaitingTasks = OldMiniMission.FavorWaitingTasks;
        NewMiniMission.AvoidPreviousRooms = OldMiniMission.AvoidPreviousRooms;
        NewMiniMission.BridgeDistantTasks = OldMiniMission.BridgeDistantTasks;
        NewMiniMission.EarlyRangeLimit = OldMiniMission.EarlyRangeLimit;
        NewMiniMission.EarlyRangeLimitRemove = OldMiniMission.EarlyRangeLimitRemove;
        NewMiniMission.RoughMapSize = OldMiniMission.RoughMapSize;
        NewMiniMission.FarTaskDistance = OldMiniMission.FarTaskDistance;
        NewMiniMission.CoopDifficultyRatio = OldMiniMission.CoopDifficultyRatio;
        NewMiniMission.UseTimeLimits = OldMiniMission.UseTimeLimits;
        NewMiniMission.EasyTime = OldMiniMission.EasyTime;
        NewMiniMission.HardTime = OldMiniMission.HardTime;
        NewMiniMission.EasySpeed = OldMiniMission.EasySpeed;
        NewMiniMission.HardSpeed = OldMiniMission.HardSpeed;
        NewMiniMission.TimeSpeedRatio = OldMiniMission.TimeSpeedRatio;
        NewMiniMission.BareMinimumTime = OldMiniMission.BareMinimumTime;
        NewMiniMission.CoopScoreRatio = OldMiniMission.CoopScoreRatio;
        NewMiniMission.SucceedPressure = OldMiniMission.SucceedPressure;
        NewMiniMission.FailPressure = OldMiniMission.FailPressure;
        NewMiniMission.EasyPressureBuild = OldMiniMission.EasyPressureBuild;
        NewMiniMission.HardPressureBuild = OldMiniMission.HardPressureBuild;
        NewMiniMission.SucceedPressureTaskCapFactor = OldMiniMission.SucceedPressureTaskCapFactor;
        NewMiniMission.FailPressureTaskCapFactor = OldMiniMission.FailPressureTaskCapFactor;
        NewMiniMission.NonScorePressure = OldMiniMission.NonScorePressure;
        NewMiniMission.NewTaskSound = OldMiniMission.NewTaskSound;
        NewMiniMission.ScoreSound = OldMiniMission.ScoreSound;
        NewMiniMission.FailSound = OldMiniMission.FailSound;
        NewMiniMission.GameOverSound = OldMiniMission.GameOverSound;
        NewMiniMission.MusicEndPitch = OldMiniMission.MusicEndPitch;
        NewMiniMission.MusicPitchExponent = OldMiniMission.MusicPitchExponent;
        NewMiniMission.MusicPitchParameterName = OldMiniMission.MusicPitchParameterName;
        NewMiniMission.RadioAssignTaskGeneric = OldMiniMission.RadioAssignTaskGeneric;
        NewMiniMission.RadioFailTaskGeneric = OldMiniMission.RadioFailTaskGeneric;
        NewMiniMission.RadioGenericAssignChance = OldMiniMission.RadioGenericAssignChance;
        NewMiniMission.RadioGenericFailChance = OldMiniMission.RadioGenericFailChance;
        NewMiniMission.RadioSpecificAssignChance = OldMiniMission.RadioSpecificAssignChance;
        NewMiniMission.RadioSpecificFailChance = OldMiniMission.RadioSpecificFailChance;
        NewMiniMission.RadioPressureThresholdMedium = OldMiniMission.RadioPressureThresholdMedium;
        NewMiniMission.RadioPressureThresholdHigh = OldMiniMission.RadioPressureThresholdHigh;
        NewMiniMission.RadioPressureThresholdExtreme = OldMiniMission.RadioPressureThresholdExtreme;
        NewMiniMission.DebugMode = OldMiniMission.DebugMode;
        NewMiniMission.DebugLogHUD = OldMiniMission.DebugLogHUD;
        NewMiniMission.Pressure = OldMiniMission.Pressure;
        NewMiniMission.MissionTime = OldMiniMission.MissionTime;
        NewMiniMission.Difficulty = OldMiniMission.Difficulty;
        NewMiniMission.SpawnRate = OldMiniMission.SpawnRate;
        NewMiniMission.Score = OldMiniMission.Score;
        NewMiniMission.LastMoodRadio = OldMiniMission.LastMoodRadio;
        NewMiniMission.RadioMessageToDo = OldMiniMission.RadioMessageToDo;
        NewMiniMission.FailShake = OldMiniMission.FailShake;
        NewMiniMission.PreviousOptimalObjective = OldMiniMission.PreviousOptimalObjective;
        NewMiniMission.Tasks = OldMiniMission.Tasks;
        NewMiniMission.ActiveTasks = OldMiniMission.ActiveTasks;
        NewMiniMission.Spawn1 = OldMiniMission.Spawn1;
        NewMiniMission.Spawn2 = OldMiniMission.Spawn2;
        NewMiniMission.Spawn3 = OldMiniMission.Spawn3;
        NewMiniMission.OccupationTimescale = OldMiniMission.OccupationTimescale;
        NewMiniMission.Players = OldMiniMission.Players;
        NewMiniMission.CurrentRoom = OldMiniMission.CurrentRoom;
        NewMiniMission.PreviousRoom = OldMiniMission.PreviousRoom;

        NewMiniMission.DebugMode = true;

		MissionSeq.MiniMission = NewMiniMission;
	}
	
	bReplacedMiniMissions = true;
}