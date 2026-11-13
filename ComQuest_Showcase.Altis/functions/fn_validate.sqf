/*
    SC_fnc_validate - checks every class of SC_comps against this game: missing (a mod) or DLC
    -> skipped. Builds SC_rows (per composition: the rows that will spawn) and logs a report.
*/
SC_rows = [];
SC_report = [];
diag_log "[SC] ---- composition validation ----";
{
    _x params ["_name", "_author", "_r", "_rows"];
    private _miss = [];
    private _dlc = [];
    private _ok = _rows select {
        private _c = _x select 0;
        private _cfg = configFile >> "CfgVehicles" >> _c;
        if (!isClass _cfg) then { _miss pushBackUnique _c; false } else {
            if (getText (_cfg >> "DLC") != "") then { _dlc pushBackUnique format ["%1 (%2)", _c, getText (_cfg >> "DLC")]; false } else { true }
        }
    };
    SC_rows pushBack _ok;
    SC_report pushBack [count _ok, count _rows, _miss, _dlc];
    diag_log format ["[SC] %1 (%2): %3/%4 objects OK%5%6", _name, _author, count _ok, count _rows,
        ["", format [" | missing (mod): %1", _miss joinString ", "]] select (_miss isNotEqualTo []),
        ["", format [" | DLC: %1", _dlc joinString ", "]] select (_dlc isNotEqualTo [])];
} forEach SC_comps;
