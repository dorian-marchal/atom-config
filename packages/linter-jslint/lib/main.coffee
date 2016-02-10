{CompositeDisposable} = require 'atom'
path = require 'path'
fs = require("fs")

module.exports =
  config:
    jslintVersion:
      title: "JSLint version:"
      type: "string"
      default: "latest"
      enum: ["latest", "es6", "es5", "2015-05-08", "2014-07-08", "2014-04-21", "2014-02-06", "2014-01-26", "2013-11-23", "2013-09-22", "2013-08-26", "2013-08-13", "2013-02-03", "2012-02-03"]
    disableWhenNoJslintrcFileInPath:
      type: 'boolean'
      default: false
      description: 'Disable linter when no `.jslintrc` is found in project.'

  activate: ->
    @subscriptions = new CompositeDisposable
    @scopes = ['source.js', 'source.js.jsx', 'source.js-semantic']
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
        jslintrcPath = helpers.find(filePath, '.jslintrc')
        if @disableWhenNoJslintrcFileInPath and not jslintrcPath
          return []

        jsLint = require("jslint").load atom.config.get("linter-jslint.jslintVersion")
        jsLinter = require("jslint").linter.doLint

        config = {}
        defaultConfigPath = path.normalize(path.join(process.env.HOME or process.env.HOMEPATH, ".jslintrc"))
        if defaultConfigPath
          try
            config = JSON.parse(fs.readFileSync(defaultConfigPath, "utf-8"))
          catch err
            console.log "Error reading config file \"" + jslintrcPath + "\": " + err  if err.code isnt "ENOENT"
        if jslintrcPath
          try
            config = JSON.parse(fs.readFileSync(jslintrcPath, "utf-8"))
          catch err
            console.log "Error reading config file \"" + jslintrcPath + "\": " + err  if err.code isnt "ENOENT"

        text = textEditor.getText()

        result = jsLinter jsLint, text, config
        unless result and result.errors.length
          return []
        output = []
        for entry in result.errors
          continue unless entry?
          message = if entry.message? then entry.message else entry.reason
          column = if entry.column? then entry.column else entry.character
          pointStart = [entry.line, column]
          pointEnd = [entry.line, column + message.length]

          # Padding for jslint.edition > 2014
          if atom.config.get("linter-jslint.jslintVersion").match /^201[0-4]/
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
