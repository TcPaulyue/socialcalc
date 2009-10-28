(function($){
    var cookieName = 'socialcalc';
    var _username = Math.random().toString();
    var _hadSnapshot;

    SocialCalc.Callbacks.broadcast = function(type, data) {
        data = data || {};
        data.user = _username;
        data.type = type;

        $.cookie(cookieName, _username, { path: '/chat' });

        $.ajax({
            url: "/chat/sc/post",
            data: data,
            type: 'post',
            dataType: 'json',
            success: function(r) { }
        });
    }

    $(function(){
        var onNewEvent = function(data) {
            if (data.user == _username) return;
            if (data.to && data.to != _username) return;

            var editor = SocialCalc.CurrentSpreadsheetControlObject.editor;

            switch (data.type) {
                case 'ecell': {
                    var peerClass = ' ' + data.user + ' defaultPeer';
                    var find = new RegExp(peerClass, 'g');

                    if (data.original) {
                        var origCR = SocialCalc.coordToCr(data.original);
                        var origCell = SocialCalc.GetEditorCellElement(editor, origCR.row, origCR.col);
                        console.log(origCell.element.className);
                        origCell.element.className = origCell.element.className.replace(find, '');
                    }

                    var cr = SocialCalc.coordToCr(data.ecell);
                    var cell = SocialCalc.GetEditorCellElement(editor, cr.row, cr.col);
                    if (cell.element.className.search(find) == -1) {
                        cell.element.className += peerClass;
                    }
                    break;
                }
                case 'ask.snapshot': {
                    SocialCalc.Callbacks.broadcast('snapshot', {
                        to: data.user,
                        snapshot: SocialCalc.CurrentSpreadsheetControlObject.CreateSpreadsheetSave()
                    });
                    // FALL THROUGH
                }
                case 'ask.ecell': {
                    SocialCalc.Callbacks.broadcast('ecell', {
                        to: data.user,
                        ecell: editor.ecell.coord
                    });
                    break;
                }
                case 'snapshot': {
                    if (_hadSnapshot) break;
                    _hadSnapshot = true;
                    var spreadsheet = SocialCalc.CurrentSpreadsheetControlObject;
                    var parts = spreadsheet.DecodeSpreadsheetSave(data.snapshot);
                    if (parts) {
                        if (parts.sheet) {
                            spreadsheet.sheet.ResetSheet();
                            spreadsheet.ParseSheetSave(data.snapshot.substring(parts.sheet.start, parts.sheet.end));
                        }
                        if (parts.edit) {
                            spreadsheet.editor.LoadEditorSettings(data.snapshot.substring(parts.edit.start, parts.edit.end));
                        }
                    }
                    if (spreadsheet.editor.context.sheetobj.attribs.recalc=="off") {
                        spreadsheet.ExecuteCommand('redisplay', '');
                        spreadsheet.ExecuteCommand('set sheet defaulttextvalueformat text-wiki');
                    }
                    else {
                        spreadsheet.ExecuteCommand('recalc', '');
                        spreadsheet.ExecuteCommand('set sheet defaulttextvalueformat text-wiki');
                    }

                    break;
                }
                case 'execute': {
                    SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands(
                        data.cmdstr,
                        data.saveundo,
                        true // isRemote = true
                    );
                    break;
                }
            }
        };

        $.ev.handlers['*'] = onNewEvent;
        $.ev.loop('/chat/sc/poll?session=' + Math.random());
    });
})(jQuery);
