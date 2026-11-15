/*
    CQ_fnc_killTag  (client, from the player's HandleDamage in CQ_fnc_playerSetup)
    [_victim, _shooter, _source] call CQ_fnc_killTag  ->  "SNIPER · Ivan Petrov · GM6 Lynx (12.7x108 mm)"
    What hit a player, for the feed ("Django was killed by ..." / "Django is down · ..."):
    a category, then the shooter's name, his weapon and its caliber. First match wins:
      FRIENDLY FIRE         a player of ours
      SPECIAL FORCES (team) HUNTERS / SABOTAGE teams (CQ_hunter)
      MORTAR                a mortar or any artillery piece
      SNIPER                sniper teams, snipers, spotters, marksmen, sniper rifles
      AIR                   helicopters and planes
      HEAVY                 any vehicle or static weapon (tanks, APCs, armed cars, HMG/GMG/AT)
      MISSION SQUAD (name)  CQ_killMissionSquads (hostage guards, outpost, tower guards)
      GUERILLA              the local militia (independent side)
      INFANTRY              any other enemy soldier
      ACCIDENT              no shooter: crash, run over, own explosive
*/
params ["_u", "_w", "_src"];
if (!isNull _w && { !(_w isKindOf "CAManBase") } && { !isNull effectiveCommander _w }) then { _w = effectiveCommander _w };   // a vehicle: its commander
if (isNull _w || { _w == _u }) exitWith { "ACCIDENT" };
private _v = vehicle _w;
private _g = group _w;
private _gid = groupId _g;
private _tl = toLower typeOf _w;
// weapon in use (the turret's when he mans a vehicle) and its magazine
private _ws = if (_v != _w) then { weaponState [_v, _v unitTurret _w] } else { weaponState _w };
_ws params [["_wpn", ""], "", "", ["_mag", ""]];
private _cat = switch (true) do {
    case (isPlayer _w && { side _g == west }): { "FRIENDLY FIRE" };
    case (_w getVariable ["CQ_hunter", false]): { format ["SPECIAL FORCES (%1)", _gid] };
    case (_v isKindOf "StaticMortar" || { getNumber (configOf _v >> "artilleryScanner") == 1 }): { "MORTAR" };
    case ("sniper" in toLower _gid || { "sniper" in _tl } || { "spotter" in _tl } || { "_m_f" in _tl } || { (toLower _wpn) find "srifle" == 0 }): { "SNIPER" };
    case (_v isKindOf "Air"): { "AIR" };
    case (_v != _w || { _w isKindOf "StaticWeapon" }): { "HEAVY" };
    case (CQ_killMissionSquads findIf { (toLower _gid) find (toLower _x) == 0 } > -1): { format ["MISSION SQUAD (%1)", _gid] };
    case (side _g == resistance): { "GUERILLA" };
    default { "INFANTRY" };
};
// weapon name and caliber: "Caliber: 6.5x39 mm ..." in the magazine description, else "NN mm" in its name
private _wn = getText (configFile >> "CfgWeapons" >> _wpn >> "displayName");
private _cal = "";
if (_mag != "") then {
    private _d = getText (configFile >> "CfgMagazines" >> _mag >> "descriptionShort");
    private _i = _d find "Caliber:";
    if (_i > -1) then {
        _cal = (_d select [_i + 8]) splitString "<" param [0, ""];
        _cal = _cal trim [" ", 0];
    } else {
        private _m = (getText (configFile >> "CfgMagazines" >> _mag >> "displayName")) regexFind ["[0-9]+([.,][0-9]+)?( ?x ?[0-9]+)? ?mm/i"];
        if (_m isNotEqualTo []) then { _cal = (_m select 0 select 0) select 0 };
    };
};
private _out = [_cat, name _w];
if (_wn != "") then { _out pushBack ([_wn, format ["%1 (%2)", _wn, _cal]] select (_cal != "")) };
_out joinString " · "
