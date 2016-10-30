{Point} = require 'atom'
path = require 'path'
fs = require 'fs'

# Your init script
#
# Atom will evaluate this file each time a new window is opened. It is run
# after packages are loaded/activated and after the previous editor state
# has been restored.
#
# An example hack to log to the console when each text editor is saved.
#
# atom.workspace.observeTextEditors (editor) ->
#   editor.onDidSave ->
#     console.log "Saved! #{editor.getPath()}"

# prevent core:copy if and only if there's one selection in
# the active editor (mini or not) and its length equals 0
atom.commands.add 'atom-text-editor', 'core:copy', (e) ->
  editor = e.currentTarget.getModel()

  # do nothing if there's more than 1 selection
  return if editor.getSelectedBufferRanges().length > 1

  # get the starting and ending points of the selection
  {start, end} = editor.getSelectedBufferRange()

  # stop the command from immediate propagation (i.e.
  # executing the same command on the same element or
  # an element higher up the DOM tree). This works
  # because atom executes commands in the reverse order
  # they were registered with atom.commands.add, and this
  # one's added after the core commands are already
  # registered.
  if start.column is end.column and start.row is end.row
    e.stopImmediatePropagation()


# temporaire, en attendant le fix du déplacement de lignes
atom.commands.add 'atom-text-editor', 'my:move-line-up', ->
  editor = atom.workspace.getActiveTextEditor()
  if atom.config.get('editor.autoIndent')
    atom.config.set('editor.autoIndent', false)
    editor.moveLineUp()
    atom.config.set('editor.autoIndent', true)
  else
    editor.moveLineUp()

atom.commands.add 'atom-text-editor', 'my:move-line-down', ->
  editor = atom.workspace.getActiveTextEditor()
  if atom.config.get('editor.autoIndent')
    atom.config.set('editor.autoIndent', false)
    editor.moveLineDown()
    atom.config.set('editor.autoIndent', true)
  else
    editor.moveLineDown()

isSpace = (char) -> char is '' or /\s/.test(char)
getCharAt = (editor, point) -> editor.getTextInBufferRange(
    [[point.row, point.column], [point.row, point.column + 1]]
)

# Copy project path with line number
# atom.commands.add 'atom-text-editor', 'my:copy-path-and-line', ->
#     editor = atom.workspace.getActiveTextEditor()
#     file = editor?.buffer.file
#     filePath = file?.path
#     console.log atom.project
#     project = atom.project.getPaths().find((project) => console.log project)
#     console.log project.path

# Open path under cursor.
atom.commands.add 'atom-text-editor', 'my:open-path-under-cursor', ->
    editor = atom.workspace.getActiveTextEditor()

    pathStart = editor.getCursorBufferPosition()

    # Search start of path
    until isSpace(getCharAt(editor, new Point(pathStart.row, pathStart.column - 1)))
        pathStart = new Point(pathStart.row, pathStart.column - 1)

    pathEnd = editor.getCursorBufferPosition()

    # Search end of path
    until isSpace(getCharAt(editor, pathEnd))
        pathEnd = new Point(pathEnd.row, pathEnd.column + 1)

    path = editor.getTextInBufferRange([pathStart, pathEnd])
    pathIsValid = (/^[a-zA-Z0-9\/\-:\.]+$/.test path) and (path.indexOf('/') isnt -1)

    console.log path

    if pathIsValid

        # Open file at specific line
        atom.open {
            pathsToOpen: ['/data-ssd/jvc-respawn/' + path]
            newWindow: false
        }

# Remove char on each side of the selection : '{selection}' -> {selection}.
atom.commands.add 'atom-text-editor', 'my:unwrap', ->
    editor = atom.workspace.getActiveTextEditor()
    selections = editor.getSelections()

    selections.forEach (selection) ->
        selectedText = selection.getText()
        selection.insertText('')
        selection.selectLeft()
        selection.insertText('')
        selection.selectRight()
        selection.insertText('')
        selection.insertText(selectedText, { select: true })


# Moves the selected text in ./query-part.sql.
# Amélios :
# - Sélectionne et lance la ligne courante si la sélection est vide
# - Sélectionne et lance le paragraphe courant si la sélection est vide
# - Extrait les headers et les prepend à query-part.sql
# - Pouvoir lancer une requête depuis n'importe quel fichier

atom.commands.add 'atom-text-editor', 'my:create-query-part', ->
    editor = atom.workspace.getActiveTextEditor()
    filePath = atom.workspace.getActivePaneItem().buffer.file?.path?

    if not filePath
        return

    warn = (message) -> atom.notifications.addWarning message, { dismissable: true }

    # Only in sql files.
    if editor.getGrammar().scopeName isnt 'source.sql'
        return warn 'Not in a `source.sql` file.'

    partFile = "#{path.dirname filePath}/query-part.sql"

    # Only if ./query-part.sql file exists.
    try
        if not fs.statSync(partFile).isFile()
            return warn "`#{partFile}` is not a file"
    catch
        return warn "`#{partFile}` doesn't exist"

    selectedText = editor.getSelectedText()

    fs.writeFileSync partFile, "#{selectedText}\n"

class SqlTokenizer

    constructor: () ->
        @scopes =
            SQL: Symbol('scope_sql')
            SINGLE_LINE_COMMENT: Symbol('scope_single_line_comment')
            MULTI_LINE_COMMENT: Symbol('scope_multi_line_comment')
            SINGLE_QUOTE_STRING: Symbol('scope_single_quote_string')
            DOUBLE_QUOTE_STRING: Symbol('scope_double_quote_string')

        # Uses "`" because CoffeeScript sucks : object keys cannot be symbols.
        @nextScopes = `{
            [this.scopes.SQL]: [
                { token: '/*', scope: this.scopes.MULTI_LINE_COMMENT },
                { token: '--', scope: this.scopes.SINGLE_LINE_COMMENT },
                { token: '\'', scope: this.scopes.SINGLE_QUOTE_STRING },
                { token: '"', scope: this.scopes.DOUBLE_QUOTE_STRING },
            ],
            [this.scopes.SINGLE_LINE_COMMENT]: [
                { token: '\n', scope: this.scopes.SQL },
            ],
            [this.scopes.MULTI_LINE_COMMENT]: [
                { token: '*/', scope: this.scopes.SQL },
            ],
            [this.scopes.SINGLE_QUOTE_STRING]: [
                { token: '\'', scope: this.scopes.SQL },
            ],
            [this.scopes.DOUBLE_QUOTE_STRING]: [
                { token: '"', scope: this.scopes.SQL },
            ],
        }`

    _findNextScope: (text, currentScope) ->
        nextScope = @nextScopes[currentScope].find((possibleScope) -> text.startsWith(possibleScope.token))
        return if nextScope then nextScope.scope else currentScope

    tokenize: (sql) ->
        splittedSql = sql.split(/(?=(?:\/\*|--|\n|\*\/|'|"))/g)

        currentScope = @scopes.SQL
        return splittedSql.map((text) =>
            currentScope = @_findNextScope(text, currentScope)
            return {
                scope: currentScope
                text
            }
        )

sqlTokenizer = new SqlTokenizer

# Fix SQL case (keywords, placeholders, ...) of current text editor.
fixSqlCase = ->
    editor = atom.workspace.getActiveTextEditor()
    buffer = atom.workspace.getActivePaneItem().buffer
    text = buffer.getText()

    # Saves cursor position to restore it after text replacement.
    cursorPositions = editor.getCursorBufferPositions()
    # Saves selection ranges to restore it after text replacement.
    selectionRanges = editor.getSelectedBufferRanges()

    uppercase = (text) -> text.toUpperCase()

    patternTransformPairs = [
        # Placeholders.
        [/__\w+__/gi, uppercase],
        # Keywords.
        [/\b(?:add|after|alter|and|as|asc|begin|by|case|check|column|constraint|create|declare|definer|desc|distinct|each|else|end|execute|false|for|foreign|from|function|group|having|if|immutable|in|index|insert|into|is|join|key|language|left|limit|not|null|on|or|order|primary|procedure|query|raise|references|return|returns|row|security|select|set|stable|table|then|trigger|true|update|using|values|when|where)\b/gi, uppercase],
    ]

    tokenizedSql = sqlTokenizer.tokenize text

    transformedSql = tokenizedSql.map((part) =>
        # Only transform SQL scope.
        if part.scope isnt sqlTokenizer.scopes.SQL
            return part

        newText = part.text
        for [pattern, transform] in patternTransformPairs
            newText = newText.replace(pattern, transform)

        return { text: newText, scope: part.scope }
    );

    finalSql = transformedSql.reduce(((res, part) -> res + part.text), '')

    # Does nothing if there is no difference.
    if text is finalSql
        return

    buffer.setTextViaDiff(finalSql)

    # Restore cursors.
    # `set` method overrides all existing cursors.
    editor.setCursorBufferPosition(cursorPositions[0])
    # Adds remaining cursors.
    for cursorPosition in cursorPositions.splice(1)
        editor.addCursorAtBufferPosition(cursorPosition)

    # Restore selections.
    editor.setSelectedBufferRanges(selectionRanges)


# Binds the execution of `fixSqlCase` on change for all SQL buffers.
atom.workspace.observeTextEditors((editor) ->
    editor.onDidStopChanging(->
        if (editor.getGrammar().scopeName is 'source.sql')
            fixSqlCase()
    )
)
atom.commands.add 'atom-text-editor', 'my:fix-sql-case', () ->
    fixSqlCase()
