define (require) ->
  Ember = require 'ember'
  require 'emberData'
  require './templates/templates'

  window.App = Ember.Application.create
    LOG_TRANSITIONS: true
  window.App