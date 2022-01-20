/*
* Code by EpicYoshiMaster
*
* Information HUD displaying relevant data for Ship Shape
* obtained from the Taskmaster.
*/
class Yoshi_HUDElement_TaskmasterDisplay extends Hat_HUDElement
	dependsOn(Yoshi_TaskmasterHelper);

var Yoshi_MiniMissionTaskmaster_InfoDisplay Taskmaster;
var TaskmasterDataPack Pack;

struct KeyValuePair {
	var string Key;
	var string Value;
};

var array<KeyValuePair> DataMap;

function OnOpenHUD(HUD H, optional String command)
{
	Pack.ShouldUpdateRooms = true;
}

function DrawLine(HUD H, coerce string key, coerce string value, float PosX, float PosY, float textscale, float OffsetX, optional Color titleColor)
{
    if(titleColor.A <= 0) {
        titleColor.R = 255;
        titleColor.G = 255;
        titleColor.B = 255;
    }
    titleColor.A = 200;
    H.Canvas.SetDrawColorStruct(titleColor);
    class'Hat_HUDMenu'.static.RenderBorderedText(H, self, key $ ":", PosX, PosY, textscale, TextAlign_Left);
    H.Canvas.SetDrawColor(255, 200, 200, 200);
    class'Hat_HUDMenu'.static.RenderBorderedText(H, self, value, PosX + OffsetX, PosY, textscale, TextAlign_Right);
}

function bool Render(HUD H)
{
	local int i;
    local float PosX, PosY, OffsetX, OffsetY, textscale;
    if(!Super.Render(H)) return false;

	H.Canvas.Font = class'Hat_FontInfo'.static.GetDefaultFont("0123456789.:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");

    PosX = 0.01 * H.Canvas.ClipX;
	OffsetX = 0.275 * H.Canvas.ClipX;
    PosY = 0.02 * H.Canvas.ClipY;
    OffsetY = 0.036 * H.Canvas.ClipY;
	textscale = 0.0005 * H.Canvas.ClipY;

	class'Yoshi_TaskmasterHelper'.static.UpdatePack(Pack, Taskmaster, Hat_Player(H.PlayerOwner.Pawn));
	UpdateDataMap();

	for(i = 0; i < DataMap.length; i++) {
		DrawLine(H, DataMap[i].Key, DataMap[i].Value, PosX, PosY, textscale, OffsetX);
		PosY += OffsetY;
	}
    
    return true;
}

function ForceUpdateActiveBridgeData() {
    Pack.ShouldUpdateRooms = true;
}

function UpdateDataMap() {
	DataMap[0].Value = Taskmaster.Pressure $ " | " $ Taskmaster.Difficulty;
	DataMap[1].Value = Taskmaster.HardTaskCap $ " | " $ Taskmaster.GetTaskCap();
	DataMap[2].Value = class'Yoshi_TaskmasterHelper'.static.ConvertToRoomName(Pack.CurrentRoom) @ "|" @ class'Yoshi_TaskmasterHelper'.static.ConvertToRoomName(Pack.PreviousRoom);
	DataMap[3].Value = Pack.NearbyRooms;
	DataMap[4].Value = Pack.ActiveRooms;
	DataMap[5].Value = Pack.BridgeRooms;
	DataMap[6].Value = string(Pack.DistantTask);
	DataMap[7].Value = string(Taskmaster.Spawn1);
	DataMap[8].Value = string(Taskmaster.Spawn2);
	DataMap[9].Value = string(Taskmaster.Spawn3);
	DataMap[10].Value = "-" $ Taskmaster.SpawnTaskDropRate;
	DataMap[11].Value = "" $ FMin(1, Taskmaster.default.FavorCurrentRoom * Lerp(2, 1, FMin(1, Taskmaster.Difficulty)));
}

defaultproperties
{
	DataMap(0)=(Key="Pressure | Difficulty")
	DataMap(1)=(Key="Hard Task Cap | Task Cap")
	DataMap(2)=(Key="Curr | Prev")
	DataMap(3)=(Key="Nearby")
	DataMap(4)=(Key="Active")
	DataMap(5)=(Key="Bridge")
	DataMap(6)=(Key="Distant Task")
	DataMap(7)=(Key="Task Timer 1")
	DataMap(8)=(Key="Task Timer 2")
	DataMap(9)=(Key="Task Timer 3")
	DataMap(10)=(Key="Task Timer Decrease")
	DataMap(11)=(Key="Current Favor")
}