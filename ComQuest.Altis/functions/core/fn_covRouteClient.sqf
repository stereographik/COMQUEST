/*
    CQ_fnc_covRouteClient  (client, called once from initPlayerLocal)
    Draws on the map the covered approach of every enemy HQ the players know (CQ_covRoutes, from
    CQ_fnc_covRoute): a line from the start point to the HQ, green where hidden, ochre where partly
    seen, red where exposed, with the route's cover at its start ("COVERED APPROACH 82 %").
*/
if (!hasInterface) exitWith {};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        private _cols = [[0.35, 0.75, 0.35, 0.95], [0.87, 0.7, 0.2, 0.95], [0.9, 0.25, 0.2, 0.95]];
        {
            _x params ["_id", "_pts", "_pct"];
            if (count _pts < 2) then { continue };
            for "_i" from 0 to (count _pts) - 2 do {
                private _a = _pts select _i; private _b = _pts select (_i + 1);
                private _e = ((_a select 2) + (_b select 2)) / 2;
                private _c = _cols select (if (_e < 0.25) then { 0 } else { [1, 2] select (_e >= 0.5) });
                _map drawLine [[_a select 0, _a select 1, 0], [_b select 0, _b select 1, 0], _c, 6];
            };
            private _s = _pts select 0;
            _map drawIcon ["\A3\ui_f\data\map\markers\military\start_CA.paa", [0.35, 0.75, 0.35, 1], [_s select 0, _s select 1, 0], 22, 22, 0,
                format ["COVERED APPROACH  %1 %%", _pct], 2, 0.04, "PuristaMedium", "right"];
        } forEach (missionNamespace getVariable [["CQ_covRoutes", "CQ_covRoutesAll"] select (missionNamespace getVariable ["CQ_dbgShowCov", false]), []]);
    }];
};
