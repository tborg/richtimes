define (require) ->
  App = require 'app'
  Ember = require 'ember'
  Select2View = require 'lib/select2View'

  App.ContentTypesView = Select2View.extend
    valueChanged: (() ->
      @send 'changeType', @controller.findProperty 'id', @get 'value'
    ).observes('value')

  App.ContentSectionsView = Select2View.extend
    valueChanged: (() ->
      @send 'changeSection', @controller.findProperty 'id', @get 'value'
    ).observes('value')

  App.ContentDatesView = Select2View.extend
    valueChanged: (() ->
      @send 'changeDate', @controller.findProperty 'id', @get 'value'
    ).observes('value')