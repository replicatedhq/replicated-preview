(require 'node-jsx').install(
  extension: '.jsx'
)

replicatedConfigRender = null

exports.toDOMFragment = (source='', filePath, grammar, callback) ->
  render source, filePath, (error, html) ->
    return callback(error) if error?

    template = document.createElement('template')
    template.innerHTML = html
    domFragment = template.content.cloneNode(true)

    defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    convertCodeBlocksToAtomEditors(domFragment, defaultCodeLanguage)
    callback(null, domFragment)

render = (text, filePath, callback) ->
  replicatedConfigRender ?= require 'replicated-config-render'
  replicatedConfigRender.renderYmlToString text, (error, html) ->
    console.log("error: " + error)
    console.log("html: " + html)
    if not error
      html = '<div id="replicated-preview">' + html + '</div>'
    return callback(error, html)

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->
  domFragment
