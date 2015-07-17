{CompositeDisposable} = require 'atom'

path = require 'path'
jsHintName = if process.platform is 'win32' then 'jshint.cmd' else 'jshint'

module.exports =
  config:
    executablePath:
      type: 'string'
      default: path.join(__dirname, '..', 'node_modules', '.bin', jsHintName)
      description: 'Path of the `jshint` executable.'
    lintInlineJavaScript:
      type: 'boolean'
      default: false
      description: 'Lint JavaScript inside `<script>` blocks in HTML or PHP files.'

  activate: ->
    scopeEmbedded = 'source.js.embedded.html'
    @scopes = ['source.js', 'source.js.jsx']
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'linter-jshint.lintInlineJavaScript',
      (lintInlineJavaScript) =>
        if lintInlineJavaScript
          @scopes.push(scopeEmbedded) unless scopeEmbedded in @scopes
        else
          @scopes.splice(@scopes.indexOf(scopeEmbedded), 1) if scopeEmbedded in @scopes

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    helpers = require('atom-linter')
    reporter = require('jshint-json') # a string path
    provider =
      grammarScopes: @scopes
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        executablePath = atom.config.get('linter-jshint.executablePath')
        filePath = textEditor.getPath()
        text = textEditor.getText()
        parameters = ['--reporter', reporter, '--filename', filePath]
        if textEditor.getGrammar().scopeName.indexOf('text.html') isnt -1 and 'source.js.embedded.html' in @scopes
          parameters.push('--extract', 'always')
        parameters.push('-')
        return helpers.exec(executablePath, parameters, {stdin: text}).then (output) ->
          try
            output = JSON.parse(output).result
          catch error
            atom.notifications.addError("Invalid Result received from JSHint",
              {detail: "Check your console for more info. It's a known bug on OSX. See https://github.com/AtomLinter/Linter/issues/726", dismissable: true})
            console.log('JSHint Result:', output)
            return []
          output = output.filter((entry) -> entry.error.id)
          return output.map (entry) ->
            error = entry.error
            pointStart = [error.line - 1, error.character - 1]
            pointEnd = [error.line - 1, error.character]
            type = error.code.substr(0, 1)
            return {
              type: if type is 'E' then 'Error' else if type is 'W' then 'Warning' else 'Info'
              text: "#{error.code} - #{error.reason}"
              filePath
              range: [pointStart, pointEnd]
            }
