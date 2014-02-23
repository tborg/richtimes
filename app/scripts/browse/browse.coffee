define (require) ->
  Ember = require 'ember'
  {ROOTS, SUBJECTS} = require '../constants'

  Ember.TEMPLATES['browse'] = Ember.Handlebars.compile require 'text!./browse.hbs'

  (App) ->
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

    App.BrowseController = Ember.ObjectController.extend
      index: null
      noTokens: Ember.computed.empty 'tokenCollectorValue'
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

    App.BrowseView = Ember.View.extend
      classNames: ['browse', 'highlight']
      classNameBindings: SUBJECTS.map(String.prototype.fmt, 'controller.%@')
      didInsertElement: () ->
        @_super()
        @get('controller.activeSubjects')
          .forEach (d) => @controller.set(d, true)

