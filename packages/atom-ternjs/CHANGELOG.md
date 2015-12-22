## [0.11.0]
- Removed `autocomplete-snippets` as a default. By default method completion now won't add snippets after confirming the suggestion. Re-activate it via package settings.
- Removed the option `do not add parantheses`
- Some performance improvements
  - Do not update the file if there are no changes made to the text-buffer
  - Reduce garbage in certain contexes
- Updated Tern to the latest version
- Added the context menu items (find definition, find references & rename) to sub-menu
- Bugfixing

## [0.10.3]
- Updated Tern to the latest version
- Fixed keybindings for platform linux (see README.md)
- Added option to display suggestions above snippets
- Do not use shadowRoot to get `.scroll-view` if shadow DOM is disabled
- Bugfixing

## [0.8.0]
- Add support for ES6

## [0.5.24]
- Add support for multiply projects

## [0.4.13]
- TypeView to display completions for fn-params

## [0.4.6]
- Documentation now provides urls and origin
- Various improvements and bugfixing

## [0.4.4]
- Improved decision if completion should be triggered

## [0.4.2]
- Documentation is now being displayed via a panel
- Various bugfixing

## [0.4.0]
- Implemented feature: Find references

## [0.3.8]
- Package now works on Windows platform

## [0.0.1] - First Release
- First working example