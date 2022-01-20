/*
* Code by EpicYoshiMaster
*
* Static Helper class designed to abstract away all of the garbage re-calculations
* done by the Taskmaster
*/
class Yoshi_TaskmasterHelper extends Object 
	abstract;

struct TaskmasterDataPack {
	var Hat_HouseRoomVolume CurrentRoom;
	var Hat_HouseRoomVolume PreviousRoom;
	var Actor DistantTask;
	var bool ShouldUpdateRooms;

	var string NearbyRooms;
	var string ActiveRooms;
	var string BridgeRooms;
};

static function UpdatePack(out TaskmasterDataPack Pack, Hat_MiniMissionTaskmaster Taskmaster, Hat_Player ply) {
	local array<Hat_HouseROomVolume> TempRooms;
	local array<Hat_HouseRoomVolume> PossibleRooms;
	local Array<int> ValidIndex;

	//We've just changed rooms, we need to make sure we update our bridge data this time
	if(Pack.CurrentRoom == None || Pack.CurrentRoom != Taskmaster.CurrentRoom[0]) {
		Pack.CurrentRoom = Taskmaster.CurrentRoom[0];
		Pack.PreviousRoom = Taskmaster.PreviousRoom[0];

		Pack.ShouldUpdateRooms = true;
	}

	Pack.NearbyRooms = ConvertRoomsToString(Pack.CurrentRoom.NearbyRooms);

	if(!Pack.ShouldUpdateRooms) return;

	GetValidTaskIndices(Taskmaster, ply, ValidIndex);

	TempRooms = GetActiveRooms(Taskmaster, ValidIndex, PossibleRooms);
	Pack.ActiveRooms = ConvertRoomsToString(TempRooms);

	TempRooms = GetBridgeRooms(Taskmaster, PossibleRooms, Pack.DistantTask);
	Pack.BridgeRooms = ConvertRoomsToString(TempRooms);

	Pack.ShouldUpdateRooms = false;
}

static function string ConvertRoomsToString(out array<Hat_HouseRoomVolume> Rooms) {
	local int i;
	local string s;

	s = "";
	for(i = 0; i < Rooms.length; i++) {
		s @= ConvertToRoomName(Rooms[i]);
	}

	if(s == "") {
		s = "None";
	}

	return s;
}

static function GetValidTaskIndices(Hat_MiniMissionTaskmaster Taskmaster, Hat_Player ply, out array<int> ValidIndex) {
	local float TaskRange;
	local int ti;

	TaskRange = Taskmaster.EarlyRangeLimit;

	while (TaskRange <= 10000)
	{
		for (ti = 0; ti < Taskmaster.Tasks.Length; ti++)
			if (Taskmaster.CanAssignTask(ply, ti))
				if (Taskmaster.IsTaskInAssignRange(ply, ti, TaskRange))
					ValidIndex.AddItem(ti);

		if (ValidIndex.Length > 0) break;

		TaskRange += 500;
	}

	// remove impossible tasks
	if (ValidIndex.Length == 0)
		for (ti = 0; ti < Taskmaster.Tasks.Length; ti++)
			if (Taskmaster.CanAssignTask(ply, ti))
				ValidIndex.AddItem(ti);
}

static function array<Hat_HouseRoomVolume> GetActiveRooms(Hat_MiniMissionTaskmaster Taskmaster, const out array<int> TaskIndex, out array<Hat_HouseRoomVolume> PossibleRooms) {
    local array<Hat_HouseRoomVolume> ActiveRooms;
    local Hat_HouseRoomVolume r;
    local bool TaskInRoom;
    local int ti, CurActive, MostActive;
    local bool ShouldAvoidPrevious;

    ShouldAvoidPrevious = false; //We'll just assume this since the rng is pointless to attempt to emulate
    PossibleRooms.length = 0;

    // find most active adjacent room
	foreach Taskmaster.CurrentRoom[0].NearbyRooms(r)
	{
		PossibleRooms.AddItem(r);

		// skip previous room unless you're in a dead end
		if (ShouldAvoidPrevious && r == Taskmaster.PreviousRoom[0] && Taskmaster.CurrentRoom[0].NearbyRooms.Length > 1) continue;

		// find most active room
		if (Taskmaster.FavorActiveRooms > 0)
		{
			CurActive = 0;
			foreach Taskmaster.ActiveTasks(ti)
			{
				if (!Taskmaster.IsTaskVisible(ti)) continue;
				if (!class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Taskmaster.CurTask(ti).Owner, r)) continue;
				CurActive++;
			}

			TaskInRoom = false;
			foreach TaskIndex(ti)
			{
				if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Taskmaster.Tasks[ti].Objectives[0].Owner, r))
				{
					TaskInRoom = true;
					break;
				}
			}
			if (!TaskInRoom) continue;

			if (CurActive > MostActive) {
                MostActive = CurActive;
                ActiveRooms.length = 0;
                ActiveRooms.AddItem(r);
            }
			else if(CurActive >= MostActive) {
				ActiveRooms.AddItem(r);
			}
		}
	}

    return ActiveRooms;
}

static function array<Hat_HouseRoomVolume> GetBridgeRooms(Hat_MiniMissionTaskmaster Taskmaster, const out array<Hat_HouseRoomVolume> PossibleRooms, out Actor DistantTask) {
    local Hat_HouseRoomVolume r, nr, nnr;
    local Array<Hat_HouseRoomVolume> BridgeRooms;
    local bool TaskInRoom;
    local int ti;

    DistantTask = None;

	foreach Taskmaster.ActiveTasks(ti)
	{
		if (!Taskmaster.IsTaskVisible(ti)) continue;
		if (Taskmaster.CurTask(ti).LowPriority && !Taskmaster.CurTask(ti).GiveScore) continue;

		// check if task is in current room
		TaskInRoom = class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Taskmaster.CurTask(ti).Owner, Taskmaster.CurrentRoom[0]);

		// check if task is in adjacent rooms
		if (!TaskInRoom)
			foreach PossibleRooms(r)
				if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Taskmaster.CurTask(ti).Owner, r))
				TaskInRoom = true;

		if (!TaskInRoom)
		{
			DistantTask = Taskmaster.CurTask(ti).Owner;

			// check adjacencies of adjacent rooms
			foreach PossibleRooms(r)
				foreach r.NearbyRooms(nr)
					if (BridgeRooms.Find(r) == INDEX_NONE)
						if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Taskmaster.CurTask(ti).Owner, nr))
							BridgeRooms.AddItem(r);

			if (BridgeRooms.Length > 0) break;

			// check adjacencies of adjacencies of adjacent rooms
			foreach PossibleRooms(r)
				foreach r.NearbyRooms(nr)
					foreach nr.NearbyRooms(nnr)
						if (BridgeRooms.Find(r) == INDEX_NONE)
							if (class'Hat_SeqCond_IsInVolume'.static.ActorInVolume(Taskmaster.CurTask(ti).Owner, nnr))
								BridgeRooms.AddItem(r);

           //Once we find a bridge room, that's all we need
			if (BridgeRooms.Length > 0)	break;
		}
	}

	return BridgeRooms;
}

static function String ConvertToRoomName(Hat_HouseRoomVolume Room) {
    if(Room == None) return "None";

    switch(Room.Name) {
        case 'Hat_HouseRoomVolume_0': return "Pool/Playpen";
        case 'Hat_HouseRoomVolume_1': return "Brown";
        case 'Hat_HouseRoomVolume_2': return "Yellow";
        case 'Hat_HouseRoomVolume_3': return "Merseal";
        case 'Hat_HouseRoomVolume_4': return "Gambling";
        case 'Hat_HouseRoomVolume_5': return "Captain";
        case 'Hat_HouseRoomVolume_6': return "Dining";
        case 'Hat_HouseRoomVolume_8': return "Lobby";
        case 'Hat_HouseRoomVolume_9': return "Kitchen/Laundry";
        case 'Hat_HouseRoomVolume_10': return "Engine Room";
    }
}