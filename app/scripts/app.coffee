define (require) ->
  Ember = require 'ember'
  DS = require 'emberData'
  # require 'emberData'
  unless window.App
    window.App = Ember.Application.create
      LOG_TRANSITIONS: true
  window.App