(function($)
{

    var chat = new Chat();
    chat.join();


    // Broadcasting code

    function Chat()
    {
        var _self = this;
        var _username = Math.random().toString();
        var _hadSnapshot;
        var _lastUser;
        var _disconnecting;
        var _chatSubscription;
        var _membersSubscription;

        this.join = function()
        {
            _disconnecting = false;
            if (!_username)
            {
                alert('Please enter a username');
                return;
            }

            var cometdURL = 'http://' + (location.host || 'localhost') + ':8080/cometd';

            $.cometd.configure({
                url: cometdURL,
                logLevel: 'debug'
            });
            $.cometd.handshake();
        };

        this.leave = function()
        {
            $.cometd.startBatch();
            $.cometd.publish('/chat/demo', {
                user: _username,
                status: 'gone'
            });
            _unsubscribe();
            $.cometd.disconnect();
            $.cometd.endBatch();
            _disconnecting = true;
        };

        this.broadcast = function(type, message) {
            message = message || {};
            message.user = _username;
            message.type = type;
            $.cometd.publish('/chat/demo', message);
        };

        this.receive = function(message) {
            if (message.data.user == _username) return;
            if (message.data.to && message.data.to != _username) return;
            // var membership = message.data.membership;
            //var text = message.data.chat;
            switch (message.data.type) {
                case 'ask.snapshot': {
                    _self.broadcast('msg.snapshot', {
                        to: message.data.user,
                        snapshot: SocialCalc.CurrentSpreadsheetControlObject.CreateSpreadsheetSave()
                    });
                    break;
                }
                case 'msg.snapshot': {
                    if (_hadSnapshot) break;
                    _hadSnapshot = true;
                    var spreadsheet = SocialCalc.CurrentSpreadsheetControlObject;
                    var parts = spreadsheet.DecodeSpreadsheetSave(message.data.snapshot);
                    if (parts) {
                        if (parts.sheet) {
                            spreadsheet.sheet.ResetSheet();
                            spreadsheet.ParseSheetSave(message.data.snapshot.substring(parts.sheet.start, parts.sheet.end));
                        }
                        if (parts.edit) {
                            spreadsheet.editor.LoadEditorSettings(message.data.snapshot.substring(parts.edit.start, parts.edit.end));
                        }
                    }
                    if (spreadsheet.editor.context.sheetobj.attribs.recalc=="off") {
                        spreadsheet.ExecuteCommand('redisplay', '');
                    }
                    else {
                        spreadsheet.ExecuteCommand('recalc', '');
                    }

                    break;
                }
                case 'execute': {
                    SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands(
                        message.data.cmdstr,
                        message.data.saveundo,
                        true // isRemote = true
                    );
                    break;
                }
            }
        };

        /**
         * Updates the members list.
         * This function is called when a message arrives on channel /chat/members
         */
        this.members = function(message)
        {
            var list = '';
            $.each(message.data, function()
            {
                list += this + '<br />';
            });
        //    $('#members').html(list);
        };

        function _unsubscribe()
        {
            if (_chatSubscription)
            {
                $.cometd.unsubscribe(_chatSubscription);
            }
            _chatSubscription = null;
            if (_membersSubscription)
            {
                $.cometd.unsubscribe(_membersSubscription);
            }
            _membersSubscription = null;
        }

        function _subscribe()
        {
            _chatSubscription = $.cometd.subscribe('/chat/demo', _self.receive);
            _membersSubscription = $.cometd.subscribe('/chat/members', _self.members);
        }

        function _connectionEstablished()
        {
            _self.receive({
                data: {
                    user: 'system',
                    chat: 'Connection to Server Opened'
                }
            });
            $.cometd.startBatch();
            _unsubscribe();
            _subscribe();
            $.cometd.publish('/service/members', {
                user: _username,
                room: '/chat/demo'
            });
            $.cometd.publish('/chat/demo', {
                user: _username,
                membership: 'join',
                chat: _username + ' has joined'
            });
            $.cometd.endBatch();

            SocialCalc.Callbacks.broadcast = chat.broadcast;
            $(function(){ chat.broadcast('ask.snapshot') });
        }

        function _connectionBroken()
        {
            _self.receive({
                data: {
                    user: 'system',
                    chat: 'Connection to Server Broken'
                }
            });
            $('#members').empty();
        }

        function _connectionClosed()
        {
            _self.receive({
                data: {
                    user: 'system',
                    chat: 'Connection to Server Closed'
                }
            });
        }

        var _connected = false;
        function _metaConnect(message)
        {
            if (_disconnecting)
            {
                _connected = false;
                _connectionClosed();
            }
            else
            {
                var wasConnected = _connected;
                _connected = message.successful === true;
                if (!wasConnected && _connected)
                {
                    _connectionEstablished();
                }
                else if (wasConnected && !_connected)
                {
                    _connectionBroken();
                }
            }
        }

        $.cometd.addListener('/meta/connect', _metaConnect);

        // Disconnect when the page unloads
        $(window).unload(_self.leave);
    }

})(jQuery);




