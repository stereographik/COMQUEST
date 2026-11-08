/*
    CQ_fnc_hqAirPad  (server)
    [_hq] call CQ_fnc_hqAirPad  ->  the HQ's rearm / delivery pad (created once, 60-140 m out),
    kept apart from the HQ's own helipad where its QRF helicopter parks.
*/
params ["_hq"];

private _pad = _hq get "rearmPad";
if (isNull _pad) then {
    _pad = [_hq get "pos", 60, 140] call CQ_fnc_airParkSpot;
    _hq set ["rearmPad", _pad];
};
_pad
