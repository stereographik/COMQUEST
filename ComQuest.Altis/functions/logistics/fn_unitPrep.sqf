/*
    CQ_fnc_unitPrep  (server)
    [_units] call CQ_fnc_unitPrep;
    Limits what each enemy soldier carries and records what a full reload is:
    CQ_infMags rifle magazines (CQ_infBelts for machine guns), CQ_infRockets spare rockets.
    Stored on the unit: CQ_magClass / CQ_magTarget / CQ_magCost, CQ_rktClass / CQ_rktTarget.
*/
params [["_units", [], [[]]]];

{
    private _u = _x;

    // Primary weapon
    private _pw = primaryWeapon _u;
    if (_pw != "") then {
        private _compat = (compatibleMagazines _pw) apply { toLower _x };
        private _mags = (magazines _u) select { toLower _x in _compat };
        private _cls = if (_mags isEqualTo []) then { (compatibleMagazines _pw) param [0, ""] } else { _mags select 0 };
        if (_cls != "") then {
            private _belt = getNumber (configFile >> "CfgMagazines" >> _cls >> "count") >= 100;
            private _target = [CQ_infMags, CQ_infBelts] select _belt;
            private _guard = 0;
            while { ({ _x == _cls } count magazines _u) > _target && { _guard < 30 } } do { _u removeMagazine _cls; _guard = _guard + 1 };
            _u setVariable ["CQ_magClass", _cls];
            _u setVariable ["CQ_magTarget", _target];
            _u setVariable ["CQ_magCost", [CQ_costMag, CQ_costBelt] select _belt];
        };
    };

    // Launcher
    private _sw = secondaryWeapon _u;
    if (_sw != "") then {
        private _compat = (compatibleMagazines _sw) apply { toLower _x };
        private _mags = (magazines _u) select { toLower _x in _compat };
        private _cls = if (_mags isEqualTo []) then { (compatibleMagazines _sw) param [0, ""] } else { _mags select 0 };
        if (_cls != "") then {
            private _guard = 0;
            while { ({ _x == _cls } count magazines _u) > CQ_infRockets && { _guard < 10 } } do { _u removeMagazine _cls; _guard = _guard + 1 };
            _u setVariable ["CQ_rktClass", _cls];
            _u setVariable ["CQ_rktTarget", CQ_infRockets];
        };
    };
} forEach _units;
