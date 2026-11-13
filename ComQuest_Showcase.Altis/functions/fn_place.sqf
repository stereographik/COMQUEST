/*
    SC_fnc_place - player placement of a composition, for base layouts
      ["start", _index] spawn SC_fnc_place   the composition appears in front of the player
                                              (its radius + 5 m away, facing him): Q / E turn it
                                              15 deg, the action menu confirms or cancels
      ["removeNear"] call SC_fnc_place        deletes the placed composition nearest the player
      ["export"] call SC_fnc_place            [name, [x, y], dir] of every placed composition:
                                              clipboard + log (SC_placed)
*/
params ["_mode", ["_i", -1]];
if (isNil "SC_placed") then { SC_placed = [] };
switch (_mode) do {
    case "start": {
        if (!isNil "SC_placing") exitWith { hint "Finish the current placement first" };
        if ((SC_rows select _i) isEqualTo []) exitWith { hint "Nothing to place: every object of it is missing or DLC" };
        (SC_comps select _i) params ["_name", "", "_r"];
        SC_placing = true;
        private _anchor = player getPos [_r + 5, getDir player];
        SC_plDir = getDir player;
        private _pairs = [_i, _anchor, SC_plDir] call SC_fnc_spawnComp;
        SC_plState = 0;
        private _kh = (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_k"];
            if (_k == 16) exitWith { SC_plDir = SC_plDir - 15; true };   // Q
            if (_k == 18) exitWith { SC_plDir = SC_plDir + 15; true };   // E
            false
        }];
        private _a1 = player addAction ["<t color='#8FD16A'>Confirm placement</t>", { SC_plState = 1 }, nil, 10];
        private _a2 = player addAction ["<t color='#BA392C'>Cancel placement</t>", { SC_plState = -1 }, nil, 9.9];
        private _last = SC_plDir;
        while { SC_plState == 0 && { alive player } } do {
            if (SC_plDir != _last) then { _last = SC_plDir; ["move", [_pairs, _anchor, SC_plDir]] call SC_fnc_spawnComp };
            hintSilent format ["Placing %1\nQ / E: turn (%2 deg)\nScroll menu: confirm / cancel", _name, round (SC_plDir mod 360)];
            sleep 0.05;
        };
        (findDisplay 46) displayRemoveEventHandler ["KeyDown", _kh];
        player removeAction _a1; player removeAction _a2;
        hintSilent "";
        if (SC_plState == 1) then {
            SC_placed pushBack [_name, _anchor, SC_plDir mod 360, _pairs];
            hint format ["%1 placed (%2 so far). Export from the showcase menu.", _name, count SC_placed];
            diag_log format ["[SC] placed %1 at %2 dir %3", _name, _anchor apply { round _x }, round (SC_plDir mod 360)];
        } else {
            { deleteVehicle (_x select 0) } forEach _pairs;
        };
        SC_placing = nil;
    };
    case "removeNear": {
        if (SC_placed isEqualTo []) exitWith { hint "Nothing placed yet" };
        private _j = 0; private _best = 1e9;
        { private _d = player distance2D (_x select 1); if (_d < _best) then { _best = _d; _j = _forEachIndex } } forEach SC_placed;
        private _e = SC_placed deleteAt _j;
        { deleteVehicle (_x select 0) } forEach (_e select 3);
        hint format ["%1 removed (%2 m away)", _e select 0, round _best];
    };
    case "export": {
        private _lines = SC_placed apply { format ["    [%1, [%2, %3], %4]", str (_x select 0), round ((_x select 1) select 0), round ((_x select 1) select 1), round (_x select 2)] };
        private _txt = "// ComQuest base layout from the showcase: [composition, [x, y], dir]" + toString [10] + "SC_layout = [" + toString [10] + (_lines joinString ("," + toString [10])) + toString [10] + "];";
        copyToClipboard _txt;
        diag_log "[SC] ---- export ----";
        { diag_log _x } forEach (_txt splitString toString [10]);
        hint format ["%1 placed composition(s) exported to the clipboard and the log", count SC_placed];
    };
};
