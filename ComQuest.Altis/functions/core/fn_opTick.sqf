/*
    CQ_fnc_opTick  (server, director task, every 5 s)
    OPERATION briefing: a fixed checklist of friendly progress, published to every player
    (CQ_opPub, shown by CQ_fnc_opClient in the map's "Operation" section). Same-type events
    are stacked in one line:
      1 Find where they land        first HQ located (MAGPIE, players within 300 m, intel)
      2 Hostile HQs                 one sub-line per built HQ, like its map marker
      3 Radio towers down           n / N of the built HQs
      4 Supply line cut             convoys and supply flights destroyed (CQ_fnc_opEvent)
      5 Special forces neutralised  Spectre teams wiped out / CQ_huntTeams
      6 Carrier empty               carrier stock %
      7 Last HQ destroyed           victory
    Each line: done or not, the time (operation clock) and the squad that did it when known.
*/
if (time < (missionNamespace getVariable ["CQ_opNext", 0])) exitWith {};
CQ_opNext = time + 5;
if (isNil "CQ_op") then { CQ_op = createHashMap };
if (isNil "CQ_opStartT") then { CQ_opStartT = time };
private _clock = {
    params ["_t"];
    private _s = round ((_t - CQ_opStartT) max 0);
    private _h = floor (_s / 3600); private _m = floor ((_s % 3600) / 60);
    format ["%1%2:%3%4", ["", "0"] select (_h < 10), _h, ["", "0"] select (_m < 10), _m]
};
private _squad = { params ["_u"]; if (!isNull _u && { isPlayer _u }) then { groupId group _u } else { "" } };
private _hqs = values CQ_hqs;
private _built = _hqs select { _x getOrDefault ["builtT", -1] > -1 };

// ---- 1 first HQ located
private _loc = CQ_op getOrDefault ["located", []];
if (_loc isEqualTo []) then {
    private _act = _hqs select { (_x get "state") in CQ_activeStates };
    {
        private _h = _x;
        private _id = _h get "id";
        private _by = "";
        if (_id in (missionNamespace getVariable ["CQ_magHqSeen", createHashMap])) then { _by = "MAGPIE" };
        if (_by == "" && { _h getOrDefault ["revealed", false] }) then { _by = "intel" };
        if (_by == "") then {
            private _near = (allPlayers select { alive _x && { side group _x == west } && { _x distance2D (_h get "pos") < 300 } });
            if (_near isNotEqualTo []) then { _by = groupId group (_near select 0) };
        };
        if (_by != "") exitWith { _loc = [time, _by, _id]; CQ_op set ["located", _loc] };
    } forEach _act;
};

// ---- 2 HQ lines (destroyed: time + squad remembered once)
private _dead = 0;
private _sub = _built apply {
    private _h = _x;
    private _id = _h get "id";
    private _all = _h get "installations";
    private _cmd = switch (true) do {
        case (_h getOrDefault ["cmdCaptured", false]): { "captured" };
        case (!alive (_h get "commander")): { "killed" };
        default { "alive" };
    };
    if ((_h get "state") == "Destroyed") then {
        _dead = _dead + 1;
        if (_h getOrDefault ["opDone", []] isEqualTo []) then { _h set ["opDone", [time, [_h getOrDefault ["lastKiller", objNull]] call _squad]] };
        (_h get "opDone") params ["_t", "_sq"];
        [true, format ["%1  ·  destroyed %2  ·  commander %3%4", [_id] call CQ_fnc_objName, [_t] call _clock, _cmd, ["", "  ·  " + _sq] select (_sq != "")]]
    } else {
        [false, format ["%1  ·  commander %2  ·  %3/%4 objectives", [_id] call CQ_fnc_objName, _cmd, { !alive _x } count _all, count _all]]
    }
};

// ---- 3 radio towers
private _towers = _built select { !isNull (_x getOrDefault ["radio", objNull]) };
private _down = _towers select { !alive (_x get "radio") };
{
    if (_x getOrDefault ["opTower", []] isEqualTo []) then { _x set ["opTower", [time, [_x getOrDefault ["lastKiller", objNull]] call _squad]] };
} forEach _down;
private _lastTower = [];
{ if (_lastTower isEqualTo [] || { ((_x get "opTower") select 0) > (_lastTower select 0) }) then { _lastTower = _x get "opTower" } } forEach _down;

// ---- 4 supply, 5 spectre, 6 carrier, 7 victory
private _cv = CQ_op getOrDefault ["convoy", [0, 0, ""]];
private _fl = CQ_op getOrDefault ["flight", [0, 0, ""]];
private _sup = [_cv, _fl] select ((_fl select 1) > (_cv select 1));
private _sp = CQ_op getOrDefault ["spectre", [0, 0, ""]];
private _pct = round (100 * ((missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs]) max 0) / (CQ_carrierHqs max 1));
private _won = !isNil "CQ_victory";

private _when = { params ["_t", "_sq"]; format ["%1%2", [_t] call _clock, ["", "  ·  " + _sq] select (_sq != "")] };
private _steps = [
    [_loc isNotEqualTo [], "Find where they land",
        if (_loc isEqualTo []) then { "Their beachhead will be due west of the carrier, within 2 km of the shore." }
        else { format ["%1  ·  %2  (%3)", [_loc select 0] call _clock, _loc select 1, [_loc select 2] call CQ_fnc_objName] }, []],
    [_won, "Hostile HQs", format ["%1 / %2 destroyed", _dead, count _built], _sub],
    [(count _towers) > 0 && { (count _down) == (count _towers) }, "Radio towers down",
        format ["%1 / %2%3", count _down, count _towers, if (_lastTower isEqualTo []) then { "" } else { "  ·  last " + (_lastTower call _when) }], []],
    [((_cv select 0) + (_fl select 0)) > 0, "Supply line cut",
        format ["%1 convoys, %2 supply flights destroyed%3", _cv select 0, _fl select 0, if ((_sup select 0) == 0) then { "" } else { "  ·  last " + ([_sup select 1, _sup select 2] call _when) }], []],
    [(_sp select 0) >= CQ_huntTeams, "Special forces neutralised",
        format ["%1 / %2 teams%3", _sp select 0, CQ_huntTeams, if ((_sp select 0) == 0) then { "" } else { "  ·  last " + ([_sp select 1, _sp select 2] call _when) }], []],
    [_pct <= 0, "Carrier empty", format ["carrier at %1 %%", _pct], []],
    [_won, "Last HQ destroyed", ["VICTORY when the carrier is empty and no HQ stands", "VICTORY"] select _won, []]
];
if !(_steps isEqualTo (missionNamespace getVariable ["CQ_opPub", []])) then {
    CQ_opPub = _steps;
    publicVariable "CQ_opPub";
};
