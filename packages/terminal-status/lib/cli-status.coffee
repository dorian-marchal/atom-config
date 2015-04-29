CliStatusView = require './cli-status-view'

module.exports =
  cliStatusView: null

  activate: (state) ->
    createStatusEntry = =>
      @cliStatusView = new CliStatusView(state.cliStatusViewState)

    atom.packages.onDidActivateInitialPackages => createStatusEntry()

  deactivate: ->
    @cliStatusView.destroy()

  configDefaults:
    'WindowHeight': 300