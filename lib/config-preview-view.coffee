path = require 'path'

{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
_ = require 'underscore-plus'

renderer = require './renderer'

module.exports =
class ConfigPreviewView extends ScrollView
  @content: ->
    console.log('content')
    @div class: 'config-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, @filePath}) ->
    console.log('config-preview-view constructor')
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @loaded = false

  attached: ->
    console.log('attached')
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.package.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  serialize: ->
    deserializer: 'ConfigPreviewView'
    filePath: @getPath()
    editorId: @editorId

  # Tear down any state and detach
  destroy: ->
    @disposables.dispose()

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    new Disposable

  subscribeToFilePath: (filePath) ->
    console.log('subscribe')

  resolveEditor: (editorId) ->
    console.log('resolveEditor')

    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderConfig()
      else
        atom.workspace?.paneForItem(this)?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  renderConfig: ->
    console.log('rendering config...')
    @showLoading() unless @loaded
    @getConfigSource().then (source) => @renderConfigSource(source) if source?

  getConfigSource: ->
    if @file?
      @file.read()
    else if @editor?
      Promise.resolve(@editor.getText())
    else
      Promise.resolve(null)

  renderConfigSource: (source) ->
    console.log('renderConfigSource')
    renderer.toDOMFragment source, @getPath(), @getGrammar(), (error, domFragment) =>
      if error
        @showError(error)
      else
        @loading = false
        @loaded = true
        @html(domFragment)
        @emitter.emit 'did.change.config'
        @originalTrigger('replicated-config-preview:config-changed')

  handleEvents: ->
    console.log('handleEvents')
    @disposables.add atom.grammars.onDidAddGrammar => _.debounce((=> @renderConfig()), 250)
    @disposables.add atom.grammars.onDidUpdateGrammar _.debounce((=> @renderConfig()), 250)

    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()

    changeHandler = =>
      @renderConfig()

      pane = atom.workspace.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem()

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      @disposables.add @editor.getBuffer().onDidStopChanging ->
        changeHandler() if atom.config.get 'replicated-config-preview.liveUpdate'
      @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
      @disposables.add @editor.getBuffer().onDidSave ->
        changeHandler() unless atom.config.get 'replicated-config-preview.liveUpdate'
      @disposables.add @editor.getBuffer().onDidReload ->
        changeHandler() unless atom.config.get 'replicated-config-preview.liveUpdate'

    @disposables.add atom.config.onDidChange 'replicated-config-preview.breakOnSingleNewline', changeHandler

  getTitle: ->
    console.log('getTitle')
    "Replicated Config Preview"

  getURI: ->
    console.log('getURI')
    if @file?
      "replicated-config-preview://#{@getPath()}"
    else
      "replicated-config-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getGrammar()

  getDocumentStyleSheets: ->
    document.styleSheets

  showError: (error) ->
    failureMessage = error?.message

    @html $$$ ->
      @h2 'Previewing Config Failed'
      @h2 failureMessage if failureMessage?

  showLoading: ->
    @loading = true
    @html $$$ ->
      @div class: 'replicated-spinner', 'Rendering Config\u2026'
