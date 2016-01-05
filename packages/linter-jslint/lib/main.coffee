{CompositeDisposable} = require 'atom'
path = require 'path'
config = require("./config")
jsLint = require("jslint").load atom.config.get("linter-jslint.jslintVersion")
jsLinter = require("jslint").linter.doLint

module.exports =
  config:
    jslintVersion:
      title: "JSLint version:"
      description: "Atom needs a reload for this setting to take effect"
      type: "string"
      default: "latest"
      enum: ["latest", "2015-05-08", "2014-07-08", "2014-04-21", "2014-02-06", "2014-01-26", "2013-11-23", "2013-09-22", "2013-08-26", "2013-08-13", "2013-02-03"]
    #executablePath:
    #  type: 'string'
    #  default: path.join(__dirname, '..', 'node_modules', 'jshint', 'bin', 'jshint')
    #  description: 'Path of the `jslint` executable.'
    #lintInlineJavaScript:
    #  type: 'boolean'
    #  default: false
    #  description: 'Lint JavaScript inside `<script>` blocks in HTML or PHP files.'
    disableWhenNoJslintrcFileInPath:
      type: 'boolean'
      default: false
      description: 'Disable linter when no `.jslintrc` is found in project.'

  activate: ->
    @subscriptions = new CompositeDisposable
    #@subscriptions.add atom.config.observe 'linter-jslint.executablePath',
    #  (executablePath) =>
    #    @executablePath = executablePath
    #scopeEmbedded = 'source.js.embedded.html'
    @scopes = ['source.js', 'source.js.jsx', 'source.js-semantic']
    #@subscriptions.add atom.config.observe 'linter-jslint.lintInlineJavaScript',
    #  (lintInlineJavaScript) =>
    #    if lintInlineJavaScript
    #      @scopes.push(scopeEmbedded) unless scopeEmbedded in @scopes
    #    else
    #      @scopes.splice(@scopes.indexOf(scopeEmbedded), 1) if scopeEmbedded in @scopes
    @subscriptions.add atom.config.observe 'linter-jslint.disableWhenNoJslintrcFileInPath',
      (disableWhenNoJslintrcFileInPath) =>
        @disableWhenNoJslintrcFileInPath = disableWhenNoJslintrcFileInPath

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    helpers = require('atom-linter')
    #reporter = require('jshint-json') # a string path
    warnings = [
      'unused_a'
      'empty_block'
    ]
    infos = [
      'nested_comment'
      'todo_comment'
      'too_long'
    ]

    provider =
      name: 'JSLint'
      grammarScopes: @scopes
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        filePath = textEditor.getPath()
        if @disableWhenNoJslintrcFileInPath and not helpers.findFile(filePath, '.jslintrc')
          return []

        text = textEditor.getText()
        result = jsLinter jsLint, text, config()
        unless result and result.errors.length
          return []
        output = []
        for entry in result.errors
          continue unless entry?
          message = if entry.message? then entry.message else entry.reason
          column = if entry.column? then entry.column else entry.character
          pointStart = [entry.line, column]
          pointEnd = [entry.line, column + message.length]

          # Padding for jslint.edition > 2015-05-08
          if atom.config.get("linter-jslint.jslintVersion") != '2015-05-08'
            pointStart = [pointStart[0] - 1, pointStart[1] - 1]
            pointEnd = [pointEnd[0] - 1, pointEnd[1] - 1]
            if entry.raw == "Expected '{a}' at column {b}, not column {c}."
              message = entry.raw
                .replace("{a}", entry.a)
                .replace("{b}", entry.b - 1)
                .replace("{c}", entry.c - 1)
                .replace("{d}", entry.d)

          if entry.code in infos
            type = 'Info'
          else if entry.code in warnings
            type = 'Warning'
          else
            type = 'Error'
          output.push {
            type
            text: message
            range: [pointStart, pointEnd]
            filePath
          }
        return output

        #parameters = ['--reporter', reporter, '--filename', filePath]
        #if textEditor.getGrammar().scopeName.indexOf('text.html') isnt -1 and 'source.js.embedded.html' in @scopes
        #  parameters.push('--extract', 'always')
        #parameters.push('-')
        #return helpers.execNode(@executablePath, parameters, {stdin: text}).then (output) ->
        #  unless output.length
        #    return []
        #  output = JSON.parse(output).result
        #  output = output.filter((entry) -> entry.error.id)
        #  result = output.map (entry) ->
        #    error = entry.error
        #    pointStart = [error.line - 1, error.character - 1]
        #    pointEnd = [error.line - 1, error.character]
        #    type = error.code.substr(0, 1)
        #    return {
        #      type: if type is 'E' then 'Error' else if type is 'W' then 'Warning' else 'Info'
        #      text: "#{error.code} - #{error.reason}"
        #      filePath
        #      range: [pointStart, pointEnd]
        #    }
        #  console.log result
        #  return result
