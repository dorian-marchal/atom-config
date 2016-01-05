linter-jslint
=========================

This plugin for [linter](https://github.com/atom-community/linter) provides an interface to [JSLint](http://www.jslint.com/help.html). It will lint JavaScript in files with the `.js` extension and optionally inside `<script>` blocks in HTML or PHP files.

## Installation
The Linter package must be installed in order to use this plugin. If it isn't installed, please follow the instructions [here](https://github.com/atom-community/linter#how-to--installation).

### Plugin installation
```sh
$ apm install linter-jslint
```

## Settings
You can configure linter-jslint by editing `~/.atom/config.cson` (choose Open Your Config in Atom menu):
```coffee
'linter-jslint':
  # Path of the `jslint` executable
  executablePath: '/path/to/bundled/jslint'

  # Lint JavaScript inside `<script>` blocks in HTML or PHP files
  lintInlineJavaScript: false

  # Disable linter when no `.jslintrc` is found in project
  disableWhenNoJslintrcFileInPath: false
```

## Contributing
If you would like to contribute enhancements or fixes, please do the following:

1. Fork the plugin repository
2. Hack on a separate topic branch created from the latest `master`
3. Commit and push the topic branch
4. Make a pull request
5. Welcome to the club :sunglasses:

Please note that modifications should follow these coding guidelines:

- Indent of 2 spaces
- Code should pass [CoffeeLint](http://www.coffeelint.org/) with the provided `coffeelint.json`
- Vertical whitespace helps readability, don't be afraid to use it

**Thank you for helping out!**
