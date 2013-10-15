define (require) ->
  App = require 'app'

  App.Router.map () ->
    @resource 'issues', ->
      @route 'issue', path: ':issue_id'

  App.IndexRoute = Ember.Route.extend
    afterModel: () ->
      @transitionTo 'issues'

  require './issues/issues'
  require './issues/issue'
