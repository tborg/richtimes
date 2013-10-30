define (require) ->
  require 'select2'
  Ember = require 'ember'

  Ember.Select.extend
    tagName: 'select'
    contentBinding: 'controller.select2Options'
    optionValuePath: 'selectId'
    optionLabelPath: 'selectText'

    didInsertElement: () ->
      @_super()
      @input = @$().select2()