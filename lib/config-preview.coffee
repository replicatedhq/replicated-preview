url = require 'url'

ConfigPreviewView = null
renderer = null

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
    breakOnSingleNewline:
      type: 'boolean'
      default: false
    liveUpdate:
      type: 'boolean'
      default: true
    openPreviewInSplitPane:
      type: 'boolean'
      default: true
    grammars:
      type: 'array'
      default: [
        'source.gfm',
        'source.litcoffee',
        'text.html.basic',
        'text.plain',
        'text.plain.null-grammar'
      ]

  activate: (state) ->
    atom.commands.add 'atom-workspace', 'config-preview:toggle': => @toggle()

    previewFile = @previewFile.bind(this)

    atom.workspace.addOpener (uriToOpen) ->
      console.log(uriToOpen)
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'replicated-config-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createConfigPreviewView(editorId: pathname.substring(1))
      else
        createConfigPreviewView(filePath: pathname)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @configPreviewView.destroy()

  serialize: ->
    configPreviewViewState: @configPreviewView.serialize()

  toggle: ->
    if isConfigPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  addPreviewForEditor: (editor) ->
    console.log('add preview')
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
      split: 'right'

    atom.workspace.open(uri, options).done (configPreviewView) ->
      if isConfigPreviewView(configPreviewView)
        previousActivePane.activate()

  removePreviewForEditor: (editor) ->
    console.log('remove preview')
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  uriForEditor: (editor) ->
    "replicated-config-preview://editor/#{editor.id}"

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "replicated-config-preview://#{encodeURI(filePath)}", searchAllPanes: true
