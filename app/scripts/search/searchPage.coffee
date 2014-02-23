define (require) ->
  Ember = require 'ember'
  d3 = require 'd3'

  Ember.TEMPLATES['search/page'] = Ember.Handlebars.compile require './searchPage.hbs'

  (App) ->
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