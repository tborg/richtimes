define (require) ->
  Ember = require 'ember'
  d3 = require 'd3'
  _ = require 'lodash'
  util = require 'lib/util'

  Ember.TEMPLATES['calendar'] = Ember.Handlebars.compile require 'text!./calendar.hbs'

  (App) ->
    App.CalendarRoute = Ember.Route.extend
      model: (params, transition) ->
        $.getJSON('/static/json/calendar.json')
          .then (model) =>
            {year, month} = transition.params
            if not year or not month then [year, month] = _.first model
            @controllerFor('calendar').setProperties
              year: String(year)
              month: String(month)
            model
      afterModel: (model, transition) ->
        if util.routeIsTarget(transition, @)
          params = @controllerFor('calendar').getProperties ['year', 'month']
          $.getJSON(util.wcJsonFile params)
            .then (d) => @transitionTo 'calendar.month', d

      actions:
        changeCalendar: ({type, value}) ->
          c = @controllerFor 'calendar'
          if type is 'month' and isNaN(Number value)
            value = c.get('months').findProperty('text', value).id
          c.set type, value
          if type is 'year' then c.set 'month', c.get('months')?[0]?.id
          $.getJSON(util.wcJsonFile c.getProperties ['year', 'month'])
            .then (d) => @transitionTo 'calendar.month', d

    App.CalendarController = Ember.ArrayController.extend
      year: null
      month: null

      years: (() ->
        years = _.uniq @get('content').map ([y]) -> String(y)
        years.map (d) -> text: d, id: d
      ).property('content')

      months: (() ->
        year = Number @get 'year'
        monthNameFormatter = d3.time.format('%B')
        now = new Date()
        nameFor = (m) ->
          now.setMonth m - 1
          monthNameFormatter now
        months = _.uniq @get('content').filter((d) -> d[0] is year).map ([_, m]) -> String m
        months.map (d) -> id: d, text: nameFor d
      ).property('year', 'content')

      selectors: (() ->
        years = @get 'years'
        year = @get 'year'
        yi = years.indexOf years.findProperty 'id', year
        month = @get 'month'
        months = @get('months')
        mi = months.indexOf months.findProperty 'id', month
        [
          {
            type: 'year',
            next: years[yi + 1]?.text or ''
            prev: years[yi - 1]?.text or ''
            value: String year
            options: years
            initSelection: (el, cb) ->
              cb @get('options').findProperty('id', @get 'value')
          }
          {
            type: 'month',
            next: months[mi + 1]?.text or ''
            prev: months[mi - 1]?.text or ''
            value: String month
            options: months
            initSelection: (el, cb) ->
              cb @get('options').findProperty('id', @get 'value')
          }
        ]
      ).property('year', 'month', 'years', 'months')