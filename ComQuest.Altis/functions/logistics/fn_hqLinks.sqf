/*
    CQ_fnc_hqLinks
    [_hub, _built] call CQ_fnc_hqLinks  ->  ids of the HQs connected to the main HQ by radio
    Breadth-first search: two built HQs are linked when both radio towers stand and they are
    within CQ_commsRange. Deliveries only go to connected HQs.
*/
params ["_hub", "_built"];

if (count _hub == 0 || { !alive (_hub get "radio") }) exitWith { [] };

private _nodes = _built select { alive (_x get "radio") };
private _seen = [_hub get "id"];
private _queue = [_hub];
while { _queue isNotEqualTo [] } do {
    private _cur = _queue deleteAt 0;
    {
        private _id = _x get "id";
        if (!(_id in _seen) && { ((_x get "pos") distance2D (_cur get "pos")) <= CQ_commsRange }) then {
            _seen pushBack _id;
            _queue pushBack _x;
        };
    } forEach _nodes;
};
_seen
