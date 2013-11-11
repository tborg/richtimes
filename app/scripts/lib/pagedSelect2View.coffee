define (require) ->
  Ember = require 'Ember'
  template = require 'text!./pagedSelect2View.hbs'

  Ember.View.extend
    template: Ember.Handlebars.compile template