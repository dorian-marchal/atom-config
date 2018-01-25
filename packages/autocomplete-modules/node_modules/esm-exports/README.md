# esm-exports
Parse ecmascript modules and collect names of export vars, functions, etc.

## CHANGELOG
* 0.8.5 - fixed parsing export all from directory
* 0.8.4 - removed unused package
* 0.8.0 - read recursive dir improvements
* 0.7.0 - catch if recursive fails
* 0.6.1 - added support tsx/jsx
* 0.6.0 - scoped types modules
* 0.5.0 - remove duplicates, fix #2
* 0.4.0 - parse inner modules
* 0.3.1 - prevent fail for non-existing directory
* 0.2.0 - parse javascript files
* 0.1.0 - added isDefault property
* 0.0.14 - removed duplicates from result
* 0.0.12 - updated @types/node
* 0.0.11 - fixed: invalid path throws error
* 0.0.9 - fixed: handle typings without extension
* 0.0.8 - first release

DEBUG
---
`inspect node_modules\ts-node\dist\_bin.js -F "node_modules/mocha/bin/_mocha" "src/*.spec.ts"`