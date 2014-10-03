###
 Package dependencies
###
jsbeautify = (require 'js-beautify').js_beautify

packgeConfig = require './config'
Observer = require './observer'
FileTypeNotSupportedView = require './not-supported-view'

module.exports =
  config: packgeConfig

  activate: (state) ->
    atom.workspaceView.command 'jsformat:format', => @format(state)

    @editorSaveSubscriptions = {}
    @editorCloseSubscriptions = {}

    # @editorSaveSubscriptions = new Observer()
    # @editorCloseSubscriptions = new Observer()

    atom.config.observe 'jsformat.format_on_save', =>
      @subscribeToEvents()

  format: (state) ->
    editor = atom.workspace.activePaneItem
    if !editor
      return

    grammar = editor.getGrammar()?.scopeName
    mainCursor = editor.getCursors()[0]
    textBuffer = editor.getBuffer()
    nonWhitespaceRegex = /\S/g
    whitespaceRegex = /\s/g
    currentCursorPosition = mainCursor.getBufferPosition()
    mainCursor.setBufferPosition([currentCursorPosition.row, currentCursorPosition.column + 1])
    isBeforeWord = mainCursor.isInsideWord()
    mainCursor.setBufferPosition(currentCursorPosition)

    if mainCursor.isInsideWord()
      # The cursor is inside a word, so let's use the beginning as the reference
      #
      currentPosition = mainCursor.getBeginningOfCurrentWordBufferPosition()

      # ideally we could do mainCursor.setBufferPosition([currentCursorPosition.row, currentCursorPosition.column + 1]).isInsideWord()
      # but .setBufferPosition returns undefined :(
      # So we have to define some stuff above instead...

    else if isBeforeWord
      # The cursor is right before a word in this case, so let's use the current cursor position as a reference
      #
      mainCursor.setBufferPosition(currentCursorPosition)
      currentPosition = currentCursorPosition

    whitespaceText = textBuffer.getTextInRange([[0, 0], currentPosition])

    nonWhitespaceCharacters = whitespaceText.match(nonWhitespaceRegex)
    whitespaceCharacterCount = whitespaceText.match(whitespaceRegex)

    if !whitespaceCharacterCount
      whitespaceCharacterCount = 0
    else
      whitespaceCharacterCount = whitespaceCharacterCount.length

    if !nonWhitespaceCharacters
      nonWhitespaceCharacters = 0
    else
      nonWhitespaceCharacters = nonWhitespaceCharacters.length

    if grammar is 'source.json' or grammar is 'source.js'
      @formatJavascript editor

      nonWhitespaceCount = 0
      text = editor.getText()

      newCursorPosition = textBuffer.positionForCharacterIndex(nonWhitespaceCharacters + whitespaceCharacterCount);

      mainCursor.setBufferPosition(newCursorPosition)

    else
      notification = new FileTypeNotSupportedView(state)
      atom.workspaceView.append(notification)
      destroyer = () ->
        notification.detach()

      setTimeout destroyer, 1500

  formatJavascript: (editor) ->
    settings = atom.config.getSettings().editor
    opts = {
      indent_size: editor.getTabLength(),
      wrap_line_length: settings.preferredLineLength
    }

    for configKey, defaultValue of @configDefaults
      opts[configKey] = atom.config.get('jsformat.' + configKey) ? defaultValue

    if @selectionsAreEmpty editor
      editor.setText(jsbeautify(editor.getText(), opts))

    else
      for selection in editor.getSelections()
        selection.insertText(jsbeautify(selection.getText(), opts), {select:true})

  selectionsAreEmpty: (editor) ->
    for selection in editor.getSelections()
      return false unless selection.isEmpty()
    true

  subscribeToEvents: (state) ->
    if atom.config.get('jsformat.format_on_save') ? @configDefaults['format_on_save']
      @editorCreationSubscription = atom.workspace.observeTextEditors (editor) =>
        grammar = editor.getGrammar().scopeName

        if grammar is 'source.js' or grammar is 'source.json'
          buffer = editor.getBuffer()

          @editorSaveSubscriptions[editor.id] = buffer.onWillSave =>
            buffer.transact =>
              @format(state)

          @editorCloseSubscriptions[editor.id] = buffer.onDidDestroy =>
            @editorSaveSubscriptions[editor.id].dispose()
            @editorCloseSubscriptions[editor.id].dispose()

            delete @editorSaveSubscriptions[editor.id]
            delete @editorCloseSubscriptions[editor.id]


          # saveSubscription = buffer.onWillSave =>
          #   buffer.transact =>
          #     @format(state)
          #
          # closeSubscription = buffer.onDidDestroy =>
          #   debugger
          #
          # @editorSaveSubscriptions.addSubscription(saveSubscription)
          # @editorCloseSubscriptions.addSubscription(closeSubscription)
    else
      if @editorCreationSubscription
        @editorCreationSubscription.dispose()
        @editorCreationSubscription = null

        for subscriptionId, subscription of @editorSaveSubscriptions
          subscription.dispose()
          delete @editorSaveSubscriptions[subscriptionId]

        for subscriptionId, subscription of @editorCloseSubscriptions
          subscription.dispose()
          delete @editorCloseSubscriptions[subscriptionId]

        # @editorSaveSubscriptions.dispose()
        # @editorSaveSubscriptions = new Observer()
        #
        # @editorCloseSubscriptions.dispose()
        # @editorCloseSubscriptions = new Observer()
