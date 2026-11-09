/*
    CQ_fnc_vehAutoFill  (server, from a player action through remoteExec)
    ["fill", _vehicle, _player] / ["clear", _vehicle, _player]
    In a loadout zone (CQ_loadZones, within CQ_loadZoneRadius):
      fill   replaces the vehicle's inventory with a full squad resupply: magazines for every
             player class, launcher rounds, grenades, smokes, 40 mm, explosives, first aid
             kits, medikit, toolkit (CQ_fnc_crateFill), scaled to the vehicle's cargo space
             (cars ~0.6, trucks and transport helicopters 1-1.5, small helicopters 0.4)
      clear  empties the vehicle's inventory
*/
params ["_mode", "_v", "_who"];
if (!isServer || { !alive _v }) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", owner _who] };
if ((CQ_loadZones findIf { _v distance2D _x < CQ_loadZoneRadius }) == -1) exitWith { ["Drive the vehicle into a loadout zone first"] call _say };
private _name = getText (configOf _v >> "displayName");
clearWeaponCargoGlobal _v; clearMagazineCargoGlobal _v; clearItemCargoGlobal _v; clearBackpackCargoGlobal _v;
if (_mode == "clear") exitWith { [format ["%1: inventory emptied", _name]] call _say };
private _load = getNumber (configOf _v >> "maximumLoad");
private _f = ((_load / 4000) max 0.4) min 1.5;
[_v, _f, false] call CQ_fnc_crateFill;
[format ["%1 filled with a squad resupply (x%2)", _name, (round (_f * 10)) / 10]] call _say;
["Auto-fill: %1 filled %2 (factor %3)", [name _who, typeOf _v, _f]] call CQ_fnc_log;
