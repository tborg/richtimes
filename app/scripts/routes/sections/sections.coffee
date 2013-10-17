define (require) ->
  App = require 'app'
  Ember = require 'ember'
  DS = require 'emberData'

  App.Section = DS.Model.extend
    subsections: DS.attr()

  App.SectionsController = Ember.ArrayController.extend

    options: (() ->
      active = @get 'active'
      @map (d) ->
        text: d.id
        active: d.id is active
    ).property 'content', 'active'

    contentChanged: (() ->
      if @get('length') and not @get('active')
        @set 'active', @get('content.content.0.id')
    ).observes('content')

    activeSectionChanged: (() ->
      if active = @get 'active'
        @transitionToRoute 'subsections', @store.find 'section', active
    ).observes 'active'

    actions:
      setSectionType: ({text}) -> @set 'active', text

  App.SectionsRoute = Ember.Route.extend
    model: () -> @store.findAll 'section'