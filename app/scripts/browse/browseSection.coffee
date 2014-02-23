define (require) ->
  Ember = require 'ember'
  _ = require 'lodash'
  {SUBJECTS} = require 'constants'
  util = require 'lib/util'

  Ember.TEMPLATES['browse/section'] = Ember.Handlebars.compile require 'text!./browseSection.hbs'

  (App) ->
    # The browseSection route is responsible for rendering the selected section.
    App.BrowseSectionRoute = Ember.Route.extend
      # `model` defer's to the controller's read method.
      model: (params) ->
        @controllerFor('browseSection').read()

      ###
      The `setupController` hook is overloaded to consolidate the article's
      entities into one nested select2-ready array.
      ###
      setupController: (controller, model) ->
        @_super(controller, model)

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

    # The browseSection controller is responsible for fetching the currently browsed article.
    App.BrowseSectionController = Ember.ArrayController.extend
      needs: ['browse']
      isLoadingBinding: 'controllers.browse.isLoading'
      tokenCollectorValueBinding: 'controllers.browse.tokenCollectorValue'
      showDetailsBinding: 'controllers.browse.showDetails'
      # `read` fetches the current issue/section; returns a promise.
      read: util.read '/v1/articles/%@/%@', (params, opts) ->
        {issue, section} = @get('controllers.browse')
          .getProperties(['issue', 'section'])
        [issue, section]

    ###
    The browseSection view handles click events on subject instances in the text
    by adding clicked subjects to the details sidebar token collector, so that they
    can be gathered and searched against.
    ###
    App.BrowseSectionView = Ember.View.extend
      # `click` handles click events for interesting elements of the currently browsed section
      click: (event) ->
        controller = @get 'controller'
        tokenCollectorValue = $.makeArray controller.get('tokenCollectorValue')
        setval = null
        clean = (str) -> (str or '').toLowerCase().trim()
        _id = (type, text) -> JSON.stringify type: type, text: text

        # `handlers` declares how to handle interesting elements.
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
          # Maybe an element intersting itself was clicked;
          if handlers[teiElement]
            handlers[teiElement] event.target
          # or maybe the child of an interesting element was clicked;
          else if (parent = $(event.target).parents('.persName, .placeName, .orgName, .rs')[0])
            teiElement = parent.getAttribute('class').split(' ')[1]
            handlers[teiElement] parent
          # or not; then do nothing.
        if setval
          controller.set 'controllers.browse.tokenCollectorValue', setval
          # Expand the details sidebar to show the added token, if it isn't open already.
          if not controller.get('showDetails')
            controller.toggleProperty 'showDetails'
