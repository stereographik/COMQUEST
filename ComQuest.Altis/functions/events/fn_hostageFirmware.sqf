/*
    CQ_fnc_hostageFirmware  (server, from the hostage's hold action, or the debug panel)
    [_player] remoteExec ["CQ_fnc_hostageFirmware", 2];
    The firmware is downloaded: the extraction starts. The hostage gets up and joins our side
    (CSAT now shoots at him) but lies wounded, a crewed friendly helicopter waits on the ground on a clear spot
    CQ_hstLzR m away with its rotors turning, and CQ_hstGuer guerillas are sent after him.
    CQ_fnc_hostageTick walks him to the helicopter and flies it home.
*/
params [["_p", objNull]];
if (!isServer || { isNil "CQ_hstState" }) exitWith {};
private _s = CQ_hstState;
if !((_s get "phase") in ["held", "clear"]) exitWith {};
private _h = _s get "hostage";
if (!alive _h) exitWith {};
_h setVariable ["CQ_hstFw", true, true];
_s set ["freer", _p];

// ---- the hostage on our side (CSAT now shoots at him), too hurt to walk: lying, to be carried
private _wg = createGroup [west, true];
[_h] joinSilent _wg;
_h setCaptive false;
_wg setBehaviour "CARELESS";
_wg setGroupIdGlobal ["Technician"];
[_h, "AinjPpneMstpSnonWnonDnon"] remoteExec ["switchMove", 0];
[_h,
    "<t color='#918C3B'>Carry the technician</t>",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_revive_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_revive_ca.paa",
    "_this distance _target < 3 && { alive _this } && { alive _target } && { vehicle _target == _target } && { isNull attachedTo _target } && { isNil { _this getVariable 'CQ_hstCarrying' } } && { vehicle _this == _this }",
    "_caller distance _target < 3 && { alive _target }",
    {}, {},
    { params ["_target"]; ["carry", _target] call CQ_fnc_hostageCarry },
    {}, [], 2, 11, false, false
] remoteExec ["BIS_fnc_holdActionAdd", 0, _h];

[_s] call CQ_fnc_hostageHeli;

// ---- guerillas after him
private _n = (CQ_hstGuer select 0) + floor random ((CQ_hstGuer select 1) - (CQ_hstGuer select 0) + 1);
private _hp = getPosATL _h;
private _from = [];
for "_i" from 1 to 10 do {
    private _q = _hp getPos [(CQ_hstGuerDist select 0) + random ((CQ_hstGuerDist select 1) - (CQ_hstGuerDist select 0)), random 360];
    if (!surfaceIsWater _q && { (allPlayers findIf { alive _x && { _x distance2D _q < 150 } }) == -1 }) exitWith { _from = _q };
};
if (_from isEqualTo []) then { _from = _hp getPos [CQ_hstGuerDist select 1, random 360] };
private _gg = createGroup [east, true];
private _classes = [CQ_guerillaLeader] + ((CQ_guerillaClasses call BIS_fnc_arrayShuffle) select [0, _n - 1]);
{ [_gg, _from, _x, 10] call CQ_fnc_civArm } forEach _classes;
[units _gg] call CQ_fnc_unitPrep;
_gg setVariable ["CQ_role", "guerilla"];
_gg setBehaviour "AWARE"; _gg setCombatMode "RED"; _gg setSpeedMode "FULL";
_gg enableDynamicSimulation false;
_gg reveal [_h, 4];
_gg move _hp;
_s set ["guer", _gg];

_s set ["phase", "extract"];
_s set ["stuckT", time]; _s set ["lastD", 1e6];
private _who = if (isNull _p) then { "Command" } else { name _p };
["Hostage event: firmware downloaded by %1, helicopter on the ground at %2 (%3 m), %4 guerillas coming from %5 m", [_who, mapGridPosition (_s get "lz"), round ((_s get "lz") distance2D _h), count units _gg, round (_from distance2D _hp)]] call CQ_fnc_log;
["hstFirmware", [_who, mapGridPosition (_s get "lz")]] call CQ_fnc_say;
