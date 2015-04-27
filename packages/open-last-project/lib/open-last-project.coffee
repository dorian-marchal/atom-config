

FS = require('fs')
module.exports =
  Save:->
    try
      Files = []
      ActiveEditor = atom.workspace.getActiveTextEditor()
      atom.workspace.getTextEditors().forEach (editor)->
        File = editor.getPath()
        return unless File
        Files.push File
      CurrentFile = ActiveEditor && ActiveEditor.getPath() || null;
      localStorage.setItem('open-last-project',JSON.stringify({Paths: atom.project.getPaths(), Files: Files, CurrentFile: CurrentFile}))
  LoadProject:->
    LastProject = localStorage.getItem('open-last-project')
    return unless LastProject
    LastProject = JSON.parse(LastProject)
    return unless LastProject.Paths

    atom.project.setPaths LastProject.Paths
    Promises = LastProject.Files.map (file)->
      return new Promise (resolve)->
        FS.exists file, (Status)->
          return resolve() unless Status
          atom.workspace.open(file).then(resolve)
    Promise.all(Promises).then ->
      # Remove the empty pane
      atom.workspace.getTextEditors().forEach (editor)->
        editor.destroy() unless editor.getPath()
      # Set the last active file
      return unless LastProject.CurrentFile
      FS.exists LastProject.CurrentFile, (Status)->
        return unless Status
        atom.workspace.open LastProject.CurrentFile
