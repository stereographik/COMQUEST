/*
    CQ_fnc_bftClient  (client, once, from initPlayerLocal; drawn by CQ_fnc_magMapClient)
    BLUE FORCE TRACKING through the data link. The vanilla friendly map content is switched off
    (initPlayerLocal), so friendlies only show through the network:
      - you always see yourself (friendly blue inside a thin red ring)
      - while YOU carry a radio and stand inside the data link's coverage (a linked node of
        CQ_linkPub within its range), you see every friendly unit that is inside the coverage too:
        one icon per vehicle (crew share it), the group's callsign next to its leader
      - out of coverage (or no radio): only yourself
    Refreshed every CQ_bftEvery s (positions are drawn live between two refreshes).
*/
if (!hasInterface) exitWith {};
CQ_bftList = [];      // [[object, label], ...]
CQ_bftOn = false;     // the player is linked right now
CQ_bftDraw = {
    params ["_map"];
    private _sz = CQ_bftIconPx * CQ_mapIconScale;
    private _c = CQ_bftColor;
    {
        _x params ["_o", "_t"];
        if (alive _o) then {
            _map drawIcon [_o call CQ_magIconOf, _c, getPosASLVisual _o, _sz, _sz, getDirVisual _o, _t, 1, 0.03, "PuristaMedium", "right"];
        };
    } forEach CQ_bftList;
    // yourself, always: friendly blue, ringed by a thin red circle (same size on screen at every zoom)
    private _me = vehicle player;
    if (alive player) then {
        private _mp = getPosASLVisual _me;
        _map drawIcon [_me call CQ_magIconOf, _c, _mp, _sz, _sz, getDirVisual _me, "", 1];
        private _mpp = (_map ctrlMapScreenToWorld [0.5, 0.5]) distance2D (_map ctrlMapScreenToWorld [0.5 + pixelW, 0.5]);   // m per screen pixel
        private _rr = (_sz / 2 + CQ_bftSelfRingPad) * _mpp;
        _map drawEllipse [_mp, _rr, _rr, 0, CQ_bftSelfRing, ""];
    };
};
[] spawn {
    while { true } do {
        private _nodes = ((missionNamespace getVariable ["CQ_linkPub", []]) param [0, []]) select { _x select 2 };
        private _cov = { params ["_p"]; (_nodes findIf { _p distance2D (_x select 0) < (_x select 1) }) > -1 };
        private _radio = alive player && { (assignedItems player) findIf { "radio" in toLower _x } > -1 };
        CQ_bftOn = _radio && { [getPosASL player] call _cov };
        private _list = [];
        if (CQ_bftOn) then {
            private _done = [vehicle player];
            {
                private _v = vehicle _x;
                if (alive _x && { !(_v in _done) } && { [getPosASL _v] call _cov }) then {
                    _done pushBack _v;
                    private _g = group _x;
                    _list pushBack [_v, ["", groupId _g] select (leader _g == _x && { count units _g > 1 || { isPlayer _x } })];
                };
            } forEach (units west);
        };
        CQ_bftList = _list;
        sleep CQ_bftEvery;
    };
};
