
_ = require 'underscore-plus'
path = require 'path'
fs = require 'fs'

{CompositeDisposable, BufferedProcess} = require "atom"
{$} = require "atom-space-pen-views"

SplitDiff = require 'split-diff'


module.exports =
class GitRevisionView

  @FILE_PREFIX = "TimeMachine - "
  ###
    This code and technique was originally from git-history package,
    see https://github.com/jakesankey/git-history/blob/master/lib/git-history-view.coffee

    Changes to permit click and drag in the time plot to travel in time:
    - don't write revision to disk for faster access and to give the user feedback when git'ing
      a rev to show is slow
    - reuse tabs more - don't open a new tab for every rev of the same file

    Changes to permit scrolling to same lines in view in the editor the history is for

    thank you, @jakesankey!

  ###
  @showRevision: (editor, revHash, options={}) ->
    options = _.defaults options,
      diff: false

    SplitDiff.disable(false)

    file = editor.getPath()

    fileContents = ""
    stdout = (output) =>
        fileContents += output
    exit = (code) =>
      if code is 0
        @_showRevision(file, editor, revHash, fileContents, options)
      else
        atom.notifications.addError "Could not retrieve revision for #{path.basename(file)} (#{code})"

    @_loadRevision file, revHash, stdout, exit


  @_loadRevision: (file, hash, stdout, exit) ->
    showArgs = [
      "-C",
      path.dirname(file),
      "show",
      "#{hash}:./#{path.basename(file)}"
    ]
    # console.log "calling git"
    new BufferedProcess {
      command: "git",
      args: showArgs,
      stdout,
      exit 
    }


  @_getInitialLineNumber: (editor) ->
    editorEle = atom.views.getView editor
    lineNumber = 0
    if editor? && editor != ''
      lineNumber = editorEle.getLastVisibleScreenRow()
      # console.log "_getInitialLineNumber", lineNumber

    # TODO: why -5?  this is what it took to actually sync the last line number
    #    between two editors
    return lineNumber - 5


  @_showRevision: (file, editor, revHash, fileContents, options={}) ->
    outputDir = "#{atom.getConfigDirPath()}/git-time-machine"
    fs.mkdir outputDir if not fs.existsSync outputDir
    outputFilePath = "#{outputDir}/#{@FILE_PREFIX}#{path.basename(file)}"
    outputFilePath += ".diff" if options.diff
    tempContent = "\n\n\nLoading #{path.basename(file)}@#{revHash}...\n\n\n\n"
    fs.writeFile outputFilePath, tempContent, (error) =>
      if not error
          promise = atom.workspace.open outputFilePath,
            split: "right"
            activatePane: false
            activateItem: true
            searchAllPanes: true
          promise.then (newTextEditor) =>
            @_updateNewTextEditor(newTextEditor, editor, revHash, fileContents)


  @_updateNewTextEditor: (newTextEditor, editor, revHash, fileContents) ->
    # slight delay so the user gets feedback on their action
    _.delay =>
      newTextEditor.setText(fileContents)
      # HACK ALERT: this is prone to eventually fail. Don't show user change
      #  message between changes to rev being viewed
      newTextEditor.buffer.cachedDiskContents = fileContents
      @_splitDiff(editor, newTextEditor)
      # split diff will keep the scroll sync'd, but doesn't seem to initially sync themes
      @_syncScroll(editor, newTextEditor)
      @_affixTabTitle newTextEditor, revHash
    , 300


  @_affixTabTitle: (newTextEditor, revHash) ->
    # speaking of hacks this is also hackish, there has to be a better way to change to
    # tab title and unlinking it from the file name
    $el = $(atom.views.getView(newTextEditor))
    $tabTitle = $el.parents('atom-pane').find('li.tab.active .title')
    titleText = $tabTitle.text()
    if titleText.indexOf('@') >= 0
      titleText = titleText.replace(/\@.*/, "@#{revHash}")
    else
      titleText += " @#{revHash}"

    $tabTitle.text(titleText)


  @_splitDiff: (editor, newTextEditor) ->
    editors =
      editor1: newTextEditor    # the older revision
      editor2: editor           # current rev

    SplitDiff.editorSubscriptions = new CompositeDisposable()
    SplitDiff.editorSubscriptions.add editors.editor1.onDidStopChanging =>
      SplitDiff.updateDiff(editors) if editors?
    SplitDiff.editorSubscriptions.add editors.editor2.onDidStopChanging =>
      SplitDiff.updateDiff(editors) if editors?
    SplitDiff.editorSubscriptions.add editors.editor1.onDidDestroy =>
      editors = null;
      SplitDiff.disable(false)
    SplitDiff.editorSubscriptions.add editors.editor2.onDidDestroy =>
      editors = null;
      SplitDiff.disable(false)

    SplitDiff.editorSubscriptions.add atom.config.onDidChange 'split-diff.ignoreWhitespace', ({newValue, oldValue}) =>
      SplitDiff.updateDiff(editors)

    SplitDiff.updateDiff editors




  # sync scroll to editor that we are show revision for
  @_syncScroll: (editor, newTextEditor) ->
    # without the delay, the scroll position will fluctuate slightly beween
    # calls to editor setText
    _.delay =>
      newTextEditor.scrollToBufferPosition({
        row: @_getInitialLineNumber(editor), column: 0
      })
    , 50