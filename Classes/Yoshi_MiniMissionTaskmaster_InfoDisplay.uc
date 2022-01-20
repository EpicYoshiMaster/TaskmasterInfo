/*
* Code by EpicYoshiMaster
*
* Custom version of the Taskmaster, designed to show additional information
* and allow the player to better understand the level's inner workings
*/
class Yoshi_MiniMissionTaskmaster_InfoDisplay extends Hat_MiniMissionTaskmaster;

var Yoshi_HUDElement_TaskmasterDisplay DisplayHUD;

const TaskDebugMode = false;

var float SpawnTaskDropRate;
var Hat_HouseRoomVolume MostActiveRoom;

var array<Hat_HouseRoomVolume> AllRooms;

function OnPreBegin()
{
	if (Tasks.Length > 0) return;

	InitializeTasks();
}

function OnBegin()
{
	local Hat_Player ply;
	local PlayerController pc;
	local Hat_HUDElement he;
	local Hat_StatusEffect_CruiseDeliveryGuides guides;
	local Hat_HouseRoomVolume rv;

	CleanUpMission();

	UpdatePlayers();
	MissionTime = 0;
	Pressure = 0;
	Difficulty = 0;
	Score = 0;
	if (MusicPitchParameterName != '')
	{
		`SetMusicParameterFloat(MusicPitchParameterName, 1);

	}
	if(DebugMode)
		Print("Starting Task Master! Mode:"@MissionMode);

	AllRooms.length = 0;
	foreach GetWorldInfo().AllActors(class'Hat_HouseRoomVolume', rv) {
		if(rv != None) {
			AllRooms.AddItem(rv);
		}
	}

	Print("Found " $ AllRooms.length $ " Rooms!", true);

	ContinueTasksInstantly = MissionMode == MiniMissionTaskMaster_SingleTask || default.ContinueTasksInstantly;

	if (MissionMode == MiniMissionTaskMaster_SingleTask)
		StartTasksUntilSpent();
	else
		StartTaskForAllPlayers();

	if (ActiveTasks.Length == 0)
		TriggerFail();

	if (MissionUsesPressure() && ShowHUD)
	{
		foreach GetWorldInfo().DynamicActors(class'Hat_Player', ply)
		{
			pc = PlayerController(ply.Controller);
			if (pc == None) continue;
			if (pc.MyHUD == None) continue;
			he = Hat_HUD(pc.MyHUD).OpenHUD(class'Hat_HUDElementTaskMaster');
			if (he != None && Hat_HUDElementTaskMaster(he) != None)
				Hat_HUDElementTaskMaster(he).Mission = self;

            if(DisplayHUD == None) {
                DisplayHUD = Yoshi_HUDElement_TaskmasterDisplay(Hat_HUD(pc.MyHUD).OpenHUD(class'Yoshi_HUDElement_TaskmasterDisplay'));
                DisplayHUD.Taskmaster = self;
            }
                
            
			if (UseHelperLine && (!class'Hat_SnatcherContract_DeathWish'.static.IsAnyActive(false) || class'Hat_SnatcherContract_DeathWish_EndlessTasks'.static.IsDeathWishEasyMode()))
			{
				guides = Hat_StatusEffect_CruiseDeliveryGuides(Hat_PawnCombat(pc.Pawn).GiveStatusEffect(class'Hat_StatusEffect_CruiseDeliveryGuides'));
				guides.Mission = self;
			}
		}
	}
	
	if (DisableUnrelatedInteractions)
		Hat_GameMissionManager(`GameManager).DisableUnrelatedInteractions = true;
}

function UpdatePlayers()
{
	local Array<Player> GamePlayers;
	local int i;

	GamePlayers = class'Engine'.static.GetEngine().GamePlayers;

	Players.Length = GamePlayers.Length;

	for (i = 0; i < GamePlayers.Length; i++)
		if (GamePlayers[i].Actor != None && GamePlayers[i].Actor.Pawn != None && Hat_Player(GamePlayers[i].Actor.Pawn) != None)
			Players[i] = Hat_Player(GamePlayers[i].Actor.Pawn);
}

function InitializeTasks()
{
	local Actor ta;
	local Hat_TaskMasterComponent tc;

	Tasks.Length = 0;

	if (DebugMode)
		Print("Initializing tasks...");

	if (TaskActors.Length == 0)
	{
		Print("MiniMission TaskMaster Error: No TaskActors set!");
		TriggerFail();
		return;
	}

	foreach TaskActors(ta)
	{
		if (ta == None) continue;
		tc = GetTaskComponent(ta);
		if (tc == None) continue;
		if (!tc.AssignAutomatically) continue;
		AddTask(tc);
	}

	AddChainLinks();

	if (Tasks.Length == 0)
	{
		Print("MiniMission TaskMaster Error: No Tasks were created! Make sure TaskActors is populated!");
		TriggerFail();
		return;
	}

	if (DebugMode)
		Debug_VerboseTaskList();
}

function Debug_VerboseTaskList()
{
	local int ti, i;
	local String s;

	Print("-----------");
	for (ti = 0; ti < Tasks.Length; ti++)
	{
		s = "[TASK "$ti$"]";
		for (i = 0; i < Tasks[ti].Objectives.Length; i++)
		{
			s @= Tasks[ti].Objectives[i].Owner;
			if (i + 1 < Tasks[ti].Objectives.Length)
				s @= "->";
		}
		Print(s);
	}
	Print("-----------");
	Print("Total tasks:"@Tasks.Length);
}

function Debug_VerboseStatusLog()
{
	local String s;
	local int i;

	s = "[PRESSURE] ";
	for (i = 0; i < 75; i++)
		s $= Round(Pressure*75) > i ? "I" : ".";

	Print(s@"[SCORE]"@Score);
	Print("[Pressure]"@Pressure@"+"$GetPriorityTasks()$"p"@"[Difficulty]"@Difficulty$(Debug_UsingTimeDifficulty() ? "-t" : "-s")@"[Score]"@Score$"/"$GetScoreTarget()@"[Minutes]"@(MissionTime/float(60)));
	Print("[ActiveTasks]"@GetVisibleTasks()@"[Cap]"@GetTaskCap()@"[Waiting]"@GetWaitingTasks()@"[Priority]"@GetPriorityTasks()$"p"@(CurrentRoom.Length > 0 ? "[CurRoom]"@CurrentRoom[0] : "")@((AvoidPreviousRooms > 0 && CurrentRoom.Length > 0) ? "[PrevRoom]"@PreviousRoom[0] : ""));
	Print("[SpawnRate]"@SpawnRate@"[Spawn1]"@Spawn1@"[Spawn2]"@Spawn2@"[Spawn3]"@Spawn3);
}

function Debug_StatusLog()
{
	Print("[Pressure]"@Pressure@"+"$GetPriorityTasks()$"p"@"[Difficulty]"@Difficulty@"[Score]"@Score$"/"$GetScoreTarget()@"[Tasks]"@GetVisibleTasks()$"/"$GetTaskCap()@"("$GetWaitingTasks()$"w)");
}

function Hat_TaskMasterComponent GetTaskComponent(Actor a)
{
	local Hat_TaskMasterComponent tc;

	foreach a.AllOwnedComponents(class'Hat_TaskMasterComponent', tc)
		return tc;

	Print("MiniMission TaskMaster Error:"@a@"does not have a Hat_TaskMasterComponent set!");
	return None;
}

function AddTask(Hat_TaskMasterComponent tc)
{
	local TaskMasterTask NewTask;
	NewTask.Objectives.AddItem(tc);
	Tasks.AddItem(NewTask);
}

function AddChainLinks(optional int Cycle = 0)
{
	local Hat_TaskMasterComponent lastobjective;
	local Actor ntask;
	local int ti;
	local int PrevAddedIndex;
	local bool AddedLink;

	if (Cycle > 30)
	{
		Print("MiniMission TaskMaster Error: Possible infinite loop detected in task assignment!");
		return;
	}

	PrevAddedIndex = -1;

	for (ti = 0; ti < Tasks.Length; ti++)
	{
		lastobjective = Tasks[ti].Objectives[Tasks[ti].Objectives.Length-1];
		foreach lastobjective.NextTask(ntask)
		{
			if (TaskActors.Find(ntask) == INDEX_NONE)
			{
				Print("MiniMission TaskMaster Error:"@ntask@"is in NextTask for"@lastobjective.Owner@"but was not added to TaskActors.");
				continue;
			}
			if (GetTaskComponent(ntask) == None) continue;
			if (Tasks[ti].Objectives.Find(GetTaskComponent(ntask)) != INDEX_NONE)
			{
				Print("MiniMission TaskMaster Infinite Loop Error:"@ntask@"was found multiple times in a task chain that starts with"@Tasks[ti].Objectives[0].Owner$"! Task chains must not loop.");
				return;
			}
			if (PrevAddedIndex != ti)
			{
				// first chain overwrites task
				Tasks[ti].Objectives.AddItem(GetTaskComponent(ntask));
				PrevAddedIndex = ti;
			}
			else
			{
				// additional chains add new tasks
				Tasks.AddItem(Tasks[ti]);
				Tasks[Tasks.Length-1].Objectives[Tasks[Tasks.Length-1].Objectives.Length-1] = GetTaskComponent(ntask);
			}
			AddedLink = true;
		}
	}

	if (AddedLink) AddChainLinks(Cycle + 1);
}

function StartTaskForAllPlayers()
{
	local Hat_Player ply;
	foreach Players(ply)
		StartNewTask(ply);
}

function StartTasksUntilSpent()
{
	local Hat_Player ply;
	local bool again;
	foreach Players(ply)
		again = StartNewTask(ply);
	if (again)
		StartTasksUntilSpent();
}

//ValidIndex holds all the possible tasks that can be used to start
function bool StartNewTask(Hat_Player Player)
{
	local Array<int> ValidIndex, NearIndex, StartIndex, NewIndex;
	local float TaskRange;
	local Array<Hat_TaskMasterComponent> CompArray;
	local Hat_TaskMasterComponent Comp;
	local int ti, i, farti;
	local bool UseRange, SpawnInLine;
	local Vector SearchPoint;

	//YOSHI ADD
	local string ValidTaskString;
	local string TaskSpawnWeightString;

	if (MissionMode == MiniMissionTaskMaster_ScoreTarget && GetVisibleTasks() >= GetScoreTarget() - Score)
		return false;

	UseRange = MissionMode != MiniMissionTaskMaster_SingleTask;

	ValidTaskString = "STARTING NEW TASK - ";

	// remove impossible tasks (in range)
	if (UseRange)
	{
		TaskRange = EarlyRangeLimit;

		while (TaskRange <= 10000)
		{
			for (ti = 0; ti < Tasks.Length; ti++)
				if (CanAssignTask(Player, ti))
					if (IsTaskInAssignRange(Player, ti, TaskRange))
						ValidIndex.AddItem(ti);

			if (ValidIndex.Length > 0) break;

			TaskRange += 500;
		}

		ValidTaskString $= "TaskRange: " $ TaskRange $ ", Valid Ranged Possible Tasks: " $ ValidIndex.length;
	}

	// remove impossible tasks
	if (ValidIndex.Length == 0) {
		for (ti = 0; ti < Tasks.Length; ti++)
			if (CanAssignTask(Player, ti))
				ValidIndex.AddItem(ti);

		ValidTaskString $= ", Valid Possible Tasks: " $ ValidIndex.length;
	}

	Print(ValidTaskString, true);

	if (ValidIndex.Length == 0) return false;

	if (FirstTask.Length > 0)
	{
		NearIndex = ValidIndex;
		Comp = GetTaskComponent(FirstTask[Rand(FirstTask.Length)]);
		Print("Using First Task:" @ Comp, true);
		FirstTask.Length = 0;
	}

	//Never happens
	if (!UseRange)
		NearIndex = ValidIndex;

	farti = -1;

	if (FarTaskDistance <= 0)
		TaskRange = Lerp(1000, RoughMapSize, Difficulty);
	else
		TaskRange = FarTaskDistance/2;

	if (Comp == None)
	{
		// find tasks in nearby rooms
		if (SpawnInRooms && Player.CurrentRooms.Length > 0 && UseRange)
			NearIndex = GetNearbyRoomTasks(Player, ValidIndex);

		// spawn distant tasks or bridge to existing distant tasks
		if (NearIndex.Length == 0)
		{
			if (SpawnInRooms && DebugMode)
				Print("No tasks found in nearby rooms! Defaulting to range-based system.");

			farti = GetFarthestTask(Player);

			if (farti == -1 && Score >= EarlyRangeLimitRemove && FarTaskDistance > 0)
			{
				Print("Spawning a Distant Task", true);
				// no far task, spawn something out of the far range (or that leads out of range immediately)
				foreach ValidIndex(ti)
					if (TravelDist(Player.Location, Tasks[ti].Objectives[0].Owner.Location) >= FarTaskDistance ||
						(Tasks[ti].Objectives.Length > 1 && Tasks[ti].Objectives[0].WaitTime <= 0 && TravelDist(Tasks[ti].Objectives[0].Owner.Location, Tasks[ti].Objectives[1].Owner.Location) >= FarTaskDistance))
						NearIndex.AddItem(ti);
			}
			else if (farti != -1)
			{
				Print("Attempting to Bridge to a Distant Task", true);
				// already has far task, do spawn checks somewhere between player and far task
				SpawnInLine = true;
			}
		}

		// still nothing, scan outward
		if (NearIndex.Length == 0)
		{
			while (TaskRange <= RoughMapSize)
			{
				SearchPoint = Player.Location;

				if (SpawnInLine)
					SearchPoint += (CurTask(farti).Owner.Location-Player.Location)*(FRand()*0.5+0.3);

				foreach ValidIndex(ti)
					if (GetTotalTaskDistance(SearchPoint, ti) <= TaskRange)
						NearIndex.AddItem(ti);

				if (NearIndex.Length > 0) break;

				if (SpawnInLine)
					TaskRange += 500;
				else if (FarTaskDistance > 0)
					TaskRange += FarTaskDistance/2;
				else
					TaskRange += 1000;
			}

			Print("Range-Based Task Scan - SpawnInLine: " $ SpawnInLine $ ", SearchPoint: " $ SearchPoint $ ", TaskRange: " $ TaskRange $ ", Result Tasks: " $ NearIndex.length, true);
		}

		// if all else fails, just use whatever exists
		if (NearIndex.Length == 0)
		{
			if (DebugMode)
				Print("No nearby tasks found! Picking at random...", true);
			NearIndex = ValidIndex;
		}

		// favor tasks that are waiting to be resumed
		if (FavorWaitingTasks >= 1 || (FavorWaitingTasks > 0 && FRand() <= FavorWaitingTasks))
		{
			Print("PROBABILITIES - FavorWaitingTasks (" $ int(FavorWaitingTasks * 100) $ "% Chance): True", true);
			NewIndex.Length = 0;

			foreach NearIndex(ti)
				if (Tasks[ti].Stage > 0)
					NewIndex.AddItem(ti);

			if (NewIndex.Length > 0) {
				NearIndex = NewIndex;
				Print("Total Possible Waiting Tasks: " $ NearIndex.length, true);
			}
			else {
				Print("No Waiting Tasks Found!", true);
			}
		}
		else {
			Print("PROBABILITIES - FavorWaitingTasks (" $ int(FavorWaitingTasks * 100) $ "% Chance): False", true);
		}

		TaskSpawnWeightString = "SPAWN WEIGHTS - ";

		// collect one of each potential task start (or more depending on weight)
		foreach NearIndex(ti) {
			if (CompArray.Find(CurTask(ti)) == INDEX_NONE) {

				for (i = 0; i < ComputeSpawnWeight(ti); i++) {
					CompArray.AddItem(CurTask(ti));
				}

				TaskSpawnWeightString $= "Comp_" $ GetRightMost(CurTask(ti)) @ "(" $ ComputeSpawnWeight(ti) $ ") | ";
			}
		}

		Print(TaskSpawnWeightString, true);

		// choose starting task
		Comp = CompArray[Rand(CompArray.Length)];

		Print("Chosen Component - " $ "Comp_" $ GetRightMost(Comp) @ "(" $ GetActorVolumeName(Comp.Owner) $ ")", true);
	}

	foreach NearIndex(ti)
		if(CurTask(ti) == Comp)
			StartIndex.AddItem(ti);

	// activate random task

	Print("FINISHED Start Task: " $ StartIndex.length $ " potential options", true);
	Print(" ", true);
	return StartTask(Player, StartIndex[Rand(StartIndex.Length)]);
}

function int ComputeSpawnWeight(int ti)
{
	local float TotalWaitTime;
	local float NumberOfSteps;
	local float r;
	local int i;

	NumberOfSteps = Tasks[ti].Objectives.Length - Tasks[ti].Stage;

	for (i = Tasks[ti].Stage; i < Tasks[ti].Objectives.Length - 1; i++)
		TotalWaitTime += Tasks[ti].Objectives[i].WaitTime;

	r = 1 + (TotalWaitTime)/30 + FMin(0, NumberOfSteps-2)/5;

	return Max(1, Round(r));
}

function Array<int> GetNearbyRoomTasks(Hat_Player p, Array<int> TaskIndex)
{
	local Array<int> ReturnIndex;
	local Hat_HouseRoomVolume r, nr, nnr, ActiveRoom, PickedRoom;
	local Array<Hat_HouseRoomVolume> PossibleRooms, BridgeRooms;
	local int ti, pid, CurActive, MostActive, ActiveNearbyRoomCount;
	local bool TaskInRoom, ShouldAvoidPrevious, ShouldBridgeDistant;
	/*YOSHI ADD */
	local bool UsingCurrentRoom, UsingActiveRoom;
	local string ProbabilitiesString;
	local string ActiveRoomString;

	UsingCurrentRoom = false;
	UsingActiveRoom = false;

	ProbabilitiesString = "PROBABILITIES - ";
	ActiveRoomString = "ACTIVE ROOMS - ";
	/*YOSHI ADD END */

	UpdatePlayers();
	UpdateCurrentRoom();

	ReturnIndex.Length = 0;

	pid = Players.Find(p);
	if (pid == INDEX_NONE) return ReturnIndex;
	if (p.CurrentRooms.Length == 0) return ReturnIndex;
	if (CurrentRoom.Length == 0 && CurrentRoom[pid] == None) return ReturnIndex;

	ActiveRoom = None;
	MostActive = 0;

	ShouldAvoidPrevious = AvoidPreviousRooms > 0 && (AvoidPreviousRooms >= 1 || FRand() <= AvoidPreviousRooms); //AvoidPreviousRooms 0.5 default
	ProbabilitiesString $= "ShouldAvoidPrevious (" $ int(AvoidPreviousRooms * 100) $  "% Chance): " $ ShouldAvoidPrevious;

	ShouldBridgeDistant = BridgeDistantTasks > 0 && (BridgeDistantTasks >= 1 || FRand() <= BridgeDistantTasks); //BridgeDistantTasks 1 default

	// find most active adjacent room
	foreach CurrentRoom[pid].NearbyRooms(r)
	{
		PossibleRooms.AddItem(r);

		ActiveRoomString $= GetRoomName(r) $ " ";

		// skip previous room unless you're in a dead end
		if (ShouldAvoidPrevious && r == PreviousRoom[pid] && CurrentRoom[pid].NearbyRooms.Length > 1) {
			ActiveRoomString $= "(Avoid Previous) | ";
			continue;
		}	

		// find most active room
		if (FavorActiveRooms > 0)
		{
			CurActive = 0;
			foreach ActiveTasks(ti)
			{
				if (!IsTaskVisible(ti)) continue;
				if (!class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, r)) continue;
				CurActive++;
			}

			TaskInRoom = false;
			foreach TaskIndex(ti)
			{
				if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Tasks[ti].Objectives[0].Owner, r))
				{
					TaskInRoom = true;
					break;
				}
			}
			if (!TaskInRoom) {
				ActiveRoomString $= "(No Valid) | ";
				continue;
			}
			else {
				ActiveRoomString $= "(" $ CurActive $ ") | ";
			}

			if (CurActive > 0)
				ActiveNearbyRoomCount++;

			if (CurActive > MostActive || (CurActive == MostActive && Rand(2) == 0))
			{
				ActiveRoom = r;
				MostActive = CurActive;
			}
		}
	}
	Print(ActiveRoomString, true);
	Print("Active Nearby Room Count: " $ ActiveNearbyRoomCount $ ", Most Active Room: " $ GetRoomName(ActiveRoom), true);

	// limit possible rooms to ones that lead to distant tasks
	if (ShouldBridgeDistant)
	{
		foreach ActiveTasks(ti)
		{
			if (!IsTaskVisible(ti)) continue;
			if (CurTask(ti).LowPriority && !CurTask(ti).GiveScore) continue;

			// check if task is in current room
			TaskInRoom = class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, CurrentRoom[pid]);

			// check if task is in adjacent rooms
			if (!TaskInRoom)
				foreach PossibleRooms(r)
					if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, r))
						TaskInRoom = true;

			if (!TaskInRoom)
			{
				if (DebugMode)
					Print("Distant task detected:" @ CurTask(ti).Owner, true);

				// check adjacencies of adjacent rooms
				foreach PossibleRooms(r)
					foreach r.NearbyRooms(nr)
						if (BridgeRooms.Find(r) == INDEX_NONE)
							if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, nr))
								BridgeRooms.AddItem(r);

				if (BridgeRooms.Length > 0) {
					Print("Found " $ BridgeRooms.length $ " Bridge Rooms in Adjacent-Adjacent Rooms.", true);
					break;
				}

				// check adjacencies of adjacencies of adjacent rooms
				foreach PossibleRooms(r)
					foreach r.NearbyRooms(nr)
						foreach nr.NearbyRooms(nnr)
							if (BridgeRooms.Find(r) == INDEX_NONE)
								if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, nnr))
									BridgeRooms.AddItem(r);

                //Once we find a bridge room, that's all we need
				if (BridgeRooms.Length > 0)	{
					Print("Found " $ BridgeRooms.length $ " Bridge Rooms in Adjacent-Adjacent-Adjacent Rooms.", true);
					break;
				}
				
			}
		}

		if (BridgeRooms.Length > 0)
		{
			PossibleRooms = BridgeRooms;
			Print("Bridging from" @ GetRoomName(CurrentRoom[pid]) @ "to" @ GetActorVolumeName(CurTask(ti).Owner), true);
		}
	}

	// avoid previous room if not bridging (and not in dead end)
	if (ShouldAvoidPrevious && BridgeRooms.Length == 0 && CurrentRoom[pid].NearbyRooms.Length > 1) {
		PossibleRooms.RemoveItem(PreviousRoom[pid]);
	}
		

	// favor current room if not bridging and little else is going on
	FavorCurrentRoom = FMin(1, default.FavorCurrentRoom * Lerp(2, 1, FMin(1, Difficulty)));// todo: make property controlled

	if (FavorCurrentRoom > 0 && BridgeRooms.Length == 0 && ActiveNearbyRoomCount < 2) {
		if (FavorCurrentRoom == 1 || FRand() <= FavorCurrentRoom) {
			UsingCurrentRoom = true;
			PickedRoom = CurrentRoom[pid];
		}

		ProbabilitiesString $= ", FavorCurrentRoom (" $ int(FavorCurrentRoom * 100) $ "% Chance): " $ UsingCurrentRoom;
	}

	// favor most active room
	if (PickedRoom == None && FavorActiveRooms > 0 && ActiveRoom != None)
	{
		//PossibleRooms.RemoveItem(ActiveRoom);
		if (FavorActiveRooms == 1 || FRand() <= FavorActiveRooms)
		{
			UsingActiveRoom = true;
			PickedRoom = ActiveRoom;
			if (DebugMode)
				Print("Favoring Active Room: " @ GetRoomName(ActiveRoom), true);
		}

		ProbabilitiesString $= ", FavorActiveRoom (" $ int(FavorActiveRooms * 100) $ "% Chance): " $ UsingActiveRoom; 
	}

	Print(ProbabilitiesString, true);

	if (PickedRoom == None && PossibleRooms.Length > 0) {
		PickedRoom = PossibleRooms[Rand(PossibleRooms.Length)];
		Print("RNG Chosen Possible Room:" @ GetRoomName(PickedRoom), true);
	}

	// list possible tasks from picked room
	if (PickedRoom != None)
		foreach TaskIndex(ti)
			if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Tasks[ti].Objectives[0].Owner, PickedRoom))
				ReturnIndex.AddItem(ti);

	if (ReturnIndex.Length == 0)
	{
		// no tasks in adjacent rooms, try current room.
		foreach TaskIndex(ti)
			if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Tasks[ti].Objectives[0].Owner, CurrentRoom[pid]))
				ReturnIndex.AddItem(ti);
		if (DebugMode && ReturnIndex.Length > 0)
			Print("No possible tasks in" @ (AvoidPreviousRooms > 0 ? "unvisited" : "") @ "adjacent rooms! Spawning task in current room" @ GetRoomName(CurrentRoom[pid]), true);
 
		// nothing there either, try previous room.
		if (ReturnIndex.Length == 0)
		{
			foreach TaskIndex(ti)
				if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Tasks[ti].Objectives[0].Owner, PreviousRoom[pid]))
					ReturnIndex.AddItem(ti);
			if (DebugMode && ReturnIndex.Length > 0)
				Print("No possible tasks in current or adjacent rooms! Spawning task in previous room"@ GetRoomName(PreviousRoom[pid]), true);
		}

		if (DebugMode && ReturnIndex.Length == 0)
			Print("No possible tasks found in rooms! Using distance check.", true);
	}

	return ReturnIndex;
}

/*YAUSHI ADD*/
function string GetActorVolumeName(Actor a) {
	local Hat_HouseRoomVolume rv;

	rv = GetActorVolume(a);
	if(rv != None) {
		return GetRoomName(rv);
	}
	
	return "None";
}

function Hat_HouseRoomVolume GetActorVolume(Actor a) {
	local Hat_HouseRoomVolume rv;

	foreach AllRooms(rv) {
		if(class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(a, rv)) {
			return rv;
		}
	}

	return rv;
}

function string GetRoomName(Hat_HouseRoomVolume Room) {
	return class'Yoshi_TaskmasterHelper'.static.ConvertToRoomName(Room);
}

/*YAUSHI ADD END*/

function UpdateCurrentRoom()
{
	local int i;

	if (CurrentRoom.Length < Players.Length)
		CurrentRoom.Length = Players.Length;

	if (PreviousRoom.Length < Players.Length)
		PreviousRoom.Length = Players.Length;

	for (i = 0; i < Players.Length; i++)
	{
		if (Players[i] == None) continue;
		if (Players[i].CurrentRooms.Length == 0) continue;
		if (Players[i].CurrentRooms[Players[i].CurrentRooms.Length-1] != CurrentRoom[i] && Players[i].CurrentRooms[Players[i].CurrentRooms.Length-1] != None)
		{
			PreviousRoom[i] = CurrentRoom[i];
			CurrentRoom[i] = Players[i].CurrentRooms[Players[i].CurrentRooms.Length-1];
		}
	}
}

function int GetFarthestTask(Hat_Player Player)
{
	local int ti, r;
	local float TestDist, BestDist;

	if (FarTaskDistance <= 0) return -1;

	r = -1;
	foreach ActiveTasks(ti)
	{
		if (Tasks[ti].Waiting > 0 && Tasks[ti].Stage + 1 >= Tasks[ti].Objectives.Length) continue;

		TestDist = TravelDist(Player.Location, Tasks[ti].Objectives[0].Owner.Location);

		if (TestDist < FarTaskDistance && Tasks[ti].Objectives.Length > 1 && Tasks[ti].Objectives[0].WaitTime <= 0)
			TestDist = TravelDist(Tasks[ti].Objectives[0].Owner.Location, Tasks[ti].Objectives[1].Owner.Location);

		if (TestDist > BestDist)
		{
			r = ti;
			BestDist = TestDist;
		}
	}

	return BestDist >= FarTaskDistance ? r : -1;
}

function float TravelDist(Vector start, Vector end)
{
	if (end.Z > start.Z + 300)
		end += (end.Z - start.Z)*vect(0,0,0.8);

	return VSize(end - start);
}

function float GetTotalTaskDistance(Vector StartPoint, int ti)
{
	local float r;
	local int i;

	r = TravelDist(StartPoint, Tasks[ti].Objectives[0].Owner.Location);

	for (i = 1; i < Tasks[ti].Objectives.Length; i++)
		r += TravelDist(Tasks[ti].Objectives[i-1].Owner.Location, Tasks[ti].Objectives[i].Owner.Location)/i;

	return r;
}

function int GetPriorityTasks()
{
	local int ti, r;

	r = 0;
	foreach ActiveTasks(ti)
		if (CurTask(ti).IsActive(ti) && !CurTask(ti).LowPriority)
			r++;

	return r;
}

function int GetVisibleTasks()
{
	local int ti, r;

	r = 0;
	foreach ActiveTasks(ti)
		if (IsTaskVisible(ti))
			r++;

	return r;
}

function int GetWaitingTasks()
{
	local int ti, r;

	r = 0;
	foreach ActiveTasks(ti)
		if (IsTaskWaiting(ti))
			r++;

	return r;
}

function bool IsTaskVisible(int ti)
{
	return CurTask(ti) != None && CurTask(ti).IsActive(ti) && Tasks[ti].Waiting == -1;
}

function bool IsTaskWaiting(int ti)
{
	return ActiveTasks.Find(ti) != INDEX_NONE && !IsLastStage(ti) && Tasks[ti].Waiting >= 0;
}

function bool IsLastStage(int ti)
{
	return Tasks[ti].Stage + 1 >= Tasks[ti].Objectives.Length;
}

function int GetTaskCap()
{
	local int target;
	target = GetScoreTarget();
	if (MissionMode == MiniMissionTaskMaster_ScoreTarget)
		HardTaskCap = Round(FMax(Lerp(EasyTaskCap,HardTaskCap,0.33), Lerp(HardTaskCap, target - Score, FClamp((Score - target*0.5)/(target*0.5),0,1))));
	return Round(FMax(1, Lerp(EasyTaskCap, HardTaskCap, Difficulty)));
}

function bool StartTask(Hat_Player Player, int ti)
{
	local Hat_TaskMasterComponent tc;

	if (ActiveTasks.Find(ti) != INDEX_NONE)
	{
		if (IsLastStage(ti)) return false;
		if (!CurTask(ti).ManualCleanup)	CurTask(ti).CleanUp(ti);
		Tasks[ti].Stage++;
		Tasks[ti].Waiting = -1;
	}
	else
	{
		foreach Tasks[ti].Objectives(tc)
			tc.CleanUp(ti);
	}

	Tasks[ti].Player = Player;

	CurTask(ti).Start(Player, self, ti, ComputeTaskTime(Player.Location, CurTask(ti).Owner.Location));

	if (ActiveTasks.Find(ti) == INDEX_NONE)
		ActiveTasks.AddItem(ti);

	if (MissionMode != MiniMissionTaskMaster_SingleTask && DebugMode)
		Debug_StatusLog();

	if (MissionMode != MiniMissionTaskMaster_SingleTask && NewTaskSound != None && !CurTask(ti).LowPriority)
		GetWorldInfo().GetALocalPlayerController().PlaySound(NewTaskSound);

	PlayRadioTaskStart(CurTask(ti));

	return true;
}

function bool CanAssignTask(Hat_Player Player, int ti)
{
	local Hat_TaskMasterComponent tc, tcc;
	local int i;

	if (TasksCompletePermanently && Tasks[ti].Completions > 0) return false;

	if (!ContinueTasksInstantly && IsTaskWaiting(ti) && Tasks[ti].Waiting == 0) return true;

	if (!Tasks[ti].Objectives[0].AssignAutomatically) return false;

	if (ActiveTasks.Find(ti) != INDEX_NONE) return false;

	foreach Tasks[ti].Objectives(tc)
		if (!tc.AllowConcurrent)
			foreach ActiveTasks(i)
				if (i != ti)
					foreach Tasks[i].Objectives(tcc)
						if (tcc == tc)
							return false;

	return true;
}

function bool IsTaskInAssignRange(Hat_Player Player, int ti, float Range)
{
	if (FirstTask.Length == 0 && EarlyRangeLimitRemove > 0 && Range > 0)
		if (Score < EarlyRangeLimitRemove && GetTotalTaskDistance(Player.Location, ti) > Range*Score)
			return false;

	return true;
}

function float ComputeTaskTime(Vector StartLocation, Vector EndLocation)
{
	local float time, speed;
	if (!UseTimeLimits) return 0;
	time = Lerp(EasyTime, HardTime, FMin(1, Difficulty));
	speed = TravelDist(StartLocation, EndLocation)/FMax(0.001, Lerp(EasySpeed, HardSpeed, FMin(1, Difficulty)));
	return FMax(BareMinimumTime, Lerp(time, speed, Clamp(TimeSpeedRatio,0,1)));
}

function Tick(float d)
{
	local float pitchalpha, rd;

	rd = d / GetWorldInfo().TimeDilation;
	MissionTime += rd;// uses real time so mission doesn't go on forever

	UpdatePlayers();

	if (AllPlayersDead())
	{
		OwnerAct.OnCancel();
		return;
	}

	// some of this uses partial realtime so timestop is on par with sprint in general
	if (UpdatePressure((d+rd)*0.5)) return;
	UpdateCurrentRoom();
	if (MissionMode != MiniMissionTaskMaster_SingleTask)
	{
		UpdateDifficulty();
		if (TasksPerMinute > 0)
		{
			UpdateSpawnTimerCustom(Spawn1, (d+rd)*0.5, (60/TasksPerMinute)*1.75);
			UpdateSpawnTimerCustom(Spawn2, (d+rd)*0.5, (60/TasksPerMinute)*3.5);
			UpdateSpawnTimerCustom(Spawn3, (d+rd)*0.5, (60/TasksPerMinute)*7);
		}
		OccupationTimescale = Lerp(1, 1.25, FClamp(Difficulty, 0, 1));
	}
	UpdateActiveTasks(d);// use fully dilated time here, so timestop can rescue failing tasks really well

	if (DebugLogHUD)
		Debug_VerboseStatusLog();

	if (MusicEndPitch != 1 && MusicPitchParameterName != '')
	{
		pitchalpha = Pressure;
		// Bit boring if you're super good, increase music pitch as you get closer to the end to add some excitement
		if (GetScoreTarget() > 0 && MissionMode == MiniMissionTaskMaster_ScoreTarget)
		{
			pitchalpha = FMax(pitchalpha, ((float(Score) / float(GetScoreTarget()))**2)*0.75);
		}
		`SetMusicParameterFloat(MusicPitchParameterName, Lerp(1.0, MusicEndPitch, pitchalpha**MusicPitchExponent));
	}
}

function bool AllPlayersDead()
{
	local Hat_Player p;

	foreach Players(p)
		if (p.Health > 0)
			return false;

	return true;
}

function bool UpdatePressure(float d)
{
	if (!MissionUsesPressure()) return false;

	Pressure += (1 - 1/(GetPriorityTasks()+1))*d*Lerp(EasyPressureBuild, HardPressureBuild, Difficulty);

	if (Pressure >= 1)
	{
		if (DebugMode)
			Print("MISSION OVER! You completed"@Score$"/"$GetScoreTarget()@"tasks."@(Score >= GetScoreTarget() ? "Good job!" : "Too bad..."));
		if (Score >= GetScoreTarget()) TriggerComplete();
		else TriggerFail();
		return true;
	}

	return false;
}

function bool MissionUsesPressure()
{
	return MissionMode != MiniMissionTaskMaster_SingleTask;
}

function UpdateDifficulty()
{
	local float vis;

	if (MinutesUntilDifficult > 0 && ScoresUntilDifficult <= 0)
		Difficulty = MissionTime/60/MinutesUntilDifficult;
	else if (MinutesUntilDifficult <= 0 && ScoresUntilDifficult > 0)
		Difficulty = float(Score)/ScoresUntilDifficult;
	else if (MinutesUntilDifficult > 0 && ScoresUntilDifficult > 0)
		Difficulty = FMin(MissionTime/60/MinutesUntilDifficult, float(Score)/ScoresUntilDifficult);
	else
		Difficulty = 0;

	Difficulty *= Lerp(1.5, 0.5, Pressure);

	Difficulty *= Lerp(1.f, 0.1f, GetMercyPercentage());
	Difficulty *= GlobalDifficultyMultiplier;
	if (class'Hat_GameManager'.default.AssistMode)
		Difficulty *= 0.15f;

	vis = GetVisibleTasks();
	SpawnRate = 0.8 + (1 - 1/(Difficulty+1))*0.6;
	SpawnRate *= Lerp(4, 0.1, FMin(1, vis/GetTaskCap()));
	if (vis == 0)
		SpawnRate *= 1.75;
	SpawnRate *= 1 + (Players.Length-1)*(CoopDifficultyRatio-1);
}

function bool Debug_UsingTimeDifficulty()
{
	if (MinutesUntilDifficult > 0 && ScoresUntilDifficult <= 0) return true;
	else if (MinutesUntilDifficult <= 0 && ScoresUntilDifficult > 0) return false;
	else if (MinutesUntilDifficult > 0 && ScoresUntilDifficult > 0) return MissionTime/60/MinutesUntilDifficult < float(Score)/ScoresUntilDifficult;
	return false;
}

function UpdateSpawnTimerCustom(out float spawn, float d, float time)
{
	if (spawn == 0)
	{
		StartTaskForAllPlayers();
        DisplayHUD.ForceUpdateActiveBridgeData();
		SetSpawnTimer(spawn, time);
	}
	else if (spawn == -1)
		SetSpawnTimer(spawn, time*(FRand()*0.8+0.2));

	spawn = FMax(0, spawn - d*SpawnRate);
    SpawnTaskDropRate = FMax(0, d*SpawnRate);
}

function SetSpawnTimer(out float spawn, float time)
{
	spawn = time;
	spawn *= (FRand()+FRand()+FRand()+FRand())*0.5;
}

function Hat_TaskMasterComponent CurTask(int ti, optional int StageOffset = 0)
{
	if (Tasks[ti].Stage + StageOffset < 0) return None;
	if (Tasks[ti].Stage + StageOffset >= Tasks[ti].Objectives.Length) return None;
	return Tasks[ti].Objectives[Tasks[ti].Stage + StageOffset];
}

function SwitchTaskOwnership(int ti, Hat_Player ply)
{
	Tasks[ti].Player = ply;
}

function FailTaskByComponent(Hat_TaskMasterComponent tc)
{
	local int i, ti;

	for (ti = 0; ti < Tasks.Length; ti++)
	{
		for (i = 0; i < Tasks[ti].Objectives.Length; i++)
		{
			if (Tasks[ti].Objectives[i] == tc)
			{
				CurTask(ti).Fail(ti);
				break;
			}
		}
	}
}

function UpdateActiveTasks(float d)
{
	local int i, ti;

	for (i = 0; i < ActiveTasks.Length; i++)
	{
		ti = ActiveTasks[i];

		CurTask(ti).UpdateTimer(d, ti);

		if (Tasks[ti].Waiting > 0)
		{
			Tasks[ti].Waiting = FMax(0, Tasks[ti].Waiting - d*(CurTask(ti).ScaleWaitTime ? OccupationTimescale : 1.0));
			if (Tasks[ti].Waiting == 0)
			{
				if (IsLastStage(ti))
				{
					if (!CurTask(ti).CleanUpOnRestart && !CurTask(ti).ManualCleanup && !CurTask(ti).CleanUpInstantly)
						CurTask(ti).CleanUp(ti);
					CleanUpTaskStruct(ti);
					CurTask(ti).WipeTask(ti);
					Tasks[ti].Completions++;
					ActiveTasks.Remove(i, 1);
					i--;
				}
				else if (ContinueTasksInstantly)
				{
					if (!CurTask(ti).CleanUpOnRestart && !CurTask(ti).ManualCleanup && !CurTask(ti).CleanUpInstantly)
						CurTask(ti).CleanUp(ti);
					StartTask(Tasks[ti].Player, ti);
				}
			}
		}
		else if (CurTask(ti).IsComplete(ti) && Tasks[ti].Waiting == -1)
		{
			CompleteTask(ti);

			if (CurTask(ti).WaitTime > 0)
			{
				Tasks[ti].Waiting = CurTask(ti).WaitTime;
				if (CurTask(ti).CleanUpInstantly && !CurTask(ti).ManualCleanup)
					CurTask(ti).CleanUp(ti);
			}
			else
			{
				if (IsLastStage(ti) || !StartTask(Tasks[ti].Player, ti))
				{
					CleanUpTaskStruct(ti);
					CurTask(ti).WipeTask(ti, true);
					Tasks[ti].Completions++;
					ActiveTasks.Remove(i, 1);
					i--;
				}
			}
		}
		else if (CurTask(ti).IsFailed(ti))
		{
			if (FailSound != None)
				GetWorldInfo().GetALocalPlayerController().PlaySound(FailSound);

			if (MissionMode == MiniMissionTaskMaster_SingleTask)
			{
				if (DebugMode)
					Print("MISSION OVER! You failed the task...");
				TriggerFail();
				return;
			}
			else
			{
				CleanUpTaskStruct(ti);
				CurTask(ti).WipeTask(ti);
				ActiveTasks.Remove(i, 1);
				i--;
				FailTask(ti);
			}
		}
	}

	if (MissionMode == MiniMissionTaskMaster_SingleTask)
	{
		if (AllTasksCompleteWaiting())
		{
			if (DebugMode)
				Print("MISSION OVER! You completed all tasks!");
			TriggerComplete();
		}
	}
	else if (MissionMode == MiniMissionTaskMaster_ScoreTarget)
	{
		if (Score >= GetScoreTarget())
		{
			if (DebugMode)
				Print("MISSION OVER! You completed all tasks!");
			TriggerComplete();
		}
	}
}

function int GetScoreTarget()
{
	return Round(ScoreTarget*(1 + (Players.Length-1)*(CoopScoreRatio-1)));
}

function bool AllTasksCompleteWaiting()
{
	local int i;

	if (ActiveTasks.Length == 0) return true;

	for (i = 0; i < ActiveTasks.Length; i++)
	{
		if (!CurTask(ActiveTasks[i]).IsComplete(ActiveTasks[i]) && !CurTask(ActiveTasks[i]).IsClean(ActiveTasks[i])) return false;
		if (!IsLastStage(ActiveTasks[i])) return false;
	}

	return true;
}

function FailTask(int ti)
{
	local Hat_GameEventsInterface GEI;

	if (DebugMode)
		Print("Failing task for"@CurTask(ti));

	Pressure = FMin(Pressure + FailPressure/FMax(1, GetTaskCap()*FailPressureTaskCapFactor), 1);

	foreach `GameEventsArray(GEI)
		GEI.OnMiniMissionGenericEvent(self, "miss");

	PlayRadioTaskFail(CurTask(ti));

	CurTask(ti).Fail(ti);
	CleanUpTaskStruct(ti);

	FailShake = true;

    DisplayHUD.ForceUpdateActiveBridgeData();
}

function CleanUpMission(optional bool fail)
{
	local Actor a;
	local int ti;

	foreach TaskActors(a)
	{
		if (GetTaskComponent(a) == None) continue;

		if (fail)
			GetTaskComponent(a).Fail();

		GetTaskComponent(a).WipeTask(, true);
	}

	for (ti = 0; ti < Tasks.Length; ti++)
		CleanUpTaskStruct(ti);

	ActiveTasks.Length = 0;
	
	if (DisableUnrelatedInteractions)
		Hat_GameMissionManager(`GameManager).DisableUnrelatedInteractions = false;
}

function CompleteTask(int ti)
{
	local float GiveScoreFactor;
	local Hat_GameEventsInterface GEI;

	GiveScoreFactor = CurTask(ti).GiveScore ? 1.0 : NonScorePressure;

	Pressure = FMax(0, Pressure - SucceedPressure/FMax(1, GetTaskCap()*SucceedPressureTaskCapFactor)*GiveScoreFactor);

	if (CurTask(ti).GiveScore)
	{
		Score++;

		foreach `GameEventsArray(GEI)
			GEI.OnMiniMissionGenericEvent(self, "score");

		if (ScoreSound != None)
			GetWorldInfo().GetALocalPlayerController().PlaySound(ScoreSound);

		if (DebugMode)
			Print("Total tasks completed:"@Score);
	}

	if (MissionMode != MiniMissionTaskMaster_SingleTask && DebugMode)
		Debug_StatusLog();

	CurTask(ti).Complete(ti);

    DisplayHUD.ForceUpdateActiveBridgeData();
}

function CleanUpTaskStruct(int ti)
{
	Tasks[ti].Stage = 0;
	Tasks[ti].Player = None;
	Tasks[ti].Waiting = -1;
}

function OnComplete()
{
	CleanUpMission();
	if (GameOverSound != None)
		GetWorldInfo().GetALocalPlayerController().PlaySound(GameOverSound);
	if (DebugMode)
		Print("End of mission: Complete");
	Super.OnComplete();
}

function OnFail()
{
	CleanUpMission();
	if (GameOverSound != None)
		GetWorldInfo().GetALocalPlayerController().PlaySound(GameOverSound);
	if (DebugMode)
		Print("End of mission: Fail");
	
	if (HaveMercy)
	{
		class'Hat_SaveBitHelper'.static.SetActBits("TaskMasterHaveMercy", class'Hat_SaveBitHelper'.static.GetActBits("TaskMasterHaveMercy")+1);
	}
	
	Super.OnFail();
}

function OnCancel()
{
	CleanUpMission();
	if (DebugMode)
		Print("End of mission: Canceled");
	Super.OnCancel();
}

function PlayRadioMood(int Mood)
{
	if (Mood <= LastMoodRadio) return;

	if (Mood == 1 && RadioPressureThresholdMedium != None)
		RadioMessage(RadioPressureThresholdMedium);
	else if (Mood == 2 && RadioPressureThresholdHigh != None)
		RadioMessage(RadioPressureThresholdHigh);
	else if (Mood == 3 && RadioPressureThresholdExtreme != None)
		RadioMessage(RadioPressureThresholdExtreme);

	LastMoodRadio = Mood;

	Players[0].Controller.ClearTimer(NameOf(WipeLastMoodRadio), self);
	Players[0].Controller.SetTimer(20, false, NameOf(WipeLastMoodRadio), self);
}

function PlayRadioTaskStart(optional Hat_TaskMasterComponent tc)
{
	if (tc != None && tc.RadioMessageStart != None && RadioSpecificAssignChance != 0 && (RadioSpecificAssignChance == 1 || FRand() <= RadioSpecificAssignChance))
		RadioMessage(tc.RadioMessageStart);
	else if (RadioAssignTaskGeneric != None && RadioGenericAssignChance != 0 && (RadioGenericAssignChance == 1 || FRand() <= RadioGenericAssignChance))
		RadioMessage(RadioAssignTaskGeneric);
}

function PlayRadioTaskFail(optional Hat_TaskMasterComponent tc)
{
	if (tc != None && tc.RadioMessageFail != None && RadioSpecificFailChance != 0 && (RadioSpecificFailChance == 1 || FRand() <= RadioSpecificFailChance))
		RadioMessage(tc.RadioMessageFail);
	else if (RadioFailTaskGeneric != None && RadioGenericFailChance != 0 && (RadioGenericFailChance == 1 || FRand() <= RadioGenericFailChance))
		RadioMessage(RadioFailTaskGeneric);
}

function WipeLastMoodRadio()
{
	LastMoodRadio = 0;
}

function RadioMessage(Hat_ConversationTree tree)
{
	RadioMessageToDo = tree;
	Players[0].Controller.ClearTimer(NameOf(DoRadioMessage), self);
	Players[0].Controller.SetTimer(1, false, NameOf(DoRadioMessage), self);
}

function DoRadioMessage()
{
	local Hat_Player ply;
	foreach Players(ply)
		class'Hat_HUDElementPlayerRadio'.static.PushConversationTree(PlayerController(ply.Controller), RadioMessageToDo);

	RadioMessageToDo = None;
}

function Hat_ObjectiveActor GetMostUrgentObjectiveActor(Actor ply)
{
	local Array<Hat_HouseRoomVolume> Rooms;
	local Array<int> RoomPop;
	local int i, ti, curpop, presstasks, pid;
	local Hat_ObjectiveActor curobj, bestobj;
	local float urgency, mosturgent;
	local Hat_HouseRoomVolume r;
	local Hat_StatusEffect_CarryStack carrystack;
	local bool notasks;

	// exit quick if there's no active tasks
	notasks = true;
	foreach ActiveTasks(ti)
	{
		if (CurTask(ti).IsActive(ti))
		{
			notasks = false;
			break;
		}
	}
	if (notasks) return None;

	// populate room pop
	foreach GetWorldInfo().DynamicActors(class'Hat_HouseRoomVolume', r)
	{
		curpop = 0;

		foreach ActiveTasks(ti)
			if (CurTask(ti).IsActive(ti) && class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, r))
				curpop++;

		Rooms.AddItem(r);
		RoomPop.AddItem(curpop);
	}

	if (Hat_PawnCombat(ply) != None)
		carrystack = Hat_StatusEffect_CarryStack(Hat_PawnCombat(ply).GetStatusEffect(class'Hat_StatusEffect_CarryStack', true));

	foreach ActiveTasks(ti)
		if (!CurTask(ti).LowPriority)
			presstasks++;

	pid = Players.Find(ply);

	if (PreviousOptimalObjective.Length < pid+1)
		PreviousOptimalObjective.Length = pid+1;

	// determine highest priority task
	foreach ActiveTasks(ti)
	{
		urgency = 0;
		curobj = CurTask(ti).GetObjectiveActorWithShortestTime();
		if (curobj == None) continue;

		if (CurTask(ti).LockTaskToStartingPlayer && CurTask(ti).GetPlayer(ti) != ply) continue;

		for (i = 0; i < Rooms.Length; i++)
		{
			if (!class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(CurTask(ti).Owner, Rooms[i])) continue;
			// tasks in rooms with many tasks
			urgency += (Sqrt(RoomPop[i])-1)*50;
			// tasks in rooms that you are in
			if (CurrentRoom[pid] != None && Rooms[i] == CurrentRoom[pid]) urgency += 100;
			// tasks adjacent rooms
			else if (CurrentRoom[pid] != None && CurrentRoom[pid].NearbyRooms.Find(Rooms[i]) != INDEX_NONE) urgency += 50;
			break;
		}

		// tasks that have less time left
		urgency -= Lerp(curobj.LifeTimeActor.LifeSpan, Sqrt(curobj.LifeTimeActor.LifeSpan), 0.3)*1.5;

		// tasks that are nearby
		urgency -= VSize(CurTask(ti).Owner.Location - ply.Location)*0.015;

		// tasks that are nearby AND are deliveries
		if (CurTask(ti).Owner.IsA('Hat_DeliveryPoint'))
			urgency -= VSize(CurTask(ti).Owner.Location - ply.Location)*0.01;

		// tasks that are deliveries, if your stack is high
		if (carrystack != None && carrystack.IsMovementImpaired() && CurTask(ti).Owner.IsA('Hat_DeliveryPoint'))
			urgency += carrystack.GetDifficulty()*45;

		// tasks that grant score, if pressure is too high
		if (CurTask(ti).GiveScore)
			urgency += Lerp(0, 50, 1-Sqrt(1-Pressure));

		// tasks that are increasing pressure, if there's a majority of tasks increasing pressure
		if (!CurTask(ti).LowPriority)
			urgency += (FMax(0, presstasks - ActiveTasks.Length*0.5)**2)*0.7;

		// task that was previously selected as most urgent (prevents it from switching back and forth too much)
		//if (PreviousOptimalObjective[pid] != None && curobj == PreviousOptimalObjective[pid])
		//	urgency += 10;

		if (bestobj == None || urgency > mosturgent)
		{
			bestobj = curobj;
			mosturgent = urgency;
		}
	}

	PreviousOptimalObjective[pid] = bestobj;
	return bestobj;
}

function float GetMercyPercentage()
{
	if (!HaveMercy) return 0;
	if (class'Hat_SnatcherContract_DeathWish'.static.IsAnyActive(false)) return 0;
	
	// 4 attempts and then it goes super easy
	return FClamp(float(class'Hat_SaveBitHelper'.static.GetActBits("TaskMasterHaveMercy")) / 4.f,0,1);
}

static final function Print(coerce string msg, optional bool Force = false)
{
    local WorldInfo wi;

	if(!TaskDebugMode && !Force) return;

	msg = "[TaskDisplay] " $ msg;

    wi = class'WorldInfo'.static.GetWorldInfo();
    if (wi != None)
    {
        if (wi.GetALocalPlayerController() != None)
            wi.GetALocalPlayerController().TeamMessage(None, msg, 'Event', 6);
        else
            wi.Game.Broadcast(wi, msg);
    }
}