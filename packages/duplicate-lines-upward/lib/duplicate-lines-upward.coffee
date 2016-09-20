module.exports =
  activate: (state) ->
    atom.commands.add 'atom-workspace', 'duplicate-lines-upward:duplicate-lines-upward', => @duplicateLinesUpward()

  # Duplicate the most recent cursor's current line upward.
  duplicateLinesUpward: ->
    editor = atom.workspace.getActiveTextEditor()
    if (!editor)
      return null
    editor.transact =>
      for selection in editor.getSelectionsOrderedByBufferPosition()
        selectedBufferRange = selection.getBufferRange()
        if selection.isEmpty()
          {start} = selection.getScreenRange()
          selection.setScreenRange([[start.row, 0], [start.row + 1, 0]], preserveFolds: true)

        [startRow, endRow] = selection.getBufferRowRange()
        endRow++

        intersectingFolds = editor.displayLayer.foldsIntersectingBufferRange([[startRow, 0], [endRow, 0]])
        rangeToDuplicate = [[startRow, 0], [endRow, 0]]
        textToDuplicate = editor.getTextInBufferRange(rangeToDuplicate)
        textToDuplicate = textToDuplicate + '\n' if endRow > editor.getLastBufferRow()
        editor.buffer.insert([startRow, 0], textToDuplicate)

        delta = endRow - startRow
        selection.setBufferRange(selectedBufferRange)
        for fold in intersectingFolds
          foldRange = editor.displayLayer.bufferRangeForFold(fold)
          editor.displayLayer.foldBufferRange(foldRange.translate([delta, 0]))
      return
