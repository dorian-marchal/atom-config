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
