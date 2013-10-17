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
      @get('subsections').map (d) ->
        text: d
        active: d is active
    ).property('subsections', 'active')

    contentChanged: (() ->
      active = @get('active')
      subsections = @get('subsections')
      if Ember.isEmpty subsections then return
      if active in subsections then return
      @set 'active', subsections[0]
    ).observes('subsections')

    activeSectionChanged: (() ->
      if @get 'active'
        issueId = @get 'issueId'
        if issueId
          @transitionToRoute 'issues.issue', @store.find 'issue', issueId
        else
          @transitionToRoute 'issues'

    ).observes 'active'

    actions:
      setSubsectionType: (option) -> @set 'active', option.text

  App.SubsectionsRoute = Ember.Route.extend
    serialize: () ->
      section_id: @controllerFor('sections').get('active')

    setupController: (controller, model) ->
      controller.set 'content', model
      @controllerFor('sections').set('active', model.get 'id')