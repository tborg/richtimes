define (require) ->
  require 'select2'
  _ = require 'lodash'

  Ember = require 'ember'

  Ember.View.extend
    tagName: 'input'
    attributeBindings: ['type']
    type: 'hidden'
    value: null
    options: null
    attributeBindings: ['style']
    style: 'width: 100%;'

    query: ({term, callback}) ->
      callback results: @get('options')
        .filter((d) -> d.toLowerCase().match term)
        .map((d) -> text: d, id: d)

    update: (e) ->
      @set('value', e.val)

    initSelection: (el, callback) ->
      id = @get 'value'
      callback id: id, text: id

    valueChanged: (() ->
      if not @select2 then return
      value = @get 'value'
      selectorVal = @select2.select2 'val'
      if selectorVal isnt value then @select2.select2 'val', value
    ).observes('value')

    didInsertElement: () ->
      @_super()
      query = _.bind @query, @
      initSelection = _.bind @initSelection, @
      update = _.bind @update, @
      @select2 = @$().select2({query, initSelection})
        .on('change', update)

    willDestroyElement: () ->
      @select2
        .off('change')
        .select2('destroy')
      @_super()