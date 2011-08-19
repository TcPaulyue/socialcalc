port = Number(process.env.VCAP_APP_PORT || 3000)
host = process.env.VCAP_APP_HOST || '127.0.0.1'

require('zappa') port, host, ->
  enable 'serve jquery'
  app.use express.static __dirname
  
  get '/': ->
    response.contentType 'text/html'
    response.sendfile 'index.mt'
  
  at broadcast: ->
    io.sockets.emit 'broadcast', this
  
  client '/player.js': ->
    SocialCalc ?= {}
    SocialCalc._username = Math.random().toString()
    SocialCalc.isConnected = true
    SocialCalc.hadSnapshot = false
    
    connect()

    SocialCalc.Callbacks.broadcast = (type, data={}) ->
      return unless SocialCalc.isConnected
      data.user = SocialCalc._username
      data.type = type
      emit 'broadcast', data

    at connection: ->
      SocialCalc.isConnected = true
      SocialCalc.Callbacks.broadcast "ask.snapshot"
      setTimeout (-> SocialCalc.hadSnapshot = true), 30000

    at broadcast: ->
      console.log "CLIENT:"
      return unless SocialCalc?.isConnected
      return if @user == SocialCalc._username
      return if @to and @to != SocialCalc._username
      editor = SocialCalc.CurrentSpreadsheetControlObject.editor
      switch @type
        when "ecell"
          peerClass = " " + @user + " defaultPeer"
          find = new RegExp(peerClass, "g")
          if @original
            origCR = SocialCalc.coordToCr(@original)
            origCell = SocialCalc.GetEditorCellElement(editor, origCR.row, origCR.col)
            origCell.element.className = origCell.element.className.replace(find, "")
          cr = SocialCalc.coordToCr(@ecell)
          cell = SocialCalc.GetEditorCellElement(editor, cr.row, cr.col)
          cell.element.className += peerClass if cell.element.className.search(find) == -1
          break
        when "ask.snapshot"
          SocialCalc.Callbacks.broadcast "snapshot",
            to: @user
            snapshot: SocialCalc.CurrentSpreadsheetControlObject.CreateSpreadsheetSave()
        when "ask.ecell"
          SocialCalc.Callbacks.broadcast "ecell",
            to: @user
            ecell: editor.ecell.coord
          break
        when "snapshot"
          break if SocialCalc.hadSnapshot
          SocialCalc.hadSnapshot = true
          spreadsheet = SocialCalc.CurrentSpreadsheetControlObject
          parts = spreadsheet.DecodeSpreadsheetSave(@snapshot)
          if parts
            if parts.sheet
              spreadsheet.sheet.ResetSheet()
              spreadsheet.ParseSheetSave @snapshot.substring(parts.sheet.start, parts.sheet.end)
            spreadsheet.editor.LoadEditorSettings @snapshot.substring(parts.edit.start, parts.edit.end)  if parts.edit
          if spreadsheet.editor.context.sheetobj.attribs.recalc == "off"
            spreadsheet.ExecuteCommand "redisplay", ""
            spreadsheet.ExecuteCommand "set sheet defaulttextvalueformat text-wiki"
          else
            spreadsheet.ExecuteCommand "recalc", ""
            spreadsheet.ExecuteCommand "set sheet defaulttextvalueformat text-wiki"
          break
        when "execute"
          SocialCalc.CurrentSpreadsheetControlObject.context.sheetobj.ScheduleSheetCommands @cmdstr, @saveundo, true
          break
