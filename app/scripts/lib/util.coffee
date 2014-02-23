define (require) ->
  d3 = require 'd3'

  routeIsTarget = (transition, route) ->
    transition.targetName.replace('.index', '') is route.get('routeName')

  next = (options, selection, offset) ->
    fn = () ->
      opts = @get options
      i = opts.indexOf @get selection
      opts[i + offset]
    fn.property(options, selection)

  sortIssues = (a, b) ->
    [y, m, d] = a.split('-').map((d) -> parseInt(d, 10))
    [_y, _m, _d] = b.split('-').map((d) -> parseInt(d, 10))
    d3.ascending(y, _y) or d3.ascending(m, _m) or d3.ascending(d, _d)

  emptyParamsGetter = () -> []

  read = (path, paramsGetter=emptyParamsGetter) -> (opts={}) ->
    if @_cancelRead then @_cancelRead()
    read = new Ember.RSVP.Promise (resolve, reject) =>
      @set 'isLoading', true
      @_cancelRead = reject
      pathParams = paramsGetter.call @, opts
      if pathParams is null then return
      endpoint = path.fmt.apply path, pathParams
      $.getJSON(endpoint, opts).then(
        (content) =>
          @_cancelRead = null
          if not ((content.status_code or 200) in [200, 201]) then reject content
          resolve content.data
          @set 'isLoading', false
        (error) =>
          @set 'isLoading', false
          @_cancelRead = null
          reject error
      )

  bySectionGetter = (params, opts) ->
    {issue, section} = @get('controllers.browse')
      .getProperties(['issue', 'section'])
    [issue, section]

  index = (rootName, childName, data) ->
    sorts =
      section: d3.ascending
      issue: sortIssues
    options = Ember.keys(data).sort sorts[rootName]
    focus = (key) ->
      name: rootName
      rootOptions: options
      childOptions: data[key].sort sorts[childName]
      value: key
      next: options[options.indexOf(key) + 1]
      prev: options[options.indexOf(key) - 1]
      page: (key) -> focus key
    focus options[0]

  select2Query = ({term, callback, page}) ->
    get_options = (opts) ->
      opts.filter((d) ->
        if d.children
          text: d.text, children: get_options d.children
        else
          (d.text or d).toLowerCase().match term
      )
    options = get_options @get('options')
    results = 
      results: options
        .slice((page - 1) * 10, page * 10)
        .map((d) -> if d.text then d else text: d, id: d)
      more: options.length > page * 10
    callback results

  numberPad2 = d3.format('02d')
  wcJsonFile = (params) -> '/static/json/%@-%@-wc.json'.fmt params.year, numberPad2 params.month

  {
    routeIsTarget
    next
    sortIssues
    emptyParamsGetter
    read
    bySectionGetter
    index
    select2Query
    numberPad2
    wcJsonFile
  }
