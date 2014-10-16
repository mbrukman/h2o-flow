Flow = if exports? then exports else @Flow = {}

# XXX add following contents to startup cells.

#   # Welcome to H<sub>2</sub>O Flow!
#   
#   **Flow** is a web-based interactive computational environment where you can combine code execution, text, mathematics, plots and rich media into a single document, much like [IPython Notebooks](http://ipython.org/notebook.html).
#   
#   A Flow is composed of a series of executable *cells*. Each *cell* has an input and an output. To provide input to a cell.
#   
#   Flow is a modal editor, which means that when you are not editing the contents.
#   
#   - To edit a cell, hit `Enter`.
#   - When you're done editing, hit `Esc`.
#   
#   Hitting `Esc` after editing a cell puts you in *Command Mode*. You can do a variety of actions in Command Mode:
#   - `a` adds a new cell **a**bove the current cell.
#   - `b` adds a new cell __b__elow the current cell.
#   - `d` `d` __d__eletes the current cell. Yes, you need to press `d` twice.
#   
#   To view a list of commands, enter help in the cell below, followed by Ctrl+Enter.
#   
#   [________________________]
#   
#   To view a list of keyboard shortcuts, type h.


# 
# TODO
#
# keyboard help dialog
# menu system
# tooltips on celltype flags
# arrow keys cause page to scroll - disable those behaviors
# scrollTo() behavior


# CLI usage:
# help
# list frames
# list models, list models with compatible frames
# list jobs
# list scores
# list nodes
# ? import dataset
# ? browse files
# ? parse
# ? inspect dataset
# ? column summary
# ? histogram / box plot / top n / characteristics plots
# ? create model
# ? score model
# ? compare scorings
#   ? input / output comparison
#   ? parameter / threshold plots
# ? predictions

marked.setOptions
  smartypants: yes
  highlight: (code, lang) ->
    if window.hljs
      (window.hljs.highlightAuto code, [ lang ]).value
    else
      code

ko.bindingHandlers.enterKey =
  init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    if action = ko.unwrap valueAccessor() 
      if isFunction action
        $element = $ element
        $element.keydown (e) -> 
          if e.which is 13
            action viewModel
          return
      else
        throw 'Enter key action is not a function'
    return

ko.bindingHandlers.typeahead =
  init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    if action = ko.unwrap valueAccessor() 
      if isFunction action
        $element = $ element
        $element.typeahead null,
          displayKey: 'value'
          source: action
      else
        throw 'Typeahead action is not a function'
    return

ko.bindingHandlers.cursorPosition =
  init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    if arg = ko.unwrap valueAccessor()
      # Bit of a hack. Attaches a method to the bound object that returns the cursor position. Uses dwieeb/jquery-textrange.
      arg.read = -> $(element).textrange 'get', 'position'
    return

ko.bindingHandlers.autoResize =
  init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    $el = $ element
      .on 'input', ->
        defer ->
          $el
            .css 'height', 'auto'
            .height element.scrollHeight
    return

ko.bindingHandlers.dom =
  update: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    arg = ko.unwrap valueAccessor()
    if arg
      $element = $ element
      $element.empty()
      $element.append arg
    return

typeOf = (a) ->
  type = Object::toString.call a
  if a is null
    return 'null'
  else if a is undefined
    return 'undefined'
  else if a is true or a is false or type is '[object Boolean]'
    return 'boolean'
  else
    switch type
      when '[object String]'
        return 'string'
      when '[object Number]'
        return 'number'
      when '[object Function]'
        return 'function'
      when '[object Object]'
        return 'object'
      when '[object Array]'
        return 'array'
      when '[object Arguments]'
        return 'arguments'
      when '[object Date]'
        return 'date'
      when '[object RegExp]'
        return 'regexp'
      else
        return type

templateOf = (view) -> view.template

# Like _.compose, but async. 
# Equivalent to caolan/async.waterfall()
pipe = (tasks) ->
  _tasks = slice tasks, 0

  next = (args, go) ->
    task = shift _tasks
    if task
      apply task, null, args.concat (error, results...) ->
        if error
          go error
        else
          next results, go
    else
      apply go, null, [ null ].concat args

  (args..., go) ->
    next args, go

iterate = (tasks) ->
  _tasks = slice tasks, 0
  _results = []
  next = (go) ->
    task = shift _tasks
    if task
      task (error, result) ->
        if error
          _results.push [ error ]
        else
          _results.push [ null, result ]
        next go
    else
      #XXX should errors be included in arg #1?
      go null, _results

  (go) ->
    next go

deepClone = (obj) ->
  JSON.parse JSON.stringify obj

exception = (message, cause) -> message: message, cause: cause

mapWithKey = (obj, f) ->
  result = []
  for key, value of obj
    result.push f value, key
  result

describeCount = (count, singular, plural) ->
  plural = singular + 's' unless plural
  switch count
    when 0
      "No #{plural}"
    when 1
      "1 #{singular}"
    else
      "#{count} #{plural}"

Flow.Sandbox = (_) ->
  context: {}
  results: {}
  routines: Flow.Routines _

Flow.Application = (_) ->
  _sandbox = Flow.Sandbox _
  _renderers = Flow.Renderers _, _sandbox
  _repl = Flow.Repl _, _renderers

  Flow.H2O _
  Flow.DialogManager _
  
  context: _
  view: _repl

Flow.ApplicationContext = (_) ->
  context$
    ready: do edges$
    requestFileGlob: do edge$
    requestImportFiles: do edge$
    requestParseFiles: do edge$
    requestJob: do edge$
    requestJobs: do edge$
    requestParseSetup: do edge$
    selectCell: do edge$
    insertAndExecuteCell: do edge$

Flow.DialogManager = (_) ->

Flow.HtmlTag = (_, level) ->
  isCode: no
  render: (input, go) ->
    output = 
      text: input.trim() or '(Untitled)'
      template: "flow-#{level}"
    go null, [ [ null , output ] ]

Flow.Markdown = (_) ->
  isCode: no
  render: (input, go) ->
    try
      output =
        html: marked input.trim() or '(No content)'
        template: 'flow-html'
      go null, [ [ null , output ] ]
    catch error
      go error

Flow.Raw = (_) ->
  isCode: no
  render: (input, go) ->
    output =
      text: input
      template: 'flow-raw'
    go null, [ [ null , output ] ]

objectToHtmlTable = (obj) ->
  if obj is undefined
    '(undefined)'
  else if obj is null
    '(null)'
  else if isString obj
    if obj
      obj
    else
      '(Empty string)'
  else if isArray obj
    html = ''
    for value, i in obj
      html += "<tr><td>#{i + 1}</td><td>#{objectToHtmlTable value}</td></tr>"
    if html
      "<table class='table table-striped table-condensed'>#{html}</table>"
    else
      '(Empty array)'
  else if isObject obj
    html = ''
    for key, value of obj
      html += "<tr><td>#{key}</td><td>#{objectToHtmlTable value}</td></tr>"
    if html
      "<table class='table table-striped table-condensed'>#{html}</table>"
    else
      '(Empty object)'
  else
    obj

Flow.ImportFilesOutput = (_, importResults) ->
  _allKeys = flatten compact map importResults, ( [ error, result ] ) ->
    if error then null else result.keys
  _canParse = _allKeys.length > 0
  _title = "#{_allKeys.length} / #{importResults.length} files imported."

  createImportView = (result) ->
    #TODO dels?
    #TODO fails?

    keys: result.keys
    template: 'flow-import-file-output'

  _importViews = map importResults, ( [error, result] ) ->
    if error
      #XXX untested
      error:
        message: 'Error importing file'
        cause: error
      template: 'flow-error'
    else
      createImportView result

  parse = ->
    paths = map _allKeys, javascriptString
    _.insertAndExecuteCell 'cs', "setupParse [ #{paths.join ','} ]"

  title: _title
  importViews: _importViews
  canParse: _canParse
  parse: parse
  template: 'flow-import-files-output'
  templateOf: templateOf


Flow.JobsOutput = (_, jobs) ->
  _jobViews = nodes$ []
  _hasJobViews = lift$ _jobViews, (jobViews) -> jobViews.length > 0
  _isLive = node$ no
  _isBusy = node$ no
  _exception = node$ null

  createJobView = (job) ->
    inspect = ->
      _.insertAndExecuteCell 'cs', "job #{javascriptString job.key.name}" 

    job: job
    inspect: inspect

  toggleRefresh = ->
    _isLive not _isLive()

  refresh = ->
    _isBusy yes
    _.requestJobs (error, jobs) ->
      _isBusy no
      if error
        _exception exception 'Error fetching jobs', error
        _isLive no
      else
        _jobViews map jobs, createJobView
        delay refresh, 2000 if _isLive()

  apply$ _isLive, (isLive) ->
    refresh() if isLive

  initialize = ->
    _jobViews map jobs, createJobView

  initialize()

  jobViews: _jobViews
  hasJobViews: _hasJobViews
  isLive: _isLive
  isBusy: _isBusy
  toggleRefresh: toggleRefresh
  refresh: refresh
  exception: _exception
  template: 'flow-jobs'

Flow.JobOutput = (_, job) ->
  _exception = node$ null

  createJobView = (job) ->
    job: job

  jobView: createJobView job
  exception: _exception
  template: 'flow-job'

parserTypes = map [ 'AUTO', 'XLS', 'CSV', 'SVMLight' ], (type) -> type: type, caption: type

parseDelimiters = do ->
  whitespaceSeparators = [
    'NULL'
    'SOH (start of heading)'
    'STX (start of text)'
    'ETX (end of text)'
    'EOT (end of transmission)'
    'ENQ (enquiry)'
    'ACK (acknowledge)'
    "BEL '\\a' (bell)"
    "BS  '\\b' (backspace)"
    "HT  '\\t' (horizontal tab)"
    "LF  '\\n' (new line)"
    "VT  '\\v' (vertical tab)"
    "FF  '\\f' (form feed)"
    "CR  '\\r' (carriage ret)"
    'SO  (shift out)'
    'SI  (shift in)'
    'DLE (data link escape)'
    'DC1 (device control 1) '
    'DC2 (device control 2)'
    'DC3 (device control 3)'
    'DC4 (device control 4)'
    'NAK (negative ack.)'
    'SYN (synchronous idle)'
    'ETB (end of trans. blk)'
    'CAN (cancel)'
    'EM  (end of medium)'
    'SUB (substitute)'
    'ESC (escape)'
    'FS  (file separator)'
    'GS  (group separator)'
    'RS  (record separator)'
    'US  (unit separator)'
    "' ' SPACE"
  ]

  createDelimiter = (caption, charCode) ->
    charCode: charCode
    caption: "#{caption}: '#{('00' + charCode).slice(-2)}'"

  whitespaceDelimiters = map whitespaceSeparators, createDelimiter

  characterDelimiters = times (126 - whitespaceSeparators.length), (i) ->
    charCode = i + whitespaceSeparators.length
    createDelimiter (String.fromCharCode charCode), charCode

  otherDelimiters = [ charCode: -1, caption: 'AUTO' ]

  concat whitespaceDelimiters, characterDelimiters, otherDelimiters

Flow.SetupParseOutput = (_, _result) ->
  _sourceKeys = map _result.srcs, (src) -> src.name
  _parserType =  node$ find parserTypes, (parserType) -> parserType.type is _result.pType
  _delimiter = node$ find parseDelimiters, (delimiter) -> delimiter.charCode is _result.sep 
  _useSingleQuotes = node$ _result.singleQuotes
  _columns = map _result.columnNames, (name) -> name: node$ name
  _rows = _result.data
  _columnCount = _result.ncols
  _hasColumns = _columnCount > 0
  _destinationKey = node$ _result.hexName
  _headerOptions = auto: 0, header: 1, data: -1
  _headerOption = node$ if _result.checkHeader is 0 then 'auto' else if _result.checkHeader is -1 then 'data' else 'header'
  _deleteOnDone = node$ yes

  parseFiles = ->
    sourceKeys = map _parsedFiles(), (file) -> file.name
    columnNames = map _columns(), (column) -> column.name()
    _.requestParseFiles sourceKeys, _destinationKey(), _parserType().type, _delimiter().charCode, _columnCount(), _useSingleQuotes(), columnNames, _deleteOnDone(), _headerOptions[_headerOption()], (error, result) -> 
      if error
        #TODO handle this properly
        _.fail 'Error', error, null, noop
      else
        _go 'confirm', result.job

  sourceKeys: _sourceKeys
  parserTypes: parserTypes
  delimiters: parseDelimiters
  parserType: _parserType
  delimiter: _delimiter
  useSingleQuotes: _useSingleQuotes
  columns: _columns
  rows: _rows
  columnCount: _columnCount
  hasColumns: _hasColumns
  destinationKey: _destinationKey
  headerOption: _headerOption
  deleteOnDone: _deleteOnDone
  parseFiles: parseFiles
  template: 'flow-parse-raw-input'

Flow.ImportFilesInput = (_) ->
  #
  # Search files/dirs
  #
  _specifiedPath = node$ ''
  _exception = node$ ''
  _hasErrorMessage = lift$ _exception, (exception) -> if exception then yes else no

  tryImportFiles = ->
    specifiedPath = _specifiedPath()
    _.requestFileGlob specifiedPath, 0, (error, result) ->
      if error
        _exception error.data.errmsg
      else
        _exception ''
        #_go 'confirm', result
        processImportResult result

  #
  # File selection 
  #
  _importedFiles = nodes$ []
  _importedFileCount = lift$ _importedFiles, (files) -> "Found #{describeCount files.length, 'file'}."
  _hasImportedFiles = lift$ _importedFiles, (files) -> files.length > 0
  _hasUnselectedFiles = lift$ _importedFiles, (files) -> some files, (file) -> not file.isSelected()
  _selectedFiles = nodes$ []
  _selectedFilesDictionary = lift$ _selectedFiles, (files) ->
    dictionary = {}
    for file in files
      dictionary[file.path] = yes
    dictionary
  _selectedFileCount = lift$ _selectedFiles, (files) -> "#{describeCount files.length, 'file'} selected."
  _hasSelectedFiles = lift$ _selectedFiles, (files) -> files.length > 0

  importFiles = (files) ->
    paths = map files, (file) -> javascriptString file.path
    _.insertAndExecuteCell 'cs', "importFiles [ #{ paths.join ',' } ]"

  importSelectedFiles = -> importFiles _selectedFiles()

  createSelectedFileItem = (path) ->
    self =
      path: path
      deselect: ->
        _selectedFiles.remove self
        for file in _importedFiles() when file.path is path
          file.isSelected no
        return

  createFileItem = (path, isSelected) ->
    self =
      path: path
      isSelected: node$ isSelected
      select: ->
        _selectedFiles.push createSelectedFileItem self.path
        self.isSelected yes 

    apply$ self.isSelected, (isSelected) ->
      _hasUnselectedFiles some _importedFiles(), (file) -> not file.isSelected()

    self

  createFileItems = (result) ->
    map result.matches, (path) ->
      createFileItem path, _selectedFilesDictionary()[path]

  listPathHints = (query, process) ->
    _.requestFileGlob query, 10, (error, result) ->
      unless error
        process map result.matches, (value) -> value: value

  selectAllFiles = ->
    _selectedFiles map _importedFiles(), (file) ->
      createSelectedFileItem file.path
    for file in _importedFiles()
      file.isSelected yes
    return

  deselectAllFiles = ->
    _selectedFiles []
    for file in _importedFiles()
      file.isSelected no
    return
  
  processImportResult = (result) -> 
    files = createFileItems result
    _importedFiles files

  specifiedPath: _specifiedPath
  hasErrorMessage: _hasErrorMessage #XXX obsolete
  exception: _exception
  tryImportFiles: tryImportFiles
  listPathHints: throttle listPathHints, 100
  hasImportedFiles: _hasImportedFiles
  importedFiles: _importedFiles
  importedFileCount: _importedFileCount
  selectedFiles: _selectedFiles
  selectAllFiles: selectAllFiles
  deselectAllFiles: deselectAllFiles
  hasUnselectedFiles: _hasUnselectedFiles
  hasSelectedFiles: _hasSelectedFiles
  selectedFileCount: _selectedFileCount
  importSelectedFiles: importSelectedFiles
  template: 'flow-import-files'

Flow.H2O = (_) ->
  createResponse = (status, data, xhr) ->
    status: status, data: data, xhr: xhr

  handleResponse = (go, jqxhr) ->
    jqxhr
      .done (data, status, xhr) ->
        go null, createResponse status, data, xhr
      .fail (xhr, status, error) ->
        go createResponse status, xhr.responseJSON, xhr

  h2oGet = (path, go) ->
    handleResponse go, $.getJSON path

  h2oPost = (path, opts, go) ->
    handleResponse go, $.post path, opts

  processResponse = (go) ->
    (error, result) ->
      if error
        #TODO error logging / retries, etc.
        go error, result
      else
        if result.data.response?.status is 'error'
          go result.data.error, result.data
        else
          go error, result.data

  request = (path, go) ->
    h2oGet path, processResponse go

  post = (path, opts, go) ->
    h2oPost path, opts, processResponse go

  composePath = (path, opts) ->
    if opts
      params = mapWithKey opts, (v, k) -> "#{k}=#{v}"
      path + '?' + join params, '&'
    else
      path

  requestWithOpts = (path, opts, go) ->
    request (composePath path, opts), go

  requestJobs = (go) ->
    request '/Jobs.json', (error, result) ->
      if error
        go exception 'Error fetching jobs', error
      else
        go null, result.jobs 

  requestJob = (key, go) ->
    #opts = key: encodeURIComponent key
    #requestWithOpts '/Job.json', opts, go
    request "/Jobs.json/#{encodeURIComponent key}", (error, result) ->
      if error
        go exception "Error fetching job '#{key}'", error
      else
        go null, head result.jobs

  requestFileGlob = (path, limit, go) ->
    opts =
      src: encodeURIComponent path
      limit: limit
    requestWithOpts '/Typeahead.json/files', opts, go

  requestImportFile = (path, go) ->
    opts = path: encodeURIComponent path
    requestWithOpts '/ImportFiles.json', opts, go

  requestImportFiles = (paths, go) ->
    tasks = map paths, (path) ->
      (go) ->
        requestImportFile path, go
    (iterate tasks) go

  requestParseSetup = (sources, go) ->
    encodedPaths = map sources, encodeURIComponent
    opts =
      srcs: "[#{join encodedPaths, ','}]"
    requestWithOpts '/ParseSetup.json', opts, go

  encodeArray = (array) -> "[#{join (map array, encodeURIComponent), ','}]"

  requestParseFiles = (sourceKeys, destinationKey, parserType, separator, columnCount, useSingleQuotes, columnNames, deleteOnDone, checkHeader, go) ->
    opts =
      hex: encodeURIComponent destinationKey
      srcs: encodeArray sourceKeys
      pType: parserType
      sep: separator
      ncols: columnCount
      singleQuotes: useSingleQuotes
      columnNames: encodeArray columnNames
      checkHeader: checkHeader
      delete_on_done: deleteOnDone
    requestWithOpts '/Parse.json', opts, go

  link$ _.requestFileGlob, requestFileGlob
  link$ _.requestImportFiles, requestImportFiles
  link$ _.requestParseSetup, requestParseSetup
  link$ _.requestParseFiles, requestParseFiles
  link$ _.requestJobs, requestJobs
  link$ _.requestJob, requestJob

_fork = (f, args) ->
  self = (go) ->
    if self.settled
      # proceed with cached error/result
      if self.rejected
        go self.error
      else
        go null, self.result
    else
      _join args, (error, args) ->
        apply f, null,
          args.concat (error, result) ->
            if error
              self.error = error
              self.fulfilled = no
              self.rejected = yes
              go error
            else
              self.result = result
              self.fulfilled = yes
              self.rejected = no
              go null, result
            self.settled = yes
            self.pending = no

  self.method = f
  self.args = args
  self.fulfilled = no
  self.rejected = no
  self.settled = no
  self.pending = yes

  self.isFuture = yes

  self

fork = (f, args...) -> _fork f, args

_join = (args, go) ->
  return go null, [] if args.length is 0

  _tasks = [] 
  _results = []

  for arg, i in args
    if arg?.isFuture
      _tasks.push future: arg, resultIndex: i
    else
      _results[i] = arg

  return go null, _results if _tasks.length is 0

  _actual = 0
  _settled = no

  forEach _tasks, (task) ->
    call task.future, null, (error, result) ->
      return if _settled
      if error
        _settled = yes
        go exception "Error evalutating future[#{task.resultIndex}]", error
      else
        _results[task.resultIndex] = result
        _actual++
        if _actual is _tasks.length
          _settled = yes
          go null, _results
      return
  return

noopFuture = (go) -> go null

renderable = (f, args..., render) ->
  ft = _fork f, args
  ft.render = render
  ft

Flow.Routines = (_) ->

  renderJobs = (jobs, go) ->
    go null, Flow.JobsOutput _, jobs    

  renderJob = (job, go) ->
    go null, Flow.JobOutput _, job

  renderImportFiles = (importResults, go) ->
    go null, Flow.ImportFilesOutput _, importResults

  renderSetupParse = (parseSetupResults, go) ->
    go null, Flow.SetupParseOutput _, parseSetupResults

  frames = (arg) ->

  frame = (arg) ->

  models = (arg) ->

  model = (arg) ->

  jobs = ->
    renderable _.requestJobs, renderJobs

  job = (arg) ->
    switch typeOf arg
      when 'string'
        renderable _.requestJob, arg, renderJob
      when 'object'
        if arg.key?
          job arg.key
        else
          #XXX print usage
          throw new Error 'ni'
      else
        #XXX print usage
        throw new Error 'ni'

  importFiles = (paths) ->
    renderable _.requestImportFiles, paths, renderImportFiles

  setupParse = (sourceKeys) ->
    renderable _.requestParseSetup, sourceKeys, renderSetupParse

  parseRaw = (opts) -> #XXX review args
    requestParseFiles sourceKeys, destinationKey, parserType, separator, columnCount, useSingleQuotes, columnNames, deleteOnDone, checkHeader, (error, result) ->


  ###
  getUsageForFunction = (f) ->
    switch f
      when help
        name: 'help'
        examples: []
        description: 'Display help on a topic or function.'
        syntax: [
          'help topic'
          'help function'
        ]
        parameters: [
          'rgb': 'Number: foo'
        ]
        returns: 'HelpTopic: The help topic'
        related: null
      when jobs

      when job

      else
        null

  help = (arg) ->
    switch typeOf arg
      when 'undefined'

      when 'string'

      when 'function'

      else
  ###

  fork: fork
  join: (args..., go) -> _join args, go
  call: (go, args...) -> _join args, go
  apply: (go, args) -> _join args, go
  jobs: jobs
  job: job
  importFiles: importFiles
  setupParse: setupParse
  parseRaw: parseRaw

safetyWrapCoffeescript = (guid) ->
  (cs, go) ->
    lines = cs
      # normalize CR/LF
      .replace /[\n\r]/g, '\n'
      # split into lines
      .split '\n'

    # indent once
    block = map lines, (line) -> '  ' + line

    # enclose in execute-immediate closure
    block.unshift "_h2o_results_['#{guid}'].implicits.push do ->"

    # join and proceed
    go null, join block, '\n'

compileCoffeescript = (cs, go) ->
  try
    go null, CoffeeScript.compile cs, bare: yes
  catch error
    go exception 'Error compiling coffee-script', error

parseJavascript = (js, go) ->
  try
    go null, esprima.parse js
  catch error
    go exception 'Error parsing javascript expression', error


identifyDeclarations = (node) ->
  return null unless node

  switch node.type
    when 'VariableDeclaration'
      return (name: declaration.id.name, object:'_h2o_context_' for declaration in node.declarations when declaration.type is 'VariableDeclarator' and declaration.id.type is 'Identifier')
        
    when 'FunctionDeclaration'
      #
      # XXX Not sure about the semantics here.
      #
      if node.id.type is 'Identifier'
        return [ name: node.id.name, object: '_h2o_context_' ]
    when 'ForStatement'
      return identifyDeclarations node.init
    when 'ForInStatement', 'ForOfStatement'
      return identifyDeclarations node.left
  return null

parseDeclarations = (block) ->
  identifiers = []
  for node in block.body
    if declarations = identifyDeclarations node
      for declaration in declarations
        identifiers.push declaration
  indexBy identifiers, (identifier) -> identifier.name

traverseJavascript = (parent, key, node, f) ->
  if isArray node
    i = node.length
    # walk backwards to allow callers to delete nodes
    while i--
      child = node[i]
      if isObject child
        traverseJavascript node, i, child, f
        f node, i, child
  else 
    for i, child of node
      if isObject child
        traverseJavascript node, i, child, f
        f node, i, child
  return

deleteAstNode = (parent, i) ->
  if _.isArray parent
    parent.splice i, 1
  else if isObject parent
    delete parent[i]

createLocalScope = (node) ->
  # parse all declarations in this scope
  localScope = parseDeclarations node.body

  # include formal parameters
  for param in node.params when param.type is 'Identifier'
    localScope[param.name] = name: param.name, object: 'local'

  localScope

# redefine scope by coalescing down to non-local identifiers
coalesceScopes = (scopes) ->
  currentScope = {}
  for scope, i in scopes
    if i is 0
      for name, identifier of scope
        currentScope[name] = identifier
    else
      for name, identifier of scope
        currentScope[name] = null
  currentScope

traverseJavascriptScoped = (scopes, parentScope, parent, key, node, f) ->
  isNewScope = node.type is 'FunctionExpression' or node.type is 'FunctionDeclaration'
  if isNewScope
    # create and push a new local scope onto scope stack
    push scopes, createLocalScope node
    currentScope = coalesceScopes scopes
  else
    currentScope = parentScope

  for key, child of node
    if isObject child
      traverseJavascriptScoped scopes, currentScope, node, key, child, f
      f currentScope, node, key, child 

  if isNewScope
    # discard local scope
    pop scopes

  return

createRootScope = (sandbox) ->
  (program, go) ->
    try
      rootScope = parseDeclarations program.body[0].expression.arguments[0].callee.body

      for name of sandbox.context
        rootScope[name] =
          name: name
          object: '_h2o_context_'
      go null, rootScope, program

    catch error
      go exception 'Error parsing root scope', error

#TODO DO NOT call this for raw javascript:
# Require alternate strategy: 
#   Declarations with 'var' need to be local to the cell.
#   Undeclared identifiers are assumed to be global.
#   'use strict' should be unsupported.
removeHoistedDeclarations = (rootScope, program, go) ->
  try
    traverseJavascript null, null, program, (parent, key, node) ->
      if node.type is 'VariableDeclaration'		
        declarations = node.declarations.filter (declaration) ->		
          declaration.type is 'VariableDeclarator' and declaration.id.type is 'Identifier' and not rootScope[declaration.id.name]		
        if declarations.length is 0
          # purge this node so that escodegen doesn't fail		
          deleteAstNode parent, key		
        else		
          # replace with cleaned-up declarations
          node.declarations = declarations
    go null, rootScope, program
  catch error
    go exception 'Error rewriting javascript', error


createGlobalScope = (rootScope, routines) ->
  globalScope = {}

  for name, identifier of rootScope
    globalScope[name] = identifier

  for name of routines
    globalScope[name] = name: name, object: 'h2o'

  globalScope

rewriteJavascript = (sandbox) ->
  (rootScope, program, go) ->
    globalScope = createGlobalScope rootScope, sandbox.routines 

    try
      traverseJavascriptScoped [ globalScope ], globalScope, null, null, program, (globalScope, parent, key, node) ->
        if node.type is 'Identifier'
          return if parent.type is 'VariableDeclarator' and key is 'id' # ignore var declarations
          return if key is 'property' # ignore members
          return unless identifier = globalScope[node.name]

          # qualify identifier with '_h2o_context_'
          parent[key] =
            type: 'MemberExpression'
            computed: no
            object:
              type: 'Identifier'
              name: identifier.object
            property:
              type: 'Identifier'
              name: identifier.name
      go null, program
    catch error
      go exception 'Error rewriting javascript', error

javascriptString = (string) -> JSON.stringify string

generateJavascript = (program, go) ->
  try
    go null, escodegen.generate program
  catch error
    return go exception 'Error generating javascript', error

compileJavascript = (js, go) ->
  try
    closure = new Function 'h2o', '_h2o_context_', '_h2o_results_', 'show', js
    go null, closure
  catch error
    go exception 'Error compiling javascript', error

executeJavascript = (sandbox, show) ->
  (closure, go) ->
    try
      go null, closure sandbox.routines, sandbox.context, sandbox.results, show
    catch error
      go exception 'Error executing javascript', error

assist = (_, routines, routine) ->
  switch routine
    when routines.importFiles
      renderable noopFuture, (ignore, go) ->
        go null, Flow.ImportFilesInput _
    else
      console.error 'NO ASSIST DEFINED'
      renderable noopFuture, (go) ->
        go message: 'what?', error: new Error()

Flow.Coffeescript = (_, guid, sandbox) ->
  show = (arg) ->
    if arg isnt show
      sandbox.results[guid].explicits.push arg
    show

  render = (ft) -> (go) ->
    if ft?.isFuture
      ft (error, result) ->
        if error
          go exception 'Error evaluating cell', error
        else
          if ft.render
            ft.render result, (error, result) ->
              if error
                go exception 'Error rendering cell output', error
              else
                go null, result 
          else if ft.print
            go null,
              text: ft.print result #TODO implement chrome dev tools style JSON inspector
              template: 'flow-raw'
          else
            #XXX pick smarter renderers based on content
            go null,
              text: ft
              template: 'flow-raw'
    else
      go null,
        text: ft
        template: 'flow-raw'

  pickResults = (results) ->
    { implicits, explicits } = results
    if explicits.length
      return explicits
    else
      implicit = head implicits
      if isFunction implicit
        for name, routine of sandbox.routines
          if implicit is routine
            show assist _, sandbox.routines, routine
            return explicits
      return implicits

  isCode: yes
  render: (input, go) ->
    sandbox.results[guid] = implicits: [], explicits: []
    tasks = [
      safetyWrapCoffeescript guid
      compileCoffeescript
      parseJavascript
      createRootScope sandbox
      removeHoistedDeclarations
      rewriteJavascript sandbox
      generateJavascript
      compileJavascript
      executeJavascript sandbox, show
    ]
    (pipe tasks) input, (error, result) ->
      if error
        go error
      else
        tasks = map (pickResults sandbox.results[guid]), render
        (iterate tasks) go

Flow.Renderers = (_, _sandbox) ->
  h1: -> Flow.HtmlTag _, 'h1'
  h2: -> Flow.HtmlTag _, 'h2'
  h3: -> Flow.HtmlTag _, 'h3'
  h4: -> Flow.HtmlTag _, 'h4'
  h5: -> Flow.HtmlTag _, 'h5'
  h6: -> Flow.HtmlTag _, 'h6'
  md: -> Flow.Markdown _
  cs: (guid) -> Flow.Coffeescript _, guid, _sandbox
  raw: -> Flow.Raw _

Flow.Cell = (_, _renderers, type='cs', input='') ->
  _guid = do uniqueId
  _type = node$ type
  _renderer = lift$ _type, (type) -> _renderers[type] _guid
  _isSelected = node$ no
  _isActive = node$ no
  _hasError = node$ no
  _isBusy = node$ no
  _isReady = lift$ _isBusy, (isBusy) -> not isBusy
  _hasInput = node$ yes
  _input = node$ input
  _outputs = nodes$ []
  _hasOutput = lift$ _outputs, (outputs) -> outputs.length > 0
  _isOutputVisible = node$ yes
  _isOutputHidden = lift$ _isOutputVisible, (visible) -> not visible

  # This is a shim.
  # The ko 'cursorPosition' custom binding attaches a read() method to this.
  _cursorPosition = {}

  # select and display input when activated
  apply$ _isActive, (isActive) ->
    if isActive
      _.selectCell self
      _hasInput yes
      _outputs [] unless _renderer().isCode
    return

  # deactivate when deselected
  apply$ _isSelected, (isSelected) ->
    _isActive no unless isSelected

  # tied to mouse-clicks on the cell
  select = ->
    _.selectCell self
    return yes # Explicity return true, otherwise KO will prevent the mouseclick event from bubbling up

  # tied to mouse-double-clicks on html content
  # TODO
  activate = -> _isActive yes

  execute = (go) ->
    input = _input().trim()
    unless input
      if go
        return go null
      else
        return

    renderer = _renderer()
    _isBusy yes
    renderer.render input, (error, results) ->
      if error
        _hasError yes
        if error.cause?
          _outputs [
            error: error
            template: 'flow-error'
          ]
        else
          _outputs [
            text: JSON.stringify error, null, 2
            template: 'flow-raw'
          ]
      else
        _hasError no
        outputs = for [ error, result ] in results
          if error
            _hasError yes
            error
          else
            result

        _outputs outputs
        _hasInput renderer.isCode

      _isBusy no
      go _hasError() if go

    _isActive no

  self =
    guid: _guid
    type: _type
    isSelected: _isSelected
    isActive: _isActive
    hasError: _hasError
    isBusy: _isBusy
    isReady: _isReady
    input: _input
    hasInput: _hasInput
    outputs: _outputs
    hasOutput: _hasOutput
    isOutputVisible: _isOutputVisible
    toggleOutput: -> _isOutputVisible not _isOutputVisible()
    showOutput: -> _isOutputVisible yes
    hideOutput: -> _isOutputVisible no
    select: select
    activate: activate
    execute: execute
    _cursorPosition: _cursorPosition
    cursorPosition: -> _cursorPosition.read()
    templateOf: templateOf
    template: 'flow-cell'

Flow.Repl = (_, _renderers) ->
  _cells = nodes$ []
  _selectedCell = null
  _selectedCellIndex = -1
  _clipboardCell = null
  _lastDeletedCell = null

  createCell = (type='cs', input='') ->
    Flow.Cell _, _renderers, type, input

  checkConsistency = ->
    for cell, i in _cells()
      unless cell
        error "index #{i} is empty"
    return

  selectCell = (target) ->
    return if _selectedCell is target
    _selectedCell.isSelected no if _selectedCell
    _selectedCell = target
    #TODO also set focus so that tabs don't jump to the first cell
    _selectedCell.isSelected yes
    _selectedCellIndex = _cells.indexOf _selectedCell
    checkConsistency()
    _selectedCell

  cloneCell = (cell) ->
    createCell cell.type(), cell.input()

  switchToCommandMode = ->
    _selectedCell.isActive no

  switchToEditMode = ->
    _selectedCell.isActive yes
    no

  convertCellToCode = ->
    _selectedCell.type 'cs'

  convertCellToHeading = (level) -> -> 
    _selectedCell.type "h#{level}"
    _selectedCell.execute()

  convertCellToMarkdown = ->
    _selectedCell.type 'md'
    _selectedCell.execute()

  convertCellToRaw = ->
    _selectedCell.type 'raw'
    _selectedCell.execute()

  copyCell = ->
    _clipboardCell = cloneCell _selectedCell

  cutCell = ->
    _clipboardCell = _selectedCell
    removeCell()

  deleteCell = ->
    _lastDeletedCell = _selectedCell
    removeCell()

  removeCell = ->
    cells = _cells()
    if cells.length > 1
      if _selectedCellIndex is cells.length - 1
        #TODO call dispose() on this cell
        splice _cells, _selectedCellIndex, 1
        selectCell cells[_selectedCellIndex - 1]
      else
        #TODO call dispose() on this cell
        splice _cells, _selectedCellIndex, 1
        selectCell cells[_selectedCellIndex]
    return
    
  insertCell = (index, cell) ->
    splice _cells, index, 0, cell
    selectCell cell
    cell

  insertCellAbove = (cell) ->
    insertCell _selectedCellIndex, cell

  insertCellBelow = (cell) ->
    insertCell _selectedCellIndex + 1, cell

  insertNewCellAbove = ->
    insertCellAbove createCell 'cs'

  insertNewCellBelow = ->
    insertCellBelow createCell 'cs'

  insertCellBelowAndRun = (type, input) ->
    cell = insertCellBelow createCell type, input
    cell.execute()

  moveCellDown = ->
    cells = _cells()
    unless _selectedCellIndex is cells.length - 1
      splice _cells, _selectedCellIndex, 1
      _selectedCellIndex++
      splice _cells, _selectedCellIndex, 0, _selectedCell
    return

  moveCellUp = ->
    unless _selectedCellIndex is 0
      cells = _cells()
      splice _cells, _selectedCellIndex, 1
      _selectedCellIndex--
      splice _cells, _selectedCellIndex, 0, _selectedCell
    return

  mergeCellBelow = ->
    cells = _cells()
    unless _selectedCellIndex is cells.length - 1
      nextCell = cells[_selectedCellIndex + 1]
      if _selectedCell.type() is nextCell.type()
        nextCell.input _selectedCell.input() + '\n' + nextCell.input()
        removeCell()
    return

  splitCell = ->
    if _selectedCell.isActive()
      input = _selectedCell.input()
      if input.length > 1
        cursorPosition = _selectedCell.cursorPosition()
        if 0 < cursorPosition < input.length - 1
          left = substr input, 0, cursorPosition
          right = substr input, cursorPosition
          _selectedCell.input left
          insertCell _selectedCellIndex + 1, createCell 'cs', right
          _selectedCell.isActive yes
    return

  pasteCellAbove = ->
    insertCell _selectedCellIndex, _clipboardCell if _clipboardCell

  pasteCellBelow = ->
    insertCell _selectedCellIndex + 1, _clipboardCell if _clipboardCell

  undoLastDelete = ->
    insertCell _selectedCellIndex + 1, _lastDeletedCell if _lastDeletedCell
    _lastDeletedCell = null

  runCell = ->
    _selectedCell.execute()
    no

  runCellAndInsertBelow = ->
    _selectedCell.execute -> insertNewCellBelow()
    no

  #TODO ipython has inconsistent behavior here. seems to be doing runCellAndInsertBelow if executed on the lowermost cell.
  runCellAndSelectBelow = ->
    _selectedCell.execute -> selectNextCell()
    no

  saveFlow = ->
    debug 'saveFlow'
    no

  toggleOutput = ->
    _selectedCell.toggleOutput()

  selectNextCell = ->
    cells = _cells()
    unless _selectedCellIndex is cells.length - 1
      selectCell cells[_selectedCellIndex + 1]
    return

  selectPreviousCell = ->
    unless _selectedCellIndex is 0
      cells = _cells()
      selectCell cells[_selectedCellIndex - 1]
    return

  displayHelp = -> debug 'displayHelp'

  # (From IPython Notebook keyboard shortcuts dialog)
  # The IPython Notebook has two different keyboard input modes. Edit mode allows you to type code/text into a cell and is indicated by a green cell border. Command mode binds the keyboard to notebook level actions and is indicated by a grey cell border.
  # 
  # Command Mode (press Esc to enable)
  # 
  normalModeKeyboardShortcuts = [
    [ 'enter', 'edit mode', switchToEditMode ]
    #[ 'shift+enter', 'run cell, select below', runCellAndSelectBelow ]
    #[ 'ctrl+enter', 'run cell', runCell ]
    #[ 'alt+enter', 'run cell, insert below', runCellAndInsertBelow ]
    [ 'y', 'to code', convertCellToCode ]
    [ 'm', 'to markdown', convertCellToMarkdown ]
    [ 'r', 'to raw', convertCellToRaw ]
    [ '1', 'to heading 1', convertCellToHeading 1 ]
    [ '2', 'to heading 2', convertCellToHeading 2 ]
    [ '3', 'to heading 3', convertCellToHeading 3 ]
    [ '4', 'to heading 4', convertCellToHeading 4 ]
    [ '5', 'to heading 5', convertCellToHeading 5 ]
    [ '6', 'to heading 6', convertCellToHeading 6 ]
    [ 'up', 'select previous cell', selectPreviousCell ]
    [ 'down', 'select next cell', selectNextCell ]
    [ 'k', 'select previous cell', selectPreviousCell ]
    [ 'j', 'select next cell', selectNextCell ]
    [ 'ctrl+k', 'move cell up', moveCellUp ]
    [ 'ctrl+j', 'move cell down', moveCellDown ]
    [ 'a', 'insert cell above', insertNewCellAbove ]
    [ 'b', 'insert cell below', insertNewCellBelow ]
    [ 'x', 'cut cell', cutCell ]
    [ 'c', 'copy cell', copyCell ]
    [ 'shift+v', 'paste cell above', pasteCellAbove ]
    [ 'v', 'paste cell below', pasteCellBelow ]
    [ 'z', 'undo last delete', undoLastDelete ]
    [ 'd d', 'delete cell (press twice)', deleteCell ]
    [ 'shift+m', 'merge cell below', mergeCellBelow ]
    [ 's', 'save notebook', saveFlow ]
    #[ 'mod+s', 'save notebook', saveFlow ]
    # [ 'l', 'toggle line numbers' ]
    [ 'o', 'toggle output', toggleOutput ]
    # [ 'shift+o', 'toggle output scrolling' ]
    # [ 'q', 'close pager' ]
    [ 'h', 'keyboard shortcuts', displayHelp ]
    # [ 'i', 'interrupt kernel (press twice)' ]
    # [ '0', 'restart kernel (press twice)' ]
  ] 

  # 
  # Edit Mode (press Enter to enable) 
  # 
  editModeKeyboardShortcuts = [
    # Tab : code completion or indent
    # Shift-Tab : tooltip
    # Cmd-] : indent
    # Cmd-[ : dedent
    # Cmd-a : select all
    # Cmd-z : undo
    # Cmd-Shift-z : redo
    # Cmd-y : redo
    # Cmd-Up : go to cell start
    # Cmd-Down : go to cell end
    # Opt-Left : go one word left
    # Opt-Right : go one word right
    # Opt-Backspace : del word before
    # Opt-Delete : del word after
    [ 'esc', 'command mode', switchToCommandMode ]
    [ 'ctrl+m', 'command mode', switchToCommandMode ]
    [ 'shift+enter', 'run cell, select below', runCellAndSelectBelow ]
    [ 'ctrl+enter', 'run cell', runCell ]
    [ 'alt+enter', 'run cell, insert below', runCellAndInsertBelow ]
    [ 'ctrl+shift+-', 'split cell', splitCell ]
    [ 'mod+s', 'save notebook', saveFlow ]
  ]

  setupKeyboardHandling = (mode) ->
    for [ shortcut, caption, f ] in normalModeKeyboardShortcuts
      Mousetrap.bind shortcut, f

    for [ shortcut, caption, f ] in editModeKeyboardShortcuts
      Mousetrap.bindGlobal shortcut, f
    return

  initialize = ->
    setupKeyboardHandling 'normal'
    cell = createCell 'cs'
    push _cells, cell
    selectCell cell

    link$ _.selectCell, selectCell
    link$ _.insertAndExecuteCell, insertCellBelowAndRun

  link$ _.ready, initialize

  cells: _cells
  templateOf: templateOf

$ ->
  window.flow = flow = Flow.Application do Flow.ApplicationContext
  ko.applyBindings flow
  flow.context.ready()
  