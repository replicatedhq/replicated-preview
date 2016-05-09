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
      html ='<div id="replicated-preview">
      <small id="note" class="navbar navbar-inverse navbar-fixed-top">
      Alpha Version: This config preview is not interactive & will only
      display the default YAML state. For detailed instructions visit:
      <a href="https://vendor.replicated.com/yaml-tool">
      https://vendor.replicated.com/yaml-tool</a></small>' + html + '</div>
      </div>'
    return callback(error, html)

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->
  domFragment
