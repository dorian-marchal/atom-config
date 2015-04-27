module.exports =
  activate: (state) ->
    atom.commands.add 'atom-workspace', 'duplicate-lines-upward:duplicate-lines-upward', => @duplicateLinesUpward()

  # Duplicate the most recent cursor's current line upward.
  duplicateLinesUpward: ->
    editor = atom.workspace.getActiveEditor()
    if (!editor)
      return null
    editor.transact =>
      for selection in editor.getSelectionsOrderedByBufferPosition()
        selectedBufferRange = selection.getBufferRange()
        if selection.isEmpty()
          {start} = selection.getScreenRange()
          selection.selectToScreenPosition([start.row + 1, 0])

        [startRow, endRow] = selection.getBufferRowRange()
        endRow++

        foldedRowRanges =
          editor.outermostFoldsInBufferRowRange(startRow, endRow)
            .map (fold) -> fold.getBufferRowRange()

        rangeToDuplicate = [[startRow, 0], [endRow, 0]]
        textToDuplicate = editor.getTextInBufferRange(rangeToDuplicate)
        textToDuplicate = textToDuplicate + '\n' if endRow > editor.getLastBufferRow()
        editor.buffer.insert([startRow, 0], textToDuplicate)

        delta = endRow - startRow
        selection.setBufferRange(selectedBufferRange)
        for [foldStartRow, foldEndRow] in foldedRowRanges
          editor.createFold(foldStartRow, foldEndRow)
