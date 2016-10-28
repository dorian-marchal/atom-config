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
# - Pouvoir lancer une requête depuis n'import quel fichier

atom.commands.add 'atom-text-editor', 'my:create-query-part', ->
    editor = atom.workspace.getActiveTextEditor()
    filePath = atom.workspace.getActivePaneItem().buffer.file.path

    warn = (message) -> atom.notifications.addWarning message, { dismissable: true }

    # Only in sql files.
    if not filePath.match(/\.sql$/)
        return warn 'Not in a .sql file.'

    partFile = "#{path.dirname filePath}/query-part.sql"

    # Only if ./query-part.sql file exists.
    try
        if not fs.statSync(partFile).isFile()
            return warn "'#{partFile}' is not a file"
    catch
        return warn "'#{partFile}' doesn't exist"

    selectedText = editor.getSelectedText()

    fs.writeFileSync partFile, "#{selectedText}\n"
