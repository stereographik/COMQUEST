/*
    CQ_fnc_vehFeed
    The on-screen feed list. Also carries the player feed (CQ_fnc_feed: joins, down, killed, revived).
    Enemy vehicles destroyed by players, with a mocking remark from command (CQ_vehKillLines):
        BTR-K Kamysh destroyed by Django · Titan MPRL
        Ha! Toasted.
    Shown in a small list of its own (left of the screen, above the chat): the CQ_vehFeedMax last
    kills only, a new one pushes the oldest out; each fades out after CQ_vehFeedLife s.
      ["kill", [vehicle, killer]]   server, from the EntityKilled handler of initServer
      ["show", [line, remark]]      every client (remark "" = one line)
*/
params [["_mode", ""], ["_a", []]];
switch (_mode) do {
    case "kill": {
        if (!isServer) exitWith {};
        _a params ["_v", "_k"];
        if (isNull _k || { !isPlayer _k } || { _v isKindOf "CAManBase" } || { _v isKindOf "ParachuteBase" }) exitWith {};
        if !(_v isKindOf "LandVehicle" || { _v isKindOf "Air" } || { _v isKindOf "Ship" } || { _v isKindOf "StaticWeapon" }) exitWith {};
        private _side = [east, west, resistance, civilian] param [getNumber (configOf _v >> "side"), civilian];
        if !(_side in [east, resistance]) exitWith {};
        private _kv = vehicle _k;
        private _wpn = if (_kv != _k) then { (weaponState [_kv, _kv unitTurret _k]) param [0, ""] } else { currentWeapon _k };
        private _wn = getText (configFile >> "CfgWeapons" >> _wpn >> "displayName");
        private _vn = getText (configOf _v >> "displayName");
        private _line = format ["%1 destroyed by %2", _vn, name _k] + (["", " · " + _wn] select (_wn != ""));
        ["show", [_line, selectRandom CQ_vehKillLines]] remoteExec ["CQ_fnc_vehFeed", 0];
        ["Vehicle kill: %1", [_line]] call CQ_fnc_log;
    };
    case "show": {
        if (!hasInterface) exitWith {};
        _a params ["_line", "_rem"];
        if (isNil "CQ_vfList") then { CQ_vfList = [] };
        CQ_vfList pushBack [_line, _rem, time];
        while { count CQ_vfList > CQ_vehFeedMax } do { CQ_vfList deleteAt 0 };
        if (isNil "CQ_vfLoop") then {
            CQ_vfLoop = [] spawn {
                disableSerialization;
                private _c = controlNull;
                while { true } do {
                    private _d = findDisplay 46;
                    if (!isNull _d && { isNull _c }) then {
                        _c = _d ctrlCreate ["RscStructuredText", -1];
                        _c ctrlSetPosition [safeZoneX + 0.01 * safeZoneW, safeZoneY + 0.50 * safeZoneH, 0.32 * safeZoneW, 0.22 * safeZoneH];
                        _c ctrlCommit 0;
                    };
                    CQ_vfList = CQ_vfList select { time - (_x select 2) < CQ_vehFeedLife };
                    private _txt = (CQ_vfList apply {
                        _x params ["_l", "_r", "_t"];
                        private _al = 1 min ((CQ_vehFeedLife - (time - _t)) / 5);   // fades over the last 5 s
                        private _n = round (255 * (_al max 0));
                        private _hx = "0123456789ABCDEF";
                        private _h = (_hx select [floor (_n / 16), 1]) + (_hx select [_n mod 16, 1]);
                        format ["<t size='0.85' shadow='2' color='#%2E8E6D9'>%1</t>", _l, _h] + (["", format ["<br/><t size='0.85' shadow='2' color='#%2E8B84A'>%1</t>", _r, _h]] select (_r != ""))
                    }) joinString "<br/>";
                    if (!isNull _c) then { _c ctrlSetStructuredText parseText _txt };
                    sleep 0.5;
                };
            };
        };
    };
};
