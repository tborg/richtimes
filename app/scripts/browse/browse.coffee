define (require) ->
  Ember = require 'ember'
  {ROOTS, SUBJECTS} = require 'constants'
  util = require 'lib/util'
  d3 = require 'd3'

  Ember.TEMPLATES['browse'] = Ember.Handlebars.compile require 'text!./browse.hbs'

  # `sortIssues` compares issue date strings chronologically.
  sortIssues = (a, b) ->
    [y, m, d] = a.split('-').map((d) -> parseInt(d, 10))
    [_y, _m, _d] = b.split('-').map((d) -> parseInt(d, 10))
    d3.ascending(y, _y) or d3.ascending(m, _m) or d3.ascending(d, _d)
  
  # `sorts` declares sorting functions for each index root type.
  sorts =
    section: d3.ascending  # plain old alphabetic sort
    issue: sortIssues

  # `index` lifts the given index object into a focal point with navigation properties.
  index = (rootName, childName, data) ->
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

  (App) ->
    ###
    The browse route covers the navigation features for point-and-click browsing.

    Browsing can be rooted by section or by date; these options are encoded as url fragments.

    Each root is associated with its own index. Each index is a relatively small
    json file which is statically required by the controller.
    ###
    App.BrowseRoute = Ember.Route.extend
      model: (params, transition) ->
        controller = @controllerFor 'browse'
        # Pick a default root if not present in the URL.
        if not (params.root in ROOTS)
          params.root = ROOTS[0]
        controller.set 'root', root = params.root
        rootIndex = controller.get '%@Index'.fmt root
        # Fill in the issue (date) and section url fragments.
        if not (key = params[root])
          params[root] = (key = rootIndex.rootOptions[0])
        controller.set('index', rootIndex.page key)
        child = controller.get 'alternateRoot'
        if not (key = params[child])
          params[child] = controller.get 'index.childOptions.0'
        controller.setProperties params
        params

      ###
      Redirect to the section route.
      ###
      afterModel: (model, transition) ->
        if util.routeIsTarget(transition, @)
          if model.section and model.issue
            @transitionTo 'browse.section', model

      actions:
        ###
        Expand or contract the right-hand sidebar.
        ###
        toggleDetails: (d) ->
          @controllerFor('browse').toggleProperty('showDetails')

    ###
    The browse controller controls the navigation behavior.

    The main special feature of this controller is its ability to
    swap the index root between issue and section.

    It also drives the sidebar's search input, in which the user
    can search for "subjects" in the currently browsed section.
    ###
    App.BrowseController = Ember.ObjectController.extend
      # `index` is the placeholder for the currently active index.
      index: null
      # `sectionIndex` is a focused index mapping sections to the issues in which they occur.
      sectionIndex: index 'section', 'issue', JSON.parse require 'text!../../json/sections.json'
      # `issueIndex` is a focused index mapping issues to the sections that occur in them.
      issueIndex: index 'issue', 'section', JSON.parse require 'text!../../json/issues.json'
      # `showDetails` determines whether the sidebar should be expanded.
      showDetails: false
      ###
      `activeSubjects` holds the list of subject types which the user has activated
      by clicking in the details sidebar. Instances of active subject types are highlighted
      in the currently browsed section.
      ###
      activeSubjects: null
      ###
      `tokenCollectorOptions` contains tokens representing selectable subject instances
      found in the currently browsed section. This is set on the browse controller by the
      browseSection route, which is responsible for loading the currently browsed section.
      ###
      tokenCollectorOptions: null

      # `loadingSpinnerOptions` moves the loading spinner underneath the navigation.
      loadingSpinnerOptions:
        top: '100px'

      # `noTokens` is true if there are no selected subjects.
      noTokens: Ember.computed.empty 'tokenCollectorValue'

      # `showDetailsIconClass` toggles between an open eye and a closed one as the details sidebar icon.
      showDetailsIconClass: (() ->
        'glyphicon-eye-%@'.fmt if @get('showDetails') then 'open' else 'close'
      ).property('showDetails')

      # `subjects` informs the selectable list in the details panel. Items where active is true are highlighted.
      subjects: (() ->
        activeSubjects = @get 'activeSubjects'
        SUBJECTS.map((d) ->
          text: d
          active: d in activeSubjects
        )
      ).property('activeSubjects')

      ###
      `setupDefaults` establishes some default values on initialization.
      Here we are careful to avoid declaring objects that are passed by reference
      on the controller's prototype.
      ###
      setupDefaults: (() ->
        @set 'content', {}
        @set 'activeSubjects', []
        @set 'index', @get 'issueIndex'
      ).on('init')

      ###
      `selectors` sets up the navigation bindings dynamically based on the chosen root.
      ###
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

      # `alternateRoot` is the index which is not the currently selected root.
      alternateRoot: (() ->
        root = @get 'root'
        ROOTS.filter((d) -> d isnt root)[0]
      ).property('root')

      actions:
        ###
        `onEntityQuery` produces a paginated, nested set of selectable subjects for the
        details sidebar token collector.
        ###
        onEntityQuery: ({term, callback, page}) ->
          getOptions = (opts) ->
            opts.filter((d) ->
              if d.children
                text: d.text, children: getOptions d.children
              else
                (d.text or d).toLowerCase().match term
            )
          options = getOptions @get('tokenCollectorOptions')
          results = 
            results: options
              .slice((page - 1) * 10, page * 10)
            more: options.length > page * 10
          callback results

        # `changeFocus` swaps the current root with the alternate root.
        changeFocus: ({type, value}) ->
          @set type, value
          if type is @get 'root'
            @set 'index', (index = @get('%@Index'.fmt type).page value)
            if not ((child = @get 'alternateRoot') in index.childOptions)
              @set child, index.childOptions[0]
          @transitionTo 'browse.section', @get('content')

        # `changeSubject` toggles the active state of subjects listed in the details sidebar.
        changeSubject: ({text}) ->
          activeSubjects = @get 'activeSubjects'
          if text in activeSubjects
            setval = activeSubjects.filter((d) -> d isnt text)
          else
            setval = activeSubjects.concat([text])
          @set 'activeSubjects', setval
          highlighted = (props, d) -> props[d] = d in setval; props
          @setProperties SUBJECTS.reduce highlighted, {}

        # `updateTokenCollector` syncs the controller's tokenCollectorValue with the select2's state.
        updateTokenCollector: (d) ->
          @set 'tokenCollectorValue', d.value

    ###
    The browser view enables highlighting via CSS selectors in the child section view
    by binding its classNames to the array of active subjects held by its controller.
    ###
    App.BrowseView = Ember.View.extend
      classNames: ['browse', 'highlight']
      classNameBindings: SUBJECTS.map(String.prototype.fmt, 'controller.%@')
      ###
      `bootstrapActiveSubjects` mimics the side effect of the controller's `changeSubject`
      action, which maps subject type name to active state directly on the controller.
      ###
      bootstrapActiveSubjects: (() ->
        @get('controller.activeSubjects')
          .forEach (d) => @controller.set(d, true)
      ).on('didInsertElement')
