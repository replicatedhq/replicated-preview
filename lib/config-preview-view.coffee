path = require 'path'
{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
debounce = require 'debounce'
renderer = require './replicated-renderer'

module.exports =
class ConfigPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new ConfigPreviewView(state)

  @content: ->
    @div class: 'config-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, @filePath}) ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  attached: ->
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else if @filePath
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  serialize: ->
    deserializer: 'ConfigPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @disposables.dispose()

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    # No op to suppress deprecation warning
    new Disposable

  onDidChangeConfig: (callback) ->
    @emitter.on 'did-change-config', callback

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath)
    @emitter.emit 'did-change-title'
    @handleEvents()
    @renderConfig()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderConfig()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @disposables.add atom.grammars.onDidAddGrammar =>
      debounce((=> @renderConfig()), 250)
    @disposables.add atom.grammars.onDidUpdateGrammar =>
      debounce((=> @renderConfig()), 250)

    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()

    changeHandler = =>
      @renderConfig()

      pane = atom.workspace.paneForItem?(this) ?
             atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      @disposables.add @editor.getBuffer().onDidStopChanging ->
        changeHandler() if atom.config.get 'replicated-preview.liveUpdate'
      @disposables.add @editor.getBuffer().onDidSave ->
        changeHandler() unless atom.config.get 'replicated-preview.liveUpdate'
      @disposables.add @editor.getBuffer().onDidReload ->
        changeHandler() unless atom.config.get 'replicated-preview.liveUpdate'
      @disposables.add @editor.onDidChangePath =>
        @emitter.emit 'did-change-title'

  renderConfig: ->
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
    console.log('Render replicated-preview')
    renderer.toDOMFragment source, @getPath(), @getGrammar(), (error, domFragment) =>
      if error
        @showError(error)
      else
        #@loading = false
        #@empty()
        #@append(domFragment)
        @html(domFragment)
        @emitter.emit 'did-change-config'
        @originalTrigger('replicated-preview:config-changed')

  getTitle: ->
    "Replicated Config Preview"

  getIconName: ->
    "replicated"

  getURI: ->
    if @file?
      "replicated-preview://#{@getPath()}"
    else
      "replicated-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getGrammar()

  showError: (error) ->
    failureMessage = error?.message

    @html $$$ ->
      @h2 'Previewing Config Failed'
      @h2 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'replicated-loading', =>
        @h3 'Rendering Config\u2026'
        @h3 =>
          @i class: 'fa fa-spinner fa-spin'

  isEqual: (other) ->
    @[0] is other?[0] # Compare DOM elements
