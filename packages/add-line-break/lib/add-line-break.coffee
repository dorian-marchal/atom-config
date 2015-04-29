{Point} = require 'atom'

# Return a start/end object couple from the two given Points.
# The points are ordered by actual position in the editor
# For example, {5, 9} will be placed before {6, 1}
sortRangePoints = (range) ->
  a = range.start
  b = range.end

  if (a.row < b.row or (a.row == b.row and a.column < b.column))
    sortedPoints =
      start: a
      end: b
  else
    sortedPoints =
      start: a
      end: b

  return sortedPoints


# If direction == 'before', add a line before the selected lines
# else, add a new line after the selected lines
addLineBreak = (direction) ->
  editor = atom.workspace.getActiveTextEditor()

  if (!editor)
    return null

  ranges = editor.getSelectedBufferRanges()
  buffer = editor.getBuffer()
  checkpoint = buffer.createCheckpoint()
  offset = 0

  for i of ranges
    {start, end} = sortRangePoints ranges[i]
    newLinePosition = if (direction == 'before') then (new Point(start.row + offset, 0)) else (new Point(end.row + offset + 1, 0))
    buffer.insert newLinePosition, '\n'
    offset++

  buffer.groupChangesSinceCheckpoint(checkpoint)

module.exports =
  activate: ->
    atom.commands.add 'atom-workspace', 'add-line-break:add-line-break-before', => @addLineBreakBefore()
    atom.commands.add 'atom-workspace', 'add-line-break:add-line-break-after', => @addLineBreakAfter()

  addLineBreakBefore: ->
    addLineBreak 'before'

  addLineBreakAfter: ->
    addLineBreak 'after'
