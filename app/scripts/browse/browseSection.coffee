define (require) ->
  Ember = require 'ember'
  _ = require 'lodash'

  Ember.TEMPLATES['browse/section'] = Ember.Handlebars.compile require 'text!./browseSection.hbs'

  (App) ->
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

    App.BrowseSectionController = Ember.ArrayController.extend
      needs: ['browse']
      isLoadingBinding: 'controllers.browse.isLoading'
      tokenCollectorValueBinding: 'controllers.browse.tokenCollectorValue'
      showDetailsBinding: 'controllers.browse.showDetails'
      read: read '/v1/articles/%@/%@', bySectionGetter

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
