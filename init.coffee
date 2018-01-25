{Point} = require 'atom'
path = require 'path'
fs = require 'fs'
os = require 'os'

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

selectParagraphUnderCursor = ->
    editor = atom.workspace.getActiveTextEditor()
    cursor = editor.getLastCursor()

    startRow = endRow = cursor.getBufferRow();

    while editor.lineTextForBufferRow(startRow)
        startRow--

    while editor.lineTextForBufferRow(endRow)
        endRow++

    editor.setSelectedBufferRange({
        start: { row: startRow + 1, column: 0 },
        end: { row: endRow, column: 0 },
    })

createQueryPart = (addExplainAnalyze = false, addCount = false) ->
    editor = atom.workspace.getActiveTextEditor()
    filePath = atom.workspace.getActivePaneItem().buffer.file?.path

    if not filePath
        return

    warn = (message) -> atom.notifications.addWarning message, { dismissable: true }

    # Only in sql files.
    if editor.getGrammar().scopeName isnt 'source.sql'
        return warn 'Not in a `source.sql` file.'

    partFile = "#{os.tmpdir()}/atom-query-part.sql"

    selectedText = editor.getSelectedText()

    if selectedText is ''
        selectParagraphUnderCursor()
        selectedText = editor.getSelectedText()

    # Extracts and prepends extracted psql headers to query part.
    headers = editor.getBuffer().getText().match(/^([\s\S]*)-- \/header\n/)?[1] or ''
    allReplaceHeaderRegex = /^-- replace: (.*)→(.*)$/gm
    singleReplaceHeaderRegex = /^-- replace: (.*)→(.*)$/m

    replaceHeaders = if headers then headers.match(allReplaceHeaderRegex) else null
    replaceList = if replaceHeaders then replaceHeaders.map((header) -> [header.match(singleReplaceHeaderRegex)[1], header.match(singleReplaceHeaderRegex)[2]]) else []

    for i, [source, dest] of replaceList
        trimmedSource = source.trim()
        trimmedDest = dest.trim()
        console.log trimmedSource, trimmedDest
        selectedText = selectedText.replace(new RegExp("#{trimmedSource}", 'gm'), trimmedDest)

    if addExplainAnalyze
        headers = ['\\x off', headers].join '\n'

    sqlPart = [
        if addExplainAnalyze then 'explain analyze\n' else undefined,
        if addCount then 'select count(*) from (\n' else undefined,
        headers,
        selectedText,
        if addCount then ') as __to_be_counted__\n' else undefined,
        '\n',
    ].join ''

    try
        fs.writeFileSync partFile, sqlPart
    catch
        return warn "Can't write in `#{partFile}`"

# Moves the selected text in /tmp/atom-query-part.sql.
atom.commands.add 'atom-text-editor', 'my:create-query-part', ->
    createQueryPart()

# Moves the selected text in /tmp/atom-query-part.sql.
atom.commands.add 'atom-text-editor', 'my:create-count-query-part', ->
    createQueryPart(false, true)

# Moves the selected text (appended to "explain analyze") in /tmp/atom-query-part.sql.
atom.commands.add 'atom-text-editor', 'my:create-explain-query-part', ->
    createQueryPart(true)

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
fixSqlCase = (editor) ->
    buffer = editor.getBuffer()

    text = buffer.getText()

    # Saves cursor position to restore it after text replacement.
    cursorPositions = editor.getCursorBufferPositions()
    # Saves selection ranges to restore it after text replacement.
    selectionRanges = editor.getSelectedBufferRanges()

    uppercase = (text) -> text.toUpperCase()

    patternTransformPairs = [
        # Placeholders.
        [/__\w+__/gi, uppercase],
        # Placeholders.
        [/\bint\b/gi, 'integer'],
        [/\bbool\b/gi, 'boolean'],
        # Keywords.
        [/\b(?:select( exists)?|nulls last|delete|(cross )?join|lateral|over|partition|add|after|alter|and|as|asc|begin|by|case|check|column|constraint|create|declare|definer|desc|distinct|each|else|end|execute|false|for|foreign|from|function|group|having|if|immutable|in|index|insert|into|is|primary key|foreign key|language|left|limit|not|null|on|or|order|primary|procedure|query|raise|references|return|returns|row|security|set|stable|table|then|trigger|true|update|using|values|when|where)\b/gi, uppercase],
        [/\bwith(?: recursive)? ?\(/gi, uppercase]
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
            fixSqlCase(editor)
    )
)
atom.commands.add 'atom-text-editor', 'my:fix-sql-case', () ->
    fixSqlCase(atom.workspace.getActiveTextEditor())

`
function findItemInPane(nonFirstPaneItem) {
  return function(firstPaneItem) {
    // check that both items are standard editor items (e.g. not SettingsView)
    if (
      Object.getPrototypeOf(firstPaneItem).constructor.name === "TextEditor" &&
      Object.getPrototypeOf(nonFirstPaneItem).constructor.name === "TextEditor"
    ) {
      return firstPaneItem.getPath() === nonFirstPaneItem.getPath()
    } else {
      return firstPaneItem.uri === nonFirstPaneItem.uri
    }
  }
}

atom.commands.add("atom-workspace", "custom:merge-panes", () => {
  const panes = atom.workspace.getCenter().getPanes()
  const firstPane = panes.shift()

  // loop through all panes except for the first pane
  for (pane of panes) {
    for (item of pane.getItems()) {
      // if item is already in first pane, delete it, otherwise move it to first pane
      if (firstPane.getItems().find(findItemInPane(item))) {
        pane.destroyItem(item)
      } else {
        pane.moveItemToPane(item, firstPane)
      }
    }
  }
})
`
