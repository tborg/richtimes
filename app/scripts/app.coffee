define (require) ->
  """
  The application core.

  Instantiates the app and registers routes and components.

  Creates the router map.

  Defines the top-level Application and Index routes.
  """
  Ember = require 'ember'
  require 'bootstrapCollapse'

  Ember.TEMPLATES['index'] = Ember.Handlebars.compile require './index.hbs'

  ###
  Create the application instance.

  The application is made available on the window.

  `App.__container__.lookup` is an extremely handy method
  to have on the command line.
  ###
  window.App = Ember.Application.create
    LOG_TRANSITIONS: true

  ###
  All route and component modules expose `load` methods that
  take the App as argument. They are responsible for attaching
  to the application according to ember's conventions.
  ###
  [
    require './lib/d3Calendar'
    require './lib/loadingSpinner'
    require './lib/pagedSelect2'
    require './lib/tokenCollector'
    require './browse/browse'
    require './browse/browseSection'
    require './search/search'
    require './search/searchPage'
    require './calendar/calendar'
    require './calendar/calendarMonth'
  ].map (load) -> load App

  ###
  The application's router.
  ###
  App.Router.map () ->
    @resource 'browse', {path: '/:root/:section/:issue'}, ->
      @route 'section'
    @resource 'search', ->
      @route 'page', {path: '/:page'}
    @resource 'calendar', ->
      @route 'month', {path: '/:year/:month'}

  ###
  The application route is the top level route.
  ###
  App.ApplicationRoute = Ember.Route.extend
    actions:
      ###
      TODO: catch otherwise unhandled exceptions here.
      ###
      error: (error, transition) ->
        throw error

  ###
  The index route redirects to the browse route.
  ###
  App.IndexRoute = Ember.Route.extend
    afterModel: (m, transition) ->
      if routeIsTarget transition, @
        @transitionTo 'browse'

  ###
  The application view is the top-level view.
  ###
  App.ApplicationView = Ember.View.extend
    ###
    Set up the "top" link in the footer.
    ###
    scrollTop: (() ->
      @$('footer a.scroll-top').click(() -> $('body').animate(scrollTop: '0'); false)
    ).on('didInsertElement')