/*
    CQ_fnc_guideDiary  (client, from initPlayerLocal)
    Map briefing: "Player guide" (one entry per chapter of CQ_guide) and "Server rules" (CQ_rules).
    The same texts are in the tablet's GUIDE and RULES tabs (CQ_fnc_squadUi).
*/
if (!hasInterface) exitWith {};
player createDiarySubject ["CQ_rules", "Server rules"];
private _r = format ["<font face='PuristaSemibold' size='16' color='#F2F1DF'>SERVER RULES</font><br/><font color='#A6A381'>%1</font><br/><br/>", CQ_rulesIntro];
{ _r = _r + format ["<font color='#918C3B'>%1.</font> %2<br/><br/>", _forEachIndex + 1, _x] } forEach CQ_rules;
_r = _r + "<font color='#A6A381'>Press U, then GUIDE &amp; RULES, to accept them or to report a player to the admins.</font>";
player createDiaryRecord ["CQ_rules", ["Rules", _r]];
player createDiarySubject ["CQ_guide", "Player guide"];
// diary records stack newest first: add the chapters last to first
private _ch = +CQ_guide;
reverse _ch;
{
    _x params ["_title", "_paras"];
    private _t = format ["<font face='PuristaSemibold' size='16' color='#F2F1DF'>%1</font><br/><br/>", _title];
    { _t = _t + _x + "<br/><br/>" } forEach _paras;
    player createDiaryRecord ["CQ_guide", [_title, _t]];
} forEach _ch;
