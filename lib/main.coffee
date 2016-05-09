url = require 'url'

ConfigPreviewView = null # Defer until used
renderer = null # Defer until used

createConfigPreviewView = (state) ->
  ConfigPreviewView ?= require './config-preview-view'
  new ConfigPreviewView(state)

isConfigPreviewView = (object) ->
  ConfigPreviewView ?= require './config-preview-view'
  object instanceof ConfigPreviewView

atom.deserializers.add
  name: 'ConfigPreviewView'
  deserialize: (state) ->
    createConfigPreviewView(state) if state.constructor is Object

module.exports =
  config:
    liveUpdate:
      type: 'boolean'
      default: true
    openPreviewInSplitPane:
      type: 'boolean'
      default: true
    openPreviewAutomatically:
      type: 'boolean'
      default: false
    closePreviewAutomatically:
      type: 'boolean'
      default: true
    grammars:
      type: 'array'
      default: [
        'text.plain.null-grammar'
        'source.yaml'
      ]

  activate: ->
    atom.commands.add 'atom-workspace',
      'replicated-preview:toggle': => @toggle()

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'replicated-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createConfigPreviewView(editorId: pathname.substring(1))
      else
        createConfigPreviewView(filePath: pathname)

    atom.workspace.onDidChangeActivePaneItem (item) =>
      @onDidChangeActivePaneItem(item)

    atom.workspace.onWillDestroyPaneItem (event) =>
      @onWillDestroyPaneItem(event.item)

  onWillDestroyPaneItem: (item) ->
    return unless (
      atom.config.get('replicated-preview.closePreviewAutomatically') and
      atom.config.get('replicated-preview.openPreviewInSplitPane')
    )
    @removePreviewForEditor(item)

  onDidChangeActivePaneItem: (item) ->
    return unless (
      atom.config.get('replicated-preview.openPreviewAutomatically') and
      atom.config.get('replicated-preview.openPreviewInSplitPane') and
      @isConfigEditor item
    )
    @addPreviewForEditor item

  isConfigEditor: (item) ->
    grammars = ['source.yaml'].concat(atom.config.get('replicated-preview.grammars') ? [])
    grammar = item?.getGrammar?()?.scopeName

    return (
      ( item?.getBuffer? and item?.getText? ) and
      ( grammar in grammars )
    )

  toggle: ->
    console.log('Toggle replicated-preview')
    if isConfigPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('replicated-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "replicated-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
      activatePane: false

    if atom.config.get('replicated-preview.openPreviewInSplitPane')
      options.split = 'right'

    atom.workspace.open(uri, options).then (configPreviewView) ->
      if isConfigPreviewView(configPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "replicated-preview://#{encodeURI(filePath)}", searchAllPanes: true
