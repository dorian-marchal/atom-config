// # Your init script
// #
// # Atom will evaluate this file each time a new window is opened. It is run
// # after packages are loaded/activated and after the previous editor state
// # has been restored.
// #
// # An example hack to log to the console when each text editor is saved.
// #
// # atom.workspace.observeTextEditors (editor) ->
// #   editor.onDidSave ->
// #     console.log "Saved! #{editor.getPath()}"

atom.keymap.keyBindings = atom.keymap.keyBindings.filter(function(binding, i) {
  return ['ctrl-alt-p'].indexOf(binding.keystrokes) === -1;
});

atom.keymap.keyBindings = atom.keymap.keyBindings.filter(function(binding, i) {
  return ['ctrl-q'].indexOf(binding.keystrokes) === -1;
});

atom.workspaceView.command('dorian:add-new-line-top', function() {
  alert('Hello :)');
});
