{CompositeDisposable} = require 'atom'

# Dependencies
{spawnSync} = require('child_process')
fs = require 'fs'
shell = require 'shell'

module.exports = BrowsePackages =
  config:
    fileManager:
      title: "File manager"
      description: "Specify the full path to a custom file manager"
      type: "string"
      default: ""
    notify:
      title: "Verbose Mode"
      description: "Show info notifications for all actions"
      type: "boolean"
      default: false
  self: 'browse'
  subscriptions: null

  activate: ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'browse:configuration-folder': => @browseConfig()
    @subscriptions.add atom.commands.add 'atom-workspace', 'browse:packages-folder': => @browsePackages()
    @subscriptions.add atom.commands.add 'atom-workspace', 'browse:project-folders': => @browseProjects()
    @subscriptions.add atom.commands.add 'atom-workspace', 'browse:reveal-file': => @revealFile()
    @subscriptions.add atom.commands.add 'atom-workspace', 'browse:reveal-all-open-files': => @revealFiles()

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null

  browsePackages: ->
    packageDirs = atom.packages.getPackageDirPaths()

    for packageDir in packageDirs
      # Does packages folder exist?
      try
        fs.accessSync(packageDir, fs.F_OK)
      catch error
        atom.notifications.addError(@self, detail: error, dismissable: true)

      # Open packages folder
      @openFolder(packageDir)

  revealFile: ->
    # Get parent folder of active file
    editor = atom.workspace.getActivePaneItem()

    if editor?.constructor.name is 'TextEditor' or editor?.constructor.name is 'ImageEditor'
      file = if editor?.buffer?.file then editor.buffer.file else if editor?.file then editor.file
      @selectFile(file.path)
      return
    
    atom.notifications.addWarning("**#{@self}**: No active file", dismissable: false)

  revealFiles: ->
    # Get all open file
    editors = atom.workspace.getPaneItems()

    if editors.length > 0
      count = 0
      for editor in editors
        continue unless editor.constructor.name is 'TextEditor' or editor.constructor.name is 'ImageEditor'

        file = if editor?.buffer?.file then editor.buffer.file else if editor?.file then editor.file
        @selectFile(file.path)
        count++

      return if count > 0

    atom.notifications.addWarning("**#{@self}**: No open files", dismissable: false)

  browseProjects: ->
    projects = atom.project.getPaths()

    unless projects.length > 0
      atom.notifications.addWarning("**#{@self}**: No active project", dismissable: false)
      return

    for project in projects
      # Skip Atom dialogs
      if project.startsWith('atom://')
        continue

      # Does project folder exist?
      try
        fs.accessSync(project, fs.F_OK)
      catch
        atom.notifications.addError(@self, detail: error, dismissable: true)
        continue

      # Open project folder
      @openFolder(project)

  browseConfig: ->
    path = require 'path'

    configFile = atom.config.getUserConfigPath()
    configPath = path.dirname(configFile)

    if configPath
      # Does config folder exist?
      try
        fs.accessSync(configPath, fs.F_OK)
      catch error
        atom.notifications.addError(@self, detail: error, dismissable: true)
        return

      # Open config folder
      @openFolder(configPath)

  selectFile: (path) ->
    # Custom file manager
    fileManager = atom.config.get('browse.fileManager')

    if fileManager
      spawnSync fileManager, [ path ]
      return

    # Default file manager
    switch process.platform
      when "darwin"
        spawnSync "open", [ "-R", path ]
        fileManager = "Finder"
      when "win32"
        spawnSync "explorer", [ "/select,#{path}" ]
        fileManager = "Explorer"
      when "linux"
        shell.showItemInFolder(path)
        fileManager = "file manager"

    @isVerbose("Revealed", path, fileManager)

  openFolder: (path) ->
    # Custom file manager
    fileManager = atom.config.get('browse.fileManager')

    if fileManager
      spawnSync fileManager, [ path ]
      return

    # Default file manager
    switch process.platform
      when "darwin"
        spawnSync "open", [ path ]
        fileManager = "Finder"
      when "win32"
        spawnSync "explorer", [ path ]
        fileManager = "Explorer"
      when "linux"
        shell.openItem(path)
        fileManager = "file manager"

    @isVerbose("Opened", path, fileManager)

  isVerbose: (verb, fullPath, fileManager) ->
    if atom.config.get('browse.notify') is true
      # Get base name
      path = require 'path'
      baseName = path.basename(fullPath)

      atom.notifications.addInfo("**#{@self}**: #{verb} `#{baseName}` in #{fileManager}", dismissable: false)
