define (require) ->

  App = require 'App'
  Ember = require 'ember'
  _ = require 'lodash'
  d3 = require 'd3'

  now = new Date()
  monthFormatter = require('d3').time.format('%B')
  monthFmt = (d) ->
    now.setMonth(parseInt(d, 10) - 1)
    monthFormatter now

  App.ContentController = Ember.ArrayController.extend
    active: null
    options: (() ->
      active = @get 'active.id'
      @map((d) ->
        id = d.get('id')
        id: id
        text: id
        active: id is active
      )
    ).property('content', 'active')

    transitionToContentType: () ->
      @transitionToRoute 'content.type', @store.find 'date'

    actions:
      select: (d) ->
        @set 'active', d
        @transitionToContentType()

  App.ContentTypeController = Ember.ArrayController.extend
    needs: ['content']

    dates: null
    sections: null

    year: null
    month: null
    day: null
    section: null

    date: ((key, value) ->
      if arguments.length > 1
        [y, m, d] = value.split('-').map((d) -> parseInt d, 10)
        year = @get('years').findProperty('id', y)
        @set 'year', year
        month = @get('months').findProperty('id', m)
        @set 'month', month
        day = @get('days').findProperty('id', d)
        @setProperties({year, month, day})
        value
      else
        {year, month, day} = @getProperties ['year', 'month', 'day']
        @filter((d) ->
          d.get('year') is year.id and
            d.get('month') is month.id and
            d.get('day') is day.id
        )[0]?.id or null
    ).property('year', 'month', 'day')

    makeYearOption: (d) -> id: d, text: d, key: 'year'
    
    makeMonthOption: (d) -> 
      id: d, text: monthFmt(d), key: 'month'
    
    makeDayOption: (d) ->    
      day = d.get('day')
      dayName = d.get('date_text').replace(',', '').split(' ')[0].trim()
      id: day, text: '%@ %@'.fmt(dayName, day), key: 'day'

    years: (() ->
      @getEach('year')
        .map(@makeYearOption)
    ).property('content')

    months: (() ->
      year = parseInt @get 'year.id', 10
      if not year then return []
      @filter((d) -> d.get('year') is year)
        .getEach('month')
        .map(@makeMonthOption)
    ).property('content', 'year')

    days: (() ->
      year = parseInt @get 'year.id', 10
      month = parseInt @get 'month.id', 10
      if not year and month then return []
      @filter((d) -> d.get('year') is year and d.get('month') is month)
        .map(@makeDayOption)
    ).property('content', 'year', 'month')

    sectionOptions: (() ->
      active = @get 'section.id'
      @get('sections').map((d) ->
        id = d.get 'id'
        id: id
        articles: d.get 'articles'
        text: id
        active: id is active
      ).sort (a, b) -> d3.ascending a.id, b.id
    ).property('sections', 'section')

    transitionToSection: () ->
      articles = @get 'section.articles'
      if articles
        @transitionToRoute 'content.type.section', @store
          .findByIds 'article', articles

    updateSections: () ->
      sections = @store.find 'section',
        date: @get('date')
        content_type: @get 'controllers.content.active.id'
      @set 'sections', sections
      sections.then (data) =>
        @notifyPropertyChange 'sections'
        preferred_id = @get 'section.id'
        preferred = if preferred_id then data.findProperty 'id', preferred_id else null
        section = if preferred then preferred else data.get('content.0')
        @send 'changeSection', section

    actions:
      changeDate: (date) ->
        @set date.key, date
        if date.key is 'year'
          @set 'month', @get('months.0')
          @set 'day', @get('days.0')
        else if date.key is 'month'
          @set 'day', @get('days.0')
        @updateSections().then(_.bind @transitionToSection, @)

      changeSection: (section) ->
        @set 'section', section
        @transitionToSection()

      nextDate: () ->
        days = @get 'days'
        if day = days[days.indexOf(days.findProperty 'id', @get 'day.id') + 1]
          return @send 'changeDate', day
        months = @get 'months'
        if month = months[months.indexOf(months.findProperty 'id', @get 'month.id') + 1]
          return @send 'changeDate', month
        years = @get 'years'
        if year = years[years.indexOf(months.findProperty 'id', @get 'year.id') + 1]
          return @send 'changeDate', year
        @send 'changeDate', years[0]

      previousDate: () ->
        days = @get 'days'
        if day = days[days.indexOf(days.findProperty 'id', @get 'day.id') - 1]
          return @send 'changeDate', day
        months = @get 'months'
        if month = months[months.indexOf(months.findProperty 'id', @get 'month.id') - 1]
          @set 'month', month
          return @send 'changeDate', (days = @get 'days')[days.length - 1]
        years = @get 'years'
        if year = years[years.indexOf(months.findProperty 'id', @get 'year.id') - 1]
          @set 'year', year
        else
          @set 'year', years[years.length - 1]
        @set 'months', (months = @get 'months')[months.length - 1]
        @send 'changeDate', (days = @get 'days')[days.length - 1]

  App.ContentTypeSectionController = Ember.ArrayController.extend
    needs: ['contentType']

    sectionChanged: (() ->
      section = @get 'controllers.contentType.section'
      if section is null then @set 'content', []
    ).observes('controllers.contentType.section')