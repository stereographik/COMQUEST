/*
    CQ_fnc_vehAutoFill  (server, from a player action through remoteExec)
    ["fill", _vehicle, _player] / ["clear", _vehicle, _player]
    Near a vehicle arsenal box or in a loading zone (CQ_fnc_vehFillSpot):
      fill   replaces the vehicle's cargo with what THIS squad shoots: every member (wherever
             he is) is read - rifle, underbarrel launcher, launcher, pistol, the magazines in
             use - and gets a balanced share (CQ_fillShare), plus a few essentials each and a
             medikit / toolkit if the squad has a medic / an engineer. The whole load is scaled
             to the vehicle's cargo space: smaller vehicle, every share shrinks alike; bigger
             one, shares grow up to CQ_fillMaxScale (a player alone: up to CQ_fillSoloScale).
      clear  empties the vehicle's cargo
*/
params ["_mode", "_v", "_who"];
if (!isServer || { !alive _v }) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", owner _who] };
if !([_v] call CQ_fnc_vehFillSpot) exitWith { ["Bring the vehicle next to a vehicle arsenal box or into a loading zone first"] call _say };
private _name = getText (configOf _v >> "displayName");
clearWeaponCargoGlobal _v; clearMagazineCargoGlobal _v; clearItemCargoGlobal _v; clearBackpackCargoGlobal _v;
if (_mode == "clear") exitWith { [format ["%1: cargo emptied", _name]] call _say };

CQ_fillShare params ["_sRifle", "_sBelt", "_sSniper", "_sUgl", "_sLaunch", "_sLaunchAlt", "_sPistol", "_sNade", "_sSmoke", "_sFak"];
private _need = createHashMap;
private _add = { params ["_c", "_k"]; if (_c != "" && { _k > 0 }) then { _need set [_c, (_need getOrDefault [_c, 0]) + _k] } };
private _mags = { params ["_w"]; getArray (configFile >> "CfgWeapons" >> _w >> "magazines") select { isClass (configFile >> "CfgMagazines" >> _x) } };
private _solo = (group _who) getVariable ["CQ_solo", false] || { count units group _who < 2 };
private _men = [units group _who, [_who]] select _solo;
private _medic = false; private _eng = false;
{
    private _u = _x;
    // rifle (or SMG, MG, marksman rifle)
    private _pw = primaryWeapon _u;
    if (_pw != "") then {
        private _m = (primaryWeaponMagazine _u) param [0, ([_pw] call _mags) param [0, ""]];
        if (_m != "") then {
            private _cnt = getNumber (configFile >> "CfgMagazines" >> _m >> "count");
            [_m, [[_sRifle, _sSniper] select (_cnt <= 10), _sBelt] select (_cnt >= 75)] call _add;
        };
        // underbarrel launcher: HE shells
        {
            if (_x != "this") then {
                private _um = getArray (configFile >> "CfgWeapons" >> _pw >> _x >> "magazines");
                [["1Rnd_HE_Grenade_shell", _um param [0, ""]] select !("1Rnd_HE_Grenade_shell" in _um), _sUgl] call _add;
            };
        } forEach getArray (configFile >> "CfgWeapons" >> _pw >> "muzzles");
    };
    // launcher: the round in use, plus one of the other kind if it has one (AP, HE)
    private _sw = secondaryWeapon _u;
    if (_sw != "") then {
        private _all = [_sw] call _mags;
        private _m = (secondaryWeaponMagazine _u) param [0, _all param [0, ""]];
        private _alt = (_all - [_m]) param [0, ""];
        [_m, [_sLaunch + 1, _sLaunch] select (_alt != "")] call _add;
        [_alt, _sLaunchAlt] call _add;
    };
    private _hw = handgunWeapon _u;
    if (_hw != "") then { [(handgunMagazine _u) param [0, ([_hw] call _mags) param [0, ""]], _sPistol] call _add };
    ["HandGrenade", _sNade] call _add;
    ["SmokeShell", _sSmoke] call _add;
    ["FirstAidKit", _sFak] call _add;
    if (_u getUnitTrait "medic") then { _medic = true };
    if (_u getUnitTrait "engineer") then { _eng = true };
} forEach (_men select { alive _x });
if (_medic) then { ["Medikit", 1] call _add };
if (_eng) then { ["ToolKit", 1] call _add };

// mass of the whole load against the vehicle's cargo space
private _mass = {
    params ["_c"];
    if (isClass (configFile >> "CfgMagazines" >> _c)) then { getNumber (configFile >> "CfgMagazines" >> _c >> "mass") }
    else { getNumber (configFile >> "CfgWeapons" >> _c >> "ItemInfo" >> "mass") }
};
private _total = 0;
{ _total = _total + (([_x] call _mass) max 1) * _y } forEach _need;
private _cap = getNumber (configOf _v >> "maximumLoad") * 0.95;
private _s = if (_total > 0) then { (_cap / _total) min ([CQ_fillMaxScale, CQ_fillSoloScale] select _solo) } else { 1 };
private _lines = [];
{
    private _k = floor (_y * _s);
    if (_k < 1 && { _s >= 0.5 }) then { _k = 1 };
    if (_k > 0) then {
        if (isClass (configFile >> "CfgMagazines" >> _x)) then { _v addMagazineCargoGlobal [_x, _k] } else { _v addItemCargoGlobal [_x, _k] };
        private _root = ["CfgWeapons", "CfgMagazines"] select (isClass (configFile >> "CfgMagazines" >> _x));
        private _dn = getText (configFile >> _root >> _x >> "displayNameShort");
        if (_dn == "") then { _dn = getText (configFile >> _root >> _x >> "displayName") };
        _lines pushBack format ["%1 x %2", _k, _dn];
    };
} forEach _need;
[format ["%1 loaded for %2 (%3 men, x%4):\n%5", _name, [groupId group _who, name _who] select _solo, count _men, (round (_s * 10)) / 10, _lines joinString "\n"]] call _say;
["Autofill: %1 filled %2 for %3 men (scale %4, %5 kinds)", [name _who, typeOf _v, count _men, (round (_s * 100)) / 100, count _lines]] call CQ_fnc_log;
