define (require) ->
  Ember = require 'ember'
  d3 = require 'd3'
  util = require 'lib/util'
  {SEARCH_LIMIT} = require 'constants'
  Ember.TEMPLATES['search/page'] = Ember.Handlebars.compile require 'text!./searchPage.hbs'

  (App) ->
    ###
    The search page route renders one page of search results.
    ###
    App.SearchPageRoute = Ember.Route.extend
      # The `model` hook is overridden to default to the first page of results.
      model: (params) ->
        if not params?.page then page: 1 else params

      # The `setupController` hook is overridden to fetch articles whenever the route is entered.
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
        # `changePage` moves the page index forward or backward.
        changePage: (increment) ->
          searchPageController = @controllerFor 'searchPage'
          {page, articles} = searchPageController
            .getProperties(['articles', 'page'])
          # If the current set of articles is empty, assume no more pages.
          if (page + increment) > 0 and articles?.length is SEARCH_LIMIT
            @transitionTo 'search.page', page: parseInt(page, 10) + parseInt(increment, 10)

    App.SearchPageController = Ember.ObjectController.extend
      needs: ['search']
      searchTermsBinding: 'controllers.search.content'
      # `isFirst` is true if the current page number is 1.
      isFirst: Ember.computed.equal 'page', 1
      # `isLast` is true if the article count is less than the limit.
      isLast: Ember.computed.lt 'articles.length', SEARCH_LIMIT
      # fetch articles that match the search query.
      read: util.read '/v1/related-articles'

      # Move the loading spinner down under the search input.
      loadingSpinnerOptions:
        top: '100px'

      # `getQueryParams` builds the argument to this controller's `read` method from the search terms.
      getQueryParams: () ->
        searchTerms = @get('searchTerms').map(JSON.parse, JSON)
        unless Ember.isEmpty searchTerms
          page = @get 'page'
          params = d3.nest()
            .key((d) -> d.type)
            .entries(searchTerms)
            .reduce(
              (a, b) ->
                a[b.key] = (a[b.type] or '') + b.values.getEach('text').join(';')
                a
              {offset: SEARCH_LIMIT * (parseInt(page, 10) - 1)}
            )