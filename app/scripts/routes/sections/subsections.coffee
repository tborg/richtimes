define (require) ->
  App = require 'app'
  Ember = require 'ember'
  DS = require 'emberData'

  App.SubsectionsController = Ember.ObjectController.extend
    active: null
    needs: ['issues']
    issueIdBinding: 'controllers.issues.issueId'

    options: (() ->
      active = @get 'active'
      $.makeArray(@get('subsections')).map (d) ->
        text: d
        active: d is active
    ).property('subsections', 'active')

    actions:
      setSubsectionType: (option) ->
        @set 'active', option.text
        @transitionToNext()
      
    transitionToNext: () ->
      @refreshIssuesController()
      @transitionToRoute 'issues', @store.find 'subsection', @get 'active'

    refreshIssuesController: () ->
      @get('controllers.issues')
        .setProperties year: null, month: null, day: null

  App.SubsectionsRoute = Ember.Route.extend

    afterModel: (model, transition) ->
      controller = @controllerFor 'subsections'
      active = controller.get 'active'
      if not active
        options = model.get('subsections')
        preferred = transition.params.subsection_id
        active = if preferred and preferred in options then preferred else options[0]
        controller.set 'active', active
        controller.refreshIssuesController()
        next = @transitionTo 'issues', @store.find 'subsection', active
        next.params = transition.params
        next

    serialize: () ->
      section_id: @controllerFor('sections').get('active')
