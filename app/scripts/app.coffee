define (require) ->
  Ember = require 'ember'
  require 'select2'
  require 'bootstrapCollapse'
  require 'd3'
  _ = require 'lodash'

  # CONSTANTS

  ROOTS = ['section', 'issue']

  # TEMPLATES

  templates = [
    {name: 'index', hbs: require 'text!./templates/index.hbs'}
    {name: 'content', hbs: require 'text!./templates/content.hbs'}
    {name: 'content/articles', hbs: require 'text!./templates/articles.hbs'}

    {name: 'components/paged-select2', hbs: require 'text!./templates/components/pagedSelect2.hbs'}
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

  read = (path, paramsGetter) -> (params, opts={}) ->
    if @_cancelRead then @_cancelRead()
    read = new Ember.RSVP.Promise (resolve, reject) =>
      @set 'isLoading', true
      @_cancelRead = reject
      endpoint = path.fmt.apply path, paramsGetter.apply @, [params, opts]
      $.getJSON(endpoint, opts).then(
        (content) =>
          @cancelRead = null
          if not ((content.status_code or 200) in [200, 201]) then reject content
          resolve content.data
          @set 'isLoading', false
        (error) =>
          @set 'isLoading', false
          @cancelRead = null
          reject error
      )

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

  # APPLICATION

  App = Ember.Application.create
    LOG_TRANSITIONS: true

  # ROUTER

  App.Router.map () ->
    @resource 'content', {path: '/:root/:section/:issue'}, ->
      @route 'articles', {path: '/articles'}
      @route 'people'
      @route 'places'
      @route 'orgs'
      @route 'things'
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
        @transitionTo 'content'

  # # CONTENT
  App.ContentRoute = Ember.Route.extend
    model: (params) ->
      controller = @controllerFor 'content'
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
          @transitionTo 'content.articles', model

  # # CONTENT - > ARTICLES
  App.ContentArticlesRoute = Ember.Route.extend
    model: (params) ->
      @controllerFor('contentArticles').read()

  # CONROLLERS

  # # CONTENT
  App.ContentController = Ember.ObjectController.extend
    subject: 'articles'
    index: null
    LoadingView: require('lib/loadingSpinnerView').extend
      options:
        top: '100px'

    init: () ->
      @_super()
      @set 'content', {}
      @set 'sectionIndex', index 'section', 'issue',
        JSON.parse require 'text!../json/sections.json'
      @set 'issueIndex', index 'issue', 'section',
        JSON.parse require 'text!../json/issues.json'

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
      changeFocus: ({type, value}) ->
        @set type, value
        if type is @get 'root'
          @set 'index', (index = @get('%@Index'.fmt type).page value)
          if not ((child = @get 'alternateRoot') in index.childOptions)
            @set child, index.childOptions[0]
        @transitionTo 'content.%@'.fmt(@get 'subject'), @get('content'), 

  # # CONTENT - > ARTICLES
  App.ContentArticlesController = Ember.ArrayController.extend
    needs: ['content']
    isLoadingBinding: 'controllers.content.isLoading'
    read: read 'articles/%@/%@', (params, opts) ->
      {issue, section} = @get('controllers.content')
        .getProperties(['issue', 'section'])
      [issue, section]

  # VIEWS

  # # APPLICATION
  App.ApplicationView = Ember.View.extend
    didInsertElement: () ->
      @_super()
      @$('footer a').click(() -> $('body').animate(scrollTop: '0'); false)


  # COMPONENTS

  # # PAGED SELECT 2
  App.PagedSelect2Component = Ember.Component.extend
    actions:
      next: () ->
        @sendAction 'select', {type: @get('type'), value: @get('nextText')}
      prev: () ->
        @sendAction 'select', {type: @get('type'), value: @get('prevText')}

    query: ({term, callback, page}) ->
      options = @get('options')
        .filter((d) -> d.toLowerCase().match term)
      results = 
        results: options
          .slice((page - 1) * 10, page * 10)
          .map((d) -> text: d, id: d)
        more: options.length > page * 10
      callback results

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
      query = _.bind @query, @
      initSelection = _.bind @initSelection, @
      update = _.bind @update, @
      containerCssClass = '%@-select-container'.fmt @get 'type'
      @select2 = @$('input').select2({query, initSelection, containerCssClass})
        .on('change', update)

    willDestroyElement: () ->
      @select2
        .off('change')
        .select2('destroy')
      @_super()
