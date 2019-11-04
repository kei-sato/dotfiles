
atom.commands.add 'atom-text-editor', 'custom:move-half-page-up', ->
  editor = atom.workspace.getActiveTextEditor()
  editor.moveUp(20)

atom.commands.add 'atom-text-editor', 'custom:move-half-page-down', ->
  editor = atom.workspace.getActiveTextEditor()
  editor.moveDown(20)

atom.commands.add 'atom-text-editor', 'custom:select-and-find', (evt) ->
  atom.commands.dispatch evt.target, 'find-and-replace:select-next'
  atom.commands.dispatch evt.target, 'find-and-replace:use-selection-as-find-pattern'

atom.commands.add 'atom-text-editor', 'custom:rename-file', (evt) ->
  atom.commands.dispatch evt.target, 'tree-view:toggle-focus'
  atom.commands.dispatch evt.target, 'tree-view:move'
