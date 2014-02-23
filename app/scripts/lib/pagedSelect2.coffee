define (require) ->
  require 'select2'
  Ember = require 'ember'
  _ = require 'lodash'

  Ember.TEMPLATES['components/paged-select2'] = Ember.Handlebars.compile require './pagedSelect2.hbs'

  (App) ->
    App.PagedSelect2Component = Ember.Component.extend
      actions:
        next: () ->
          @sendAction 'select', {type: @get('type'), value: @get('nextText')}
        prev: () ->
          @sendAction 'select', {type: @get('type'), value: @get('prevText')}

      update: (e) ->
        @sendAction 'select', {type: @get('type'), value: e.val}

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
        query = _.bind select2Query, @
        initSelection = _.bind @initSelection, @
        update = _.bind @update, @
        @select2 = @$('input').select2({query, initSelection})
          .on('change', update)

      willDestroyElement: () ->
        @select2
          .off('change')
          .select2('destroy')
        @_super()

