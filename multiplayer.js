(function($){
    var cookieName = 'socialcalc';
    var _username = Math.random().toString();
    var _isMaster = false;
    var _hadSnapshot = false;
    var mq = [];

    SocialCalc.Callbacks.broadcast = function(type, data) {
        data = data || {};
        data.user = _username;
        data.type = type;

        $.cookie(cookieName, _username, { path: '/chat' });
        mq.push(data);
    }

    $(function(){
        var doPost = function() {
            if (mq.length == 0) {
                setTimeout(doPost, 100);
                return;
            }

            var data = mq.shift();
            $.ajax({
                url: "/chat/sc/post",
                data: data,
                type: 'post',
                dataType: 'json',
                complete: function(r) {
                    doPost();
                }
            });
        };

        doPost();

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
                    if (_isMaster) {
                        SocialCalc.Callbacks.broadcast('snapshot', {
                            to: data.user,
                            snapshot: SocialCalc.CurrentSpreadsheetControlObject.CreateSpreadsheetSave()
                        });
                    }
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

        if ((!$.browser.msie) && typeof DUI != 'undefined') {
            var s = new DUI.Stream();
            s.listen('application/json', function(payload) {
                var event = eval('(' + payload + ')');
                onNewEvent(event);
            });
            s.load('/chat/sc/mxhrpoll?session=' + Math.random());
        } else {
            $.ev.handlers['*'] = onNewEvent;
            $.ev.loop('/chat/sc/poll?session=' + Math.random());
        }

        SocialCalc.Callbacks.broadcast('ask.snapshot');
        setTimeout(function(){
            if (!_hadSnapshot) {
                _isMaster = _hadSnapshot = true;
            }
        }, 10000);
    });
})(jQuery);
