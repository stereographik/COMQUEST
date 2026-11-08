/*
    CQ_fnc_crateSlots
    [_vehicle] call CQ_fnc_crateSlots  ->  how many supply crates it can carry
*/
params ["_v"];
switch (true) do {
    case (_v isKindOf "Truck_F"): { 4 };
    case (_v isKindOf "Heli_Light_01_base_F"): { 1 };
    case (_v isKindOf "Helicopter"): { 2 };
    case (_v isKindOf "Plane"): { 4 };
    default { 1 };
}
