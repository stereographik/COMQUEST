/*
    CQ_fnc_magMarks  (client, from MAGPIE's report through remoteExec)
    [[[pos, kind], ...]] call CQ_fnc_magMarks;
    Shows every new identification as a small enemy marker on this player's map for
    CQ_magMarkerTime seconds. kind: inf, light, armour, air, static, hq.
*/
params [["_dots", []]];
if (!hasInterface) exitWith {};
_dots spawn {
    private _made = [];
    {
        _x params ["_p", "_k"];
        private _m = createMarkerLocal [format ["cq_mag_%1_%2", diag_tickTime, _forEachIndex], _p];
        _m setMarkerTypeLocal (switch (_k) do {
            case "inf": { "mil_dot" };
            case "hq": { "mil_objective" };
            case "static": { "mil_box" };
            case "air": { "mil_arrow2" };
            default { "mil_triangle" };
        });
        _m setMarkerColorLocal "ColorOPFOR";
        _m setMarkerSizeLocal ([[0.5, 0.5], [0.9, 0.9]] select (_k == "hq"));
        _made pushBack _m;
    } forEach _this;
    sleep CQ_magMarkerTime;
    { deleteMarkerLocal _x } forEach _made;
};
