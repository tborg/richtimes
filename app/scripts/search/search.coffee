define (require) ->
  Ember = require 'ember'

  Ember.TEMPLATES['search'] = Ember.Handlebars.compile require 'text!./search.hbs'

  (App) ->
    ###
    The search route is responsible for rendering the search input.
    ###
    App.SearchRoute = Ember.Route.extend
      ###
      The `setupController` hook is overloaded to attempt to use the tokens
      from the details sidebar by default.
      ###
      setupController: (controller, model) ->
        if Ember.isEmpty(model)
          try
            model = @controllerFor('browse')
              .get('tokenCollectorValue')
          catch e
            model = []
        @_super(controller, model)

      actions:
        # `goToSection` routes back to the browse view, showing the specified issue/section.
        goToSection: (root, issue, section) ->
          model = {root, issue, section}
          browseController = @controllerFor('browse')
          browseController.set 'root', root
          alternateRoot = browseController.get 'alternateRoot'
          browseController.send 'changeFocus', type: root, value: model[root]
          browseController.send 'changeFocus', type: alternateRoot, value: model[alternateRoot]

    # The search controller drives the search input.
    App.SearchController = Ember.ArrayController.extend
      ###
      `searchSuggestionsQuery` configures the ajax request for search suggestions,
      using the built-in select2 query function
      ###
      searchSuggestionsQuery:
        url: '/v1/suggestions'
        dataType: 'json'
        quitMillis: 250
        cache: true
        data: (term, page) -> {term, page}
        results: (data) ->
          results: data.data
          more: data.more

      ###
      `contentChanged` routes to the first page of search results
      whenever the search input value changes.
      ###
      contentChanged: (() ->
        @transitionToRoute 'search.page', page: 1
      ).observes('content')

      actions:
        # `changeContent` updates the controller's representation of the search input value.
        changeContent: (d) -> @set 'content', d.value
