path = require 'path'
ColorBuffer = require '../lib/color-buffer'
jsonFixture = require('./spec-helper').jsonFixture(__dirname, 'fixtures')

describe 'ColorBuffer', ->
  [editor, colorBuffer, pigments, project] = []

  editBuffer = (text, options={}) ->
    if options.start?
      if options.end?
        range = [options.start, options.end]
      else
        range = [options.start, options.start]

      editor.setSelectedBufferRange(range)

    editor.insertText(text)
    editor.getBuffer().emitter.emit('did-stop-changing') unless options.noEvent

  beforeEach ->
    atom.config.set 'pigments.sourceNames', [
      '*.styl'
      '*.less'
    ]

    atom.config.set 'pigments.ignoredNames', ['project/vendor/**']

    waitsForPromise ->
      atom.workspace.open('four-variables.styl').then (o) -> editor = o

    waitsForPromise -> atom.packages.activatePackage('pigments').then (pkg) ->
      pigments = pkg.mainModule
      project = pigments.getProject()

  it 'creates a color buffer for each editor in the workspace', ->
    expect(project.colorBuffersByEditorId[editor.id]).toBeDefined()

  describe 'when an editor without path is opened', ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open().then (o) ->
          editor = o
          colorBuffer = project.colorBufferForEditor(editor)

      waitsForPromise -> colorBuffer.variablesAvailable()

    it 'does not fails when updating the colorBuffer', ->
      expect(-> colorBuffer.update()).not.toThrow()

    describe 'when the file is saved and aquires a path', ->
      describe 'that is legible', ->
        beforeEach ->
          spyOn(colorBuffer, 'update').andCallThrough()
          spyOn(editor, 'getPath').andReturn('new-path.styl')
          editor.emitter.emit 'did-change-path', editor.getPath()

          waitsFor -> colorBuffer.update.callCount > 0

        it 'adds the path to the project paths', ->
          expect('new-path.styl' in project.getPaths()).toBeTruthy()

      describe 'that is not legible', ->
        beforeEach ->
          spyOn(colorBuffer, 'update').andCallThrough()
          spyOn(editor, 'getPath').andReturn('new-path.sass')
          editor.emitter.emit 'did-change-path', editor.getPath()

          waitsFor -> colorBuffer.update.callCount > 0

        it 'does not add the path to the project paths', ->
          expect('new-path.styl' in project.getPaths()).toBeFalsy()

      describe 'that is ignored', ->
        beforeEach ->
          spyOn(colorBuffer, 'update').andCallThrough()
          spyOn(editor, 'getPath').andReturn('project/vendor/new-path.styl')
          editor.emitter.emit 'did-change-path', editor.getPath()

          waitsFor -> colorBuffer.update.callCount > 0

        it 'does not add the path to the project paths', ->
          expect('new-path.styl' in project.getPaths()).toBeFalsy()

  describe 'when created without a previous state', ->
    beforeEach ->
      colorBuffer = project.colorBufferForEditor(editor)
      waitsForPromise -> colorBuffer.initialize()

    it 'scans the buffer for colors without waiting for the project variables', ->
      expect(colorBuffer.getColorMarkers().length).toEqual(4)
      expect(colorBuffer.getValidColorMarkers().length).toEqual(3)

    it 'creates the corresponding markers in the text editor', ->
      expect(editor.findMarkers(type: 'pigments-color').length).toEqual(4)

    it 'knows that it is legible as a variables source file', ->
      expect(colorBuffer.isVariablesSource()).toBeTruthy()

    describe 'when the editor is destroyed', ->
      it 'destroys the color buffer at the same time', ->
        editor.destroy()

        expect(project.colorBuffersByEditorId[editor.id]).toBeUndefined()

    ##    ##     ##    ###    ########   ######
    ##    ##     ##   ## ##   ##     ## ##    ##
    ##    ##     ##  ##   ##  ##     ## ##
    ##    ##     ## ##     ## ########   ######
    ##     ##   ##  ######### ##   ##         ##
    ##      ## ##   ##     ## ##    ##  ##    ##
    ##       ###    ##     ## ##     ##  ######

    describe 'when the project variables becomes available', ->
      [updateSpy] = []
      beforeEach ->
        updateSpy = jasmine.createSpy('did-update-color-markers')
        colorBuffer.onDidUpdateColorMarkers(updateSpy)
        waitsForPromise -> colorBuffer.variablesAvailable()

      it 'replaces the invalid markers that are now valid', ->
        expect(colorBuffer.getValidColorMarkers().length).toEqual(4)
        expect(updateSpy.argsForCall[0][0].created.length).toEqual(1)
        expect(updateSpy.argsForCall[0][0].destroyed.length).toEqual(1)

      it 'destroys the text editor markers', ->
        expect(editor.findMarkers(type: 'pigments-color').length).toEqual(4)

      it 'creates markers for variables in the buffer', ->
        expect(colorBuffer.getVariableMarkers().length).toEqual(4)
        expect(editor.findMarkers(type: 'pigments-variable').length).toEqual(4)

      describe 'when a variable marker is edited', ->
        [colorsUpdateSpy] = []
        beforeEach ->
          updateSpy = jasmine.createSpy('did-update-variable-markers')
          colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
          colorBuffer.onDidUpdateVariableMarkers(updateSpy)
          colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
          editBuffer '#336699', start: [0,13], end: [0,17]
          waitsFor -> updateSpy.callCount > 0

        it 'updates the modified variable marker', ->
          expect(colorBuffer.getVariableMarkerByName('base-color').variable.value).toEqual('#336699')

        it 'has the same number of variables than before', ->
          expect(colorBuffer.getVariableMarkers().length).toEqual(4)
          expect(editor.findMarkers(type: 'pigments-variable').length).toEqual(4)

        it 'updates the modified colors', ->
          waitsFor -> colorsUpdateSpy.callCount > 0
          runs ->
            expect(colorsUpdateSpy.argsForCall[0][0].destroyed.length).toEqual(2)
            expect(colorsUpdateSpy.argsForCall[0][0].created.length).toEqual(2)

      describe 'when a new variable is added', ->
        [colorsUpdateSpy] = []

        beforeEach ->
          waitsForPromise -> colorBuffer.variablesAvailable()

          runs ->
            updateSpy = jasmine.createSpy('did-update-variable-markers')
            colorBuffer.onDidUpdateColorMarkers(updateSpy)
            editor.moveToBottom()
            editBuffer '\nfoo = base-color'
            waitsFor -> updateSpy.callCount > 0

        it 'adds a marker for the new variable', ->
          expect(colorBuffer.getVariableMarkers().length).toEqual(5)
          expect(colorBuffer.getVariableMarkerByName('foo').variable.value).toEqual('base-color')
          expect(editor.findMarkers(type: 'pigments-variable').length).toEqual(5)

        it 'dispatches the new marker in a did-update-variable-markers event', ->
          expect(updateSpy.argsForCall[0][0].destroyed.length).toEqual(0)
          expect(updateSpy.argsForCall[0][0].created.length).toEqual(1)

      describe 'when a variable marker is removed', ->
        [colorsUpdateSpy] = []
        beforeEach ->
          updateSpy = jasmine.createSpy('did-update-variable-markers')
          colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
          colorBuffer.onDidUpdateVariableMarkers(updateSpy)
          colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
          editBuffer '', start: [0,0], end: [0,17]
          waitsFor -> updateSpy.callCount > 0

        it 'updates the modified variable marker', ->
          expect(colorBuffer.getVariableMarkerByName('base-color')).toBeUndefined()

        it 'dispatches the new marker in a did-update-variable-markers event', ->
          expect(updateSpy.argsForCall[0][0].destroyed.length).toEqual(1)
          expect(updateSpy.argsForCall[0][0].created.length).toEqual(0)

        it 'invalidates colors that were relying on the deleted variables', ->
          waitsFor -> colorsUpdateSpy.callCount > 0
          runs ->
            expect(colorBuffer.getColorMarkers().length).toEqual(3)
            expect(colorBuffer.getValidColorMarkers().length).toEqual(2)

      describe '::serialize', ->
        beforeEach ->
          waitsForPromise -> colorBuffer.variablesAvailable()

        it 'returns the whole buffer data', ->
          expected = jsonFixture "four-variables-buffer.json", {
            id: editor.id
            root: atom.project.getPaths()[0]
            colorMarkers: colorBuffer.getColorMarkers().map (m) -> m.marker.id
            variableMarkers: colorBuffer.getVariableMarkers().map (m) -> m.marker.id
          }

          expect(colorBuffer.serialize()).toEqual(expected)

    ##     ######   #######  ##        #######  ########   ######
    ##    ##    ## ##     ## ##       ##     ## ##     ## ##    ##
    ##    ##       ##     ## ##       ##     ## ##     ## ##
    ##    ##       ##     ## ##       ##     ## ########   ######
    ##    ##       ##     ## ##       ##     ## ##   ##         ##
    ##    ##    ## ##     ## ##       ##     ## ##    ##  ##    ##
    ##     ######   #######  ########  #######  ##     ##  ######

    describe 'with a buffer with only colors', ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('buttons.styl').then (o) -> editor = o

        runs ->
          colorBuffer = project.colorBufferForEditor(editor)

      it 'creates the color markers for the variables used in the buffer', ->
        waitsForPromise -> colorBuffer.initialize()
        runs -> expect(colorBuffer.getColorMarkers().length).toEqual(0)

      it 'creates the color markers for the variables used in the buffer', ->
        waitsForPromise -> colorBuffer.variablesAvailable()
        runs -> expect(colorBuffer.getColorMarkers().length).toEqual(3)

      describe 'when a color marker is edited', ->
        [colorsUpdateSpy] = []

        beforeEach ->
          waitsForPromise -> colorBuffer.variablesAvailable()

          runs ->
            colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
            colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
            editBuffer '#336699', start: [1,13], end: [1,23]
            waitsFor -> colorsUpdateSpy.callCount > 0

        it 'updates the modified color marker', ->
          markers = colorBuffer.getColorMarkers()
          marker = markers[markers.length-1]
          expect(marker.color).toBeColor('#336699')

        it 'updates only the affected marker', ->
          expect(colorsUpdateSpy.argsForCall[0][0].destroyed.length).toEqual(1)
          expect(colorsUpdateSpy.argsForCall[0][0].created.length).toEqual(1)

        it 'removes the previous editor markers', ->
          expect(editor.findMarkers(type: 'pigments-color').length).toEqual(3)

      describe 'when a new color is added', ->
        [colorsUpdateSpy] = []

        beforeEach ->
          waitsForPromise -> colorBuffer.variablesAvailable()

          runs ->
            colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
            colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
            editor.moveToBottom()
            editBuffer '\n#336699'
            waitsFor -> colorsUpdateSpy.callCount > 0

        it 'adds a marker for the new color', ->
          markers = colorBuffer.getColorMarkers()
          marker = markers[markers.length-1]
          expect(markers.length).toEqual(4)
          expect(marker.color).toBeColor('#336699')
          expect(editor.findMarkers(type: 'pigments-color').length).toEqual(4)

        it 'dispatches the new marker in a did-update-color-markers event', ->
          expect(colorsUpdateSpy.argsForCall[0][0].destroyed.length).toEqual(0)
          expect(colorsUpdateSpy.argsForCall[0][0].created.length).toEqual(1)

      describe 'when a color marker is edited', ->
        [colorsUpdateSpy] = []

        beforeEach ->
          waitsForPromise -> colorBuffer.variablesAvailable()

          runs ->
            colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
            colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
            editBuffer '', start: [1,2], end: [1,23]
            waitsFor -> colorsUpdateSpy.callCount > 0

        it 'updates the modified color marker', ->
          expect(colorBuffer.getColorMarkers().length).toEqual(2)

        it 'updates only the affected marker', ->
          expect(colorsUpdateSpy.argsForCall[0][0].destroyed.length).toEqual(1)
          expect(colorsUpdateSpy.argsForCall[0][0].created.length).toEqual(0)

        it 'removes the previous editor markers', ->
          expect(editor.findMarkers(type: 'pigments-color').length).toEqual(2)

  ##    ####  ######   ##    ##  #######  ########  ######## ########
  ##     ##  ##    ##  ###   ## ##     ## ##     ## ##       ##     ##
  ##     ##  ##        ####  ## ##     ## ##     ## ##       ##     ##
  ##     ##  ##   #### ## ## ## ##     ## ########  ######   ##     ##
  ##     ##  ##    ##  ##  #### ##     ## ##   ##   ##       ##     ##
  ##     ##  ##    ##  ##   ### ##     ## ##    ##  ##       ##     ##
  ##    ####  ######   ##    ##  #######  ##     ## ######## ########

  describe 'with a buffer part of the ignored files', ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('project/vendor/css/variables.less').then (o) -> editor = o

      runs ->
        colorBuffer = project.colorBufferForEditor(editor)

      waitsForPromise -> colorBuffer.variablesAvailable()

    it 'knows that it is part of the ignored files', ->
      expect(colorBuffer.isIgnored()).toBeTruthy()

    it 'knows that it is a variables source file', ->
      expect(colorBuffer.isVariablesSource()).toBeTruthy()

    it 'scans the buffer for variables for in-buffer use only', ->
      expect(colorBuffer.getColorMarkers().length).toEqual(20)
      validMarkers = colorBuffer.getColorMarkers().filter (m) ->
        m.color.isValid()

      expect(validMarkers.length).toEqual(20)

    describe 'when the buffer is edited', ->
      beforeEach ->
        colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
        colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
        editor.moveToBottom()
        editBuffer '\n\n@new-color = @base0;\n'
        waitsFor -> colorsUpdateSpy.callCount > 0

      it 'finds the newly added color', ->
        expect(colorBuffer.getColorMarkers().length).toEqual(21)
        validMarkers = colorBuffer.getColorMarkers().filter (m) ->
          m.color.isValid()

        expect(validMarkers.length).toEqual(21)

  ##    ##    ##  #######  ##     ##    ###    ########   ######
  ##    ###   ## ##     ## ##     ##   ## ##   ##     ## ##    ##
  ##    ####  ## ##     ## ##     ##  ##   ##  ##     ## ##
  ##    ## ## ## ##     ## ##     ## ##     ## ########   ######
  ##    ##  #### ##     ##  ##   ##  ######### ##   ##         ##
  ##    ##   ### ##     ##   ## ##   ##     ## ##    ##  ##    ##
  ##    ##    ##  #######     ###    ##     ## ##     ##  ######

  describe 'with a buffer not being a variable source', ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('project/lib/main.coffee').then (o) -> editor = o

      runs -> colorBuffer = project.colorBufferForEditor(editor)

      waitsForPromise -> colorBuffer.variablesAvailable()

    it 'knows that it is not part of the source files', ->
      expect(colorBuffer.isVariablesSource()).toBeFalsy()

    it 'knows that it is not part of the ignored files', ->
      expect(colorBuffer.isIgnored()).toBeFalsy()

    it 'scans the buffer for variables for in-buffer use only', ->
      expect(colorBuffer.getColorMarkers().length).toEqual(4)
      validMarkers = colorBuffer.getColorMarkers().filter (m) ->
        m.color.isValid()

      expect(validMarkers.length).toEqual(4)

    describe 'when the buffer is edited', ->
      beforeEach ->
        colorsUpdateSpy = jasmine.createSpy('did-update-color-markers')
        spyOn(project, 'reloadVariablesForPath').andCallThrough()
        colorBuffer.onDidUpdateColorMarkers(colorsUpdateSpy)
        editor.moveToBottom()
        editBuffer '\n\n@new-color = red;\n'
        waitsFor -> colorsUpdateSpy.callCount > 0

      it 'finds the newly added color', ->
        expect(colorBuffer.getColorMarkers().length).toEqual(5)
        validMarkers = colorBuffer.getColorMarkers().filter (m) ->
          m.color.isValid()

        expect(validMarkers.length).toEqual(5)

      it 'does not ask the project to reload the variables', ->
        expect(project.reloadVariablesForPath).not.toHaveBeenCalled()

  ##    ########  ########  ######  ########  #######  ########  ########
  ##    ##     ## ##       ##    ##    ##    ##     ## ##     ## ##
  ##    ##     ## ##       ##          ##    ##     ## ##     ## ##
  ##    ########  ######    ######     ##    ##     ## ########  ######
  ##    ##   ##   ##             ##    ##    ##     ## ##   ##   ##
  ##    ##    ##  ##       ##    ##    ##    ##     ## ##    ##  ##
  ##    ##     ## ########  ######     ##     #######  ##     ## ########

  describe 'when created with a previous state', ->
    describe 'with variables and colors', ->
      beforeEach ->
        waitsForPromise -> project.initialize()
        runs ->
          project.colorBufferForEditor(editor).destroy()

          state = jsonFixture('four-variables-buffer.json', {
            id: editor.id
            root: atom.project.getPaths()[0]
            colorMarkers: [-1..-4]
            variableMarkers: [-5..-8]
          })
          state.editor = editor
          state.project = project
          colorBuffer = new ColorBuffer(state)

      it 'creates markers from the state object', ->
        expect(colorBuffer.getColorMarkers().length).toEqual(4)
        expect(colorBuffer.getVariableMarkers().length).toEqual(4)

      it 'restores the markers properties', ->
        variableMarker = colorBuffer.getVariableMarkers()[0]
        expect(variableMarker.variable).toEqual(project.getVariableByName('base-color'))

        colorMarker = colorBuffer.getColorMarkers()[3]
        expect(colorMarker.color).toBeColor(255,255,255,0.5)
        expect(colorMarker.color.variables).toEqual(['base-color'])

      it 'restores the editor markers', ->
        expect(editor.findMarkers(type: 'pigments-variable').length).toEqual(4)
        expect(editor.findMarkers(type: 'pigments-color').length).toEqual(4)

      it 'restores the ability to fetch markers', ->
        expect(colorBuffer.findColorMarkers().length).toEqual(4)
        expect(colorBuffer.findVariableMarkers().length).toEqual(4)

        for marker in colorBuffer.findColorMarkers()
          expect(marker).toBeDefined()

        for marker in colorBuffer.findVariableMarkers()
          expect(marker).toBeDefined()

    describe 'with an invalid color', ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('invalid-color.styl').then (o) ->
            editor = o

        waitsForPromise -> project.initialize()

        runs ->
          state = jsonFixture('invalid-color-buffer.json', {
            id: editor.id
            root: atom.project.getPaths()[0]
            colorMarkers: [-1]
            variableMarkers: []
          })
          state.editor = editor
          state.project = project
          colorBuffer = new ColorBuffer(state)

      it 'creates markers from the state object', ->
        expect(colorBuffer.getColorMarkers().length).toEqual(1)
        expect(colorBuffer.getValidColorMarkers().length).toEqual(0)