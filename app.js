(function() {
  var host, port;
  port = Number(process.env.VCAP_APP_PORT || 3000);
  host = process.env.VCAP_APP_HOST || '127.0.0.1';
  require('zappa')(port, host, function() {
    enable('serve jquery');
    app.use(express.static(__dirname));
    get({
      '/': function() {
        response.contentType('text/html');
        return response.sendfile('index.mt');
      }
    });
    at({
      broadcast: function() {
        return io.sockets.emit('broadcast', this);
      }
    });
    return client({
      '/player.js': function() {
        if (typeof SocialCalc === "undefined" || SocialCalc === null) {
          SocialCalc = {};
        }
        SocialCalc._username = Math.random().toString();
        SocialCalc.isConnected = true;
        SocialCalc.hadSnapshot = false;
        connect();
        SocialCalc.Callbacks.broadcast = function(type, data) {
          if (data == null) {
            data = {};
          }
          if (!SocialCalc.isConnected) {
            return;
          }
          data.user = SocialCalc._username;
          data.type = type;
          return emit('broadcast', data);
        };
        at({
          connection: function() {
            SocialCalc.isConnected = true;
            SocialCalc.Callbacks.broadcast("ask.snapshot");
            return setTimeout((function() {
              return SocialCalc.hadSnapshot = true;
            }), 30000);
          }
        });
        return at({
          broadcast: function() {
            var cell, cr, editor, find, origCR, origCell, parts, peerClass, spreadsheet;
            if (!(typeof SocialCalc !== "undefined" && SocialCalc !== null ? SocialCalc.isConnected : void 0)) {
              return;
            }
            if (this.user === SocialCalc._username) {
              return;
            }
            if (this.to && this.to !== SocialCalc._username) {
              return;
            }
            editor = SocialCalc.CurrentSpreadsheetControlObject.editor;
            switch (this.type) {
              case "ecell":
                peerClass = " " + this.user + " defaultPeer";
                find = new RegExp(peerClass, "g");
                if (this.original) {
                  origCR = SocialCalc.coordToCr(this.original);
                  origCell = SocialCalc.GetEditorCellElement(editor, origCR.row, origCR.col);
                  origCell.element.className = origCell.element.className.replace(find, "");
                }
                cr = SocialCalc.coordToCr(this.ecell);
                cell = SocialCalc.GetEditorCellElement(editor, cr.row, cr.col);
                if (cell.element.className.search(find) === -1) {
                  cell.element.className += peerClass;
                }
                break;
              case "ask.snapshot":
                return SocialCalc.Callbacks.broadcast("snapshot", {
                  to: this.user,
                  snapshot: SocialCalc.CurrentSpreadsheetControlObject.CreateSpreadsheetSave()
                });
              case "ask.ecell":
                SocialCalc.Callbacks.broadcast("ecell", {
                  to: this.user,
                  ecell: editor.ecell.coord
                });
                break;
              case "snapshot":
                if (SocialCalc.hadSnapshot) {
                  break;
                }
                SocialCalc.hadSnapshot = true;
                spreadsheet = SocialCalc.CurrentSpreadsheetControlObject;
                parts = spreadsheet.DecodeSpreadsheetSave(this.snapshot);
                if (parts) {
                  if (parts.sheet) {
                    spreadsheet.sheet.ResetSheet();
                    spreadsheet.ParseSheetSave(this.snapshot.substring(parts.sheet.start, parts.sheet.end));
                  }
                  if (parts.edit) {
                    spreadsheet.editor.LoadEditorSettings(this.snapshot.substring(parts.edit.start, parts.edit.end));
                  }
                }
                if (spreadsheet.editor.context.sheetobj.attribs.recalc === "off") {
                  spreadsheet.ExecuteCommand("redisplay", "");
                  spreadsheet.ExecuteCommand("set sheet defaulttextvalueformat text-wiki");
                } else {
                  spreadsheet.ExecuteCommand("recalc", "");
                  spreadsheet.ExecuteCommand("set sheet defaulttextvalueformat text-wiki");
                }
                break;
              case "execute":
                SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands(this.cmdstr, this.saveundo, true);
                break;
            }
          }
        });
      }
    });
  });
}).call(this);
