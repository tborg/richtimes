define (require) ->
  Ember = require 'ember'

  Ember.TEMPLATES['search'] = Ember.Handlebars.compile require './search.hbs'

  (App) ->
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

    App.SearchController = Ember.ObjectController.extend
      searchSuggestionsQuery:
        url: '/v1/suggestions'
        dataType: 'json'
        quitMillis: 250
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
