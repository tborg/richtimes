define (require) ->
  App = require 'app'
  Ember = require 'ember'
  DS = require 'emberData'

  App.Section = DS.Model.extend
    subsections: DS.attr()

  App.SectionsController = Ember.ArrayController.extend
    needs: ['subsections']

    options: (() ->
      active = @get 'active'
      @map (d) ->
        text: d.id
        active: d.id is active
    ).property 'content', 'active'

    actions:
      setSectionType: ({text}) ->
        @set 'active', text
        @set 'controllers.subsections.active', null
        @transitionToRoute 'subsections', @store.find 'section', text

  App.SectionsRoute = Ember.Route.extend
    model: (params) -> @store.findAll 'section'

    afterModel: (model, transition) ->
      controller = @controllerFor 'sections'
      active = controller.get 'active'
      if not active
        options = model.getEach 'id'
        preferred = transition.params.section_id
        active = if preferred and preferred in options then preferred else options[0]
        controller.set 'active', active
        next = @transitionTo 'subsections', @store.find 'section', active
        next.params = transition.params
        next