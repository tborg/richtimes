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
    {name: 'search/page', hbs: require 'text!./templates/searchPage.hbs'}
    {name: 'calendar', hbs: require 'text!././templates/calendar.hbs'}
    {name: 'calendar/month', hbs: require 'text!././templates/calendarMonth.hbs'}
    {name: 'components/token-collector', hbs: require 'text!./templates/components/tokenCollector.hbs'}
    {name: 'components/paged-select2', hbs: require 'text!./templates/components/pagedSelect2.hbs'}
    {name: 'components/loading-spinner', hbs: require 'text!./templates/components/loadingSpinner.hbs'}
    {name: 'components/d3-calendar', hbs: '<svg {{bindAttr height="height" width="width"}}></svg>'}
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

  # APPLICATION

  window.App = Ember.Application.create
    LOG_TRANSITIONS: true

  # ROUTER

  App.Router.map () ->
    @resource 'browse', {path: '/:root/:section/:issue'}, ->
      @route 'section'
    @resource 'search', ->
      @route 'page', {path: '/:page'}
    @resource 'calendar', ->
      @route 'month', {path: '/:year/:month'}

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
    model: (params) ->
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
          model = []
      @_super(controller, model)

    actions:
      goToSection: (root, issue, section) ->
        model = {root, issue, section}
        browseController = @controllerFor('browse')
        browseController.set 'root', root
        alternateRoot = browseController.get 'alternateRoot'
        browseController.send 'changeFocus', type: root, value: model[root]
        browseController.send 'changeFocus', type: alternateRoot, value: model[alternateRoot]


  # # SEARCH -> PAGE
  App.SearchPageRoute = Ember.Route.extend
    model: (params) ->
      if not params?.page then page: 1 else params

    setupController: (controller, model) ->
      @_super.apply @, arguments
      controller.read(controller.getQueryParams())
      .then((articles) ->
        controller.set 'articles', d3.nest()
          .key((d) -> d.date)
          .key((d) -> d.subsection)
          .entries(articles)
      )

    actions:
      changePage: (increment) ->
        searchPageController = @controllerFor 'searchPage'
        {limit, page, articles} = searchPageController
          .getProperties(['limit', 'articles', 'page'])
        if (page + increment) > 0 and not Ember.isEmpty articles
          @transitionTo 'search.page', page: parseInt(page, 10) + parseInt(increment, 10)

  App.CalendarRoute = Ember.Route.extend
    model: (params, transition) ->
      $.getJSON('/static/json/calendar.json')
        .then (model) =>
          {year, month} = transition.params
          if not year or not month then [year, month] = _.first model
          @controllerFor('calendar').setProperties
            year: String(year)
            month: String(month)
          model
    afterModel: (model, transition) ->
      if routeIsTarget(transition, @)
        params = @controllerFor('calendar').getProperties ['year', 'month']
        $.getJSON(wcJsonFile params)
          .then (d) => @transitionTo 'calendar.month', d

    actions:
      changeCalendar: ({type, value}) ->
        c = @controllerFor 'calendar'
        if type is 'month' and isNaN(Number value)
          value = c.get('months').findProperty('text', value).id
        c.set type, value
        if type is 'year' then c.set 'month', c.get('months')?[0]?.id
        $.getJSON(wcJsonFile c.getProperties ['year', 'month'])
          .then (d) => @transitionTo 'calendar.month', d

  App.CalendarMonthRoute = Ember.Route.extend
    model: (params) ->
      $.getJSON(wcJsonFile params)

    afterModel: (model) -> console.log model

    serialize: () ->
      @controllerFor('calendar').getProperties(['year', 'month'])

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
        @transitionTo 'browse.section', @get('content')

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
    searchSuggestionsQuery:
      url: '/v1/suggestions'
      dataType: 'json'
      quitMillis: 500
      cache: true
      data: (term, page) -> {term, page}
      results: (data) ->
        results: data.data
        more: data.more

    contentChanged: (() ->
      @transitionTo 'search.page', page: 1
    ).observes('content')

    actions:
      changeContent: (d) -> @set 'content', d.value


  # # SEARCH - > PAGE
  App.SearchPageController = Ember.ObjectController.extend
    loadingSpinnerOptions:
      top: '100px'

    needs: ['search']
    limit: 10
    searchTermsBinding: 'controllers.search.content'
    isFirst: Ember.computed.equal 'page', 1
    read: read '/v1/related-articles'

    getQueryParams: () ->
      searchTerms = @get('searchTerms').map(JSON.parse, JSON)
      unless Ember.isEmpty searchTerms
        {limit, page} = @getProperties ['limit', 'page']
        params = d3.nest()
          .key((d) -> d.type)
          .entries(searchTerms)
          .reduce(
            (a, b) ->
              a[b.key] = (a[b.type] or '') + b.values.getEach('text').join(';')
              a
            {offset: limit * (parseInt(page, 10) - 1)}
          )

  # # CALENDAR

  App.CalendarController = Ember.ArrayController.extend
    year: null
    month: null

    years: (() ->
      years = _.uniq @get('content').map ([y]) -> String(y)
      years.map (d) -> text: d, id: d
    ).property('content')

    months: (() ->
      year = Number @get 'year'
      monthNameFormatter = d3.time.format('%B')
      now = new Date()
      nameFor = (m) ->
        now.setMonth m - 1
        monthNameFormatter now
      months = _.uniq @get('content').filter((d) -> d[0] is year).map ([_, m]) -> String m
      months.map (d) -> id: d, text: nameFor d
    ).property('year', 'content')

    selectors: (() ->
      years = @get 'years'
      year = @get 'year'
      yi = years.indexOf years.findProperty 'id', year
      month = @get 'month'
      months = @get('months')
      mi = months.indexOf months.findProperty 'id', month
      [
        {
          type: 'year',
          next: years[yi + 1]?.text or ''
          prev: years[yi - 1]?.text or ''
          value: String year
          options: years
          initSelection: (el, cb) ->
            cb @get('options').findProperty('id', @get 'value')
        }
        {
          type: 'month',
          next: months[mi + 1]?.text or ''
          prev: months[mi - 1]?.text or ''
          value: String month
          options: months
          initSelection: (el, cb) ->
            cb @get('options').findProperty('id', @get 'value')
        }
      ]
    ).property('year', 'month', 'years', 'months')

  # # CALENDAR -> MONTH

  App.CalendarMonthController = Ember.ArrayController.extend
    needs: ['calendar']
    offset: (() ->
      year = Number @get 'controllers.calendar.year'
      month = Number @get 'controllers.calendar.month'
      for [y, m, d, wd] in @get('controllers.calendar.content')
        if y is year and m is month and d is 1
          return wd
      return 0
    ).property('controllers.calendar.month', 'controllers.calendar.year')

    drawCell: (selection) ->
      sectionNest = d3.nest().key((d) -> d.section)

      count = (d) -> if d then d3.sum d.mapProperty 'count' else d

      counts = @get('data').map(count)
      max = d3.max counts

      height = @cellHeight
      width = @cellWidth

      cell = selection.selectAll('.total')
        .data((d) -> [d].map(count).filter(Boolean))

      cell.enter().append('rect').classed('total', true)

      cell
        .transition()
        .duration(500)
        .attr('height', (d) -> height * d / max)
        .attr('width', (d) -> width * d / max)
        .attr('x', (d) -> (width - width * d / max) / 2)
        .attr('y', (d) -> (height - height * d / max) / 2)

      datetext = selection.selectAll('.datetext')
        .data((d, i) => if d then [i - @offset] else [])

      datetext.enter().append('text').classed('datetext', true)

      datetext
        .text((d) -> d + 1)
        .attr('x', height - 20)
        .attr('y', '20')
        .attr('font-size', '16px')
        .attr('fill', 'red')

      datetext.exit().remove()

      # section = selection.selectAll('.section')
      #   .data((d) -> sectionNest.entries(Ember.makeArray d)
      #     .map(({key, values}) -> d3.sum values.mapProperty 'count')
      #     .reduce(
      #       ({offset, sections}, sectionWC) ->
      #         {offset: offset + sectionWC + 5, sections: sections.concat([{offset, sectionWC}])}
      #       {offset: 5, sections: []}
      #     )
      #   )

      # section.enter().append('rect').classed('section', true)

      # section
      #   .transition()
      #   .attr('x', 10)
      #   .attr('y', ({offset}) -> offset)
      #   .attr('height', ({sectionWC}) -> sectionWC)
      #   .attr('width', width - 5)

      # section.exit()
      #   .transition()
      #   .attr('width', 0)
      #   .attr('height', 0)
      #   .remove()

      cell.exit()
        .transition()
        .duration(500)
        .attr('height', 0)
        .attr('width', 0)
        .remove()

      selection

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

  App.D3CalendarComponent = Ember.Component.extend
    data: undefined
    offset: undefined
    cellWidth: 100
    cellHeight: 100
    cellPadding: 25
    margin: 25

    height: (() ->
      6 * (@cellHeight + @cellPadding) + (@margin * 2)
    ).property('cellHeight', 'cellPadding', 'margin')

    width: (() ->
      7 * (@cellWidth + @cellPadding) + (@margin * 2)
    ).property('cellWidth', 'cellPadding', 'margin')

    paddedData: (() ->
      offset = @getWithDefault 'offset', 0
      data = @getWithDefault 'data', []
      pre = d3.range(0, offset).map(-> null)
      post = d3.range(0, 35 - offset - data.length).map(-> null)
      pre.concat(data).concat(post)
    ).property('data', 'offset')

    translateCell: (d, i) ->
      row = (Math.floor i / 7)
      cell = i % 7
      height = @cellHeight + @cellPadding
      width = @cellWidth + @cellPadding
      x = width * cell + @margin
      y = height * row + @margin
      "translate(#{x}, #{y})"

    drawCell: (selection) -> selection

    draw: (() ->
      days = d3.select(@$('svg')[0])
        .selectAll('.day')
        .data(@get('paddedData'), (d, i) => String i + @offset)

      days
        .enter()
        .append('g').classed('day', true)

      days
        .attr('transform', _.bind @translateCell, @)

      days
        .call(_.bind @drawCell, @)

      days.exit().remove()
    ).on('didInsertElement').observes('data', 'offset')