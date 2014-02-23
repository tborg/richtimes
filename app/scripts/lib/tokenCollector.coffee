define (require) ->
  require 'select2'
  Ember = require 'ember'
  _ = require 'lodash'

  Ember.TEMPLATES['components/token-collector'] = Ember.Handlebars.compile require './tokenCollector.hbs'

  (App) ->
    App.TokenCollectorComponent = Ember.Component.extend
      value: null
      placeholder: null
      onQuery: null
      style: 'width:100%'
      separator: ';'
      minimumInputLength: 0
      maximumSelectionSize: 10
      multiple: true

      update: (e) ->
        @sendAction 'changed', value: e.val

      didInsertElement: () ->
        @_super()
        @setup()

      query: (context) ->
        @sendAction 'onQuery', context

      setup: () ->
        maximumSelectionSize = @get 'maximumSelectionSize'
        minimumInputLength = @get 'minimumInputLength'
        options = @getProperties [
          'maximumSelectionSize'
          'minimumInputLength'
          'multiple'
          'separator'
          'placeholder'
        ]
        options.initSelection = _.bind @initSelection, @
        if @ajax
          options.ajax = @ajax
        else
          options.query = _.bind @query, @

        update = _.bind @update, @
        @select2 = @$('input')
          .select2(options)
          .select2('val', @get 'value')
          .on('change', update)

      willDestroyElement: () ->
        if @select2 then @select2
          .off('change')
          .select2('destroy')
        @_super()

      initSelection: (el, callback) ->
        values = @get 'value'
        callback values.map (id) -> id: id, text: JSON.parse(id).text

      valueChanged: (() ->
        if not @select2 then return
        value = @get 'value'
        selectorVal = @select2.select2 'val'
        # lodash for deep comparison of arrays.
        if not _.isEqual(selectorVal, value) then @select2.select2 'val', value
      ).observes('value')