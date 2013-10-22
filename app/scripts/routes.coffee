define (require) ->

  App = require 'app'
  Ember = require 'ember'
  require 'bootstrapDropdown'

  App.Router.map () ->
    @resource 'home'

    @resource 'content', ->
      @resource 'content.type', {path: ':content_type_id'}, ->
        @route 'section', {path: ':date_id/:section_id'}

    @resource 'people'
    @resource 'places'
    @resource 'orgs'
    @resource 'things'
    @route 'missing', {path: '/*path'}

  App.ContentRoute = Ember.Route.extend
    model: () -> @store.find 'contentType'

    afterModel: (model, transition) ->
      controller = @controllerFor 'content'
      if not controller.get('active')
        type = transition.params.content_type
        options = model.get('content')
        selection = if type then options.findProperty('id', type) else options[0].id
        controller.set 'active', id: selection, text: selection, active: true
        next = controller.transitionToContentType()
        next.params = transition.params

  App.ContentTypeRoute = Ember.Route.extend
    model: () -> @store.find 'date'

    afterModel: (model, transition) ->
      controller = @controllerFor('contentType')
      date = controller.get('date')
      # unless date
      date = transition.params.date_id or model.get('content.0.id')
      controller.set 'content', model
      controller.set 'date', date
      controller.set 'section', id: transition.params.section_id
      controller.updateSections()

    serialize: () ->
      content_type_id: @controllerFor('content').get('active.id')

  App.ContentTypeSectionRoute = Ember.Route.extend
    serialize: () ->
      contentTypeController = @controllerFor('contentType')
      date_id: contentTypeController.get 'date'
      section_id: contentTypeController.get 'section.id'

  App.MissingRoute = Ember.Route.extend
    redirect: () ->
      @transitionTo 'home'