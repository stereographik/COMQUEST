/*
    CQ_fnc_tabletCol  (client)
    The icon column on the field tablet's left side (media\comtablet_l_ca.paa, comtablet_r_ca.paa): CQ_tabletColSlots
    slots in CQ_tabletCol ([x0, y0, x1, y1] as fractions of the picture), filled from the top.
    Each icon (media\icons\<name>_ca.paa, white, tinted here) switches the window's tab; the
    selected one sits in a lighter box.
      ["create", [_d, [_picX, _picY, _pw, _ph], [[icon, tooltip, key], ...], _var, _dirty]] call CQ_fnc_tabletCol;
          _var    uiNamespace variable holding the window's current tab (set to key on click)
          _dirty  uiNamespace variable set true on click ("" = none)
      ["sel", [_var, _currentKey]] call CQ_fnc_tabletCol;     highlight the current tab
*/
params ["_mode", "_args"];
disableSerialization;
switch (_mode) do {
    case "create": {
        _args params ["_d", "_pic", "_items", "_var", ["_dirty", ""]];
        _pic params ["_px", "_py", "_pw", "_ph"];
        CQ_tabletCol params ["_cx0", "_cy0", "_cx1", "_cy1"];
        private _cx = _px + _pw * _cx0;
        private _cw = _pw * (_cx1 - _cx0);
        private _cy = _py + _ph * _cy0;
        private _sh = _ph * (_cy1 - _cy0) / CQ_tabletColSlots;
        private _iw = _cw * CQ_tabletIconSize;
        private _ih = _iw * pixelH / pixelW;                     // square on screen
        if (_ih > _sh * 0.8) then { _ih = _sh * 0.8; _iw = _ih * pixelW / pixelH };
        private _bx = 2 * pixelW; private _by = 2 * pixelH;      // box border
        private _slots = [];
        {
            _x params ["_icon", "_tip", "_key"];
            private _sy = _cy + _forEachIndex * _sh;
            private _out = _d ctrlCreate ["RscText", -1];
            _out ctrlSetPosition [_cx + _bx, _sy + _by, _cw - 2 * _bx, _sh - 2 * _by];
            _out ctrlSetBackgroundColor (CQ_tabletColors get "boxEdge");
            _out ctrlCommit 0;
            private _in = _d ctrlCreate ["RscText", -1];
            _in ctrlSetPosition [_cx + 2 * _bx, _sy + 2 * _by, _cw - 4 * _bx, _sh - 4 * _by];
            _in ctrlSetBackgroundColor (CQ_tabletColors get "box");
            _in ctrlCommit 0;
            private _line = _d ctrlCreate ["RscText", -1];
            _line ctrlSetPosition [_cx + 3 * _bx, _sy + _sh - _by / 2, _cw - 6 * _bx, _by];
            _line ctrlSetBackgroundColor (CQ_tabletColors get "line");
            _line ctrlCommit 0;
            private _ic = _d ctrlCreate ["RscActivePicture", -1];
            _ic ctrlSetPosition [_cx + (_cw - _iw) / 2, _sy + (_sh - _ih) / 2, _iw, _ih];
            _ic ctrlSetText (getMissionPath format ["media\icons\%1_ca.paa", _icon]);
            _ic ctrlSetTextColor (CQ_tabletColors get "icon");
            _ic ctrlSetActiveColor (CQ_tabletColors get "hover");
            _ic ctrlSetTooltip _tip;
            _ic ctrlCommit 0;
            _ic setVariable ["CQ_colKey", _key];
            _ic setVariable ["CQ_colVar", _var];
            _ic setVariable ["CQ_colDirty", _dirty];
            _ic ctrlAddEventHandler ["ButtonClick", {
                params ["_c"];
                private _v = _c getVariable "CQ_colVar";
                uiNamespace setVariable [_v, _c getVariable "CQ_colKey"];
                private _dt = _c getVariable ["CQ_colDirty", ""];
                if (_dt != "") then { uiNamespace setVariable [_dt, true] };
                ["sel", [_v, _c getVariable "CQ_colKey"]] call CQ_fnc_tabletCol;
            }];
            { _x ctrlShow false } forEach [_out, _in];
            _slots pushBack [_out, _in, _ic, _key];
        } forEach _items;
        uiNamespace setVariable [_var + "Col", _slots];
        ["sel", [_var, uiNamespace getVariable [_var, ""]]] call CQ_fnc_tabletCol;
    };
    case "sel": {
        _args params ["_var", "_cur"];
        {
            _x params ["_out", "_in", "_ic", "_key"];
            private _on = _key == _cur;
            _out ctrlShow _on;
            _in ctrlShow _on;
            _ic ctrlSetTextColor (CQ_tabletColors get (["icon", "iconOn"] select _on));
        } forEach (uiNamespace getVariable [_var + "Col", []]);
    };
};
