(function($)
{

    var chat = new Chat();
    chat.join();

    // Broadcasting code

    function Chat()
    {
        var _self = this;
        var _username = Math.random().toString();
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

        this.send = function(cmdstr, saveundo)
        {
            $.cometd.publish('/chat/demo', {
                user: _username,
                status: 'execute',
                cmdstr: cmdstr,
                saveundo: saveundo
            });
        };

        this.receive = function(message)
        {
            var fromUser = message.data.user;
            var status = message.data.status;
            // var membership = message.data.membership;
            //var text = message.data.chat;
            switch (status) {
                case 'execute': {
                    if (fromUser != _username) {
                        SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands(
                            message.data.cmdstr,
                            message.data.saveundo,
                            true // isRemote = true
                        );
                    }
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

            SocialCalc.Callbacks.broadcast_command = chat.send;
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




