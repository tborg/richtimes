define (require) ->
  App = require 'app'

  App.Router.map () ->
    @resource 'sections', ->
      @resource 'subsections', {path: ':section_id'}, ->
        @resource 'issues', {path: ':subsection_name'}, ->
          @route 'issue', {path: ':issue_id'}

  App.IndexRoute = Ember.Route.extend
    afterModel: () ->
      @transitionTo 'sections'

  require './sections/sections'
  require './sections/subsections'
  require './sections/issues'
  require './sections/issue'
