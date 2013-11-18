define (require) ->
  Ember = require 'ember'
  require 'select2'
  require 'bootstrapCollapse'
  require 'd3'
  _ = require 'lodash'

  # CONSTANTS

  ROOTS = ['section', 'issue']
  SUBJECTS = ['people', 'places', 'organizations', 'keywords']

  # TEMPLATES

  templates = [
    {name: 'index', hbs: require 'text!./templates/index.hbs'}
    {name: 'browse', hbs: require 'text!./templates/browse.hbs'}
    {name: 'browse/section', hbs: require 'text!./templates/section.hbs'}
    {name: 'search', hbs: require 'text!./templates/search.hbs'}

    {name: 'components/token-collector', hbs: require 'text!./templates/components/tokenCollector.hbs'}
    {name: 'components/paged-select2', hbs: require 'text!./templates/components/pagedSelect2.hbs'}
    {name: 'components/loading-spinner', hbs: require 'text!./templates/components/loadingSpinner.hbs'}
  ]

  for {name, hbs} in templates
    Ember.TEMPLATES[name] = Ember.Handlebars.compile hbs

  # UTIL

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

  read = (path, paramsGetter) -> (opts={}) ->
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

  # APPLICATION

  App = Ember.Application.create
    LOG_TRANSITIONS: true

  # ROUTER

  App.Router.map () ->
    @resource 'browse', {path: '/:root/:section/:issue'}, ->
      @route 'section'
    @resource 'search'
    @route 'missing', {path: '/*path'}

  # ROUTES

  # # APPLICATION
  App.ApplicationRoute = Ember.Route.extend

    actions:
      error: (error, transition) ->
        throw error
        # @transitionTo 'content'

  App.IndexRoute = Ember.Route.extend
    afterModel: (m, transition) ->
      if routeIsTarget transition, @
        @transitionTo 'browse'

  # # BROWSE
  App.BrowseRoute = Ember.Route.extend
    model: (params, transition) ->
      controller = @controllerFor 'browse'
      if not (params.root in ROOTS)
        params.root = ROOTS[0]
      controller.set 'root', root = params.root
      rootIndex = controller.get '%@Index'.fmt root
      if not (key = params[root])
        params[root] = (key = rootIndex.rootOptions[0])
      controller.set('index', rootIndex.page key)
      child = controller.get 'alternateRoot'
      if not (key = params[child])
        params[child] = controller.get 'index.childOptions.0'
      controller.setProperties params
      params

    afterModel: (model, transition) ->
      if routeIsTarget(transition, @)
        if model.section and model.issue
          @transitionTo 'browse.section', model

    actions:
      toggleDetails: (d) ->
        @controllerFor('browse').toggleProperty('showDetails')



  # # BROWSE - > SECTION
  App.BrowseSectionRoute = Ember.Route.extend
    model: (params) ->
      @controllerFor('browseSection').read()

    setupController: (controller, model) ->
      @_super(controller, model)
      # consolidate the article entities into one nested select2-ready array.

      prep = (key, arr) ->
        _.unique arr.map (d) ->
          id: JSON.stringify({type: key, text: d})
          text: d

      related = SUBJECTS.map((k) ->
        text: k
        children: prep k, _.flatten model.getEach('related.%@'.fmt k)
      )

      @controllerFor('browse')
        .set('tokenCollectorOptions', related)

  # # SEARCH
  App.SearchRoute = Ember.Route.extend
    model: () ->
      try
        @controllerFor('browse')
          .get('tokenCollectorValue')
      catch e
        # the browse route hasn't been entered yet / thats ok ...
        {}

    setupController: (controller, model) ->
      if Ember.isEmpty(model)
        try
          model = @controllerFor('browse')
            .get('tokenCollectorValue')
        catch e
          model = {}
      @_super(controller, model)

    actions:
      goToSection: (root, issue, section) ->
        model = {root, issue, section}
        browseController = @controllerFor('browse')
        browseController.set 'root', root
        alternateRoot = browseController.get 'alternateRoot'
        browseController.send 'changeFocus', type: root, value: model[root]
        browseController.send 'changeFocus', type: alternateRoot, value: model[alternateRoot]
  # CONTROLLERS

  # # BROWSE
  App.BrowseController = Ember.ObjectController.extend
    index: null
    noTokens: Ember.computed.empty('tokenCollectorValue')
    loadingSpinnerOptions:
      top: '100px'

    showDetails: false

    showDetailsIconClass: (() ->
      'glyphicon-eye-%@'.fmt if @get('showDetails') then 'open' else 'close'
    ).property('showDetails')

    subjects: (() ->
      activeSubjects = @get 'activeSubjects'
      SUBJECTS.map((d) ->
        text: d
        active: d in activeSubjects
      )
    ).property('activeSubjects')

    activeSubjects: null

    init: () ->
      @_super()
      @set 'content', {}
      @set 'activeSubjects', []
      @set 'sectionIndex', index 'section', 'issue',
        JSON.parse require 'text!../json/sections.json'
      @set 'issueIndex', index 'issue', 'section',
        JSON.parse require 'text!../json/issues.json'
      @set 'index', @get 'issueIndex'
      window.z = @

    selectors: (() ->
      index = @get('index')
      if not index then return []
      [
        {
          type: (root = @get 'root')
          options: index.rootOptions
          value: @get root
          next: index.next
          prev: index.prev
        }
        {
          type: (child = @get 'alternateRoot')
          options: index.childOptions
          value: (childVal = @get child)
          next: index.childOptions[(childI = index.childOptions.indexOf childVal) + 1]
          prev: index.childOptions[childI - 1]
        }
      ]
    ).property('content', 'issue', 'section', 'index')

    alternateRoot: (() ->
      root = @get 'root'
      ROOTS.filter((d) -> d isnt root)[0]
    ).property('root')

    actions:
      onEntityQuery: ({term, callback, page}) ->
        get_options = (opts) ->
          opts.filter((d) ->
            if d.children
              text: d.text, children: get_options d.children
            else
              (d.text or d).toLowerCase().match term
          )
        options = get_options @get('tokenCollectorOptions')
        results = 
          results: options
            .slice((page - 1) * 10, page * 10)
          more: options.length > page * 10
        callback results

      changeFocus: ({type, value}) ->
        @set type, value
        if type is @get 'root'
          @set 'index', (index = @get('%@Index'.fmt type).page value)
          if not ((child = @get 'alternateRoot') in index.childOptions)
            @set child, index.childOptions[0]
        @transitionToRoute 'browse.section', @get('content')

      changeSubject: ({text}) ->
        activeSubjects = @get 'activeSubjects'
        wasActive = (d) -> d in activeSubjects
        if wasActive text
          setval = activeSubjects.filter((d) -> d isnt text)
        else
          setval = activeSubjects.concat([text])
        isActive = (d) -> d in setval
        highlighted = (props, d) -> props[d] = isActive d; props
        @set 'activeSubjects', setval
        @setProperties SUBJECTS.reduce highlighted, {}

      updateTokenCollector: (d) ->
        @set 'tokenCollectorValue', d.value



  # # BROWSE - > SECTION
  App.BrowseSectionController = Ember.ArrayController.extend
    needs: ['browse']
    isLoadingBinding: 'controllers.browse.isLoading'
    tokenCollectorValueBinding: 'controllers.browse.tokenCollectorValue'
    showDetailsBinding: 'controllers.browse.showDetails'
    read: read '/v1/articles/%@/%@', bySectionGetter

  # # SEARCH
  App.SearchController = Ember.ObjectController.extend
    read: read '/v1/related-articles', () -> []
    loadingSpinnerOptions:
      top: '100px'

    contentChanged: (() ->
      searchTerms = @get('content').map(JSON.parse, JSON)
      unless Ember.isEmpty searchTerms
        params = d3.nest().key((d) -> d.type).entries(searchTerms)
          .reduce(
            (a, b) ->
              a[b.key] = (a[b.type] or '') + b.values.getEach('text').join(';')
              a
            {}
          )
        @read(params).then((articles) =>
          @set 'articles', d3.nest()
            .key((d) -> d.date)
            .key((d) -> d.subsection)
            .entries(articles)
        )
    ).observes('content')

    searchSuggestionsQuery:
      url: '/v1/suggestions'
      dataType: 'json'
      quitMillis: 500
      cache: true
      data: (term, page) -> {term, page}
      results: (data) ->
        results: data.data
        more: data.more

    actions:
      changeContent: (d) -> @set 'content', d.value

    readSearchSuggestions: read '/v1/suggestions', () -> []

  # VIEWS

  # # APPLICATION
  App.ApplicationView = Ember.View.extend
    didInsertElement: () ->
      @_super()
      @$('footer a').click(() -> $('body').animate(scrollTop: '0'); false)


  # # BROWSE
  App.BrowseView = Ember.View.extend
    classNames: ['browse', 'highlight']
    classNameBindings: SUBJECTS.map(String.prototype.fmt, 'controller.%@')
    didInsertElement: () ->
      @_super()
      @get('controller.activeSubjects')
        .forEach (d) => @controller.set(d, true)


  # # BROWSE - > SECTION
  App.BrowseSectionView = Ember.View.extend
    click: (event) ->
      controller = @get 'controller'
      tokenCollectorValue = $.makeArray controller.get('tokenCollectorValue')
      setval = null
      clean = (str) -> (str or '').toLowerCase().trim()
      _id = (type, text) -> JSON.stringify type: type, text: text
      handlers =
        persName: (target) ->
          if (n = clean target.getAttribute('data-tei-n')) and target.getAttribute('data-tei-reg')
            if not (n in tokenCollectorValue)
              setval = tokenCollectorValue.concat [_id('people', n)]
        placeName: (target) ->
          if (reg = clean target.getAttribute('data-tei-reg')) and target.getAttribute('data-tei-key')
            if not (reg in tokenCollectorValue)
              setval = tokenCollectorValue.concat [_id('places', reg)]
        orgName: (target) ->
          if (n = clean target.getAttribute('data-tei-n')) and target.getAttribute('data-tei-type')
            if not (n in tokenCollectorValue)
              setval = tokenCollectorValue.concat [_id('organizations', n)]
        rs: (target) ->
          if (reg = clean target.getAttribute('data-tei-reg')) and target.getAttribute('data-tei-type')
            if not (reg in tokenCollectorValue)
              setval = tokenCollectorValue.concat [_id('keywords', reg)]

      cls = event.target.getAttribute('class') or ''
      if cls.match 'tei'
        teiElement = cls.split(' ')[1]
        if handlers[teiElement]
          handlers[teiElement] event.target
        else if (parent = $(event.target).parents('.persName, .placeName, .orgName, .rs')[0])
          teiElement = parent.getAttribute('class').split(' ')[1]
          handlers[teiElement] parent
      if setval
        controller.set 'controllers.browse.tokenCollectorValue', setval
        if not controller.get('showDetails')
          controller.toggleProperty 'showDetails'

  # COMPONENTS

  App.LoadingSpinnerComponent = require('lib/loadingSpinner')

  # # SELECT2 TOKEN COLLECTOR

  App.TokenCollectorComponent = Ember.Component.extend
    value: null
    placeholder: null
    onQuery: null
    style: 'width:100%'
    separator: ';'
    minimumInputLength: 0
    maximumSelectionSize: 10
    multiple: true

    update: (e) ->
      @sendAction 'changed', value: e.val

    didInsertElement: () ->
      @_super()
      @setup()

    query: (context) ->
      @sendAction 'onQuery', context

    setup: () ->
      maximumSelectionSize = @get 'maximumSelectionSize'
      minimumInputLength = @get 'minimumInputLength'
      options = @getProperties [
        'maximumSelectionSize'
        'minimumInputLength'
        'multiple'
        'separator'
        'placeholder'
      ]
      options.initSelection = _.bind @initSelection, @
      if @ajax
        options.ajax = @ajax
      else
        options.query = _.bind @query, @

      update = _.bind @update, @
      @select2 = @$('input')
        .select2(options)
        .select2('val', @get 'value')
        .on('change', update)

    willDestroyElement: () ->
      if @select2 then @select2
        .off('change')
        .select2('destroy')
      @_super()

    initSelection: (el, callback) ->
      values = @get 'value'
      callback values.map (id) -> id: id, text: JSON.parse(id).text

    valueChanged: (() ->
      if not @select2 then return
      value = @get 'value'
      selectorVal = @select2.select2 'val'
      # lodash for deep comparison of arrays.
      if not _.isEqual(selectorVal, value) then @select2.select2 'val', value
    ).observes('value')

  # # PAGED SELECT 2
  App.PagedSelect2Component = Ember.Component.extend
    actions:
      next: () ->
        @sendAction 'select', {type: @get('type'), value: @get('nextText')}
      prev: () ->
        @sendAction 'select', {type: @get('type'), value: @get('prevText')}

    update: (e) ->
      @sendAction 'select', {type: @get('type'), value: e.val}

    initSelection: (el, callback) ->
      id = @get 'value'
      callback id: id, text: id

    valueChanged: (() ->
      if not @select2 then return
      value = @get 'value'
      selectorVal = @select2.select2 'val'
      if selectorVal isnt value then @select2.select2 'val', value
    ).observes('value')

    didInsertElement: () ->
      @_super()
      query = _.bind select2Query, @
      initSelection = _.bind @initSelection, @
      update = _.bind @update, @
      @select2 = @$('input').select2({query, initSelection})
        .on('change', update)

    willDestroyElement: () ->
      @select2
        .off('change')
        .select2('destroy')
      @_super()
